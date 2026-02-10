import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// 信用分仪表盘 — CustomPainter 实现
///
/// 环形仪表盘，弧线根据分数渐变（红→黄→绿），
/// 进入页面时弧线从 0 动画扫到目标值，
/// 中心显示分数数字滚动动画。
class CreditScoreGauge extends StatefulWidget {
  const CreditScoreGauge({
    super.key,
    required this.score,
    this.maxScore = 100,
    this.size = 120,
    this.strokeWidth = 10,
    this.animationDuration = const Duration(milliseconds: 1200),
    this.label,
  });

  /// 当前分数
  final double score;

  /// 最大分数
  final double maxScore;

  /// 组件尺寸
  final double size;

  /// 弧线宽度
  final double strokeWidth;

  /// 动画时长
  final Duration animationDuration;

  /// 底部标签
  final String? label;

  @override
  State<CreditScoreGauge> createState() => _CreditScoreGaugeState();
}

class _CreditScoreGaugeState extends State<CreditScoreGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sweepAnimation;
  late final Animation<double> _numberAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    final normalizedScore =
        (widget.score / widget.maxScore).clamp(0.0, 1.0);

    _sweepAnimation = Tween<double>(
      begin: 0.0,
      end: normalizedScore,
    ).animate(curved);

    _numberAnimation = Tween<double>(
      begin: 0.0,
      end: widget.score,
    ).animate(curved);

    // 延迟启动，让页面先渲染
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(CreditScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      final normalizedScore =
          (widget.score / widget.maxScore).clamp(0.0, 1.0);
      _sweepAnimation = Tween<double>(
        begin: _sweepAnimation.value,
        end: normalizedScore,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _numberAnimation = Tween<double>(
        begin: _numberAnimation.value,
        end: widget.score,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _GaugePainter(
                  progress: _sweepAnimation.value,
                  strokeWidth: widget.strokeWidth,
                  isDark: isDark,
                ),
                child: Center(
                  child: Text(
                    '${_numberAnimation.value.round()}',
                    style: AppTypography.price.copyWith(
                      color: _getScoreColor(_sweepAnimation.value),
                      fontWeight: FontWeight.w800,
                      fontSize: widget.size * 0.25,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.label!,
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ],
    );
  }

  static Color _getScoreColor(double progress) {
    if (progress < 0.3) {
      return Color.lerp(AppColors.error, AppColors.warning, progress / 0.3)!;
    } else if (progress < 0.7) {
      return Color.lerp(
          AppColors.warning, AppColors.success, (progress - 0.3) / 0.4)!;
    } else {
      return AppColors.success;
    }
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.strokeWidth,
    required this.isDark,
  });

  final double progress;
  final double strokeWidth;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 弧线范围：从 135° 到 405°（共 270°）
    const startAngle = 135 * math.pi / 180;
    const totalSweep = 270 * math.pi / 180;

    // 绘制灰色底环
    final bgPaint = Paint()
      ..color = isDark
          ? AppColors.textTertiaryDark.withValues(alpha: 0.3)
          : AppColors.skeletonBase.withValues(alpha: 0.6)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      bgPaint,
    );

    if (progress <= 0) return;

    // 绘制刻度线
    _drawTickMarks(canvas, center, radius, size);

    // 绘制彩色弧线（渐变）
    final sweepAngle = totalSweep * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradientPaint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: _getGradientColors(progress),
        transform: const GradientRotation(0),
      ).createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, false, gradientPaint);

    // 绘制弧线末端光晕
    final endAngle = startAngle + sweepAngle;
    final endPoint = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );

    final glowPaint = Paint()
      ..color = _getEndColor(progress).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(endPoint, strokeWidth * 0.6, glowPaint);
  }

  void _drawTickMarks(
      Canvas canvas, Offset center, double radius, Size size) {
    const startAngle = 135 * math.pi / 180;
    const totalSweep = 270 * math.pi / 180;
    const tickCount = 27; // 每 10 度一个刻度

    final tickPaint = Paint()
      ..color = isDark
          ? AppColors.textTertiaryDark.withValues(alpha: 0.15)
          : AppColors.textTertiaryLight.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    for (int i = 0; i <= tickCount; i++) {
      final angle = startAngle + (totalSweep * i / tickCount);
      final isLong = i % 9 == 0; // 每 90° 一个长刻度（0%, ~33%, ~66%, 100%）
      final outerRadius = radius + strokeWidth / 2 + 3;
      final innerRadius = outerRadius - (isLong ? 8 : 5);

      final outer = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      final inner = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );

      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  List<Color> _getGradientColors(double progress) {
    if (progress < 0.3) {
      return [AppColors.error, AppColors.warning];
    } else if (progress < 0.7) {
      return [AppColors.warning, AppColors.success];
    } else {
      return [AppColors.success, const Color(0xFF00C853)];
    }
  }

  Color _getEndColor(double progress) {
    if (progress < 0.3) return AppColors.error;
    if (progress < 0.7) return AppColors.warning;
    return AppColors.success;
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
