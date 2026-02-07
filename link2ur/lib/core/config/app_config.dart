import 'package:flutter/foundation.dart';

/// 应用配置管理
class AppConfig {
  AppConfig._();
  static final AppConfig instance = AppConfig._();

  /// 环境类型
  AppEnvironment _environment = AppEnvironment.production;
  AppEnvironment get environment => _environment;

  /// API基础URL
  String get baseUrl {
    switch (_environment) {
      case AppEnvironment.development:
        return 'https://linktest.up.railway.app';
      case AppEnvironment.staging:
        return 'https://linktest.up.railway.app';
      case AppEnvironment.production:
        return 'https://api.link2ur.com';
    }
  }

  /// WebSocket URL
  String get wsUrl {
    switch (_environment) {
      case AppEnvironment.development:
        return 'wss://linktest.up.railway.app';
      case AppEnvironment.staging:
        return 'wss://linktest.up.railway.app';
      case AppEnvironment.production:
        return 'wss://api.link2ur.com';
    }
  }

  /// Stripe公钥
  String get stripePublishableKey {
    switch (_environment) {
      case AppEnvironment.development:
      case AppEnvironment.staging:
        return const String.fromEnvironment(
          'STRIPE_PUBLISHABLE_KEY_TEST',
          defaultValue: '',
        );
      case AppEnvironment.production:
        return const String.fromEnvironment(
          'STRIPE_PUBLISHABLE_KEY_LIVE',
          defaultValue: '',
        );
    }
  }

  /// Apple Pay商户标识
  String get applePayMerchantId => 'merchant.com.link2ur.app';

  /// 请求超时时间
  Duration get requestTimeout => const Duration(seconds: 30);

  /// 是否启用调试日志
  bool get enableDebugLog => kDebugMode || _environment != AppEnvironment.production;

  /// 初始化配置
  Future<void> init() async {
    // 从环境变量读取环境类型
    const envString = String.fromEnvironment('ENV', defaultValue: 'production');
    _environment = AppEnvironment.values.firstWhere(
      (e) => e.name == envString,
      orElse: () => AppEnvironment.production,
    );

    if (kDebugMode) {
      _environment = AppEnvironment.development;
    }
  }
}

/// 应用环境类型
enum AppEnvironment {
  development,
  staging,
  production,
}
