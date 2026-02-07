import 'package:firebase_analytics/firebase_analytics.dart';

import 'logger.dart';

/// 分析服务
/// 参考iOS Analytics.swift
/// 封装事件追踪和用户行为分析
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _isInitialized = false;

  /// 初始化分析服务
  Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _isInitialized = true;
      AppLogger.info('Analytics - Initialized');
    } catch (e) {
      AppLogger.error('Analytics - Initialization failed', e);
    }
  }

  /// 记录页面浏览
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      AppLogger.error('Analytics - logScreenView failed', e);
    }
  }

  /// 记录自定义事件
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics?.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      AppLogger.error('Analytics - logEvent failed', e);
    }
  }

  /// 设置用户ID
  Future<void> setUserId(String? userId) async {
    if (!_isInitialized) return;

    try {
      await _analytics?.setUserId(id: userId);
    } catch (e) {
      AppLogger.error('Analytics - setUserId failed', e);
    }
  }

  /// 设置用户属性
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics?.setUserProperty(name: name, value: value);
    } catch (e) {
      AppLogger.error('Analytics - setUserProperty failed', e);
    }
  }

  // ==================== 业务事件 ====================

  /// 用户登录
  Future<void> logLogin({String? method}) async {
    await logEvent(name: 'login', parameters: {
      if (method != null) 'method': method,
    });
  }

  /// 用户注册
  Future<void> logSignUp({String? method}) async {
    await logEvent(name: 'sign_up', parameters: {
      if (method != null) 'method': method,
    });
  }

  /// 发布任务
  Future<void> logTaskCreated({
    required int taskId,
    String? category,
  }) async {
    await logEvent(name: 'task_created', parameters: {
      'task_id': taskId,
      if (category != null) 'category': category,
    });
  }

  /// 申请任务
  Future<void> logTaskApplied({required int taskId}) async {
    await logEvent(name: 'task_applied', parameters: {'task_id': taskId});
  }

  /// 发布论坛帖子
  Future<void> logForumPostCreated({required int postId}) async {
    await logEvent(name: 'forum_post_created', parameters: {'post_id': postId});
  }

  /// 跳蚤市场发布
  Future<void> logFleaMarketItemCreated({required int itemId}) async {
    await logEvent(
      name: 'flea_market_item_created',
      parameters: {'item_id': itemId},
    );
  }

  /// 支付完成
  Future<void> logPaymentCompleted({
    required double amount,
    required String currency,
  }) async {
    await logEvent(name: 'payment_completed', parameters: {
      'amount': amount,
      'currency': currency,
    });
  }

  /// 分享内容
  Future<void> logShare({
    required String contentType,
    required String itemId,
    String? method,
  }) async {
    await _analytics?.logShare(
      contentType: contentType,
      itemId: itemId,
      method: method ?? 'unknown',
    );
  }

  /// 搜索
  Future<void> logSearch({required String searchTerm}) async {
    await _analytics?.logSearch(searchTerm: searchTerm);
  }

  /// 获取 Firebase Analytics Observer（用于 GoRouter）
  FirebaseAnalyticsObserver? get observer {
    if (_analytics == null) return null;
    return FirebaseAnalyticsObserver(analytics: _analytics!);
  }
}
