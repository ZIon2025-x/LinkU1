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

    // 计算透明度
    // 如果是收缩型 Header (max > min)，根据收缩进度计算
    // 如果是固定高度 Header (max == min)，根据是否遮挡内容计算
    double opacity = 0.0;
    if (maxExtent > minExtent) {
      opacity = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    } else {
      opacity = overlapsContent ? 1.0 : 0.0;
    }

    if (!enableBlur || opacity < 0.1) {
      return SizedBox.expand(child: child);
    }

    return ClipRect(
      child: BackdropFilter(
        // 使用固定模糊半径，避免滚动时频繁重绘导致性能问题
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: isDark
              ? AppColors.backgroundDark.withValues(alpha: 0.8 * opacity)
              : AppColors.backgroundLight.withValues(alpha: 0.85 * opacity),
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
