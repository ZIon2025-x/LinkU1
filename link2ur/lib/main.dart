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
import 'data/services/api_service.dart';
import 'data/services/iap_service.dart';
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

  // 设置屏幕方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 初始化Hive
  await Hive.initFlutter();

  // 初始化存储服务
  await StorageService.instance.init();

  // 初始化应用配置
  await AppConfig.instance.init();

  // 初始化网络监测
  await NetworkMonitor.instance.initialize();

  // 初始化Bloc观察者
  Bloc.observer = AppBlocObserver();

  // 初始化 IAP 内购服务
  final apiService = ApiService();
  await IAPService.instance.initialize(apiService: apiService);

  // 注意：不在这里 remove 原生启动画面
  // 原生启动画面会保持到 app.dart 中认证检查完成后再移除
  // 这样用户看到的是：原生 logo → 直接进主界面，没有重复的 Flutter SplashView

  runApp(const Link2UrApp());
}

/// Bloc观察者，用于调试
class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    AppLogger.debug('Bloc created: ${bloc.runtimeType}');
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    AppLogger.debug('Bloc ${bloc.runtimeType} changed: $change');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    AppLogger.error('Bloc ${bloc.runtimeType} error: $error', stackTrace);
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    AppLogger.debug('Bloc closed: ${bloc.runtimeType}');
  }
}
