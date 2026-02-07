import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'logger.dart';

/// 崩溃报告服务
/// 参考iOS CrashReporter.swift
/// 集成 Firebase Crashlytics 进行崩溃和错误追踪
class CrashReporter {
  CrashReporter._();

  static final CrashReporter instance = CrashReporter._();

  bool _isInitialized = false;

  /// 初始化崩溃报告
  Future<void> initialize() async {
    try {
      // 在 release 模式下启用 Crashlytics
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );

      // 捕获 Flutter 框架错误
      FlutterError.onError = (FlutterErrorDetails details) {
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        } else {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        }
      };

      // 捕获异步错误
      PlatformDispatcher.instance.onError = (error, stack) {
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
        return true;
      };

      _isInitialized = true;
      AppLogger.info('CrashReporter - Initialized');
    } catch (e) {
      AppLogger.error('CrashReporter - Initialization failed', e);
    }
  }

  /// 记录非致命错误
  Future<void> recordError(
    dynamic exception, {
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
  }) async {
    if (!_isInitialized || kDebugMode) return;

    try {
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stackTrace ?? StackTrace.current,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      AppLogger.error('CrashReporter - Record error failed', e);
    }
  }

  /// 设置用户ID
  Future<void> setUserId(String userId) async {
    if (!_isInitialized) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (e) {
      AppLogger.error('CrashReporter - Set user ID failed', e);
    }
  }

  /// 设置自定义键值
  Future<void> setCustomKey(String key, Object value) async {
    if (!_isInitialized) return;
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (e) {
      AppLogger.error('CrashReporter - Set custom key failed', e);
    }
  }

  /// 记录日志消息
  Future<void> log(String message) async {
    if (!_isInitialized) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      AppLogger.error('CrashReporter - Log failed', e);
    }
  }

  /// 包装 Zone 运行，自动捕获未处理异常
  Future<void> runGuarded(Future<void> Function() body) async {
    await runZonedGuarded(
      body,
      (error, stackTrace) {
        if (kDebugMode) {
          AppLogger.error('Uncaught error', error, stackTrace);
        } else {
          FirebaseCrashlytics.instance.recordError(error, stackTrace);
        }
      },
    );
  }
}
