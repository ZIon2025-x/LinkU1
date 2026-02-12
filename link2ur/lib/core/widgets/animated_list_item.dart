import 'package:flutter/material.dart';

/// 列表项入场动画方向
enum AnimatedListDirection {
  /// 从下方进入（默认）
  bottom,

  /// 从左侧进入
  left,

  /// 从右侧进入
  right,

  /// 缩放进入
  scale,
}

/// 列表项分布入场动画
///
/// 包裹列表的每个 item，实现多属性交错动画入场效果：
/// 透明度 → 位移 → 缩放按顺序错开，带弹簧曲线。
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
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animationDuration = const Duration(milliseconds: 500),
    this.slideOffset = 30.0,
    this.curve = Curves.easeOutCubic,
    this.direction = AnimatedListDirection.bottom,
    this.useSpringEffect = false,
  });

  /// 列表索引，用于计算延迟
  final int index;

  /// 子组件
  final Widget child;

  /// 每个 item 之间的延迟（瀑布效果）
  final Duration staggerDelay;

  /// 单个 item 的动画时长
  final Duration animationDuration;

  /// 位移偏移量 (px)
  final double slideOffset;

  /// 动画曲线
  final Curve curve;

  /// 进入方向
  final AnimatedListDirection direction;

  /// 是否使用弹簧效果
  final bool useSpringEffect;

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  /// index > 5 的列表项跳过动画，直接显示（避免大量无用 Future 和 AnimationController）
  /// 降低阈值：同时存在 6+ 个 AnimationController 在 debug 模式下会产生明显卡顿
  bool get _shouldAnimate => widget.index <= 5;

  @override
  void initState() {
    super.initState();

    if (!_shouldAnimate) return;

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    final effectiveCurve =
        widget.useSpringEffect ? Curves.elasticOut : widget.curve;

    // 简化为两层动画：透明度 + 位移（去掉 Scale 层减少 transform 开销）
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    final slideBegin = switch (widget.direction) {
      AnimatedListDirection.bottom => Offset(0, widget.slideOffset),
      AnimatedListDirection.left => Offset(-widget.slideOffset, 0),
      AnimatedListDirection.right => Offset(widget.slideOffset, 0),
      AnimatedListDirection.scale => Offset.zero,
    };

    _slideAnimation = Tween<Offset>(
      begin: slideBegin,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller!,
      curve: Interval(0.1, 1.0, curve: effectiveCurve),
    ));

    // 错开延迟启动 — 延迟到首帧渲染后再开始动画
    // 避免在 build 阶段大量 Future.delayed 占用主线程调度
    final delay = widget.staggerDelay * widget.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (delay == Duration.zero) {
        _controller?.forward();
      } else {
        Future.delayed(delay, () {
          if (mounted) _controller?.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 超出动画范围的列表项直接显示，节省 AnimationController 开销
    // RepaintBoundary 隔离每个列表项的重绘区域，避免单项更新导致相邻项重绘
    if (!_shouldAnimate) {
      return RepaintBoundary(child: widget.child);
    }

    // 使用 FadeTransition 替代 Opacity widget：
    // Opacity widget 在值不为 0/1 时会触发 saveLayer（离屏缓冲区），
    // 导致每帧额外的 GPU 合成。FadeTransition 直接操作 RenderObject.opacity，
    // 无需 saveLayer，性能显著更优。
    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) => Transform.translate(
        offset: _slideAnimation!.value,
        child: child,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation!,
        child: RepaintBoundary(child: widget.child),
      ),
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
