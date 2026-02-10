import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// 技能雷达图 — CustomPainter 实现
///
/// 多边形雷达图，数据点从中心向外展开动画，
/// 半透明填充 + 外框线 + 顶点小圆点。
class SkillRadarChart extends StatefulWidget {
  const SkillRadarChart({
    super.key,
    required this.data,
    this.size = 200,
    this.maxValue = 1.0,
    this.color,
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  /// 数据点：label → value（0.0 ~ maxValue）
  final Map<String, double> data;

  /// 组件尺寸
  final double size;

  /// 数据最大值（用于归一化）
  final double maxValue;

  /// 数据区域颜色（默认使用 primary）
  final Color? color;

  /// 展开动画时长
  final Duration animationDuration;

  @override
  State<SkillRadarChart> createState() => _SkillRadarChartState();
}

class _SkillRadarChartState extends State<SkillRadarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    Future.delayed(const Duration(milliseconds: 300), () {
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
    if (widget.data.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.color ?? AppColors.primary;

    return RepaintBoundary(
      child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RadarPainter(
              data: widget.data,
              maxValue: widget.maxValue,
              progress: _expandAnimation.value,
              color: color,
              isDark: isDark,
            ),
            size: Size(widget.size, widget.size),
          );
        },
      ),
    ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.data,
    required this.maxValue,
    required this.progress,
    required this.color,
    required this.isDark,
  });

  final Map<String, double> data;
  final double maxValue;
  final double progress;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 30; // 留出标签空间
    final entries = data.entries.toList();
    final sides = entries.length;
    if (sides < 3) return;

    final angleStep = 2 * math.pi / sides;
    // 从顶部开始（-π/2）
    const startAngle = -math.pi / 2;

    // 绘制网格
    _drawGrid(canvas, center, radius, sides, startAngle, angleStep);

    // 绘制轴线
    _drawAxes(canvas, center, radius, sides, startAngle, angleStep);

    // 绘制数据区域（带动画）
    _drawDataArea(
        canvas, center, radius, entries, startAngle, angleStep);

    // 绘制标签
    _drawLabels(
        canvas, center, radius, entries, startAngle, angleStep, size);
  }

  void _drawGrid(Canvas canvas, Offset center, double radius, int sides,
      double startAngle, double angleStep) {
    final gridPaint = Paint()
      ..color = isDark
          ? AppColors.textTertiaryDark.withValues(alpha: 0.15)
          : AppColors.textTertiaryLight.withValues(alpha: 0.2)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // 3 层同心多边形
    for (int ring = 1; ring <= 3; ring++) {
      final ringRadius = radius * ring / 3;
      final path = Path();
      for (int i = 0; i <= sides; i++) {
        final angle = startAngle + angleStep * (i % sides);
        final point = Offset(
          center.dx + ringRadius * math.cos(angle),
          center.dy + ringRadius * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
  }

  void _drawAxes(Canvas canvas, Offset center, double radius, int sides,
      double startAngle, double angleStep) {
    final axisPaint = Paint()
      ..color = isDark
          ? AppColors.textTertiaryDark.withValues(alpha: 0.1)
          : AppColors.textTertiaryLight.withValues(alpha: 0.15)
      ..strokeWidth = 0.8;

    for (int i = 0; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, point, axisPaint);
    }
  }

  void _drawDataArea(
      Canvas canvas,
      Offset center,
      double radius,
      List<MapEntry<String, double>> entries,
      double startAngle,
      double angleStep) {
    if (progress <= 0) return;

    final dataPath = Path();
    final points = <Offset>[];

    for (int i = 0; i <= entries.length; i++) {
      final entry = entries[i % entries.length];
      final normalizedValue =
          (entry.value / maxValue).clamp(0.0, 1.0) * progress;
      final angle = startAngle + angleStep * (i % entries.length);
      final point = Offset(
        center.dx + radius * normalizedValue * math.cos(angle),
        center.dy + radius * normalizedValue * math.sin(angle),
      );

      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }

      if (i < entries.length) points.add(point);
    }
    dataPath.close();

    // 填充区域（半透明）
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    // 边框线
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dataPath, strokePaint);

    // 顶点小圆点
    for (final point in points) {
      // 外圈光晕
      canvas.drawCircle(
        point,
        5,
        Paint()..color = color.withValues(alpha: 0.2),
      );
      // 白底
      canvas.drawCircle(
        point,
        3.5,
        Paint()..color = isDark ? AppColors.cardBackgroundDark : Colors.white,
      );
      // 彩色圆点
      canvas.drawCircle(
        point,
        2.5,
        Paint()..color = color,
      );
    }
  }

  void _drawLabels(
      Canvas canvas,
      Offset center,
      double radius,
      List<MapEntry<String, double>> entries,
      double startAngle,
      double angleStep,
      Size size) {
    for (int i = 0; i < entries.length; i++) {
      final angle = startAngle + angleStep * i;
      final labelRadius = radius + 18;
      final labelPoint = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: entries[i].key,
          style: AppTypography.caption2.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // 根据角度调整对齐方式
      double dx = labelPoint.dx - textPainter.width / 2;
      double dy = labelPoint.dy - textPainter.height / 2;

      // 左右边缘偏移
      if (math.cos(angle) > 0.3) {
        dx = labelPoint.dx - 2;
      } else if (math.cos(angle) < -0.3) {
        dx = labelPoint.dx - textPainter.width + 2;
      }

      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.data != data;
  }
}
