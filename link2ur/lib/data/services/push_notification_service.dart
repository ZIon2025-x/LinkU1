import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/logger.dart';
import 'storage_service.dart';
import 'api_service.dart';

/// 推送通知服务
/// 封装 Firebase Cloud Messaging 和本地通知
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// GoRouter 实例，用于通知导航
  GoRouter? _router;

  /// API 服务实例，用于上传 Token
  ApiService? _apiService;

  /// 设置路由器引用（在 app.dart 中调用）
  void setRouter(GoRouter router) {
    _router = router;
  }

  /// 设置 API 服务引用
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }

  /// 初始化推送通知服务
  Future<void> init() async {
    // 请求通知权限
    await _requestPermission();

    // 初始化本地通知
    await _initLocalNotifications();

    // 获取并保存 FCM Token
    await _getFCMToken();

    // 监听前台消息
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 监听后台消息点击
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 检查app是否从通知启动
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // 监听 Token 刷新
    _messaging.onTokenRefresh.listen((token) async {
      AppLogger.info('FCM Token refreshed');
      await StorageService.instance.savePushToken(token);
      await _uploadTokenToServer(token);
    });

    AppLogger.info('PushNotificationService initialized');
  }

  /// 上传推送 Token 到服务器
  Future<void> _uploadTokenToServer(String token) async {
    try {
      if (_apiService == null) {
        AppLogger.warning('ApiService not set, skipping token upload');
        return;
      }
      await _apiService!.post(
        '/api/users/me/device-token',
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'type': 'fcm',
        },
      );
      AppLogger.info('FCM Token uploaded to server');
    } catch (e) {
      AppLogger.error('Failed to upload FCM token to server', e);
    }
  }

  /// 请求通知权限
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    AppLogger.info(
      'Notification permission: ${settings.authorizationStatus}',
    );
  }

  /// 初始化本地通知
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 创建 Android 通知渠道
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'link2ur_default',
        'Link²Ur 通知',
        description: 'Link²Ur 应用通知',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// 获取 FCM Token
  Future<String?> _getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        AppLogger.info('FCM Token obtained');
        await StorageService.instance.savePushToken(token);
        await _uploadTokenToServer(token);
      }
      return token;
    } catch (e) {
      AppLogger.error('Failed to get FCM token', e);
      return null;
    }
  }

  /// 处理前台消息
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('Foreground message: ${message.messageId}');

    final notification = message.notification;
    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? '',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// 处理消息点击(后台/terminated)
  void _handleMessageOpenedApp(RemoteMessage message) {
    AppLogger.info('Message opened: ${message.messageId}');
    final data = message.data;
    if (data.containsKey('type')) {
      _navigateByNotificationType(data['type'], data);
    }
  }

  /// 显示本地通知
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'link2ur_default',
      'Link²Ur 通知',
      channelDescription: 'Link²Ur 应用通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// 通知点击回调
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.info('Notification tapped: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        // payload 格式为 data.toString()，尝试解析
        // 对于简单场景，直接导航到通知中心
        _router?.push('/notifications');
      } catch (e) {
        AppLogger.error('Failed to parse notification payload', e);
        _router?.push('/notifications');
      }
    }
  }

  /// 根据通知类型导航
  void _navigateByNotificationType(
    String type,
    Map<String, dynamic> data,
  ) {
    if (_router == null) {
      AppLogger.warning('Router not set, cannot navigate');
      return;
    }

    switch (type) {
      case 'task_update':
      case 'task_applied':
      case 'task_accepted':
      case 'task_completed':
      case 'task_confirmed':
      case 'task_cancelled':
        final taskId = data['task_id'] ?? data['related_id'];
        if (taskId != null) {
          _router!.push('/tasks/$taskId');
        } else {
          _router!.push('/notifications');
        }
        break;
      case 'message':
      case 'task_chat':
        final taskId = data['task_id'];
        final userId = data['user_id'] ?? data['sender_id'];
        if (taskId != null) {
          _router!.push('/task-chat/$taskId');
        } else if (userId != null) {
          _router!.push('/chat/${userId.toString()}');
        } else {
          _router!.go('/messages-tab');
        }
        break;
      case 'forum_reply':
      case 'forum_like':
        final postId = data['post_id'] ?? data['related_id'];
        if (postId != null) {
          _router!.push('/forum/posts/$postId');
        } else {
          _router!.push('/notifications');
        }
        break;
      case 'payment':
      case 'payment_success':
      case 'payment_failed':
        _router!.push('/wallet');
        break;
      case 'flea_market':
        final itemId = data['item_id'] ?? data['related_id'];
        if (itemId != null) {
          _router!.push('/flea-market/$itemId');
        } else {
          _router!.push('/notifications');
        }
        break;
      case 'activity':
        final activityId = data['activity_id'] ?? data['related_id'];
        if (activityId != null) {
          _router!.push('/activities/$activityId');
        } else {
          _router!.push('/notifications');
        }
        break;
      case 'leaderboard':
        final leaderboardId = data['leaderboard_id'] ?? data['related_id'];
        if (leaderboardId != null) {
          _router!.push('/leaderboard/$leaderboardId');
        } else {
          _router!.push('/notifications');
        }
        break;
      default:
        _router!.push('/notifications');
        break;
    }
  }

  /// 订阅主题
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    AppLogger.info('Subscribed to topic: $topic');
  }

  /// 取消订阅主题
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    AppLogger.info('Unsubscribed from topic: $topic');
  }
}
