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
  /// [clientSecret] AccountSession client_secret
  /// [apiBaseUrl] 后端 API 基础 URL（供原生 Activity 刷新 client_secret 用）
  /// [authToken] 用户认证 token（供原生 Activity 调用后端 API 用）
  /// 
  /// 返回结果：
  /// - `completed`: 用户完成入驻
  /// - `cancelled`: 用户取消
  /// - 抛出异常: 加载失败或其他错误
  Future<String> openOnboarding({
    required String publishableKey,
    required String clientSecret,
    String? apiBaseUrl,
    String? authToken,
  }) async {
    try {
      final result = await _channel.invokeMethod('openOnboarding', {
        'publishableKey': publishableKey,
        'clientSecret': clientSecret,
        'apiBaseUrl': apiBaseUrl,
        'authToken': authToken,
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
}
