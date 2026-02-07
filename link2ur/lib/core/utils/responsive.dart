import 'package:flutter/material.dart';

/// 响应式断点常量
/// 用于区分移动端、平板、桌面布局
class Breakpoints {
  Breakpoints._();

  /// 移动端最大宽度
  static const double mobile = 600;

  /// 平板最大宽度
  static const double tablet = 1024;

  /// 桌面端最大宽度（用于超宽屏约束）
  static const double desktop = 1440;

  /// 内容区最大宽度（桌面端居中约束）
  static const double maxContentWidth = 960;

  /// 侧边栏展开宽度
  static const double sidebarExpanded = 240;

  /// 侧边栏收起宽度（NavigationRail）
  static const double sidebarCollapsed = 72;
}

/// 响应式工具方法
class ResponsiveUtils {
  ResponsiveUtils._();

  /// 当前是否为移动端布局
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < Breakpoints.mobile;

  /// 当前是否为平板布局
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= Breakpoints.mobile && width < Breakpoints.tablet;
  }

  /// 当前是否为桌面布局
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

  /// 当前是否为非移动端（平板或桌面）
  static bool isWideScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoints.mobile;
}

/// 响应式布局组件
/// 根据屏幕宽度自动选择 mobile / tablet / desktop 布局
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  /// 移动端布局（< 600px）
  final Widget mobile;

  /// 平板布局（600-1024px），不提供则使用 desktop
  final Widget? tablet;

  /// 桌面布局（>= 1024px）
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.tablet) {
          return desktop;
        } else if (constraints.maxWidth >= Breakpoints.mobile) {
          return tablet ?? desktop;
        }
        return mobile;
      },
    );
  }
}
