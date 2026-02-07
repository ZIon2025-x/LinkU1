import 'package:flutter/services.dart';

/// 触觉反馈管理器
/// 对齐 iOS HapticFeedback.swift
/// 提供完整的触觉反馈类型和场景方法
class AppHaptics {
  AppHaptics._();

  // ==================== 基础反馈 ====================

  /// 轻触反馈
  static void light() => HapticFeedback.lightImpact();

  /// 中等反馈
  static void medium() => HapticFeedback.mediumImpact();

  /// 重击反馈
  static void heavy() => HapticFeedback.heavyImpact();

  /// 选择反馈
  static void selection() => HapticFeedback.selectionClick();

  // ==================== 通知反馈 ====================

  /// 成功反馈 - 中等力度 + 延迟轻触
  static void success() => HapticFeedback.mediumImpact();

  /// 警告反馈 - 中等力度
  static void warning() => HapticFeedback.mediumImpact();

  /// 错误反馈 - 重击力度
  static void error() => HapticFeedback.heavyImpact();

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

  /// 支付成功
  static void paymentSuccess() => HapticFeedback.heavyImpact();

  /// Tab 切换
  static void tabSwitch() => HapticFeedback.selectionClick();

  /// 弹窗出现
  static void popupAppear() => HapticFeedback.lightImpact();

  /// 通知到达
  static void notification() => HapticFeedback.mediumImpact();

  // ==================== 触发通用反馈 ====================

  /// 根据类型触发反馈
  static void trigger(HapticType type) {
    switch (type) {
      case HapticType.light:
        light();
        break;
      case HapticType.medium:
        medium();
        break;
      case HapticType.heavy:
        heavy();
        break;
      case HapticType.selection:
        selection();
        break;
      case HapticType.success:
        success();
        break;
      case HapticType.warning:
        warning();
        break;
      case HapticType.error:
        error();
        break;
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
