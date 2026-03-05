import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// 触觉反馈管理器
/// iOS: 增强触觉反馈通过 MethodChannel (UINotificationFeedbackGenerator, UIImpactFeedbackGenerator rigid/soft)
/// Android/Web: Flutter 内置 HapticFeedback
class AppHaptics {
  AppHaptics._();

  static const _channel = MethodChannel('com.link2ur/haptics');
  static bool get _useNativeHaptics => !kIsWeb && Platform.isIOS;

  // ==================== 基础反馈 ====================

  /// 轻触反馈
  static void light() => HapticFeedback.lightImpact();

  /// 中等反馈
  static void medium() => HapticFeedback.mediumImpact();

  /// 重击反馈
  static void heavy() => HapticFeedback.heavyImpact();

  /// 选择反馈
  static void selection() => HapticFeedback.selectionClick();

  // ==================== 通知反馈 (iOS 增强) ====================

  /// 成功反馈 — iOS: UINotificationFeedbackGenerator(.success)
  static void success() {
    if (_useNativeHaptics) {
      _channel.invokeMethod('notificationSuccess');
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// 警告反馈 — iOS: UINotificationFeedbackGenerator(.warning)
  static void warning() {
    if (_useNativeHaptics) {
      _channel.invokeMethod('notificationWarning');
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// 错误反馈 — iOS: UINotificationFeedbackGenerator(.error)
  static void error() {
    if (_useNativeHaptics) {
      _channel.invokeMethod('notificationError');
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  // ==================== iOS 独有反馈 ====================

  /// 刚性碰撞反馈 (iOS: UIImpactFeedbackGenerator(.rigid), Android: mediumImpact)
  static void rigid() {
    if (_useNativeHaptics) {
      _channel.invokeMethod('impactRigid');
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// 柔和碰撞反馈 (iOS: UIImpactFeedbackGenerator(.soft), Android: lightImpact)
  static void soft() {
    if (_useNativeHaptics) {
      _channel.invokeMethod('impactSoft');
    } else {
      HapticFeedback.lightImpact();
    }
  }

  // ==================== 场景反馈 ====================

  /// 按钮点击
  static void buttonTap() => HapticFeedback.lightImpact();

  /// 卡片点击
  static void cardTap() => HapticFeedback.lightImpact();

  /// 列表选择
  static void listSelect() => HapticFeedback.selectionClick();

  /// 开关切换
  static void toggle() => HapticFeedback.mediumImpact();

  /// 滑块拖动
  static void slider() => HapticFeedback.selectionClick();

  /// 长按
  static void longPress() => HapticFeedback.mediumImpact();

  /// 拖拽
  static void drag() => HapticFeedback.selectionClick();

  /// 放下（拖拽结束）
  static void drop() => HapticFeedback.lightImpact();

  /// 下拉刷新触发
  static void pullToRefresh() => HapticFeedback.mediumImpact();

  /// 删除操作
  static void deleteAction() => HapticFeedback.heavyImpact();

  /// 收藏/取消收藏
  static void favorite() => HapticFeedback.lightImpact();

  /// 点赞
  static void like() => HapticFeedback.lightImpact();

  /// 分享
  static void share() => HapticFeedback.lightImpact();

  /// 发送消息
  static void sendMessage() => HapticFeedback.lightImpact();

  /// 截图
  static void screenshot() => HapticFeedback.mediumImpact();

  /// 支付成功 — 使用原生 success 反馈
  static void paymentSuccess() => success();

  /// Tab 切换
  static void tabSwitch() => HapticFeedback.selectionClick();

  /// 弹窗出现 — 使用柔和碰撞
  static void popupAppear() => soft();

  /// 通知到达
  static void notification() => HapticFeedback.mediumImpact();

  // ==================== 触发通用反馈 ====================

  /// 根据类型触发反馈
  static void trigger(HapticType type) {
    switch (type) {
      case HapticType.light:
        light();
      case HapticType.medium:
        medium();
      case HapticType.heavy:
        heavy();
      case HapticType.selection:
        selection();
      case HapticType.success:
        success();
      case HapticType.warning:
        warning();
      case HapticType.error:
        error();
    }
  }

  /// 预热所有反馈生成器
  /// 建议在 App 启动时调用
  static void prepareAll() {
    // Flutter 的 HapticFeedback 不需要显式预热
    // 但调用一次 selection 可以触发引擎初始化
    // 这里保持接口一致
  }
}

/// 触觉反馈类型
enum HapticType {
  light,
  medium,
  heavy,
  selection,
  success,
  warning,
  error,
}
