import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../constants/app_assets.dart';

/// 启动屏：专业简洁，Logo + Slogan + 呼吸动效，支持暗黑模式
/// 参考iOS SplashView.swift
class SplashView extends StatefulWidget {
  const SplashView({super.key, this.onComplete});

  /// 闪屏完成回调
  final VoidCallback? onComplete;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _textController;
  late Animation<double> _breathAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    // Logo 呼吸动效
    _breathController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // 文字淡入
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // 延迟启动文字动画
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _textController.forward();
    });

    // 闪屏完成后回调
    if (widget.onComplete != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) widget.onComplete!();
      });
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 背景
          _buildBackground(isDark),

          // 内容
          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                // Logo 容器
                _buildLogoContainer(isDark),

                const SizedBox(height: 20),

                // Slogan
                FadeTransition(
                  opacity: _textAnimation,
                  child: _buildSlogan(isDark),
                ),

                const Spacer(),

                // 底部品牌签名
                Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Text(
                    'POWERED BY Link²Ur',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFFA6A6A6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 背景（微渐变 + 弥散光）
  Widget _buildBackground(bool isDark) {
    if (isDark) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1E2338),
              Color(0xFF12121A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // 弥散光
            Positioned(
              top: -80,
              left: -60,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3366AA).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -40,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF338088).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF8F9FF),
              Color(0xFFFDFDFF),
              Color(0xFFF9FDFB),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // 弥散光
            Positioned(
              top: -80,
              left: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.10),
                      AppColors.primary.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -40,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF66BFD9).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -40,
              right: -20,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF73B3E6).withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Logo 容器
  Widget _buildLogoContainer(bool isDark) {
    return AnimatedBuilder(
      animation: _breathAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _breathAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.primary
                  .withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            AppAssets.logo,
            width: 108,
            height: 108,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  /// Slogan
  Widget _buildSlogan(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Link to your ',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.9,
            color: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : const Color(0xFF595959),
          ),
        ),
        Text(
          'World',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.7,
            color: isDark
                ? const Color(0xFF73A6FF)
                : AppColors.primary,
          ),
        ),
      ],
    );
  }
}
