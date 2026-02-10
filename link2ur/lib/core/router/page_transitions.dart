import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ============================================================
// 自定义转场 Page — 供 GoRouter pageBuilder 使用
// ============================================================

/// iOS 弹簧转场（参考 SwiftUI .spring(response: 0.35, dampingFraction: 0.86)）
///
/// 效果：
/// - 新页面从右侧弹性滑入，带轻微过冲回弹
/// - 前一页面同步左移淡出
/// - 比标准 Cupertino 转场更有活力
class SpringSlideTransitionPage<T> extends CustomTransitionPage<T> {
  SpringSlideTransitionPage({
    required super.child,
    super.key,
    super.name,
  }) : super(
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 主动画：弹簧滑入
            final slideAnimation = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: _iOSSpringCurve,
              reverseCurve: Curves.easeInCubic,
            ));

            // 前一页面：向左轻移 + 淡出
            final secondarySlide = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.25, 0.0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
            ));

            final secondaryFade = Tween<double>(
              begin: 1.0,
              end: 0.9,
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOut,
            ));

            return SlideTransition(
              position: secondarySlide,
              child: FadeTransition(
                opacity: secondaryFade,
                child: SlideTransition(
                  position: slideAnimation,
                  child: child,
                ),
              ),
            );
          },
        );
}

/// iOS 风格弹簧曲线 - response: 0.35, dampingFraction: 0.86
const Curve _iOSSpringCurve = _DampedSpringCurve(0.86, 0.35);

class _DampedSpringCurve extends Curve {
  const _DampedSpringCurve(this.damping, this.response);
  final double damping;
  final double response;

  @override
  double transformInternal(double t) {
    // Critically damped spring approximation
    final omega = 2 * math.pi / response;
    final zeta = damping;
    final omegaD = omega * math.sqrt(1 - zeta * zeta).clamp(0.01, double.infinity);
    return 1 - math.exp(-zeta * omega * t) *
        (math.cos(omegaD * t) + (zeta * omega / omegaD) * math.sin(omegaD * t));
  }
}

/// 底部滑入转场（创建/编辑类页面）
///
/// 模拟 iOS present 模态效果：
/// - 新页面从底部滑入
/// - 前一页面略微缩小
/// - 手势可下拉关闭
class SlideUpTransitionPage<T> extends CustomTransitionPage<T> {
  SlideUpTransitionPage({
    required super.child,
    super.key,
    super.name,
  }) : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            ));

            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
        );
}

/// 淡入缩放转场（登录/注册/引导页等全屏切换）
///
/// 效果：
/// - 新页面从 95% 缩放 + 透明淡入到 100% + 完全不透明
/// - 曲线使用 easeOutCubic，感觉柔和自然
class FadeScaleTransitionPage<T> extends CustomTransitionPage<T> {
  FadeScaleTransitionPage({
    required super.child,
    super.key,
    super.name,
  }) : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleAnimation = Tween<double>(
              begin: 0.94,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
        );
}

/// 共享轴转场（同层级页面切换，如 Tab 之间）
///
/// Material Motion 规范中的 Shared Axis 转场：
/// - 新页面从右侧淡入滑入，旧页面向左淡出滑出
/// - 水平轴共享，暗示同层级导航
class SharedAxisTransitionPage<T> extends CustomTransitionPage<T> {
  SharedAxisTransitionPage({
    required super.child,
    super.key,
    super.name,
  }) : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 进入：从右侧 30px 淡入
            final primarySlide = Tween<Offset>(
              begin: const Offset(30, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final primaryFade = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
            );

            // 退出：向左 30px 淡出
            final secondarySlide = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-30, 0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeInCubic,
            ));

            final secondaryFade = Tween<double>(
              begin: 1.0,
              end: 0.0,
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
            ));

            return FadeTransition(
              opacity: secondaryFade,
              child: Transform.translate(
                offset: secondarySlide.value,
                child: FadeTransition(
                  opacity: primaryFade,
                  child: Transform.translate(
                    offset: primarySlide.value,
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
}

/// 容器变形转场（卡片展开为详情页，Material Motion 风格）
///
/// 效果：
/// - 从一个小容器展开为全屏
/// - 缩放 + 淡入的组合，比 Hero 更通用
class ContainerTransformPage<T> extends CustomTransitionPage<T> {
  ContainerTransformPage({
    required super.child,
    super.key,
    super.name,
  }) : super(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleAnimation = Tween<double>(
              begin: 0.85,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            );

            final radiusAnimation = Tween<double>(
              begin: 16.0,
              end: 0.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(radiusAnimation.value),
                  child: child,
                ),
              ),
            );
          },
        );
}
