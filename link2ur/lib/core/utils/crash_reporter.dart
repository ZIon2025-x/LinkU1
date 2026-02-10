import 'dart:async';

import 'package:flutter/foundation.dart';

import 'logger.dart';

/// 崩溃报告服务
/// 参考iOS CrashReporter.swift
/// 使用 Flutter 内置错误处理 + AppLogger 记录崩溃信息
/// 可后续集成 Sentry 等第三方崩溃追踪服务
class CrashReporter {
  CrashReporter._();

  static final CrashReporter instance = CrashReporter._();

  bool _isInitialized = false;
  String? _userId;

  /// 初始化崩溃报告
  Future<void> initialize() async {
    try {
      // 捕获 Flutter 框架错误
      FlutterError.onError = (FlutterErrorDetails details) {
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        } else {
          AppLogger.error(
            'Flutter fatal error',
            details.exception,
            details.stack,
          );
        }
      };

      // 捕获异步错误
      PlatformDispatcher.instance.onError = (error, stack) {
        if (!kDebugMode) {
          AppLogger.error('Platform error (fatal)', error, stack);
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
      AppLogger.error(
        'CrashReporter${reason != null ? ' ($reason)' : ''}${fatal ? ' [FATAL]' : ''}',
        exception,
        stackTrace ?? StackTrace.current,
      );
    } catch (e) {
      AppLogger.error('CrashReporter - Record error failed', e);
    }
  }

  /// 设置用户ID
  Future<void> setUserId(String userId) async {
    if (!_isInitialized) return;
    _userId = userId;
    AppLogger.info('CrashReporter - User ID set: $userId');
  }

  /// 设置自定义键值
  Future<void> setCustomKey(String key, Object value) async {
    if (!_isInitialized) return;
    AppLogger.info('CrashReporter - Custom key: $key = $value');
  }

  /// 记录日志消息
  Future<void> log(String message) async {
    if (!_isInitialized) return;
    AppLogger.info('CrashReporter - $message');
  }

  /// 包装 Zone 运行，自动捕获未处理异常
  Future<void> runGuarded(Future<void> Function() body) async {
    await runZonedGuarded(
      body,
      (error, stackTrace) {
        if (kDebugMode) {
          AppLogger.error('Uncaught error', error, stackTrace);
        } else {
          AppLogger.error(
            'Uncaught error${_userId != null ? ' (user: $_userId)' : ''}',
            error,
            stackTrace,
          );
        }
      },
    );
  }
}
