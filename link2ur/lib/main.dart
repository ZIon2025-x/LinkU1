import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/utils/logger.dart';
import 'core/utils/network_monitor.dart';
import 'data/services/storage_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // 保持原生启动画面直到 Flutter 初始化完毕
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 初始化日志
  AppLogger.init();
  AppLogger.info('App starting...');

  // 捕获 Flutter 框架渲染错误（调试时打印到控制台）
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('=== FlutterError ===\n${details.exceptionAsString()}',
        details.exception, details.stack);
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // 并行化无依赖的初始化操作，减少冷启动时间
  // 屏幕方向 和 Hive 初始化互不依赖，可并行执行
  await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    Hive.initFlutter(),
  ]);

  // StorageService 依赖 Hive，必须在 Hive.initFlutter 之后
  // 内部已并行化 SharedPreferences + Hive.openBox + CacheManager
  await StorageService.instance.init();

  // AppConfig 依赖 StorageService，必须在其之后
  await AppConfig.instance.init();

  // 网络监测：非阻塞初始化，不影响启动速度
  NetworkMonitor.instance.initialize();

  // 配置全局 ImageCache 大小：扩大缓存以减少重复解码
  PaintingBinding.instance.imageCache.maximumSize = 200; // 默认 1000 → 200（控制数量）
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100MB

  // 初始化Bloc观察者
  Bloc.observer = AppBlocObserver();

  // IAP 内购服务：延迟到首次进入支付/VIP页面时懒初始化
  // 避免阻塞启动流程（详见 IAPService.ensureInitialized）

  // 注意：不在这里 remove 原生启动画面
  // 原生启动画面会保持到 app.dart 中认证检查完成后再移除
  // 这样用户看到的是：原生 logo → 直接进主界面，没有重复的 Flutter SplashView

  runApp(const Link2UrApp());
}

/// Bloc观察者，用于调试和错误追踪
class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (kDebugMode) {
      AppLogger.debug('Bloc created: ${bloc.runtimeType}');
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    // Release 模式下跳过状态变更日志，避免性能开销
    if (kDebugMode) {
      AppLogger.debug('Bloc ${bloc.runtimeType} changed: $change');
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    // 错误日志在所有模式下保留
    AppLogger.error('Bloc ${bloc.runtimeType} error: $error', stackTrace);
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    if (kDebugMode) {
      AppLogger.debug('Bloc closed: ${bloc.runtimeType}');
    }
  }
}
