import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// 应用日志工具
/// 参考iOS Logger.swift
class AppLogger {
  AppLogger._();

  static bool _initialized = false;

  /// 初始化日志
  static void init() {
    _initialized = true;
    if (kDebugMode) {
      info('Logger initialized in debug mode');
    }
  }

  /// 是否启用日志
  static bool get _enabled => _initialized && AppConfig.instance.enableDebugLog;

  /// 调试日志
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _log('DEBUG', message, error, stackTrace);
  }

  /// 信息日志
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _log('INFO', message, error, stackTrace);
  }

  /// 警告日志
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _log('WARNING', message, error, stackTrace);
  }

  /// 错误日志
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message, error, stackTrace);
  }

  /// 网络请求日志
  static void network(String method, String url, {int? statusCode, String? body}) {
    if (!_enabled) return;
    final buffer = StringBuffer();
    buffer.writeln('$method $url');
    if (statusCode != null) {
      buffer.writeln('Status: $statusCode');
    }
    if (body != null && body.length < 500) {
      buffer.writeln('Body: $body');
    }
    _log('NETWORK', buffer.toString());
  }

  /// 生命周期日志
  static void lifecycle(String event, [String? details]) {
    if (!_enabled) return;
    final message = details != null ? '$event: $details' : event;
    _log('LIFECYCLE', message);
  }

  /// 用户行为日志
  static void analytics(String event, [Map<String, dynamic>? params]) {
    if (!_enabled) return;
    final buffer = StringBuffer();
    buffer.write('Event: $event');
    if (params != null && params.isNotEmpty) {
      buffer.write(' | Params: $params');
    }
    _log('ANALYTICS', buffer.toString());
  }

  /// 性能日志
  static void performance(String operation, Duration duration) {
    if (!_enabled) return;
    _log('PERF', '$operation took ${duration.inMilliseconds}ms');
  }

  /// 内部日志方法
  static void _log(String level, String message, [Object? error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [$level] $message';

    if (kDebugMode) {
      developer.log(
        logMessage,
        name: 'Link2Ur',
        error: error,
        stackTrace: stackTrace,
      );

      // 同时输出到控制台
      debugPrint(logMessage);
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  /// 计时器 - 开始
  static Stopwatch startTimer(String operation) {
    final stopwatch = Stopwatch()..start();
    debug('Starting: $operation');
    return stopwatch;
  }

  /// 计时器 - 结束
  static void endTimer(Stopwatch stopwatch, String operation) {
    stopwatch.stop();
    performance(operation, stopwatch.elapsed);
  }
}

/// 扩展方法 - 方便在任何对象上调用日志
extension LoggerExtension on Object {
  void logDebug(String message) => AppLogger.debug('[$runtimeType] $message');
  void logInfo(String message) => AppLogger.info('[$runtimeType] $message');
  void logWarning(String message) => AppLogger.warning('[$runtimeType] $message');
  void logError(String message, [Object? error, StackTrace? stackTrace]) =>
      AppLogger.error('[$runtimeType] $message', error, stackTrace);
}
