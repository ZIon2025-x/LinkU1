import 'package:flutter/material.dart';
import '../design/app_colors.dart';

/// 与 iOS AppColors.background (systemGroupedBackground) 对齐的页面背景组件
///
/// 基础背景色使用 [AppColors.backgroundFor]（浅色 #F2F2F7，深色 #000000），
/// 个人中心页可开启 [hasTopGradient] 叠加顶部 primary 渐变。
///
/// 用法示例：
/// ```dart
/// Scaffold(
///   backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
///   body: PageBackground(
///     child: yourContent,
///   ),
/// )
/// ```
class PageBackground extends StatelessWidget {
  const PageBackground({
    super.key,
    required this.child,
    this.hasTopGradient = false,
  });

  /// 子组件
  final Widget child;

  /// 是否叠加顶部渐变（个人中心页使用）
  /// 对齐 iOS ProfileView：primary.opacity(0.15) → transparent，高度 300
  final bool hasTopGradient;

  @override
  Widget build(BuildContext context) {
    if (!hasTopGradient) return child;

    return Stack(
      children: [
        // 顶部渐变 —— 对齐 iOS ProfileView.backgroundView
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 内容
        child,
      ],
    );
  }
}
