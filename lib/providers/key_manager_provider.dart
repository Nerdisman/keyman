import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssh_key_manager/models/ssh_key.dart';
import 'package:ssh_key_manager/utils/key_generator.dart';
import 'package:ssh_key_manager/utils/file_utils.dart';

class KeyManagerProvider extends ChangeNotifier {
  static const String _keyStoreFileName = 'keyman_keys.json';

  final List<SSHKey> _keys = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _keyStorePath;

  List<SSHKey> get keys => List.unmodifiable(_keys);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  KeyManagerProvider();

  static Future<KeyManagerProvider> create() async {
    final provider = KeyManagerProvider();
    await provider._initKeyStore();
    return provider;
  }

  Future<void> _initKeyStore() async {
    final appDir = await getApplicationDocumentsDirectory();
    _keyStorePath = '${appDir.path}${Platform.pathSeparator}keyman';
    final keyStoreDir = Directory(_keyStorePath!);
    if (!await keyStoreDir.exists()) {
      await keyStoreDir.create(recursive: true);
    }
  }

  Future<void> loadKeys() async {
    if (_keyStorePath == null) {
      await _initKeyStore();
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final keyStoreFile = File('$_keyStorePath$_keyStoreFileName');

      if (await keyStoreFile.exists()) {
        final jsonString = await keyStoreFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _keys.clear();
        _keys.addAll(jsonList.map((e) => SSHKey.fromJson(e)));
        await _validateKeys();
      }
    } catch (e) {
      _errorMessage = '加载密钥列表失败: ${e.toString()}';
      _keys.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _validateKeys() async {
    for (int i = 0; i < _keys.length; i++) {
      final key = _keys[i];
      final privateExists = await File(key.privateKeyPath).exists();
      final publicExists = await File(key.publicKeyPath).exists();

      KeyStatus newStatus;
      if (!privateExists || !publicExists) {
        newStatus = KeyStatus.missing;
      } else {
        newStatus = await FileUtils.validateKeyPair(
            key.privateKeyPath, key.publicKeyPath);
      }

      _keys[i] = key.copyWith(status: newStatus);
    }

    _keys.removeWhere((key) => key.status == KeyStatus.missing);
    await _saveKeys();
  }

  Future<void> _saveKeys() async {
    if (_keyStorePath == null) {
      await _initKeyStore();
    }

    try {
      final keyStoreFile = File('$_keyStorePath$_keyStoreFileName');
      final jsonList = _keys.map((k) => k.toJson()).toList();
      await keyStoreFile.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      _errorMessage = '保存密钥列表失败: ${e.toString()}';
    }
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

      final isValid =
          await FileUtils.validateKeyPair(privateKeyPath, publicKeyPath);
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
      final privateFile = File(key.privateKeyPath);
      final publicFile = File(key.publicKeyPath);

      if (await privateFile.exists()) {
        await privateFile.delete();
      }
      if (await publicFile.exists()) {
        await publicFile.delete();
      }

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
      final status =
          await FileUtils.validateKeyPair(privateKeyPath, publicKeyPath);
      if (status != KeyStatus.valid) {
        _errorMessage = '密钥文件无效或损坏';
        return false;
      }

      final fileName = privateKeyPath.split(Platform.pathSeparator).last;
      final keyType = _detectKeyType(privateKeyPath);
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

  KeyType _detectKeyType(String path) {
    final fileName = path.toLowerCase();
    if (fileName.contains('rsa')) {
      return KeyType.rsa2048;
    } else if (fileName.contains('ed25519')) {
      return KeyType.ed25519;
    }
    return KeyType.rsa2048;
  }

  Future<bool> _checkPassphrase(String privateKeyPath) async {
    try {
      final content = await File(privateKeyPath).readAsString();
      return content.contains('ENCRYPTED');
    } catch (e) {
      return false;
    }
  }
}
