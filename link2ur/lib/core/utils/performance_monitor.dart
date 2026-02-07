import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'logger.dart';

/// 网络请求度量
class NetworkRequestMetric {
  NetworkRequestMetric({
    required this.endpoint,
    required this.method,
    required this.startTime,
    this.duration,
    this.statusCode,
    this.error,
    this.requestSize,
    this.responseSize,
  });

  final String endpoint;
  final String method;
  final DateTime startTime;
  Duration? duration;
  int? statusCode;
  String? error;
  int? requestSize;
  int? responseSize;

  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;
  bool get isSlow =>
      duration != null && duration!.inMilliseconds > 3000;
}

/// 操作计时器
class _OperationTimer {
  _OperationTimer(this.name) : startTime = DateTime.now();

  final String name;
  final DateTime startTime;
}

/// FPS 监控器
class FPSMonitor {
  FPSMonitor._();
  static final FPSMonitor instance = FPSMonitor._();

  bool _isRunning = false;
  int _frameCount = 0;
  DateTime? _lastReportTime;
  double _currentFPS = 0;
  final List<double> _fpsHistory = [];
  static const int _maxHistory = 60;
  double get currentFPS => _currentFPS;
  List<double> get fpsHistory => List.unmodifiable(_fpsHistory);

  /// FPS 等级
  String get fpsLevel {
    if (_currentFPS >= 55) return 'excellent';
    if (_currentFPS >= 45) return 'good';
    if (_currentFPS >= 30) return 'fair';
    return 'poor';
  }

  /// 启动 FPS 监控（仅 Debug 模式）
  void start() {
    if (!kDebugMode || _isRunning) return;
    _isRunning = true;
    _lastReportTime = DateTime.now();
    _frameCount = 0;

    // 使用 SchedulerBinding 监听帧
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);

    AppLogger.info('FPSMonitor: Started');
  }

  void _onFrame(Duration timestamp) {
    if (!_isRunning) return;

    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastReportTime!);

    if (elapsed.inMilliseconds >= 1000) {
      _currentFPS = _frameCount * 1000 / elapsed.inMilliseconds;
      _frameCount = 0;
      _lastReportTime = now;

      _fpsHistory.add(_currentFPS);
      if (_fpsHistory.length > _maxHistory) {
        _fpsHistory.removeAt(0);
      }

      // 低 FPS 警告
      if (_currentFPS < 30) {
        AppLogger.warning('Low FPS detected: ${_currentFPS.toStringAsFixed(1)}');
      }
    }
  }

  /// 停止 FPS 监控
  void stop() {
    _isRunning = false;
    AppLogger.info('FPSMonitor: Stopped');
  }

  /// 重置
  void reset() {
    _fpsHistory.clear();
    _currentFPS = 0;
    _frameCount = 0;
  }
}

/// 性能监控器
/// 对齐 iOS PerformanceMonitor.swift
/// 提供网络请求监控、操作计时、FPS 监控、性能报告
class PerformanceMonitor {
  PerformanceMonitor._();
  static final PerformanceMonitor instance = PerformanceMonitor._();

  /// 网络请求度量记录
  final List<NetworkRequestMetric> _networkMetrics = [];
  static const int _maxMetrics = 100;

  /// 操作计时器
  final Map<String, _OperationTimer> _activeTimers = {};

  /// 操作耗时记录（name -> list of durations）
  final Map<String, List<Duration>> _operationDurations = {};

  /// 初始化
  void initialize() {
    if (kDebugMode) {
      FPSMonitor.instance.start();
    }
    AppLogger.info('PerformanceMonitor initialized');
  }

  // ==================== 网络请求监控 ====================

  /// 记录网络请求
  void recordNetworkRequest(NetworkRequestMetric metric) {
    _networkMetrics.add(metric);
    if (_networkMetrics.length > _maxMetrics) {
      _networkMetrics.removeAt(0);
    }

    if (metric.isSlow) {
      AppLogger.warning(
          'Slow request: ${metric.method} ${metric.endpoint} '
          '(${metric.duration?.inMilliseconds}ms)');
    }
  }

  /// 获取网络请求平均耗时
  double get averageNetworkDuration {
    final completed =
        _networkMetrics.where((m) => m.duration != null).toList();
    if (completed.isEmpty) return 0;
    final total = completed.fold<int>(
        0, (sum, m) => sum + m.duration!.inMilliseconds);
    return total / completed.length;
  }

  /// 获取慢请求数
  int get slowRequestCount =>
      _networkMetrics.where((m) => m.isSlow).length;

  /// 获取失败请求数
  int get failedRequestCount =>
      _networkMetrics.where((m) => !m.isSuccess && m.statusCode != null).length;

  // ==================== 操作计时 ====================

  /// 开始计时
  void startOperation(String name) {
    _activeTimers[name] = _OperationTimer(name);
  }

  /// 结束计时
  Duration? endOperation(String name) {
    final timer = _activeTimers.remove(name);
    if (timer == null) return null;

    final duration = DateTime.now().difference(timer.startTime);

    _operationDurations.putIfAbsent(name, () => []);
    _operationDurations[name]!.add(duration);

    // 保留最新 50 条
    if (_operationDurations[name]!.length > 50) {
      _operationDurations[name]!.removeAt(0);
    }

    return duration;
  }

  /// 测量同步操作
  T measure<T>(String name, T Function() operation) {
    startOperation(name);
    try {
      final result = operation();
      endOperation(name);
      return result;
    } catch (e) {
      endOperation(name);
      rethrow;
    }
  }

  /// 测量异步操作
  Future<T> measureAsync<T>(
      String name, Future<T> Function() operation) async {
    startOperation(name);
    try {
      final result = await operation();
      endOperation(name);
      return result;
    } catch (e) {
      endOperation(name);
      rethrow;
    }
  }

  // ==================== 报告 ====================

  /// 获取性能报告
  Map<String, dynamic> getReport() {
    return {
      'network': {
        'totalRequests': _networkMetrics.length,
        'averageDurationMs': averageNetworkDuration.toStringAsFixed(1),
        'slowRequests': slowRequestCount,
        'failedRequests': failedRequestCount,
      },
      'fps': {
        'current': FPSMonitor.instance.currentFPS.toStringAsFixed(1),
        'level': FPSMonitor.instance.fpsLevel,
      },
      'operations': _operationDurations.map((name, durations) {
        final avg = durations.fold<int>(
                0, (sum, d) => sum + d.inMilliseconds) /
            durations.length;
        return MapEntry(name, {
          'count': durations.length,
          'averageMs': avg.toStringAsFixed(1),
        });
      }),
    };
  }

  /// 重置所有数据
  void reset() {
    _networkMetrics.clear();
    _activeTimers.clear();
    _operationDurations.clear();
    FPSMonitor.instance.reset();
  }
}
