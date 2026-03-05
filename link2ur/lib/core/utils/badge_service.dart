import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import 'logger.dart';

/// App 角标管理服务
/// iOS: MethodChannel (原生 UNUserNotificationCenter)
/// Android: flutter_app_badger (支持三星、华为、小米等启动器)
class BadgeService {
  BadgeService._();
  static final BadgeService instance = BadgeService._();

  /// iOS 专用 MethodChannel
  static const _channel = MethodChannel('com.link2ur/badge');

  /// iOS 使用原生 MethodChannel，Android 使用 flutter_app_badger
  static bool get _useNativeChannel => !kIsWeb && Platform.isIOS;

  /// 更新 App 图标角标数
  /// [count] 未读总数（通知 + 消息）
  Future<void> updateBadge(int count) async {
    if (kIsWeb) return;

    try {
      if (_useNativeChannel) {
        await _channel.invokeMethod('updateBadge', count);
      } else {
        if (count > 0) {
          FlutterAppBadger.updateBadgeCount(count);
        } else {
          FlutterAppBadger.removeBadge();
        }
      }
    } catch (e) {
      AppLogger.error('BadgeService - updateBadge failed', e);
    }
  }

  /// 清除 App 图标角标
  Future<void> clearBadge() async {
    if (kIsWeb) return;

    try {
      if (_useNativeChannel) {
        await _channel.invokeMethod('clearBadge');
      } else {
        FlutterAppBadger.removeBadge();
      }
    } catch (e) {
      AppLogger.error('BadgeService - clearBadge failed', e);
    }
  }

  /// 获取当前角标数
  Future<int> getBadgeCount() async {
    if (kIsWeb) return 0;

    try {
      if (_useNativeChannel) {
        final count = await _channel.invokeMethod<int>('getBadgeCount');
        return count ?? 0;
      }
      // flutter_app_badger 不支持在 Android 上读取角标数
      return 0;
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
