import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'logger.dart';

/// 安全管理器
/// 对齐 iOS SecurityManager.swift
/// 提供 AES 加密/解密、安全存储、敏感数据掩码
class SecurityManager {
  SecurityManager._();
  static final SecurityManager instance = SecurityManager._();

  static const String _keyStorageKey = 'security_manager_aes_key';
  static const String _ivStorageKey = 'security_manager_aes_iv';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  enc.Key? _key;
  enc.IV? _iv;

  /// 初始化安全管理器
  /// 从安全存储中加载或生成 AES 密钥
  Future<void> initialize() async {
    try {
      // 尝试加载已有密钥
      final keyBase64 = await _secureStorage.read(key: _keyStorageKey);
      final ivBase64 = await _secureStorage.read(key: _ivStorageKey);

      if (keyBase64 != null && ivBase64 != null) {
        _key = enc.Key.fromBase64(keyBase64);
        _iv = enc.IV.fromBase64(ivBase64);
      } else {
        // 生成新密钥
        _key = enc.Key.fromSecureRandom(32); // 256-bit
        _iv = enc.IV.fromSecureRandom(16); // 128-bit

        // 保存到安全存储
        await _secureStorage.write(
            key: _keyStorageKey, value: _key!.base64);
        await _secureStorage.write(
            key: _ivStorageKey, value: _iv!.base64);
      }

      AppLogger.info('SecurityManager initialized');
    } catch (e) {
      AppLogger.error('SecurityManager initialization failed', e);
    }
  }

  // ==================== AES 加密/解密 ====================

  /// AES 加密数据
  /// 返回 Base64 编码的加密字符串
  String? encrypt(String plainText) {
    if (_key == null || _iv == null) {
      AppLogger.warning('SecurityManager: Not initialized');
      return null;
    }

    try {
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      AppLogger.error('SecurityManager: Encrypt failed', e);
      return null;
    }
  }

  /// AES 解密数据
  /// [encryptedBase64] Base64 编码的加密字符串
  String? decrypt(String encryptedBase64) {
    if (_key == null || _iv == null) {
      AppLogger.warning('SecurityManager: Not initialized');
      return null;
    }

    try {
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
      final decrypted =
          encrypter.decrypt64(encryptedBase64, iv: _iv);
      return decrypted;
    } catch (e) {
      AppLogger.error('SecurityManager: Decrypt failed', e);
      return null;
    }
  }

  /// 加密字节数据
  Uint8List? encryptBytes(Uint8List data) {
    if (_key == null || _iv == null) return null;

    try {
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(data.toList(), iv: _iv);
      return encrypted.bytes;
    } catch (e) {
      AppLogger.error('SecurityManager: Encrypt bytes failed', e);
      return null;
    }
  }

  /// 解密字节数据
  Uint8List? decryptBytes(Uint8List encryptedData) {
    if (_key == null || _iv == null) return null;

    try {
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
      final encrypted = enc.Encrypted(encryptedData);
      final decrypted = encrypter.decryptBytes(encrypted, iv: _iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      AppLogger.error('SecurityManager: Decrypt bytes failed', e);
      return null;
    }
  }

  // ==================== 安全存储 ====================

  /// 安全存储数据
  Future<void> secureStore(String data, {required String key}) async {
    try {
      final encrypted = encrypt(data);
      if (encrypted != null) {
        await _secureStorage.write(key: key, value: encrypted);
      }
    } catch (e) {
      AppLogger.error('SecurityManager: Secure store failed', e);
    }
  }

  /// 安全读取数据
  Future<String?> secureRetrieve({required String key}) async {
    try {
      final encrypted = await _secureStorage.read(key: key);
      if (encrypted != null) {
        return decrypt(encrypted);
      }
    } catch (e) {
      AppLogger.error('SecurityManager: Secure retrieve failed', e);
    }
    return null;
  }

  /// 安全删除数据
  Future<void> secureDelete({required String key}) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      AppLogger.error('SecurityManager: Secure delete failed', e);
    }
  }

  // ==================== 敏感数据掩码 ====================

  /// 掩码敏感数据（用于日志）
  /// 保留前 2 位和后 2 位，中间用 * 替换
  static String maskSensitiveData(String data) {
    if (data.length <= 4) {
      return '*' * data.length;
    }
    final prefix = data.substring(0, 2);
    final suffix = data.substring(data.length - 2);
    final masked = '*' * (data.length - 4);
    return '$prefix$masked$suffix';
  }

  /// 掩码手机号
  static String maskPhone(String phone) {
    if (phone.length < 7) return '*' * phone.length;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  /// 掩码邮箱
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return maskSensitiveData(email);
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '$name***@$domain';
    return '${name.substring(0, 2)}***@$domain';
  }

  /// 掩码银行卡号
  static String maskCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length < 8) return '*' * cleaned.length;
    return '${cleaned.substring(0, 4)} **** **** ${cleaned.substring(cleaned.length - 4)}';
  }

  // ==================== 证书验证 ====================

  /// 验证 SSL 证书（在 Flutter 中通过 Dio 的证书验证完成）
  /// 这里提供一个标志位
  bool get enableCertificatePinning => true;

  // ==================== 安全错误 ====================
}

/// 安全异常
class SecurityException implements Exception {
  SecurityException(this.message);
  final String message;

  @override
  String toString() => 'SecurityException: $message';
}
