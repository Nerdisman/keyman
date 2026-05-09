import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes_fast.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:ssh_key_manager/models/ssh_key.dart';

class KeyGenerator {
  static Future<void> generateKey({
    required KeyType type,
    required String privateKeyPath,
    required String publicKeyPath,
    String? passphrase,
    String? comment,
  }) async {
    final secureRandom = FortunaRandom();
    final seed = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seed)));

    AsymmetricKeyPair<PublicKey, PrivateKey> keyPair;

    if (type == KeyType.rsa2048 || type == KeyType.rsa4096) {
      final rsaGenerator = RSAKeyGenerator()
        ..init(ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), type.bits, 64),
          secureRandom,
        ));
      keyPair = rsaGenerator.generateKeyPair();
    } else {
      throw Exception('Ed25519 密钥生成暂不支持');
    }

    final privateKeyPem = _encodePrivateKey(keyPair.privateKey, passphrase);
    final publicKeySsh = _encodePublicKey(keyPair.publicKey, type, comment);

    await File(privateKeyPath).writeAsString(privateKeyPem);
    await File(publicKeyPath).writeAsString(publicKeySsh);
  }

  static String _encodePrivateKey(PrivateKey privateKey, String? passphrase) {
    if (privateKey is RSAPrivateKey) {
      return _encodeRSAPrivateKey(privateKey, passphrase);
    }
    throw Exception('不支持的密钥类型');
  }

  static String _encodeRSAPrivateKey(RSAPrivateKey key, String? passphrase) {
    final modulus = _encodeBigInt(key.modulus!);
    final publicExponent = _encodeBigInt(key.publicExponent!);
    final privateExponent = _encodeBigInt(key.privateExponent!);

    final p = _encodeBigInt(key.p!);
    final q = _encodeBigInt(key.q!);

    final dmp1 = _encodeBigInt(key.privateExponent! % (key.p! - BigInt.one));
    final dmq1 = _encodeBigInt(key.privateExponent! % (key.q! - BigInt.one));
    final iqmp = _modInverse(key.q!, key.p!);
    final iqmpEncoded = _encodeBigInt(iqmp);

    final sequence = [
      0,
      modulus,
      publicExponent,
      privateExponent,
      p,
      q,
      dmp1,
      dmq1,
      iqmpEncoded,
    ];

    final der = _encodeSequence(sequence);
    final base64Content = base64.encode(der);

    if (passphrase != null && passphrase.isNotEmpty) {
      return _encryptPrivateKey(base64Content, passphrase);
    }

    return '-----BEGIN RSA PRIVATE KEY-----\n${_formatBase64(base64Content)}-----END RSA PRIVATE KEY-----';
  }

  static BigInt _modInverse(BigInt a, BigInt m) {
    BigInt m0 = m;
    BigInt y = BigInt.zero;
    BigInt x = BigInt.one;

    if (m == BigInt.one) {
      return BigInt.zero;
    }

    while (a > BigInt.one) {
      BigInt q = a ~/ m;
      BigInt t = m;
      m = a % m;
      a = t;
      t = y;
      y = x - q * y;
      x = t;
    }

    if (x < BigInt.zero) {
      x += m0;
    }

    return x;
  }

  static String _encryptPrivateKey(String base64Content, String passphrase) {
    final iv = List<int>.generate(16, (_) => Random.secure().nextInt(256));

    final key = _deriveKey(passphrase, iv.sublist(0, 8));
    final cipher = CBCBlockCipher(AESFastEngine())
      ..init(
          true,
          ParametersWithIV(
              KeyParameter(Uint8List.fromList(key)), Uint8List.fromList(iv)));

    final paddedContent = _pkcs7Pad(base64Content.codeUnits, 16);
    final encrypted = cipher.process(Uint8List.fromList(paddedContent));

    final encryptedBase64 = base64.encode(encrypted);

    return '-----BEGIN RSA PRIVATE KEY-----\nProc-Type: 4,ENCRYPTED\nDEK-Info: AES-256-CBC,${_bytesToHex(iv)}\n\n${_formatBase64(encryptedBase64)}-----END RSA PRIVATE KEY-----';
  }

  static List<int> _deriveKey(String passphrase, List<int> salt) {
    const iterations = 10000;
    final hmac = HMac(SHA256Digest(), 64)
      ..init(KeyParameter(Uint8List.fromList(passphrase.codeUnits)));

    Uint8List key = Uint8List.fromList(salt);
    for (int i = 0; i < iterations; i++) {
      key = hmac.process(key);
    }

    return key.sublist(0, 32);
  }

  static String _encodePublicKey(
      PublicKey publicKey, KeyType type, String? comment) {
    if (publicKey is RSAPublicKey) {
      return _encodeRSAPublicKey(publicKey, comment);
    }
    throw Exception('不支持的密钥类型');
  }

  static String _encodeRSAPublicKey(RSAPublicKey key, String? comment) {
    final algorithm = utf8.encode('ssh-rsa');
    final exponent = _encodeBigInt(key.exponent!);
    final modulus = _encodeBigInt(key.modulus!);

    final length1 = _encodeInt(algorithm.length);
    final length2 = _encodeInt(exponent.length);
    final length3 = _encodeInt(modulus.length);

    final bytes = [
      ...length1,
      ...algorithm,
      ...length2,
      ...exponent,
      ...length3,
      ...modulus
    ];
    final base64Content = base64.encode(bytes);

    return 'ssh-rsa $base64Content${comment != null ? ' $comment' : ''}';
  }

  static List<int> _encodeBigInt(BigInt number) {
    if (number == BigInt.zero) {
      return [0];
    }

    final bitLength = number.bitLength;
    final byteLength = (bitLength + 7) ~/ 8;
    final result = Uint8List(byteLength);

    for (int i = byteLength - 1; i >= 0; i--) {
      result[i] = (number & BigInt.from(0xff)).toInt();
      number = number >> 8;
    }

    if (result.isNotEmpty && result[0] >= 128) {
      return [0, ...result];
    }
    return result.toList();
  }

  static List<int> _encodeInt(int number) {
    return [
      (number >> 24) & 0xFF,
      (number >> 16) & 0xFF,
      (number >> 8) & 0xFF,
      number & 0xFF,
    ];
  }

  static List<int> _encodeSequence(List<dynamic> items) {
    final parts = <int>[];
    for (final item in items) {
      if (item is int) {
        parts.addAll([0x02, 0x01, item]);
      } else if (item is List<int>) {
        final length = item.length;
        if (length < 128) {
          parts.addAll([0x02, length, ...item]);
        } else {
          final lengthBytes = _encodeInt(length);
          parts.addAll(
              [0x02, 0x80 + lengthBytes.length, ...lengthBytes, ...item]);
        }
      }
    }

    final length = parts.length;
    if (length < 128) {
      return [0x30, length, ...parts];
    } else {
      final lengthBytes = _encodeInt(length);
      return [0x30, 0x80 + lengthBytes.length, ...lengthBytes, ...parts];
    }
  }

  static String _formatBase64(String content) {
    final lines = <String>[];
    for (int i = 0; i < content.length; i += 64) {
      lines.add(content.substring(
          i, i + 64 > content.length ? content.length : i + 64));
    }
    return lines.join('\n');
  }

  static List<int> _pkcs7Pad(List<int> data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    return [...data, ...List.filled(padLength, padLength)];
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }
}
