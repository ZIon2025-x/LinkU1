import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger.dart';

/// 启动阶段
enum LaunchPhase {
  preMain,
  appInit,
  willFinish,
  didFinish,
  firstFrame,
  interactive,
  dataLoaded,
}

/// 启动阶段记录
class LaunchPhaseRecord {
  LaunchPhaseRecord({
    required this.phase,
    required this.timestamp,
    this.durationFromPrevious,
    this.totalDuration,
  });

  final LaunchPhase phase;
  final DateTime timestamp;
  final Duration? durationFromPrevious;
  final Duration? totalDuration;

  /// 阶段是否在正常范围内
  bool get isNormal {
    if (durationFromPrevious == null) return true;
    final ms = durationFromPrevious!.inMilliseconds;
    switch (phase) {
      case LaunchPhase.preMain:
        return ms < 500;
      case LaunchPhase.appInit:
        return ms < 1000;
      case LaunchPhase.willFinish:
        return ms < 200;
      case LaunchPhase.didFinish:
        return ms < 500;
      case LaunchPhase.firstFrame:
        return ms < 1000;
      case LaunchPhase.interactive:
        return ms < 500;
      case LaunchPhase.dataLoaded:
        return ms < 3000;
    }
  }
}

/// 启动性能报告
class LaunchPerformanceReport {
  LaunchPerformanceReport({
    required this.launchDate,
    required this.totalDuration,
    required this.phases,
    this.isWarmLaunch = false,
  });

  final DateTime launchDate;
  final Duration totalDuration;
  final List<LaunchPhaseRecord> phases;
  final bool isWarmLaunch;

  /// 是否正常启动（< 3 秒且所有阶段正常）
  bool get isNormalLaunch =>
      totalDuration.inMilliseconds < 3000 &&
      phases.every((p) => p.isNormal);

  /// 最慢的阶段
  LaunchPhaseRecord? get slowestPhase {
    if (phases.isEmpty) return null;
    return phases.reduce((a, b) {
      final aDur = a.durationFromPrevious?.inMilliseconds ?? 0;
      final bDur = b.durationFromPrevious?.inMilliseconds ?? 0;
      return aDur >= bDur ? a : b;
    });
  }

  /// 生成报告摘要
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('=== Launch Performance Report ===');
    buffer.writeln('Date: ${launchDate.toIso8601String()}');
    buffer.writeln(
        'Total: ${totalDuration.inMilliseconds}ms (${isNormalLaunch ? "NORMAL" : "SLOW"})');
    buffer.writeln('Type: ${isWarmLaunch ? "Warm" : "Cold"}');
    buffer.writeln('Phases:');
    for (final phase in phases) {
      final dur = phase.durationFromPrevious?.inMilliseconds ?? 0;
      final flag = phase.isNormal ? '' : ' [SLOW]';
      buffer.writeln('  ${phase.phase.name}: ${dur}ms$flag');
    }
    return buffer.toString();
  }
}

/// 启动性能监控器
/// 对齐 iOS LaunchPerformanceMonitor.swift
/// 测量和报告应用启动性能
class LaunchPerformanceMonitor {
  LaunchPerformanceMonitor._();
  static final LaunchPerformanceMonitor instance =
      LaunchPerformanceMonitor._();

  static const String _historyKey = 'launch_performance_history';
  static const String _lastLaunchTimeKey = 'last_launch_time_ms';
  static const int _maxHistory = 10;

  DateTime? _launchStartTime;
  final Map<LaunchPhase, DateTime> _phaseTimestamps = {};
  LaunchPerformanceReport? _lastReport;
  bool _isCompleted = false;

  /// 最新的报告
  LaunchPerformanceReport? get lastReport => _lastReport;

  /// 标记启动开始（应尽早调用）
  void markLaunchStart() {
    _launchStartTime = DateTime.now();
    _phaseTimestamps.clear();
    _isCompleted = false;
    _phaseTimestamps[LaunchPhase.preMain] = _launchStartTime!;
  }

  /// 标记阶段完成
  void markPhase(LaunchPhase phase) {
    if (_isCompleted) return;
    _phaseTimestamps[phase] = DateTime.now();
    AppLogger.info(
        'Launch phase: ${phase.name} at ${DateTime.now().difference(_launchStartTime ?? DateTime.now()).inMilliseconds}ms');
  }

  /// 标记数据加载完成
  void markDataLoaded() {
    markPhase(LaunchPhase.dataLoaded);
    completeLaunch();
  }

  /// 完成启动测量并生成报告
  Future<void> completeLaunch() async {
    if (_isCompleted || _launchStartTime == null) return;
    _isCompleted = true;

    final now = DateTime.now();
    final totalDuration = now.difference(_launchStartTime!);

    // 构建阶段记录
    final phases = <LaunchPhaseRecord>[];
    DateTime? previousTime = _launchStartTime;

    for (final phase in LaunchPhase.values) {
      final timestamp = _phaseTimestamps[phase];
      if (timestamp != null) {
        final durationFromPrev = previousTime != null
            ? timestamp.difference(previousTime)
            : null;
        final totalDur = timestamp.difference(_launchStartTime!);

        phases.add(LaunchPhaseRecord(
          phase: phase,
          timestamp: timestamp,
          durationFromPrevious: durationFromPrev,
          totalDuration: totalDur,
        ));

        previousTime = timestamp;
      }
    }

    _lastReport = LaunchPerformanceReport(
      launchDate: _launchStartTime!,
      totalDuration: totalDuration,
      phases: phases,
    );

    // 保存启动时间
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _lastLaunchTimeKey, totalDuration.inMilliseconds);

      // 保存历史
      final history =
          prefs.getStringList(_historyKey) ?? [];
      history.add(totalDuration.inMilliseconds.toString());
      if (history.length > _maxHistory) {
        history.removeRange(0, history.length - _maxHistory);
      }
      await prefs.setStringList(_historyKey, history);
    } catch (e) {
      AppLogger.error('Launch performance save failed', e);
    }

    // 日志输出
    if (kDebugMode) {
      AppLogger.info(_lastReport!.summary);
    }

    // 慢启动报告
    if (!_lastReport!.isNormalLaunch) {
      AppLogger.warning(
          'Slow launch detected: ${totalDuration.inMilliseconds}ms');
    }
  }

  /// 获取历史启动数据
  Future<List<int>> getHistoricalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_historyKey) ?? [];
      return history.map((s) => int.tryParse(s) ?? 0).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取平均启动时间（毫秒）
  Future<double> getAverageLaunchDuration() async {
    final history = await getHistoricalData();
    if (history.isEmpty) return 0;
    return history.reduce((a, b) => a + b) / history.length;
  }
}

/// 延迟初始化管理器
/// 对齐 iOS DeferredInitializationManager
/// 在首帧后执行非关键初始化任务
class DeferredInitializationManager {
  DeferredInitializationManager._();
  static final DeferredInitializationManager instance =
      DeferredInitializationManager._();

  final List<_DeferredTask> _tasks = [];
  bool _executed = false;

  /// 注册延迟任务
  /// [priority] 0 = 最高优先级
  void register({
    required String name,
    int priority = 5,
    required Future<void> Function() task,
  }) {
    if (_executed) {
      // 已执行过，直接执行
      task();
      return;
    }
    _tasks.add(_DeferredTask(name: name, priority: priority, task: task));
  }

  /// 执行所有延迟任务（按优先级排序）
  Future<void> executeAll() async {
    if (_executed) return;
    _executed = true;

    // 按优先级排序
    _tasks.sort((a, b) => a.priority.compareTo(b.priority));

    for (final task in _tasks) {
      try {
        final start = DateTime.now();
        await task.task();
        final elapsed = DateTime.now().difference(start);

        if (elapsed.inMilliseconds > 100) {
          AppLogger.performance(
              'Deferred task "${task.name}"', elapsed);
        }
      } catch (e) {
        AppLogger.error('Deferred task "${task.name}" failed', e);
      }
    }

    _tasks.clear();
    AppLogger.info('DeferredInitializationManager: All tasks executed');
  }
}

class _DeferredTask {
  _DeferredTask({
    required this.name,
    required this.priority,
    required this.task,
  });

  final String name;
  final int priority;
  final Future<void> Function() task;
}
