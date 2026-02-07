import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/utils/logger.dart';
import 'storage_service.dart';

/// 推送通知服务
/// 封装 Firebase Cloud Messaging 和本地通知
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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
      // TODO: 上传新token到服务器
    });

    AppLogger.info('PushNotificationService initialized');
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
    final androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 创建 Android 通知渠道
    if (Platform.isAndroid) {
      final channel = AndroidNotificationChannel(
        'link2ur_default',
        'Link2Ur 通知',
        description: 'Link2Ur 应用通知',
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
        // TODO: 上传token到服务器
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
    // TODO: 根据 message.data 导航到对应页面
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
    final androidDetails = AndroidNotificationDetails(
      'link2ur_default',
      'Link2Ur 通知',
      channelDescription: 'Link2Ur 应用通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
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
    // TODO: 解析 payload 并导航
  }

  /// 根据通知类型导航
  void _navigateByNotificationType(
    String type,
    Map<String, dynamic> data,
  ) {
    // TODO: 使用 GoRouter 进行导航
    switch (type) {
      case 'task_update':
        // 导航到任务详情
        break;
      case 'message':
        // 导航到聊天
        break;
      case 'forum_reply':
        // 导航到帖子详情
        break;
      default:
        // 导航到通知中心
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
