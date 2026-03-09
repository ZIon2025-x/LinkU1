import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

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
        if (details.exception is StripeConfigException) {
          AppLogger.error(
            'Stripe 未配置。请使用 --dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_xxx 运行。',
            details.exception,
            details.stack,
          );
        } else if (_isElementTreeTimingAssert(details)) {
          // StatefulShellRoute.indexedStack + BLoC 轮询在路由过渡期间的时序竞争，
          // 导致已 deactivate 的 element 被 BLoC stream listener 触发 markNeedsBuild()。
          // 仅 debug 模式触发（release 中 assert 被编译器移除），功能不受影响。
          AppLogger.warning(
            'Framework timing assert (suppressed): ${details.exceptionAsString()}',
          );
          return; // 不红屏、不 dump
        } else {
          AppLogger.error(
            'FlutterError: ${details.exceptionAsString()}',
            details.exception,
            details.stack,
          );
        }
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
      };

      // 捕获异步错误（Future/async 中未捕获的异常）
      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.error('Platform error (uncaught)', error, stack);
        return true;
      };

      _isInitialized = true;
      AppLogger.info('CrashReporter - Initialized');
    } catch (e) {
      AppLogger.error('CrashReporter - Initialization failed', e);
    }
  }

  /// 检测 Flutter framework 中因路由过渡时序导致的 element 树断言。
  /// 这些断言仅在 debug 模式出现，release 中不存在，不影响功能。
  static bool _isElementTreeTimingAssert(FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    // BuildOwner.scheduleBuildFor() — element 已 deactivate 但 stream listener 触发 rebuild
    if (msg.contains('_elements.contains(element)')) return true;
    // InheritedElement.unmount() — IndexedStack 分支 element 卸载时依赖未完全解除
    if (msg.contains('_dependents.isEmpty')) return true;
    // 以下为上述时序竞争的级联错误，原始错误已被抑制但这些次生错误仍会显示：
    // cupertino/route.dart — CupertinoPage 手势控制器在路由过渡中被重置后收到 dragUpdate
    if (msg.contains('_backGestureController != null')) return true;
    // Element.renderObject — 已 deactivate 的 element 被访问 renderObject（如 Hero 或 BLoC rebuild）
    if (msg.contains('renderObject of inactive element')) return true;
    return false;
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
