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

  /// 移动端请求签名密钥（与后端 MOBILE_APP_SECRET 一致，用于 X-App-Signature）
  /// 通过 --dart-define=MOBILE_APP_SECRET=xxx 传入，不传则不发签名（后端会 fallback 会话验证但打 WARNING）
  static String get mobileAppSecret =>
      const String.fromEnvironment('MOBILE_APP_SECRET', defaultValue: '');

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
  String get applePayMerchantId => 'merchant.com.link2ur';

  /// Web 前端 URL（React 宣传站）
  String get webFrontendUrl {
    switch (_environment) {
      case AppEnvironment.development:
        return 'http://localhost:3000';
      case AppEnvironment.staging:
        return 'https://www.link2ur.com';
      case AppEnvironment.production:
        return 'https://www.link2ur.com';
    }
  }

  /// Flutter Web App URL（用户端 Web）
  String get webAppUrl {
    switch (_environment) {
      case AppEnvironment.development:
        return 'http://localhost:8080';
      case AppEnvironment.staging:
        return 'https://app.link2ur.com';
      case AppEnvironment.production:
        return 'https://app.link2ur.com';
    }
  }

  /// 请求超时时间
  Duration get requestTimeout => const Duration(seconds: 30);

  /// 是否启用调试日志
  bool get enableDebugLog => kDebugMode || _environment != AppEnvironment.production;

  /// 初始化配置（同步，无异步操作）
  void init() {
    // 从环境变量读取环境类型
    const envString = String.fromEnvironment('ENV', defaultValue: 'production');
    _environment = AppEnvironment.values.firstWhere(
      (e) => e.name == envString,
      orElse: () => AppEnvironment.production,
    );

    // debug 和 profile 模式均使用开发环境（仅 release 走生产）
    if (!kReleaseMode) {
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
        // 生产环境：缺少 Stripe 密钥仅发出警告，不阻塞启动
        // Stripe 功能在用户实际进入支付页面时才需要密钥，
        // 此处崩溃会导致整个应用无法启动（包括 Web 端白屏）
        AppLogger.error('Stripe configuration missing in production',
          Exception(errorMessage));
      } else {
        // 开发/测试环境仅警告（AppLogger 内部已处理输出，无需额外 debugPrint）
        AppLogger.warning(errorMessage);
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
