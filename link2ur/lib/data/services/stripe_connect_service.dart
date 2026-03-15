import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import '../../core/utils/logger.dart';

/// Stripe Connect 原生服务
/// 通过 MethodChannel 调用 Android/iOS 原生 SDK 进行 Onboarding
class StripeConnectService {
  StripeConnectService._();
  static final StripeConnectService instance = StripeConnectService._();

  static const _channel = MethodChannel('com.link2ur/stripe_connect');

  /// 打开原生 Onboarding 页面
  ///
  /// [publishableKey] Stripe Publishable Key
  /// [clientSecret] AccountSession client_secret（Flutter 层在调用前已获取 fresh secret）
  ///
  /// 返回结果：
  /// - `completed`: 用户完成入驻
  /// - `cancelled`: 用户取消
  /// - 抛出异常: 加载失败或其他错误
  Future<String> openOnboarding({
    required String publishableKey,
    required String clientSecret,
  }) async {
    try {
      final result = await _channel.invokeMethod('openOnboarding', {
        'publishableKey': publishableKey,
        'clientSecret': clientSecret,
      });

      if (result is Map) {
        return result['status'] as String? ?? 'unknown';
      }
      return 'unknown';
    } on PlatformException catch (e) {
      AppLogger.error('StripeConnectService: openOnboarding failed', e);
      rethrow;
    } catch (e) {
      AppLogger.error('StripeConnectService: openOnboarding unknown error', e);
      rethrow;
    }
  }

  /// 打开原生账户管理页面（用于已完成 onboarding 的 V2 账户更新收款信息）
  ///
  /// [publishableKey] Stripe Publishable Key
  /// [clientSecret] AccountSession client_secret（需包含 account_management 组件）
  ///
  /// 注意：Android Stripe Connect SDK 不支持嵌入式账户管理组件，
  /// 调用方应在 Android 上改用 Express Dashboard URL。
  /// 此方法在 Android 上会抛出 [UnsupportedError]。
  Future<String> openAccountManagement({
    required String publishableKey,
    required String clientSecret,
  }) async {
    if (Platform.isAndroid) {
      throw UnsupportedError(
        'Embedded account management is not available on Android. '
        'Use Express Dashboard URL instead.',
      );
    }
    try {
      final result = await _channel.invokeMethod('openAccountManagement', {
        'publishableKey': publishableKey,
        'clientSecret': clientSecret,
      });

      if (result is Map) {
        return result['status'] as String? ?? 'unknown';
      }
      return 'unknown';
    } on PlatformException catch (e) {
      AppLogger.error('StripeConnectService: openAccountManagement failed', e);
      rethrow;
    } catch (e) {
      AppLogger.error('StripeConnectService: openAccountManagement unknown error', e);
      rethrow;
    }
  }
}
