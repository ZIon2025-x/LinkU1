import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// 投票对比条 — CustomPainter 实现
///
/// 左右对比条（赞成绿色←→反对红色），
/// 按比例分配宽度，中间显示净票数，
/// 投票时条形动画过渡。
class VoteComparisonBar extends StatefulWidget {
  const VoteComparisonBar({
    super.key,
    required this.upvotes,
    required this.downvotes,
    this.height = 6,
    this.showLabels = true,
    this.showNetVotes = true,
    this.animationDuration = const Duration(milliseconds: 600),
    this.upColor,
    this.downColor,
  });

  /// 赞成票数
  final int upvotes;

  /// 反对票数
  final int downvotes;

  /// 条形高度
  final double height;

  /// 是否显示标签（赞/踩数）
  final bool showLabels;

  /// 是否显示中间净票数（如 +5 / -2）
  final bool showNetVotes;

  /// 动画时长
  final Duration animationDuration;

  /// 赞成颜色（默认绿色）
  final Color? upColor;

  /// 反对颜色（默认红色）
  final Color? downColor;

  @override
  State<VoteComparisonBar> createState() => _VoteComparisonBarState();
}

class _VoteComparisonBarState extends State<VoteComparisonBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _ratioAnimation;

  double get _targetRatio {
    final total = widget.upvotes + widget.downvotes;
    if (total == 0) return 0.5;
    return widget.upvotes / total;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _ratioAnimation = Tween<double>(
      begin: 0.5,
      end: _targetRatio,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(VoteComparisonBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.upvotes != widget.upvotes ||
        oldWidget.downvotes != widget.downvotes) {
      _ratioAnimation = Tween<double>(
        begin: _ratioAnimation.value,
        end: _targetRatio,
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
    final upColor = widget.upColor ?? AppColors.success;
    final downColor = widget.downColor ?? AppColors.error;
    final netVotes = widget.upvotes - widget.downvotes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabels) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_up_rounded, size: 12, color: upColor),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.upvotes}',
                    style: AppTypography.caption.copyWith(
                      color: upColor,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              if (widget.showNetVotes)
                Text(
                  netVotes >= 0 ? '+$netVotes' : '$netVotes',
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.downvotes}',
                    style: AppTypography.caption.copyWith(
                      color: downColor,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.thumb_down_rounded, size: 12, color: downColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ComparisonBarPainter(
                ratio: _ratioAnimation.value,
                height: widget.height,
                upColor: upColor,
                downColor: downColor,
                isDark: isDark,
              ),
              size: Size(double.infinity, widget.height),
            );
          },
        ),
      ],
    );
  }
}

class _ComparisonBarPainter extends CustomPainter {
  _ComparisonBarPainter({
    required this.ratio,
    required this.height,
    required this.upColor,
    required this.downColor,
    required this.isDark,
  });

  final double ratio;
  final double height;
  final Color upColor;
  final Color downColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final barRadius = height / 2;
    const gapWidth = 3.0;

    // 左侧（赞成）
    final leftWidth = (size.width - gapWidth) * ratio;
    if (leftWidth > 0) {
      final leftRect = RRect.fromLTRBR(
        0,
        0,
        leftWidth,
        height,
        Radius.circular(barRadius),
      );
      final leftPaint = Paint()
        ..shader = LinearGradient(
          colors: [upColor.withValues(alpha: 0.7), upColor],
        ).createShader(Rect.fromLTWH(0, 0, leftWidth, height));
      canvas.drawRRect(leftRect, leftPaint);
    }

    // 右侧（反对）
    final rightStart = leftWidth + gapWidth;
    final rightWidth = size.width - rightStart;
    if (rightWidth > 0) {
      final rightRect = RRect.fromLTRBR(
        rightStart,
        0,
        size.width,
        height,
        Radius.circular(barRadius),
      );
      final rightPaint = Paint()
        ..shader = LinearGradient(
          colors: [downColor, downColor.withValues(alpha: 0.7)],
        ).createShader(
            Rect.fromLTWH(rightStart, 0, rightWidth, height));
      canvas.drawRRect(rightRect, rightPaint);
    }
  }

  @override
  bool shouldRepaint(_ComparisonBarPainter oldDelegate) {
    return oldDelegate.ratio != ratio || oldDelegate.isDark != isDark;
  }
}
