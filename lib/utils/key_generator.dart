import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:ssh_key_manager/models/ssh_key.dart';

class _Ed25519PrivateKey implements PrivateKey {
  final List<int> privateKey;
  final List<int> publicKey;

  _Ed25519PrivateKey(this.privateKey, this.publicKey);
}

class _Ed25519PublicKey implements PublicKey {
  final List<int> publicKey;

  _Ed25519PublicKey(this.publicKey);
}

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
    } else if (type == KeyType.ed25519) {
      keyPair = _generateEd25519KeyPair(secureRandom);
    } else {
      throw Exception('不支持的密钥类型');
    }

    final privateKeyPem =
        _encodePrivateKey(keyPair.privateKey, passphrase, type);
    final publicKeySsh = _encodePublicKey(keyPair.publicKey, type, comment);

    await File(privateKeyPath).writeAsString(privateKeyPem);
    await File(publicKeyPath).writeAsString(publicKeySsh);
  }

  static AsymmetricKeyPair<PublicKey, PrivateKey> _generateEd25519KeyPair(
      FortunaRandom secureRandom) {
    final privateKey = secureRandom.nextBytes(32);
    final publicKey = _deriveEd25519PublicKey(privateKey);
    return AsymmetricKeyPair<PublicKey, PrivateKey>(
      _Ed25519PublicKey(publicKey),
      _Ed25519PrivateKey(privateKey, publicKey),
    );
  }

  static List<int> _deriveEd25519PublicKey(List<int> privateKey) {
    final hash = sha512.convert(privateKey).bytes;
    final s = Uint8List.fromList(hash.sublist(0, 32));
    s[0] &= 248;
    s[31] &= 127;
    s[31] |= 64;

    final A = _scalarMultBase(s);
    return A;
  }

  static List<int> _scalarMultBase(Uint8List scalar) {
    final result = Uint8List(32);
    for (int i = 255; i >= 0; i--) {
      final bit = (scalar[i ~/ 8] >> (i % 8)) & 1;
      if (bit == 1) {
        for (int j = 0; j < 32; j++) {
          result[j] ^= _ed25519BasePoint[j];
        }
      }
    }
    return result.toList();
  }

  static final Uint8List _ed25519BasePoint = Uint8List.fromList([
    0x21,
    0x69,
    0x36,
    0xD3,
    0xCD,
    0x6E,
    0x53,
    0xFE,
    0xC0,
    0xA4,
    0xE2,
    0x31,
    0xFD,
    0x67,
    0x96,
    0x32,
    0x93,
    0x5A,
    0xE4,
    0x26,
    0x45,
    0x3B,
    0x95,
    0x4D,
    0xDA,
    0xD1,
    0x91,
    0x3C,
    0xE2,
    0xC0,
    0x4B,
    0x3D,
  ]);

  static String _encodePrivateKey(
      PrivateKey privateKey, String? passphrase, KeyType type) {
    if (privateKey is RSAPrivateKey) {
      return _encodeRSAPrivateKey(privateKey, passphrase);
    }
    if (privateKey is _Ed25519PrivateKey) {
      return _encodeEd25519PrivateKey(privateKey, passphrase);
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
    final cipher = CBCBlockCipher(AESEngine())
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
    if (publicKey is _Ed25519PublicKey) {
      return _encodeEd25519PublicKey(publicKey, comment);
    }
    throw Exception('不支持的密钥类型');
  }

  static String _encodeEd25519PrivateKey(
      _Ed25519PrivateKey key, String? passphrase) {
    final privateBytes = key.privateKey;
    final publicBytes = key.publicKey;

    final content = List<int>.from(privateBytes)..addAll(publicBytes);
    final base64Content = base64.encode(content);

    if (passphrase != null && passphrase.isNotEmpty) {
      return _encryptEd25519PrivateKey(base64Content, passphrase);
    }

    return '-----BEGIN OPENSSH PRIVATE KEY-----\n${_formatBase64(base64Content)}-----END OPENSSH PRIVATE KEY-----';
  }

  static String _encryptEd25519PrivateKey(
      String base64Content, String passphrase) {
    final iv = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final key = _deriveKey(passphrase, iv.sublist(0, 8));
    final cipher = CBCBlockCipher(AESEngine())
      ..init(
          true,
          ParametersWithIV(
              KeyParameter(Uint8List.fromList(key)), Uint8List.fromList(iv)));

    final paddedContent = _pkcs7Pad(base64Content.codeUnits, 16);
    final encrypted = cipher.process(Uint8List.fromList(paddedContent));

    final encryptedBase64 = base64.encode(encrypted);

    return '-----BEGIN OPENSSH PRIVATE KEY-----\nProc-Type: 4,ENCRYPTED\nDEK-Info: AES-256-CBC,${_bytesToHex(iv)}\n\n${_formatBase64(encryptedBase64)}-----END OPENSSH PRIVATE KEY-----';
  }

  static String _encodeEd25519PublicKey(
      _Ed25519PublicKey key, String? comment) {
    final algorithm = utf8.encode('ssh-ed25519');
    final publicBytes = key.publicKey;

    final length1 = _encodeInt(algorithm.length);
    final length2 = _encodeInt(publicBytes.length);

    final bytes = List<int>.from(length1)
      ..addAll(algorithm)
      ..addAll(length2)
      ..addAll(publicBytes);
    final base64Content = base64.encode(bytes);

    return 'ssh-ed25519 $base64Content${comment != null ? ' $comment' : ''}';
  }

  static String _encodeRSAPublicKey(RSAPublicKey key, String? comment) {
    final algorithm = utf8.encode('ssh-rsa');
    final exponent = _encodeBigInt(key.exponent!);
    final modulus = _encodeBigInt(key.modulus!);

    final length1 = _encodeInt(algorithm.length);
    final length2 = _encodeInt(exponent.length);
    final length3 = _encodeInt(modulus.length);

    final bytes = List<int>.from(length1)
      ..addAll(algorithm)
      ..addAll(length2)
      ..addAll(exponent)
      ..addAll(length3)
      ..addAll(modulus);
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
    return List<int>.from(data)..addAll(List.filled(padLength, padLength));
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }
}
