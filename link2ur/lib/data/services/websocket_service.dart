import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/network_monitor.dart';
import 'storage_service.dart';

/// WebSocket服务
/// 参考iOS WebSocketService.swift
class WebSocketService extends WidgetsBindingObserver {
  WebSocketService._();
  static final WebSocketService instance = WebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  StreamSubscription<NetworkStatus>? _networkSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldBeConnected = false; // 是否应该保持连接（用户已登录）
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 15;
  static const Duration _heartbeatIntervalForeground = Duration(seconds: 30);
  static const Duration _heartbeatIntervalBackground = Duration(seconds: 120);
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 60);
  bool _appInForeground = true;

  /// 消息流控制器
  final _messageController = StreamController<WebSocketMessage>.broadcast();

  /// 连接状态流控制器
  final _connectionController = StreamController<bool>.broadcast();

  /// 消息流
  Stream<WebSocketMessage> get messageStream => _messageController.stream;

  /// 连接状态流
  Stream<bool> get connectionStream => _connectionController.stream;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 连接
  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    _shouldBeConnected = true;
    _isConnecting = true;

    // 注册生命周期观察者（自适应心跳）
    WidgetsBinding.instance.addObserver(this);

    // 检查网络状态 — 无网络时不尝试连接，等待网络恢复
    if (!NetworkMonitor.instance.isConnected) {
      AppLogger.warning('Cannot connect WebSocket: No network, will retry when online');
      _isConnecting = false;
      _listenForNetworkRecovery();
      return;
    }

    try {
      final token = await StorageService.instance.getAccessToken();
      if (token == null || token.isEmpty) {
        AppLogger.warning('Cannot connect WebSocket: No token');
        _isConnecting = false;
        return;
      }

      final wsUrl = '${AppConfig.instance.wsUrl}/ws?token=${Uri.encodeComponent(token)}';
      AppLogger.info('Connecting to WebSocket: ${AppConfig.instance.wsUrl}/ws');

      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        headers: {
          'X-Session-ID': token,
          'Authorization': 'Bearer $token',
        },
      );

      // 等待连接完成
      await _channel!.ready;

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionController.add(true);

      AppLogger.info('WebSocket connected');

      // 开始监听消息
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // 开始心跳
      _startHeartbeat();

      // 监听网络变化以便断网时暂停/恢复
      _listenForNetworkRecovery();
    } catch (e) {
      AppLogger.error('WebSocket connection failed', e);
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  /// 手动重连（重置计数器）
  Future<void> reconnect() async {
    _reconnectAttempts = 0;
    await disconnect();
    _shouldBeConnected = true;
    await connect();
  }

  /// 断开连接
  Future<void> disconnect() async {
    _shouldBeConnected = false;
    _cancelReconnect();
    _stopHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    _networkSubscription?.cancel();
    _networkSubscription = null;
    _subscription?.cancel();
    _subscription = null;

    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }

    _isConnected = false;
    _connectionController.add(false);
    AppLogger.info('WebSocket disconnected');
  }

  /// 发送消息
  void send(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      AppLogger.warning('Cannot send message: Not connected');
      return;
    }

    try {
      final json = jsonEncode(message);
      _channel!.sink.add(json);
      AppLogger.debug('WebSocket sent: $json');
    } catch (e) {
      AppLogger.error('WebSocket send error', e);
    }
  }

  /// 发送聊天消息
  void sendChatMessage({
    required String receiverId,
    required String content,
    String? msgType,
    int? taskId,
  }) {
    send({
      'type': 'chat_message',
      'receiver_id': receiverId,
      'content': content,
      'msg_type': msgType ?? 'text',
      if (taskId != null) 'task_id': taskId,
    });
  }

  /// 发送已读回执
  void sendReadReceipt({
    required String senderId,
    int? taskId,
  }) {
    send({
      'type': 'read_receipt',
      'sender_id': senderId,
      if (taskId != null) 'task_id': taskId,
    });
  }

  /// 发送正在输入
  void sendTyping({
    required String receiverId,
    int? taskId,
  }) {
    send({
      'type': 'typing',
      'receiver_id': receiverId,
      if (taskId != null) 'task_id': taskId,
    });
  }

  /// 处理收到的消息
  void _onMessage(dynamic data) {
    try {
      AppLogger.debug('WebSocket received: $data');

      if (data is String) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final message = WebSocketMessage.fromJson(json);
        _messageController.add(message);
      }
    } catch (e) {
      AppLogger.error('WebSocket message parse error', e);
    }
  }

  /// 处理错误
  void _onError(dynamic error) {
    AppLogger.error('WebSocket error', error);
    _handleDisconnect();
  }

  /// 处理连接关闭
  void _onDone() {
    AppLogger.info('WebSocket connection closed');
    _handleDisconnect();
  }

  /// 处理断开连接
  void _handleDisconnect() {
    _isConnected = false;
    _connectionController.add(false);
    _stopHeartbeat();
    _scheduleReconnect();
  }

  /// 开始心跳（根据前台/后台自适应间隔）
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    final interval = _appInForeground
        ? _heartbeatIntervalForeground
        : _heartbeatIntervalBackground;
    _heartbeatTimer = Timer.periodic(interval, (_) {
      send({'type': 'ping'});
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 应用生命周期变化时切换心跳频率
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _appInForeground;
    _appInForeground = state == AppLifecycleState.resumed;
    // 仅在前后台切换且已连接时重启心跳
    if (wasForeground != _appInForeground && _isConnected) {
      _startHeartbeat();
    }
  }

  /// 监听网络恢复并自动重连
  void _listenForNetworkRecovery() {
    _networkSubscription?.cancel();
    _networkSubscription = NetworkMonitor.instance.statusStream.listen((status) {
      if (_shouldBeConnected && !_isConnected && !_isConnecting) {
        if (status == NetworkStatus.wifi || status == NetworkStatus.cellular) {
          AppLogger.info('Network recovered, reconnecting WebSocket...');
          _reconnectAttempts = 0; // 网络恢复时重置计数器
          connect();
        }
      }
    });
  }

  /// 安排重连（指数退避）
  void _scheduleReconnect() {
    if (!_shouldBeConnected) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      AppLogger.warning(
        'Max reconnect attempts ($_maxReconnectAttempts) reached. '
        'Will auto-reconnect when network status changes.',
      );
      // 即使达到最大尝试次数，仍然监听网络恢复
      _listenForNetworkRecovery();
      return;
    }

    // 无网络时不发起重连，等待网络恢复事件
    if (!NetworkMonitor.instance.isConnected) {
      AppLogger.info('No network, waiting for connectivity to resume...');
      _listenForNetworkRecovery();
      return;
    }

    _reconnectTimer?.cancel();

    // 指数退避：1s, 2s, 4s, 8s, 16s... 最大60s
    final delaySeconds = _initialReconnectDelay.inSeconds *
        (1 << _reconnectAttempts); // 2^attempts
    final clampedDelay = Duration(
      seconds: delaySeconds.clamp(
        _initialReconnectDelay.inSeconds,
        _maxReconnectDelay.inSeconds,
      ),
    );

    AppLogger.info(
        'Scheduling reconnect in ${clampedDelay.inSeconds}s (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(clampedDelay, () {
      _reconnectAttempts++;
      AppLogger.info('Reconnecting... (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
      connect();
    });
  }

  /// 取消重连
  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _networkSubscription?.cancel();
    _networkSubscription = null;
    _messageController.close();
    _connectionController.close();
  }
}

/// WebSocket消息
class WebSocketMessage {
  WebSocketMessage({
    required this.type,
    this.data,
  });

  final String type;
  final Map<String, dynamic>? data;

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String? ?? 'unknown',
      data: json,
    );
  }

  /// 是否是聊天消息
  bool get isChatMessage => type == 'chat_message' || type == 'new_message';

  /// 是否是已读回执
  bool get isReadReceipt => type == 'read_receipt';

  /// 是否是正在输入
  bool get isTyping => type == 'typing';

  /// 是否是系统通知
  bool get isNotification => type == 'notification';

  /// 是否是任务更新
  bool get isTaskUpdate => type == 'task_update';

  @override
  String toString() => 'WebSocketMessage(type: $type, data: $data)';
}
