import 'package:flutter/material.dart';

/// 全局动画常量
///
/// 统一管理动画时长与曲线，确保全 App 动画节奏一致。
/// 参考 Material Motion 规范 + iOS Human Interface Guidelines。
class AppAnimations {
  AppAnimations._();

  // ==================== 时长 ====================

  /// 微交互（按钮按压、图标切换）
  static const Duration micro = Duration(milliseconds: 100);

  /// 快速（Chip 选中、开关切换、小组件状态变化）
  static const Duration fast = Duration(milliseconds: 200);

  /// 标准（卡片展开、列表项入场、Tab 切换）
  static const Duration standard = Duration(milliseconds: 300);

  /// 中等（页面转场、模态弹出）
  static const Duration medium = Duration(milliseconds: 400);

  /// 慢速（复杂编排动画、引导页）
  static const Duration slow = Duration(milliseconds: 500);

  /// 强调（结果弹窗、庆祝动画）
  static const Duration emphasis = Duration(milliseconds: 600);

  // ==================== 曲线 ====================

  /// 标准减速（进入视图）— Material 3 emphasized decelerate
  static const Curve decelerate = Curves.easeOutCubic;

  /// 标准加速（退出视图）
  static const Curve accelerate = Curves.easeInCubic;

  /// 标准缓动（状态变化）
  static const Curve standard_ = Curves.easeInOutCubic;

  /// 弹簧效果（按钮回弹、卡片弹入）
  static const Curve spring = Curves.easeOutBack;

  /// 弹性效果（图标弹出、强调动画）
  static const Curve elastic = Curves.elasticOut;

  /// 线性（进度条、计时器）
  static const Curve linear = Curves.linear;

  /// 锐利减速（快速响应的交互）
  static const Curve sharpDecelerate = Curves.easeOutQuart;

  // ==================== 页面转场时长 ====================

  /// 前进转场
  static const Duration pageForward = Duration(milliseconds: 350);

  /// 后退转场
  static const Duration pageReverse = Duration(milliseconds: 300);

  /// 模态弹出
  static const Duration modalEnter = Duration(milliseconds: 350);

  /// 模态关闭
  static const Duration modalExit = Duration(milliseconds: 250);

  // ==================== 列表交错 ====================

  /// 列表项交错延迟
  static const Duration staggerDelay = Duration(milliseconds: 50);

  /// 最大交错数量（超过此数的列表项不做入场动画）
  static const int maxStaggerCount = 8;

  // ==================== 便捷方法 ====================

  /// 创建标准 CurvedAnimation（减速进入）
  static CurvedAnimation decelerateAnimation(Animation<double> parent) {
    return CurvedAnimation(parent: parent, curve: decelerate);
  }

  /// 创建标准 CurvedAnimation（加速退出）
  static CurvedAnimation accelerateAnimation(Animation<double> parent) {
    return CurvedAnimation(parent: parent, curve: accelerate);
  }
}
