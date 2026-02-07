import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger.dart';

/// App Review 管理器
/// 对齐 iOS AppReview.swift
/// 基于启动次数、安装天数、上次请求间隔来控制评价弹窗
class AppReviewManager {
  AppReviewManager._();
  static final AppReviewManager instance = AppReviewManager._();

  final InAppReview _inAppReview = InAppReview.instance;

  // 评价条件阈值
  static const int _minLaunchCount = 5;
  static const int _minDaysSinceInstall = 7;
  static const int _minDaysSinceLastRequest = 30;

  // SharedPreferences keys
  static const String _launchCountKey = 'app_review_launch_count';
  static const String _installDateKey = 'app_review_install_date';
  static const String _lastRequestDateKey = 'app_review_last_request_date';
  static const String _requestCountKey = 'app_review_request_count';

  /// 初始化（记录安装日期）
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_installDateKey)) {
      await prefs.setString(
        _installDateKey,
        DateTime.now().toIso8601String(),
      );
      AppLogger.info('AppReview: Install date recorded');
    }
  }

  /// 增加启动计数
  Future<void> incrementLaunchCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_launchCountKey) ?? 0;
    await prefs.setInt(_launchCountKey, count + 1);
  }

  /// 检查是否可以请求评价
  Future<bool> get canRequestReview async {
    final prefs = await SharedPreferences.getInstance();

    // 检查启动次数
    final launchCount = prefs.getInt(_launchCountKey) ?? 0;
    if (launchCount < _minLaunchCount) return false;

    // 检查安装天数
    final installDateStr = prefs.getString(_installDateKey);
    if (installDateStr != null) {
      final installDate = DateTime.tryParse(installDateStr);
      if (installDate != null) {
        final daysSinceInstall =
            DateTime.now().difference(installDate).inDays;
        if (daysSinceInstall < _minDaysSinceInstall) return false;
      }
    }

    // 检查距上次请求的天数
    final lastRequestStr = prefs.getString(_lastRequestDateKey);
    if (lastRequestStr != null) {
      final lastRequest = DateTime.tryParse(lastRequestStr);
      if (lastRequest != null) {
        final daysSinceLastRequest =
            DateTime.now().difference(lastRequest).inDays;
        if (daysSinceLastRequest < _minDaysSinceLastRequest) return false;
      }
    }

    return true;
  }

  /// 请求评价
  /// 自动检查条件，满足时弹出系统评价弹窗
  Future<void> requestReview() async {
    final shouldRequest = await canRequestReview;
    if (!shouldRequest) {
      AppLogger.info('AppReview: Conditions not met, skipping');
      return;
    }

    try {
      final available = await _inAppReview.isAvailable();
      if (!available) {
        AppLogger.info('AppReview: In-app review not available');
        return;
      }

      await _inAppReview.requestReview();

      // 记录请求时间和次数
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastRequestDateKey,
        DateTime.now().toIso8601String(),
      );
      final count = prefs.getInt(_requestCountKey) ?? 0;
      await prefs.setInt(_requestCountKey, count + 1);

      AppLogger.info('AppReview: Review requested successfully');
    } catch (e) {
      AppLogger.error('AppReview: Request review failed', e);
    }
  }

  /// 打开应用商店评价页面
  Future<void> openStoreReview({String? appStoreId}) async {
    try {
      await _inAppReview.openStoreListing(
        appStoreId: appStoreId,
      );
    } catch (e) {
      AppLogger.error('AppReview: Open store listing failed', e);
    }
  }

  /// 重置评价记录
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_launchCountKey);
    await prefs.remove(_lastRequestDateKey);
    await prefs.remove(_requestCountKey);
    AppLogger.info('AppReview: Records reset');
  }
}
