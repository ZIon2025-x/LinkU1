import 'package:flutter/material.dart';
import '../design/app_typography.dart';

/// 数字滚动动画组件
///
/// 数字变化时，每一位数字独立从旧值滚动到新值，
/// 使用 TweenAnimationBuilder + ClipRect 实现滚轮效果。
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.prefix,
    this.suffix,
  });

  /// 当前数值
  final int value;

  /// 文字样式
  final TextStyle? style;

  /// 动画时长
  final Duration duration;

  /// 动画曲线
  final Curve curve;

  /// 前缀（如 "$"、"+"）
  final String? prefix;

  /// 后缀（如 "pts"、"%"）
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, _) {
        final displayValue = animatedValue.round();
        final text = '${prefix ?? ''}$displayValue${suffix ?? ''}';
        final effectiveStyle = style ?? AppTypography.title3;

        return Text(
          text,
          style: effectiveStyle.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}

/// 带滚轮效果的数字动画组件
///
/// 每一位数字独立滚动，视觉效果更丰富。
/// 适用于需要强调数字变化的场景（如余额、分数）。
class RollingCounter extends StatefulWidget {
  const RollingCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.digitHeight,
  });

  /// 当前数值
  final int value;

  /// 文字样式
  final TextStyle? style;

  /// 动画时长
  final Duration duration;

  /// 动画曲线
  final Curve curve;

  /// 数字高度（默认根据样式自动计算）
  final double? digitHeight;

  @override
  State<RollingCounter> createState() => _RollingCounterState();
}

class _RollingCounterState extends State<RollingCounter> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = widget.style ?? AppTypography.title3;
    final digits = widget.value.toString().split('');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(digits.length, (index) {
        return _RollingDigit(
          digit: int.parse(digits[index]),
          style: effectiveStyle,
          duration: widget.duration,
          curve: widget.curve,
          digitHeight: widget.digitHeight,
          delay: Duration(milliseconds: index * 50),
        );
      }),
    );
  }
}

class _RollingDigit extends StatefulWidget {
  const _RollingDigit({
    required this.digit,
    required this.style,
    required this.duration,
    required this.curve,
    this.digitHeight,
    this.delay = Duration.zero,
  });

  final int digit;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final double? digitHeight;
  final Duration delay;

  @override
  State<_RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<_RollingDigit>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _currentDigit = 0;
  int _targetDigit = 0;

  @override
  void initState() {
    super.initState();
    _targetDigit = widget.digit;
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(_RollingDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.digit != widget.digit) {
      _currentDigit = _targetDigit;
      _targetDigit = widget.digit;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 测量数字高度
    final textPainter = TextPainter(
      text: TextSpan(text: '0', style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    final digitHeight = widget.digitHeight ?? textPainter.height;

    return SizedBox(
      height: digitHeight,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final offset = _animation.value;
            return Stack(
              children: [
                // 旧数字（向上滑出）
                Transform.translate(
                  offset: Offset(0, -digitHeight * offset),
                  child: Text(
                    '$_currentDigit',
                    style: widget.style.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                // 新数字（从下方滑入）
                Transform.translate(
                  offset: Offset(0, digitHeight * (1 - offset)),
                  child: Text(
                    '$_targetDigit',
                    style: widget.style.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
