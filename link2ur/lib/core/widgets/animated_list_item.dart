import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 列表项分布入场动画
///
/// 包裹列表的每个 item，实现从下方淡入 + 上移的入场效果，
/// 各 item 之间有错开延迟，形成波浪式入场。
///
/// 用法:
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => AnimatedListItem(
///     index: index,
///     child: YourCard(...),
///   ),
/// )
/// ```
class AnimatedListItem extends StatefulWidget {
  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.animationDuration = const Duration(milliseconds: 400),
    this.slideOffset = 30.0,
    this.curve = Curves.easeOutCubic,
  });

  /// 列表索引，用于计算延迟
  final int index;

  /// 子组件
  final Widget child;

  /// 每个 item 之间的延迟
  final Duration staggerDelay;

  /// 单个 item 的动画时长
  final Duration animationDuration;

  /// 上移偏移量 (px)
  final double slideOffset;

  /// 动画曲线
  final Curve curve;

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(curved);

    // 错开延迟启动，最多错开8个（避免长列表延迟太久）
    final clampedIndex = math.min(widget.index, 8);
    final delay = widget.staggerDelay * clampedIndex;

    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: _slideAnimation.value,
        child: Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Sliver 版本的分布入场代理
///
/// 用于 CustomScrollView / SliverList 等场景。
/// 包裹在 SliverList 的 delegate 中使用。
///
/// 用法:
/// ```dart
/// SliverList(
///   delegate: SliverChildBuilderDelegate(
///     (context, index) => AnimatedListItem(
///       index: index,
///       child: YourCard(...),
///     ),
///   ),
/// )
/// ```
