import 'dart:ui';
import 'package:flutter/material.dart';
import '../design/app_colors.dart';

/// 自定义吸顶 Header 代理
///
/// 滚动时 Header 吸顶，吸顶过程中背景从透明过渡到毛玻璃效果。
/// 使用 SliverPersistentHeaderDelegate 实现。
///
/// 用法:
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverPersistentHeader(
///       pinned: true,
///       delegate: StickyHeaderDelegate(
///         minHeight: 50,
///         maxHeight: 50,
///         child: YourTabBar(),
///       ),
///     ),
///   ],
/// )
/// ```
class StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
    this.enableBlur = true,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;
  final bool enableBlur;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 吸顶进度（0=完全展开，1=完全收起）
    final progress =
        (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    if (!enableBlur || progress < 0.1) {
      return SizedBox.expand(child: child);
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10 * progress,
          sigmaY: 10 * progress,
        ),
        child: Container(
          color: isDark
              ? AppColors.backgroundDark.withValues(alpha: 0.8 * progress)
              : AppColors.backgroundLight.withValues(alpha: 0.85 * progress),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
