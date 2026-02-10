import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// 环形进度条 — CustomPainter 实现
///
/// 双层圆弧（底层灰色、顶层渐变色），
/// 端点圆头，中心显示百分比文字，
/// 进入视口时自动播放动画。
class AnimatedCircularProgress extends StatefulWidget {
  const AnimatedCircularProgress({
    super.key,
    required this.progress,
    this.size = 80,
    this.strokeWidth = 8,
    this.color,
    this.gradientColors,
    this.showPercentage = true,
    this.centerWidget,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.label,
  });

  /// 进度值（0.0 ~ 1.0）
  final double progress;

  /// 组件尺寸
  final double size;

  /// 弧线宽度
  final double strokeWidth;

  /// 单色（与 gradientColors 互斥）
  final Color? color;

  /// 渐变色列表（与 color 互斥）
  final List<Color>? gradientColors;

  /// 是否显示中心百分比文字
  final bool showPercentage;

  /// 自定义中心组件（优先于百分比文字）
  final Widget? centerWidget;

  /// 动画时长
  final Duration animationDuration;

  /// 底部标签
  final String? label;

  @override
  State<AnimatedCircularProgress> createState() =>
      _AnimatedCircularProgressState();
}

class _AnimatedCircularProgressState extends State<AnimatedCircularProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(AnimatedCircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.progress.clamp(0.0, 1.0),
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
    final effectiveColor = widget.color ?? AppColors.primary;
    final effectiveGradient = widget.gradientColors ??
        [effectiveColor, effectiveColor.withValues(alpha: 0.7)];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _CircularProgressPainter(
                  progress: _progressAnimation.value,
                  strokeWidth: widget.strokeWidth,
                  gradientColors: effectiveGradient,
                  isDark: isDark,
                ),
                child: Center(
                  child: widget.centerWidget ??
                      (widget.showPercentage
                          ? Text(
                              '${(_progressAnimation.value * 100).round()}%',
                              style: AppTypography.subheadlineBold.copyWith(
                                color: effectiveColor,
                                fontSize: widget.size * 0.2,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            )
                          : null),
                ),
              );
            },
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 6),
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
}

class _CircularProgressPainter extends CustomPainter {
  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradientColors,
    required this.isDark,
  });

  final double progress;
  final double strokeWidth;
  final List<Color> gradientColors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 从顶部开始（-π/2）
    const startAngle = -math.pi / 2;
    const totalSweep = 2 * math.pi;

    // 灰色底环
    final bgPaint = Paint()
      ..color = isDark
          ? AppColors.textTertiaryDark.withValues(alpha: 0.2)
          : AppColors.skeletonBase.withValues(alpha: 0.5)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, totalSweep, false, bgPaint);

    if (progress <= 0) return;

    // 渐变弧线
    final sweepAngle = totalSweep * progress;

    final gradientPaint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: gradientColors,
      ).createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, false, gradientPaint);

    // 末端光晕
    final endAngle = startAngle + sweepAngle;
    final endPoint = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );

    final glowPaint = Paint()
      ..color = gradientColors.last.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(endPoint, strokeWidth * 0.5, glowPaint);
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
