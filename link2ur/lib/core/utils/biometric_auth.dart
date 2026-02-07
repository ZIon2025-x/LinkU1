import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'logger.dart';

/// 生物认证管理器
/// 参考iOS BiometricAuth.swift
/// 封装 Face ID / Touch ID / 指纹认证功能
class BiometricAuthManager {
  BiometricAuthManager._();

  static final BiometricAuthManager instance = BiometricAuthManager._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// 检查设备是否支持生物认证
  Future<bool> get isAvailable async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      AppLogger.error('BiometricAuth - Check availability failed', e);
      return false;
    }
  }

  /// 获取可用的生物认证类型
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      AppLogger.error('BiometricAuth - Get biometrics failed', e);
      return [];
    }
  }

  /// 是否支持Face ID
  Future<bool> get hasFaceId async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// 是否支持指纹
  Future<bool> get hasFingerprint async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint);
  }

  /// 执行生物认证
  /// [localizedReason] 显示给用户的认证原因
  /// [useErrorDialogs] 是否使用系统错误弹窗
  /// [stickyAuth] 是否在应用切换后继续认证
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final available = await isAvailable;
      if (!available) {
        return const BiometricAuthResult(
          success: false,
          error: BiometricAuthError.notAvailable,
          message: '设备不支持生物认证',
        );
      }

      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: false,
        ),
      );

      return BiometricAuthResult(
        success: authenticated,
        error: authenticated ? null : BiometricAuthError.failed,
        message: authenticated ? '认证成功' : '认证失败',
      );
    } on PlatformException catch (e) {
      AppLogger.error('BiometricAuth - Platform error', e);
      return BiometricAuthResult(
        success: false,
        error: _mapError(e),
        message: e.message ?? '认证出错',
      );
    } catch (e) {
      AppLogger.error('BiometricAuth - Unknown error', e);
      return const BiometricAuthResult(
        success: false,
        error: BiometricAuthError.unknown,
        message: '认证出错',
      );
    }
  }

  BiometricAuthError _mapError(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return BiometricAuthError.notAvailable;
      case 'NotEnrolled':
        return BiometricAuthError.notEnrolled;
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return BiometricAuthError.lockedOut;
      case 'PasscodeNotSet':
        return BiometricAuthError.passcodeNotSet;
      default:
        return BiometricAuthError.unknown;
    }
  }
}

/// 生物认证结果
class BiometricAuthResult {
  const BiometricAuthResult({
    required this.success,
    this.error,
    this.message,
  });

  final bool success;
  final BiometricAuthError? error;
  final String? message;
}

/// 生物认证错误类型
enum BiometricAuthError {
  /// 设备不支持
  notAvailable,

  /// 未注册生物信息
  notEnrolled,

  /// 认证失败
  failed,

  /// 已被锁定（多次尝试失败）
  lockedOut,

  /// 未设置密码
  passcodeNotSet,

  /// 未知错误
  unknown,
}
