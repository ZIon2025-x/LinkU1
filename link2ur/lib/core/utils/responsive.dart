import 'package:flutter/material.dart';

/// 响应式断点常量
/// 用于区分移动端与桌面端布局
class Breakpoints {
  Breakpoints._();

  /// 移动端最大宽度（< 768px 为移动端）
  static const double mobile = 768;

  /// 平板最大宽度（与桌面端合并，>= 768px 统一使用桌面布局）
  static const double tablet = 768;

  /// 桌面端最大宽度（用于超宽屏约束）
  static const double desktop = 1440;

  /// 内容区最大宽度（桌面端居中约束）
  static const double maxContentWidth = 1100;

  /// 抽屉宽度
  static const double drawerWidth = 320;
}

/// 响应式工具方法
class ResponsiveUtils {
  ResponsiveUtils._();

  /// 当前是否为移动端布局（< 768px）
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < Breakpoints.mobile;

  /// 当前是否为桌面布局（>= 768px，平板与桌面合并）
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoints.mobile;

  /// 当前是否为宽桌面（>= 1024px，用于更宽的布局）
  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;

  /// 当前是否为非移动端（同 isDesktop）
  static bool isWideScreen(BuildContext context) => isDesktop(context);
}

/// 响应式布局组件
/// 根据屏幕宽度自动选择 mobile / desktop 布局
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  /// 移动端布局（< 768px）
  final Widget mobile;

  /// 平板布局（保留兼容性，不再单独使用）
  final Widget? tablet;

  /// 桌面布局（>= 768px）
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.mobile) {
          return desktop;
        }
        return mobile;
      },
    );
  }
}
