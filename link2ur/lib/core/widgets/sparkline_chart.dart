import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// 迷你折线图 — CustomPainter 实现
///
/// 纯折线迷你图（无坐标轴），
/// 渐变填充区域 + 平滑曲线，
/// 触摸时显示具体数值。
class SparklineChart extends StatefulWidget {
  const SparklineChart({
    super.key,
    required this.data,
    this.height = 60,
    this.color,
    this.lineWidth = 2.0,
    this.showDots = false,
    this.fillGradient = true,
    this.animationDuration = const Duration(milliseconds: 800),
    this.interactive = false,
  });

  /// 数据点列表
  final List<double> data;

  /// 图表高度
  final double height;

  /// 线条颜色
  final Color? color;

  /// 线条宽度
  final double lineWidth;

  /// 是否显示数据点圆点
  final bool showDots;

  /// 是否显示渐变填充
  final bool fillGradient;

  /// 绘制动画时长
  final Duration animationDuration;

  /// 是否支持触摸交互
  final bool interactive;

  @override
  State<SparklineChart> createState() => _SparklineChartState();
}

class _SparklineChartState extends State<SparklineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _drawAnimation;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _drawAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details, double width) {
    if (!widget.interactive || widget.data.length < 2) return;
    final dx = details.localPosition.dx;
    final step = width / (widget.data.length - 1);
    final index = (dx / step).round().clamp(0, widget.data.length - 1);
    setState(() {
      _touchedIndex = index;
    });
  }

  void _onPanEnd() {
    setState(() {
      _touchedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.length < 2) return SizedBox(height: widget.height);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.color ?? AppColors.primary;
    // 预计算 min/max，避免 paint 每帧 O(n) 遍历
    final minVal = widget.data.reduce(math.min);
    final maxVal = widget.data.reduce(math.max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          onPanUpdate: widget.interactive
              ? (details) => _onPanUpdate(details, width)
              : null,
          onPanEnd: widget.interactive ? (_) => _onPanEnd() : null,
          onPanCancel: widget.interactive ? _onPanEnd : null,
            child: RepaintBoundary(
            child: SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SparklinePainter(
                    data: widget.data,
                    progress: _drawAnimation.value,
                    color: color,
                    lineWidth: widget.lineWidth,
                    showDots: widget.showDots,
                    fillGradient: widget.fillGradient,
                    isDark: isDark,
                    minVal: minVal,
                    maxVal: maxVal,
                    touchedIndex: _touchedIndex,
                  ),
                  size: Size(width, widget.height),
                );
              },
            ),
          ),
          ),
        );
      },
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.data,
    required this.progress,
    required this.color,
    required this.lineWidth,
    required this.showDots,
    required this.fillGradient,
    required this.isDark,
    required this.minVal,
    required this.maxVal,
    this.touchedIndex,
  });

  final List<double> data;
  final double progress;
  final Color color;
  final double lineWidth;
  final bool showDots;
  final bool fillGradient;
  final bool isDark;
  /// 预计算的最小值和最大值，避免在 paint 中每帧重复 O(n) 遍历
  final double minVal;
  final double maxVal;
  final int? touchedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2 || progress <= 0) return;

    final padding = lineWidth + 2;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    final range = maxVal - minVal;
    final effectiveRange = range == 0 ? 1.0 : range;

    // 计算数据点位置
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = padding + (chartWidth * i / (data.length - 1));
      final normalizedY = (data[i] - minVal) / effectiveRange;
      final y = padding + chartHeight * (1 - normalizedY);
      points.add(Offset(x, y));
    }

    // 截取动画进度对应的可见点
    final visibleCount =
        (points.length * progress).ceil().clamp(2, points.length);
    final visiblePoints = points.sublist(0, visibleCount);

    // 构建平滑路径
    final linePath = _createSmoothPath(visiblePoints);

    // 绘制渐变填充
    if (fillGradient) {
      final fillPath = Path.from(linePath)
        ..lineTo(visiblePoints.last.dx, size.height)
        ..lineTo(visiblePoints.first.dx, size.height)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.2 * progress),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(fillPath, fillPaint);
    }

    // 绘制线条
    final linePaint = Paint()
      ..color = color.withValues(alpha: progress)
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // 绘制数据点
    if (showDots && progress >= 0.8) {
      final dotOpacity = ((progress - 0.8) / 0.2).clamp(0.0, 1.0);
      for (final point in visiblePoints) {
        canvas.drawCircle(
          point,
          3,
          Paint()
            ..color = (isDark ? AppColors.cardBackgroundDark : Colors.white)
                .withValues(alpha: dotOpacity),
        );
        canvas.drawCircle(
          point,
          2,
          Paint()..color = color.withValues(alpha: dotOpacity),
        );
      }
    }

    // 绘制触摸指示器
    if (touchedIndex != null && touchedIndex! < visiblePoints.length) {
      final touchPoint = visiblePoints[touchedIndex!];

      // 垂直虚线
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(touchPoint.dx, 0),
        Offset(touchPoint.dx, size.height),
        dashPaint,
      );

      // 高亮圆点
      canvas.drawCircle(
        touchPoint,
        6,
        Paint()..color = color.withValues(alpha: 0.2),
      );
      canvas.drawCircle(
        touchPoint,
        4,
        Paint()..color = isDark ? AppColors.cardBackgroundDark : Colors.white,
      );
      canvas.drawCircle(
        touchPoint,
        3,
        Paint()..color = color,
      );

      // 数值标签
      final value = data[touchedIndex!];
      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(1),
          style: AppTypography.caption2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final tooltipWidth = textPainter.width + 12;
      final tooltipHeight = textPainter.height + 8;
      var tooltipX = touchPoint.dx - tooltipWidth / 2;
      tooltipX = tooltipX.clamp(0.0, size.width - tooltipWidth);
      final tooltipY = touchPoint.dy - tooltipHeight - 8;

      final tooltipRect = RRect.fromLTRBR(
        tooltipX,
        tooltipY,
        tooltipX + tooltipWidth,
        tooltipY + tooltipHeight,
        const Radius.circular(4),
      );

      canvas.drawRRect(
        tooltipRect,
        Paint()..color = color,
      );

      textPainter.paint(
        canvas,
        Offset(tooltipX + 6, tooltipY + 4),
      );
    }
  }

  Path _createSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlX = (current.dx + next.dx) / 2;

      path.cubicTo(
        controlX,
        current.dy,
        controlX,
        next.dy,
        next.dx,
        next.dy,
      );
    }

    return path;
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.touchedIndex != touchedIndex ||
        oldDelegate.isDark != isDark;
  }
}
