import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'logger.dart';

/// 网络监测服务
/// 参考iOS Reachability.swift
/// 实时监控网络连接状态
class NetworkMonitor {
  NetworkMonitor._();

  static final NetworkMonitor instance = NetworkMonitor._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// 当前网络状态
  NetworkStatus _currentStatus = NetworkStatus.unknown;
  NetworkStatus get currentStatus => _currentStatus;

  /// 是否已连接
  bool get isConnected =>
      _currentStatus == NetworkStatus.wifi ||
      _currentStatus == NetworkStatus.cellular;

  /// 是否使用WiFi
  bool get isWifi => _currentStatus == NetworkStatus.wifi;

  /// 是否使用移动数据
  bool get isCellular => _currentStatus == NetworkStatus.cellular;

  /// 网络状态变化流
  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  bool _initialized = false;

  /// 初始化网络监测
  Future<void> initialize() async {
    // 防止重复初始化导致旧订阅泄漏
    if (_initialized) {
      AppLogger.debug('NetworkMonitor - Already initialized, skipping');
      return;
    }

    try {
      // 获取初始状态
      final results = await _connectivity.checkConnectivity();
      _currentStatus = _mapStatus(results);
      AppLogger.info('NetworkMonitor - Initial status: $_currentStatus');

      // 监听变化
      _subscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final newStatus = _mapStatus(results);
          if (newStatus != _currentStatus) {
            _currentStatus = newStatus;
            _statusController.add(newStatus);
            AppLogger.info('NetworkMonitor - Status changed: $newStatus');
          }
        },
        onError: (Object error) {
          AppLogger.error('NetworkMonitor - Stream error', error);
        },
      );
      _initialized = true;
    } catch (e) {
      AppLogger.error('NetworkMonitor - Initialization failed', e);
    }
  }

  /// 手动检查当前网络状态
  Future<NetworkStatus> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _currentStatus = _mapStatus(results);
      return _currentStatus;
    } catch (e) {
      AppLogger.error('NetworkMonitor - Check connectivity failed', e);
      return NetworkStatus.unknown;
    }
  }

  /// 映射连接结果到网络状态
  NetworkStatus _mapStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) {
      return NetworkStatus.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      return NetworkStatus.cellular;
    } else if (results.contains(ConnectivityResult.ethernet)) {
      return NetworkStatus.wifi; // 视为WiFi
    } else if (results.contains(ConnectivityResult.vpn)) {
      return NetworkStatus.wifi; // VPN视为已连接
    } else if (results.contains(ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.unknown;
  }

  /// 释放资源
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _statusController.close();
    _initialized = false;
  }
}

/// 网络状态枚举
enum NetworkStatus {
  /// WiFi连接
  wifi,

  /// 移动数据连接
  cellular,

  /// 无网络
  offline,

  /// 未知
  unknown,
}
