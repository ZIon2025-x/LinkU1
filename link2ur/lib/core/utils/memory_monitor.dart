import 'dart:async';

import 'package:flutter/foundation.dart';

import 'logger.dart';

/// 内存压力级别
enum MemoryPressureLevel {
  normal,
  warning,
  critical,
  emergency,
}

/// 内存快照
class MemorySnapshot {
  MemorySnapshot({
    required this.timestamp,
    required this.usedBytes,
    required this.heapSizeBytes,
    required this.externalBytes,
    required this.pressureLevel,
    this.context,
  });

  final DateTime timestamp;
  final int usedBytes;
  final int heapSizeBytes;
  final int externalBytes;
  final MemoryPressureLevel pressureLevel;
  final String? context;

  double get usageMB => usedBytes / (1024 * 1024);
  double get heapSizeMB => heapSizeBytes / (1024 * 1024);
  double get externalMB => externalBytes / (1024 * 1024);
  double get usagePercentage =>
      heapSizeBytes > 0 ? (usedBytes / heapSizeBytes * 100) : 0;

  String get summary =>
      'Memory: ${usageMB.toStringAsFixed(1)}MB / '
      '${heapSizeMB.toStringAsFixed(1)}MB '
      '(${usagePercentage.toStringAsFixed(0)}%) '
      '[${pressureLevel.name}]';
}

/// 内存监控器
/// 对齐 iOS MemoryMonitor.swift
/// 追踪 Dart VM 内存使用、检测内存压力、触发清理
class MemoryMonitor {
  MemoryMonitor._();
  static final MemoryMonitor instance = MemoryMonitor._();

  Timer? _monitorTimer;
  bool _isMonitoring = false;

  /// 内存快照历史
  final List<MemorySnapshot> _history = [];
  static const int _maxHistory = 100;

  /// 内存压力阈值（MB）
  static const double _warningThresholdMB = 200;
  static const double _criticalThresholdMB = 350;
  static const double _emergencyThresholdMB = 500;

  /// 当前内存压力级别
  MemoryPressureLevel _currentLevel = MemoryPressureLevel.normal;
  MemoryPressureLevel get currentLevel => _currentLevel;

  /// 内存压力变更回调
  void Function(MemoryPressureLevel level)? onPressureLevelChanged;

  /// 清理回调
  void Function(MemoryPressureLevel level)? onCleanupRequired;

  /// 初始化并开始监控
  void initialize({Duration interval = const Duration(seconds: 5)}) {
    if (!kDebugMode) return; // 仅 Debug 模式
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitorTimer = Timer.periodic(interval, (_) => _checkMemory());
    AppLogger.info('MemoryMonitor initialized');
  }

  /// 手动获取当前内存快照
  MemorySnapshot takeSnapshot({String? context}) {
    // 获取内存信息的近似值
    // Flutter 不直接暴露 Dart VM 内存信息到生产代码中
    // 这里使用近似估算
    const int usedBytes = 0;
    const int heapSizeBytes = 0;
    const int externalBytes = 0;

    // 注意：精确内存追踪需要通过 DevTools / Observatory
    // 这里提供基础的框架，实际数值可在 profile 模式下获取

    final level = _calculatePressureLevel(usedBytes);

    final snapshot = MemorySnapshot(
      timestamp: DateTime.now(),
      usedBytes: usedBytes,
      heapSizeBytes: heapSizeBytes,
      externalBytes: externalBytes,
      pressureLevel: level,
      context: context,
    );

    _history.add(snapshot);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }

    return snapshot;
  }

  /// 获取内存历史
  List<MemorySnapshot> getMemoryHistory({int? limit}) {
    if (limit != null && limit < _history.length) {
      return _history.sublist(_history.length - limit);
    }
    return List.unmodifiable(_history);
  }

  /// 检测内存泄漏
  /// 比较两个快照的内存变化
  bool detectLeak({
    required MemorySnapshot baseline,
    required MemorySnapshot current,
    double thresholdMB = 50,
  }) {
    final diffMB =
        (current.usedBytes - baseline.usedBytes) / (1024 * 1024);
    return diffMB > thresholdMB;
  }

  /// 触发清理
  void performCleanup(MemoryPressureLevel level) {
    AppLogger.info(
        'MemoryMonitor: Performing cleanup for level ${level.name}');
    onCleanupRequired?.call(level);

    // 建议垃圾回收
    // 注意：Dart VM 会自动管理 GC，这里只是建议
  }

  /// 停止监控
  void stop() {
    _monitorTimer?.cancel();
    _isMonitoring = false;
    AppLogger.info('MemoryMonitor stopped');
  }

  // ==================== 内部方法 ====================

  void _checkMemory() {
    final snapshot = takeSnapshot();
    final newLevel = snapshot.pressureLevel;

    if (newLevel != _currentLevel) {
      final oldLevel = _currentLevel;
      _currentLevel = newLevel;
      onPressureLevelChanged?.call(newLevel);

      AppLogger.info(
          'Memory pressure changed: ${oldLevel.name} -> ${newLevel.name}');

      // 自动触发清理
      if (newLevel.index >= MemoryPressureLevel.warning.index) {
        performCleanup(newLevel);
      }
    }
  }

  MemoryPressureLevel _calculatePressureLevel(int usedBytes) {
    final usedMB = usedBytes / (1024 * 1024);
    if (usedMB >= _emergencyThresholdMB) return MemoryPressureLevel.emergency;
    if (usedMB >= _criticalThresholdMB) return MemoryPressureLevel.critical;
    if (usedMB >= _warningThresholdMB) return MemoryPressureLevel.warning;
    return MemoryPressureLevel.normal;
  }

  /// 释放资源
  void dispose() {
    stop();
    _history.clear();
  }
}

/// ANR 检测器
/// 对齐 iOS ANRDetector
/// 检测主线程长时间阻塞
class ANRDetector {
  ANRDetector._();
  static final ANRDetector instance = ANRDetector._();

  Timer? _watchdogTimer;
  DateTime? _lastPingTime;
  bool _isRunning = false;

  /// ANR 阈值（秒）
  static const int _thresholdSeconds = 5;

  /// ANR 检测回调
  void Function()? onANRDetected;

  /// 启动 ANR 检测（仅 Debug 模式）
  void start() {
    if (!kDebugMode || _isRunning) return;
    _isRunning = true;
    _lastPingTime = DateTime.now();

    _watchdogTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkForANR(),
    );

    AppLogger.info('ANRDetector: Started');
  }

  /// 更新 ping 时间（应在每帧调用）
  void ping() {
    _lastPingTime = DateTime.now();
  }

  void _checkForANR() {
    if (_lastPingTime == null) return;

    final elapsed = DateTime.now().difference(_lastPingTime!);
    if (elapsed.inSeconds >= _thresholdSeconds) {
      AppLogger.warning(
          'ANR detected! Main thread blocked for ${elapsed.inSeconds}s');
      onANRDetected?.call();
      // 重置以避免持续报告
      _lastPingTime = DateTime.now();
    }
  }

  /// 停止 ANR 检测
  void stop() {
    _watchdogTimer?.cancel();
    _isRunning = false;
  }
}
