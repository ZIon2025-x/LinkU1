import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/logger.dart';
import 'storage_service.dart';
import 'api_service.dart';

/// 推送通知服务
/// 使用原生 APNs (iOS) / FCM (Android) + 本地通知
/// 通过 MethodChannel 与原生端通信获取推送 Token 和消息
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// MethodChannel 用于与原生推送交互
  static const _channel = MethodChannel('com.link2ur/push');

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
    // Web 上不支持推送通知
    if (kIsWeb) {
      AppLogger.info('PushNotificationService: Skipped on Web');
      return;
    }

    // 初始化本地通知
    await _initLocalNotifications();

    // 监听原生端推送事件
    _channel.setMethodCallHandler(_handleNativeCall);

    // 获取已有的推送 Token（原生端注册后缓存）
    try {
      final token = await _channel.invokeMethod<String>('getDeviceToken');
      if (token != null) {
        AppLogger.info('Push token obtained from native');
        await StorageService.instance.savePushToken(token);
        await _uploadTokenToServer(token);
      }
    } catch (e) {
      AppLogger.warning('Native push channel not ready: $e');
    }

    AppLogger.info('PushNotificationService initialized');
  }

  /// 处理原生端回调
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onTokenRefresh':
        final token = call.arguments as String;
        AppLogger.info('Push token refreshed');
        await StorageService.instance.savePushToken(token);
        await _uploadTokenToServer(token);
        break;
      case 'onRemoteMessage':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        _handleRemoteMessage(data);
        break;
      case 'onNotificationTapped':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        _handleNotificationTapped(data);
        break;
    }
  }

  /// 上传推送 Token 到服务器
  /// 与原生 iOS 项目 APIService.registerDeviceToken 保持一致
  Future<void> _uploadTokenToServer(String token) async {
    try {
      if (_apiService == null) {
        AppLogger.warning('ApiService not set, skipping token upload');
        return;
      }

      // 获取设备信息（与原生项目一致）
      String deviceId = '';
      final platformId = ApiConfig.platformId;
      if (!kIsWeb) {
        final deviceInfo = DeviceInfoPlugin();
        if (platformId == 'ios') {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? '';
        } else if (platformId == 'android') {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        }
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final deviceLanguage = _getDeviceLanguage();

      await _apiService!.post(
        ApiEndpoints.deviceToken,
        data: {
          'device_token': token,
          'platform': platformId,
          'device_id': deviceId,
          'app_version': packageInfo.version,
          'device_language': deviceLanguage,
        },
      );
      AppLogger.info('Push token uploaded to server');
    } catch (e) {
      AppLogger.error('Failed to upload push token to server', e);
    }
  }

  /// 注销推送 Token（登出时调用）
  Future<void> unregisterToken() async {
    try {
      final token = StorageService.instance.getPushToken();
      if (token == null || _apiService == null) return;

      await _apiService!.delete(
        ApiEndpoints.deviceToken,
        data: {'device_token': token},
      );
      AppLogger.info('Push token unregistered from server');
    } catch (e) {
      AppLogger.error('Failed to unregister push token', e);
    }
  }

  /// 初始化本地通知
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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
    if (!kIsWeb && ApiConfig.platformId == 'android') {
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

  /// 处理远程推送消息（前台收到时显示本地通知）
  /// 支持双语 payload：后端可在 custom.localized 中发送多语言内容
  /// 格式: {"localized": {"en": {"title": "...", "body": "..."}, "zh": {"title": "...", "body": "..."}}}
  void _handleRemoteMessage(Map<String, dynamic> data) {
    AppLogger.info('Remote message received');

    String title;
    String body;

    // 尝试从 localized 字段提取当前语言内容
    final localized = _extractLocalized(data);
    if (localized != null) {
      final lang = _getDeviceLanguage();
      final content = (localized[lang] as Map<String, dynamic>?) ??
          (localized['en'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      title = content['title'] as String? ?? '';
      body = content['body'] as String? ?? '';
    } else {
      // 后端已按 device_language 发送单语言，直接使用
      title = data['title'] as String? ?? '';
      body = data['body'] as String? ?? '';
    }

    if (title.isNotEmpty || body.isNotEmpty) {
      _showLocalNotification(
        title: title,
        body: body,
        payload: data.toString(),
      );
    }
  }

  /// 从 payload 中提取 localized 内容
  /// 兼容 custom.localized 和 localized 两种格式
  Map<String, dynamic>? _extractLocalized(Map<String, dynamic> data) {
    // 格式1: data["localized"]
    if (data['localized'] is Map) {
      return Map<String, dynamic>.from(data['localized'] as Map);
    }
    // 格式2: data["custom"]["localized"]
    if (data['custom'] is Map) {
      final custom = Map<String, dynamic>.from(data['custom'] as Map);
      if (custom['localized'] is Map) {
        return Map<String, dynamic>.from(custom['localized'] as Map);
      }
    }
    return null;
  }

  /// 获取设备语言（简化为 "en" 或 "zh"）
  /// 与原生项目 PushNotificationLocalizer.deviceLanguage 逻辑一致
  String _getDeviceLanguage() {
    // 优先从 StorageService 获取用户设置的语言
    final savedLang = StorageService.instance.getLanguage();
    if (savedLang != null) {
      return savedLang.startsWith('zh') ? 'zh' : 'en';
    }
    // Web 上使用 window.navigator.language 的结果已由 Flutter 自动处理
    return 'en';
  }

  /// 处理通知点击（从原生端传来）
  void _handleNotificationTapped(Map<String, dynamic> data) {
    AppLogger.info('Notification tapped from native');
    if (data.containsKey('type')) {
      _navigateByNotificationType(data['type'] as String, data);
    } else {
      _router?.push('/notifications');
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

  /// 通知点击回调（本地通知）
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.info('Notification tapped: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
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
}
