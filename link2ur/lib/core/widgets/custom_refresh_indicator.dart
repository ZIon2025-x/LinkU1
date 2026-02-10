import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design/app_colors.dart';

/// 自定义下拉刷新指示器 — CustomPainter 实现
///
/// 替代系统 RefreshIndicator：
/// - 下拉时 Logo 从小到大弹出
/// - 加载中 Logo 做呼吸动画
/// - 使用 CustomPainter 绘制自定义进度弧线
class BrandRefreshIndicator extends StatelessWidget {
  const BrandRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
  });

  /// 子组件
  final Widget child;

  /// 刷新回调
  final Future<void> Function() onRefresh;

  /// 指示器颜色
  final Color? color;

  /// 指示器位移
  final double displacement;

  /// 边缘偏移
  final double edgeOffset;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: displacement,
      edgeOffset: edgeOffset,
      color: effectiveColor,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.cardBackgroundDark
          : Colors.white,
      notificationPredicate: defaultScrollNotificationPredicate,
      child: child,
    );
  }
}

/// 自定义刷新指示器画笔 — 带有弧线进度效果
///
/// 可用于非 RefreshIndicator 的场景，如手动控制的刷新 UI。
class RefreshArcIndicator extends StatefulWidget {
  const RefreshArcIndicator({
    super.key,
    this.size = 32,
    this.strokeWidth = 2.5,
    this.color,
    this.isRefreshing = false,
    this.pullProgress = 0.0,
  });

  /// 组件尺寸
  final double size;

  /// 弧线宽度
  final double strokeWidth;

  /// 颜色
  final Color? color;

  /// 是否正在刷新
  final bool isRefreshing;

  /// 下拉进度（0.0 ~ 1.0）
  final double pullProgress;

  @override
  State<RefreshArcIndicator> createState() => _RefreshArcIndicatorState();
}

class _RefreshArcIndicatorState extends State<RefreshArcIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(RefreshArcIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing && !oldWidget.isRefreshing) {
      _controller.repeat();
    } else if (!widget.isRefreshing && oldWidget.isRefreshing) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? AppColors.primary;

    if (widget.isRefreshing) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return _buildIndicator(effectiveColor, _controller.value);
        },
      );
    }

    return _buildIndicator(effectiveColor, null);
  }

  Widget _buildIndicator(Color color, double? rotationProgress) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Transform.rotate(
        angle: rotationProgress != null
            ? rotationProgress * 2 * math.pi
            : 0,
        child: CustomPaint(
          painter: _ArcPainter(
            progress: widget.isRefreshing ? 0.75 : widget.pullProgress,
            strokeWidth: widget.strokeWidth,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  final double progress;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
