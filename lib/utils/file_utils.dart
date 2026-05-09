import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:ssh_key_manager/models/ssh_key.dart';

class FileUtils {
  static Future<String> getDefaultSSHPath() async {
    final homeDir = await getApplicationDocumentsDirectory();
    return '${homeDir.path}${Platform.pathSeparator}.ssh';
  }

  static Future<KeyStatus> validateKeyPair(
      String privateKeyPath, String publicKeyPath) async {
    try {
      final privateFile = File(privateKeyPath);
      final publicFile = File(publicKeyPath);

      if (!await privateFile.exists()) {
        return KeyStatus.missing;
      }

      if (!await publicFile.exists()) {
        return KeyStatus.missing;
      }

      final privateContent = await privateFile.readAsString();
      final publicContent = await publicFile.readAsString();

      if (!privateContent.startsWith('-----BEGIN') ||
          !privateContent.contains('-----END')) {
        return KeyStatus.invalid;
      }

      if (!publicContent.startsWith('ssh-') &&
          !publicContent.startsWith('ecdsa-sha2-')) {
        return KeyStatus.invalid;
      }

      return KeyStatus.valid;
    } catch (e) {
      return KeyStatus.invalid;
    }
  }

  static Future<String> readPublicKey(String publicKeyPath) async {
    final file = File(publicKeyPath);
    if (!await file.exists()) {
      throw Exception('公钥文件不存在');
    }
    return await file.readAsString();
  }

  static Future<void> openFileLocation(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在');
    }

    final directory = file.parent.path;
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [directory]);
    }
  }

  static Future<void> backupConfig(String configPath, String backupPath) async {
    final file = File(configPath);
    if (await file.exists()) {
      await file.copy(backupPath);
    }
  }

  static bool isValidFilePath(String path) {
    try {
      final file = File(path);
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }
}
