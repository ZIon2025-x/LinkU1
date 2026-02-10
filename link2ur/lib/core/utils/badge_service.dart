import 'dart:io';
import 'package:flutter/services.dart';

import 'logger.dart';

/// App 角标管理服务
/// 参考 iOS 原生 BadgeManager.swift
/// 通过 MethodChannel 调用原生 API 更新 app 图标角标
class BadgeService {
  BadgeService._();
  static final BadgeService instance = BadgeService._();

  /// MethodChannel 用于与原生角标 API 通信
  static const _channel = MethodChannel('com.link2ur/badge');

  /// 更新 App 图标角标数
  /// [count] 未读总数（通知 + 消息）
  Future<void> updateBadge(int count) async {
    if (!Platform.isIOS) return; // Android 由系统/launcher 处理

    try {
      await _channel.invokeMethod('updateBadge', count);
    } catch (e) {
      AppLogger.error('BadgeService - updateBadge failed', e);
    }
  }

  /// 清除 App 图标角标
  Future<void> clearBadge() async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('clearBadge');
    } catch (e) {
      AppLogger.error('BadgeService - clearBadge failed', e);
    }
  }

  /// 获取当前角标数
  Future<int> getBadgeCount() async {
    if (!Platform.isIOS) return 0;

    try {
      final count = await _channel.invokeMethod<int>('getBadgeCount');
      return count ?? 0;
    } catch (e) {
      AppLogger.error('BadgeService - getBadgeCount failed', e);
      return 0;
    }
  }

  /// 根据未读通知数和未读消息数更新角标
  /// 与原生项目 AppState.updateAppIconBadge() 逻辑一致
  Future<void> updateBadgeFromCounts({
    required int unreadNotificationCount,
    required int unreadMessageCount,
  }) async {
    final totalUnread = unreadNotificationCount + unreadMessageCount;
    await updateBadge(totalUnread);
  }
}
