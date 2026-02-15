import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/haptic_feedback.dart';
import '../design/app_colors.dart';

/// 评分星星动画组件 — CustomPainter 实现
///
/// - 5 颗星从左到右依次亮起（交错 100ms）
/// - 半星支持（CustomPainter 裁剪）
/// - 用户评分时星星弹簧缩放
class AnimatedStarRating extends StatefulWidget {
  const AnimatedStarRating({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 24,
    this.spacing = 4,
    this.activeColor,
    this.inactiveColor,
    this.onRatingChanged,
    this.animationDuration = const Duration(milliseconds: 600),
    this.allowHalfRating = true,
  });

  /// 当前评分（0.0 ~ maxRating）
  final double rating;

  /// 最大评分
  final int maxRating;

  /// 星星尺寸
  final double size;

  /// 星星间距
  final double spacing;

  /// 激活颜色
  final Color? activeColor;

  /// 未激活颜色
  final Color? inactiveColor;

  /// 评分变化回调（可选，为 null 时为只读）
  final ValueChanged<double>? onRatingChanged;

  /// 动画时长
  final Duration animationDuration;

  /// 是否允许半星
  final bool allowHalfRating;

  @override
  State<AnimatedStarRating> createState() => _AnimatedStarRatingState();
}

class _AnimatedStarRatingState extends State<AnimatedStarRating>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _playEntryAnimation();
  }

  void _initAnimations() {
    _controllers = List.generate(
      widget.maxRating,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    _scaleAnimations = _controllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 1.3)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.3, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 50,
        ),
      ]).animate(controller);
    }).toList();
  }

  void _playEntryAnimation() {
    for (int i = 0; i < widget.maxRating; i++) {
      if (i < widget.rating.ceil()) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          if (mounted) _controllers[i].forward();
        });
      }
    }
  }

  @override
  void didUpdateWidget(AnimatedStarRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rating != widget.rating) {
      // 重新播放动画
      for (final controller in _controllers) {
        controller.reset();
      }
      _playEntryAnimation();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleTap(int index, double localX) {
    if (widget.onRatingChanged == null) return;

    AppHaptics.selection();

    // 弹簧缩放反馈
    _controllers[index].forward(from: 0);

    final double newRating;
    if (widget.allowHalfRating) {
      final isLeftHalf = localX < widget.size / 2;
      newRating = isLeftHalf ? index + 0.5 : (index + 1).toDouble();
    } else {
      newRating = (index + 1).toDouble();
    }
    widget.onRatingChanged!(newRating);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = widget.activeColor ?? AppColors.gold;
    final inactiveColor = widget.inactiveColor ??
        (isDark
            ? AppColors.textTertiaryDark.withValues(alpha: 0.3)
            : AppColors.skeletonBase);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.maxRating, (index) {
        // 计算这颗星的填充比例
        final starFill = (widget.rating - index).clamp(0.0, 1.0);

        return Padding(
          padding: EdgeInsets.only(
            right: index < widget.maxRating - 1 ? widget.spacing : 0,
          ),
          child: GestureDetector(
            onTapUp: widget.onRatingChanged != null
                ? (TapUpDetails d) => _handleTap(index, d.localPosition.dx)
                : null,
            child: AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, _) {
                final scale = index < widget.rating.ceil()
                    ? _scaleAnimations[index].value
                    : 1.0;
                return Transform.scale(
                  scale: scale.clamp(0.0, 2.0),
                  child: SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: CustomPaint(
                      painter: _StarPainter(
                        fillRatio: starFill,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.fillRatio,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double fillRatio;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final path = _createStarPath(center, radius, radius * 0.4, 5);

    // 绘制底层（未激活）
    canvas.drawPath(
      path,
      Paint()
        ..color = inactiveColor
        ..style = PaintingStyle.fill,
    );

    if (fillRatio <= 0) return;

    if (fillRatio >= 1.0) {
      // 完整填充
      canvas.drawPath(
        path,
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill,
      );
    } else {
      // 半星裁剪
      canvas.save();
      canvas.clipRect(
          Rect.fromLTWH(0, 0, size.width * fillRatio, size.height));
      canvas.drawPath(
        path,
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }
  }

  Path _createStarPath(
      Offset center, double outerRadius, double innerRadius, int points) {
    final path = Path();
    final angle = math.pi / points;

    for (int i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? outerRadius : innerRadius;
      final currentAngle = i * angle - math.pi / 2;
      final x = center.dx + r * math.cos(currentAngle);
      final y = center.dy + r * math.sin(currentAngle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) {
    return oldDelegate.fillRatio != fillRatio ||
        oldDelegate.activeColor != activeColor;
  }
}
