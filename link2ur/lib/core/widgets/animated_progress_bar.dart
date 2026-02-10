import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// 动画进度条 — CustomPainter 实现
///
/// 圆头进度条 + 人数文字标注 + 满员脉冲动画。
/// 替代系统 LinearProgressIndicator。
class AnimatedProgressBar extends StatefulWidget {
  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.height = 8,
    this.color,
    this.backgroundColor,
    this.showLabel = false,
    this.label,
    this.animationDuration = const Duration(milliseconds: 800),
    this.warningThreshold = 0.8,
    this.enablePulse = true,
  });

  /// 进度值（0.0 ~ 1.0）
  final double progress;

  /// 条形高度
  final double height;

  /// 进度颜色
  final Color? color;

  /// 背景颜色
  final Color? backgroundColor;

  /// 是否显示标签
  final bool showLabel;

  /// 自定义标签（如 "8/20"）
  final String? label;

  /// 动画时长
  final Duration animationDuration;

  /// 警告阈值（超过此值变红）
  final double warningThreshold;

  /// 是否启用满员脉冲
  final bool enablePulse;

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _progressController.forward();
    });

    _setupPulse();
  }

  void _setupPulse() {
    if (widget.enablePulse && widget.progress >= widget.warningThreshold) {
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat(reverse: true);

      _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.progress.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ));
      _progressController
        ..reset()
        ..forward();

      // 更新脉冲动画
      if (widget.progress >= widget.warningThreshold &&
          _pulseController == null) {
        _setupPulse();
      } else if (widget.progress < widget.warningThreshold) {
        _pulseController?.dispose();
        _pulseController = null;
        _pulseAnimation = null;
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  Color _getProgressColor(double progress) {
    if (progress >= widget.warningThreshold) {
      return widget.color ?? AppColors.error;
    }
    return widget.color ?? AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel && widget.label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label!,
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(widget.progress * 100).round()}%',
                style: AppTypography.caption.copyWith(
                  color: _getProgressColor(widget.progress),
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        AnimatedBuilder(
          animation: Listenable.merge([
            _progressController,
            if (_pulseController != null) _pulseController!,
          ]),
          builder: (context, _) {
            return CustomPaint(
              painter: _ProgressBarPainter(
                progress: _progressAnimation.value,
                height: widget.height,
                color: _getProgressColor(_progressAnimation.value),
                backgroundColor: widget.backgroundColor ??
                    (isDark
                        ? AppColors.textTertiaryDark.withValues(alpha: 0.2)
                        : AppColors.skeletonBase.withValues(alpha: 0.5)),
                isDark: isDark,
                pulseProgress: _pulseAnimation?.value,
              ),
              size: Size(double.infinity, widget.height),
            );
          },
        ),
      ],
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter({
    required this.progress,
    required this.height,
    required this.color,
    required this.backgroundColor,
    required this.isDark,
    this.pulseProgress,
  });

  final double progress;
  final double height;
  final Color color;
  final Color backgroundColor;
  final bool isDark;
  final double? pulseProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final barRadius = height / 2;

    // 背景条
    final bgRect = RRect.fromLTRBR(
      0,
      0,
      size.width,
      height,
      Radius.circular(barRadius),
    );
    canvas.drawRRect(bgRect, Paint()..color = backgroundColor);

    if (progress <= 0) return;

    // 进度条
    final progressWidth = size.width * progress;
    final progressRect = RRect.fromLTRBR(
      0,
      0,
      progressWidth,
      height,
      Radius.circular(barRadius),
    );

    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.8), color],
      ).createShader(Rect.fromLTWH(0, 0, progressWidth, height));

    canvas.drawRRect(progressRect, progressPaint);

    // 满员脉冲光晕
    if (pulseProgress != null && pulseProgress! > 0) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.15 * pulseProgress!)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, 4 + pulseProgress! * 4);
      canvas.drawRRect(progressRect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_ProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.isDark != isDark;
  }
}
