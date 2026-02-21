import 'package:flutter/material.dart';

/// 网格项类型 — 对齐 iOS AdaptiveLayout.GridItemType
enum GridItemType {
  task, // 任务卡片
  fleaMarket, // 跳蚤市场商品
  forum, // 论坛帖子
  standard, // 默认
}

/// 响应式断点常量
class Breakpoints {
  Breakpoints._();

  // ===== 新断点（Material 3 风格）=====

  /// 紧凑型：手机竖屏（< 600px）
  static const double compact = 600;

  /// 中等型：平板竖屏 / 大手机横屏（600-900px）
  static const double medium = 900;

  /// 展开型：平板横屏 / 桌面（> 1200px）
  static const double expanded = 1200;

  // ===== 兼容旧断点 =====

  /// 移动端最大宽度（< 768px 为移动端）
  static const double mobile = 768;

  /// 平板最大宽度（与桌面端合并，>= 768px 统一使用桌面布局）
  static const double tablet = 768;

  /// 桌面端最大宽度（用于超宽屏约束）
  static const double desktop = 1440;

  /// 内容区最大宽度（桌面端居中约束，对齐 frontend 1200px）
  static const double maxContentWidth = 1200;

  /// 详情页最大宽度（防止大屏拉伸过宽，对齐 iOS 900px）
  static const double maxDetailWidth = 900;

  /// 抽屉宽度（对齐 frontend HamburgerMenu 350-400px）
  static const double drawerWidth = 360;
}

/// 响应式工具方法
class ResponsiveUtils {
  ResponsiveUtils._();

  // ===== 设备级别判断 =====

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

  /// 是否为平板级别（600-1200px）
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= Breakpoints.compact && w < Breakpoints.expanded;
  }

  // ===== 自适应网格 — 对齐 iOS AdaptiveLayout =====

  /// 根据屏幕宽度和内容类型计算网格列数
  ///
  /// 对齐 iOS `AdaptiveLayout.gridColumnCount`:
  /// | 宽度范围           | task | fleaMarket | forum | standard |
  /// |-------------------|------|------------|-------|----------|
  /// | < 600  (手机)      |  2   |     2      |   1   |    2     |
  /// | 600-900 (平板竖)    |  2   |     3      |   2   |    2     |
  /// | 900-1200(平板横)    |  3   |     4      |   2   |    3     |
  /// | > 1200  (桌面)      |  4   |     5      |   3   |    4     |
  static int gridColumnCount(
    BuildContext context, {
    GridItemType type = GridItemType.standard,
  }) {
    final w = MediaQuery.sizeOf(context).width;

    if (w >= Breakpoints.expanded) {
      // 桌面
      switch (type) {
        case GridItemType.task:
          return 4;
        case GridItemType.fleaMarket:
          return 5;
        case GridItemType.forum:
          return 3;
        case GridItemType.standard:
          return 4;
      }
    } else if (w >= Breakpoints.medium) {
      // 平板横屏
      switch (type) {
        case GridItemType.task:
          return 3;
        case GridItemType.fleaMarket:
          return 4;
        case GridItemType.forum:
          return 2;
        case GridItemType.standard:
          return 3;
      }
    } else if (w >= Breakpoints.compact) {
      // 平板竖屏
      switch (type) {
        case GridItemType.task:
          return 2;
        case GridItemType.fleaMarket:
          return 3;
        case GridItemType.forum:
          return 2;
        case GridItemType.standard:
          return 2;
      }
    } else {
      // 手机
      switch (type) {
        case GridItemType.task:
          return 2;
        case GridItemType.fleaMarket:
          return 2;
        case GridItemType.forum:
          return 1;
        case GridItemType.standard:
          return 2;
      }
    }
  }

  // ===== 自适应间距与约束 =====

  /// 自适应水平内边距（桌面端 24 对齐 frontend）
  /// compact: 16, medium: 20, expanded: 24
  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= Breakpoints.expanded) return 24.0;
    if (w >= Breakpoints.medium) return 24.0;
    if (w >= Breakpoints.compact) return 20.0;
    return 16.0; // AppSpacing.md
  }

  /// 详情页最大宽度约束
  /// 手机: 不限制, 平板及以上: 900
  static double detailMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= Breakpoints.compact) return Breakpoints.maxDetailWidth;
    return double.infinity;
  }
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

  /// 平板布局（768-1200px 使用；未提供时回退到 desktop）
  final Widget? tablet;

  /// 桌面布局（>= 768px）
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < Breakpoints.mobile) {
          return mobile;
        }
        // 平板横屏区间 (768-1200)：若提供 tablet 则使用，否则 desktop
        if (tablet != null && w >= Breakpoints.mobile && w < Breakpoints.expanded) {
          return tablet!;
        }
        return desktop;
      },
    );
  }
}
