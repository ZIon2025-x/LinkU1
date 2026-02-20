import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/utils/crash_reporter.dart';
import 'core/utils/logger.dart';
import 'core/utils/network_monitor.dart';
import 'data/services/payment_service.dart';
import 'data/services/storage_service.dart';

void main() {
  // 将所有初始化和 runApp 放在同一个 Zone 内，避免 Zone mismatch 错误
  // CrashReporter 已设置 FlutterError.onError + PlatformDispatcher.onError，
  // runZonedGuarded 额外捕获 Zone 内未处理的异步异常（三层防护互补）
  runZonedGuarded(
    () async {
      // Web 上使用路径 URL 策略（去掉 # 号）
      usePathUrlStrategy();

      // 禁用运行时字体下载，使用 assets 打包的 Inter 字体
      GoogleFonts.config.allowRuntimeFetching = false;

      final widgetsBinding =
          WidgetsFlutterBinding.ensureInitialized();

      // 保持原生启动画面直到 Flutter 初始化完毕（Web 上为 no-op）
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

      // 初始化日志
      AppLogger.init();
      AppLogger.info('App starting...');

      // 统一错误捕获：FlutterError + PlatformDispatcher
      await CrashReporter.instance.initialize();

      // 设置系统UI样式（Web 上这些调用会被忽略，但不会报错）
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      // 并行化无依赖的初始化操作，减少冷启动时间
      await Future.wait([
        if (!kIsWeb) // 屏幕方向锁定仅在移动端生效
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]),
        Hive.initFlutter(),
      ]);

      // StorageService 依赖 Hive，必须在 Hive.initFlutter 之后
      // 内部已并行化 SharedPreferences + Hive.openBox + CacheManager
      await StorageService.instance.init();

      // AppConfig 依赖 StorageService，必须在其之后（同步初始化，无需 await）
      AppConfig.instance.init();

      // Stripe 支付（信用卡/Apple Pay/支付宝）需在首次支付前完成初始化，避免点击「确认支付」时抛出 StripeConfigException
      await _initStripeIfConfigured();

      // 网络监测：非阻塞初始化，不影响启动速度
      NetworkMonitor.instance.initialize();

      // 配置全局 ImageCache 大小：扩大缓存以减少重复解码
      // 本应用有大量图片列表（首页、论坛、跳蚤市场等），需要足够缓存支撑回滑
      PaintingBinding.instance.imageCache.maximumSize = 500; // 支持 3-5 屏图片缓存
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          150 << 20; // 150MB

      // 初始化Bloc观察者（仅调试模式，避免 release 构建中拦截每个事件/状态变更的开销）
      if (kDebugMode) {
        Bloc.observer = AppBlocObserver();
      }

      // IAP 内购服务：延迟到首次进入支付/VIP页面时懒初始化
      // 避免阻塞启动流程（详见 IAPService.ensureInitialized）

      // 注意：不在这里 remove 原生启动画面
      // 原生启动画面会保持到 app.dart 中认证检查完成后再移除
      // 这样用户看到的是：原生 logo → 直接进主界面，没有重复的 Flutter SplashView

      runApp(const Link2UrApp());
    },
    (error, stackTrace) {
      AppLogger.error('Uncaught zone error', error, stackTrace);
    },
  );
}

/// 在配置了 Stripe 公钥时初始化 Stripe，避免支付页点击确认时出现 StripeConfigException
Future<void> _initStripeIfConfigured() async {
  if (AppConfig.instance.stripePublishableKey.isEmpty) return;
  try {
    await PaymentService.instance.init();
  } catch (e, st) {
    AppLogger.warning('Stripe init failed (payments may fail): $e', st);
  }
}

/// Bloc观察者，用于调试和错误追踪
///
/// 仅记录白名单内 BLoC 的状态变更，避免 15+ BLoC 高频日志拖慢 Debug 模式。
/// 错误日志始终保留（所有 BLoC）。
class AppBlocObserver extends BlocObserver {
  /// 需要详细状态变更日志的 BLoC 白名单
  static const _trackedBlocs = {
    'AuthBloc',
    'PaymentBloc',
    'WalletBloc',
    'NotificationBloc',
  };

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (kDebugMode && _trackedBlocs.contains(bloc.runtimeType.toString())) {
      AppLogger.debug(
        'Bloc ${bloc.runtimeType}: '
        '${change.currentState.runtimeType} → ${change.nextState.runtimeType}',
      );
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    AppLogger.error('Bloc ${bloc.runtimeType} error: $error', stackTrace);
  }
}
