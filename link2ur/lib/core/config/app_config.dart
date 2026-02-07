import 'package:flutter/foundation.dart';

import '../utils/logger.dart';

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

    // 验证关键配置
    _validateConfiguration();
  }

  /// 验证配置的完整性
  void _validateConfiguration() {
    // 验证 Stripe 密钥配置
    final stripeKey = stripePublishableKey;

    if (stripeKey.isEmpty) {
      final envName = _environment.name.toUpperCase();
      final keyName = _environment == AppEnvironment.production
          ? 'STRIPE_PUBLISHABLE_KEY_LIVE'
          : 'STRIPE_PUBLISHABLE_KEY_TEST';

      final errorMessage = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  Stripe 配置缺失

环境: $envName
缺少环境变量: $keyName

请在构建时提供 Stripe 密钥：
  flutter run --dart-define=$keyName=pk_test_xxx
  flutter build --dart-define=$keyName=pk_test_xxx

或在开发环境中，您可以在 launch.json 中配置：
  "args": ["--dart-define=$keyName=pk_test_xxx"]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';

      if (_environment == AppEnvironment.production) {
        // 生产环境必须配置，否则抛出错误
        AppLogger.error('Stripe configuration missing in production',
          Exception(errorMessage));
        throw StateError('Stripe publishable key is required in production environment.\n$errorMessage');
      } else {
        // 开发/测试环境仅警告
        AppLogger.warning(errorMessage);
        debugPrint(errorMessage);
      }
    } else {
      // 验证密钥格式
      final expectedPrefix = _environment == AppEnvironment.production ? 'pk_live_' : 'pk_test_';
      if (!stripeKey.startsWith(expectedPrefix)) {
        AppLogger.warning(
          'Stripe key format warning: Expected key to start with "$expectedPrefix" but got "${stripeKey.substring(0, 8)}..."'
        );
      } else {
        AppLogger.info('Stripe configuration validated successfully for ${_environment.name}');
      }
    }

    // 验证 API 基础 URL 可访问性（仅记录）
    AppLogger.info('API Base URL: $baseUrl');
    AppLogger.info('WebSocket URL: $wsUrl');
  }
}

/// 应用环境类型
enum AppEnvironment {
  development,
  staging,
  production,
}
