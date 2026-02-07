import 'package:flutter/services.dart';

/// 触觉反馈工具类
/// 参考iOS DesignSystem中的haptic feedback模式
/// 统一管理全App触觉反馈，与iOS原生体验对齐
class HapticHelper {
  HapticHelper._();

  /// 选择反馈 - Tab切换、选项选择
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// 轻触反馈 - 主按钮点击、普通交互
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// 中等反馈 - FAB点击、重要操作
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// 重触反馈 - 删除、危险操作确认
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// 成功反馈 - 操作成功完成
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// 警告反馈 - 警告提示
  static void warning() {
    HapticFeedback.heavyImpact();
  }

  /// 错误反馈 - 操作失败
  static void error() {
    HapticFeedback.heavyImpact();
  }
}
