import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_key_manager/models/ssh_key.dart';
import 'package:ssh_key_manager/utils/key_generator.dart';
import 'package:ssh_key_manager/utils/file_utils.dart';

class KeyManagerProvider extends ChangeNotifier {
  static const _keysKey = 'ssh_keys';
  final SharedPreferences _prefs;
  List<SSHKey> _keys = [];
  bool _isLoading = false;
  String? _errorMessage;

  KeyManagerProvider(this._prefs);

  List<SSHKey> get keys => _keys;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadKeys() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final jsonString = _prefs.getString(_keysKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _keys = jsonList.map((e) => SSHKey.fromJson(e)).toList();
        await _validateKeys();
      } else {
        await _loadKeysFromDefaultPath();
      }
    } catch (e) {
      _errorMessage = '加载密钥列表失败: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _validateKeys() async {
    for (int i = 0; i < _keys.length; i++) {
      final key = _keys[i];
      final status = await FileUtils.validateKeyPair(key.privateKeyPath, key.publicKeyPath);
      _keys[i] = key.copyWith(status: status);
    }
    await _saveKeys();
  }

  Future<void> _loadKeysFromDefaultPath() async {
    final defaultPath = await FileUtils.getDefaultSSHPath();
    final dir = Directory(defaultPath);
    
    if (!await dir.exists()) {
      return;
    }

    final files = await dir.list().where((entity) => entity is File).toList();
    final privateKeyFiles = files
        .where((f) => f.path.endsWith('_rsa') || f.path.endsWith('_ed25519'))
        .cast<File>();

    for (final privateKeyFile in privateKeyFiles) {
      final publicKeyPath = '${privateKeyFile.path}.pub';
      if (!await File(publicKeyPath).exists()) continue;

      final keyType = _detectKeyType(privateKeyFile.path);
      if (keyType == null) continue;

      final key = SSHKey(
        id: privateKeyFile.path,
        name: _extractKeyName(privateKeyFile.path),
        type: keyType,
        privateKeyPath: privateKeyFile.path,
        publicKeyPath: publicKeyPath,
        createdAt: (await privateKeyFile.stat()).modified,
        status: KeyStatus.valid,
        hasPassphrase: await _checkPassphrase(privateKeyFile.path),
      );

      _keys.add(key);
    }

    await _saveKeys();
  }

  KeyType? _detectKeyType(String path) {
    if (path.endsWith('_rsa')) {
      return KeyType.rsa2048;
    } else if (path.endsWith('_ed25519')) {
      return KeyType.ed25519;
    }
    return null;
  }

  String _extractKeyName(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    return fileName.replaceAll('_rsa', '').replaceAll('_ed25519', '');
  }

  Future<bool> _checkPassphrase(String privateKeyPath) async {
    final content = await File(privateKeyPath).readAsString();
    return content.contains('ENCRYPTED');
  }

  Future<void> _saveKeys() async {
    final jsonList = _keys.map((k) => k.toJson()).toList();
    await _prefs.setString(_keysKey, jsonEncode(jsonList));
  }

  Future<bool> generateKey({
    required String name,
    required KeyType type,
    String? comment,
    String? passphrase,
    String? customPath,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final savePath = customPath ?? await FileUtils.getDefaultSSHPath();
      await Directory(savePath).create(recursive: true);

      final privateKeyPath = '$savePath${Platform.pathSeparator}$name';
      final publicKeyPath = '$privateKeyPath.pub';

      await KeyGenerator.generateKey(
        type: type,
        privateKeyPath: privateKeyPath,
        publicKeyPath: publicKeyPath,
        passphrase: passphrase,
        comment: comment,
      );

      final isValid = await FileUtils.validateKeyPair(privateKeyPath, publicKeyPath);
      if (isValid != KeyStatus.valid) {
        _errorMessage = '密钥生成后校验失败';
        return false;
      }

      final key = SSHKey(
        id: privateKeyPath,
        name: name,
        comment: comment,
        type: type,
        privateKeyPath: privateKeyPath,
        publicKeyPath: publicKeyPath,
        createdAt: DateTime.now(),
        status: KeyStatus.valid,
        hasPassphrase: passphrase != null && passphrase.isNotEmpty,
      );

      _keys.add(key);
      await _saveKeys();
      return true;
    } catch (e) {
      _errorMessage = '生成密钥失败: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteKey(String id) async {
    try {
      final key = _keys.firstWhere((k) => k.id == id);
      await File(key.privateKeyPath).delete();
      await File(key.publicKeyPath).delete();
      _keys.removeWhere((k) => k.id == id);
      await _saveKeys();
    } catch (e) {
      _errorMessage = '删除密钥失败: ${e.toString()}';
    }
    notifyListeners();
  }

  Future<void> updateKey(String id, {String? name, String? comment}) async {
    final index = _keys.indexWhere((k) => k.id == id);
    if (index == -1) return;

    _keys[index] = _keys[index].copyWith(name: name, comment: comment);
    await _saveKeys();
    notifyListeners();
  }

  Future<void> refreshKeys() async {
    await loadKeys();
  }

  Future<bool> importKey(String privateKeyPath, String publicKeyPath) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await FileUtils.validateKeyPair(privateKeyPath, publicKeyPath);
      if (status != KeyStatus.valid) {
        _errorMessage = '密钥文件无效或损坏';
        return false;
      }

      final fileName = privateKeyPath.split(Platform.pathSeparator).last;
      final keyType = _detectKeyType(privateKeyPath) ?? KeyType.rsa2048;
      final hasPassphrase = await _checkPassphrase(privateKeyPath);

      final key = SSHKey(
        id: privateKeyPath,
        name: fileName,
        type: keyType,
        privateKeyPath: privateKeyPath,
        publicKeyPath: publicKeyPath,
        createdAt: (await File(privateKeyPath).stat()).modified,
        status: status,
        hasPassphrase: hasPassphrase,
      );

      if (!_keys.any((k) => k.id == privateKeyPath)) {
        _keys.add(key);
        await _saveKeys();
      }

      return true;
    } catch (e) {
      _errorMessage = '导入密钥失败: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
