import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/haptic_feedback.dart';
import '../design/app_colors.dart';

/// 点赞/收藏粒子爆炸动画按钮
///
/// 点击时：图标弹簧缩放 + 周围散射粒子 + 粒子沿随机角度抛出并淡出。
/// 使用 CustomPainter + 物理动画实现，
/// 这是原生开发实现起来非常复杂的效果。
class AnimatedLikeButton extends StatefulWidget {
  const AnimatedLikeButton({
    super.key,
    required this.isLiked,
    required this.onTap,
    this.likedIcon = Icons.favorite,
    this.unlikedIcon = Icons.favorite_border,
    this.likedColor,
    this.unlikedColor,
    this.size = 24,
    this.count,
    this.showCount = false,
    this.particleCount = 7,
  });

  /// 是否已点赞
  final bool isLiked;

  /// 点击回调
  final VoidCallback onTap;

  /// 已点赞图标
  final IconData likedIcon;

  /// 未点赞图标
  final IconData unlikedIcon;

  /// 已点赞颜色
  final Color? likedColor;

  /// 未点赞颜色
  final Color? unlikedColor;

  /// 图标尺寸
  final double size;

  /// 计数（可选）
  final int? count;

  /// 是否显示计数
  final bool showCount;

  /// 粒子数量
  final int particleCount;

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _particleAnimation;

  bool _wasLiked = false;

  @override
  void initState() {
    super.initState();
    _wasLiked = widget.isLiked;

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.7)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_scaleController);

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _particleAnimation = CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked && !_wasLiked) {
      // 从未点赞变为已点赞：播放动画
      _scaleController.forward(from: 0);
      _particleController.forward(from: 0);
    }
    _wasLiked = widget.isLiked;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    AppHaptics.like();
    if (!widget.isLiked) {
      _scaleController.forward(from: 0);
      _particleController.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final likedColor = widget.likedColor ?? AppColors.accentPink;
    final unlikedColor = widget.unlikedColor ??
        (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight);

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size + 16,
              height: widget.size + 16,
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    [_scaleController, _particleController]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ParticlePainter(
                      progress: _particleAnimation.value,
                      color: likedColor,
                      particleCount: widget.particleCount,
                      centerSize: widget.size,
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Icon(
                          widget.isLiked
                              ? widget.likedIcon
                              : widget.unlikedIcon,
                          size: widget.size,
                          color: widget.isLiked ? likedColor : unlikedColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.showCount && widget.count != null) ...[
              const SizedBox(width: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text(
                  '${widget.count}',
                  key: ValueKey<int>(widget.count!),
                  style: TextStyle(
                    fontSize: widget.size * 0.5,
                    fontWeight: FontWeight.w600,
                    color: widget.isLiked ? likedColor : unlikedColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.progress,
    required this.color,
    required this.particleCount,
    required this.centerSize,
  });

  final double progress;
  final Color color;
  final int particleCount;
  final double centerSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42); // 固定种子保证稳定

    for (int i = 0; i < particleCount; i++) {
      final angle = (2 * math.pi * i / particleCount) +
          random.nextDouble() * 0.5 - 0.25;
      final maxDistance = centerSize * 1.2 + random.nextDouble() * 8;
      final distance = maxDistance * progress;

      final particleX = center.dx + distance * math.cos(angle);
      final particleY = center.dy + distance * math.sin(angle);

      // 粒子大小：先变大再变小
      final sizeProgress = progress < 0.3
          ? progress / 0.3
          : 1.0 - (progress - 0.3) / 0.7;
      final particleSize =
          (2 + random.nextDouble() * 2) * sizeProgress;

      // 粒子颜色渐变
      final colors = [
        color,
        AppColors.gold,
        AppColors.accent,
        color.withValues(alpha: 0.8),
      ];
      final particleColor =
          colors[i % colors.length].withValues(alpha: 1.0 - progress);

      // 绘制粒子
      if (particleSize > 0) {
        // 圆形粒子
        canvas.drawCircle(
          Offset(particleX, particleY),
          particleSize,
          Paint()..color = particleColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
