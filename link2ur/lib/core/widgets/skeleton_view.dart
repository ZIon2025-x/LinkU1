import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_radius.dart';

/// 骨架屏视图
/// 参考iOS SkeletonView.swift
class SkeletonView extends StatelessWidget {
  const SkeletonView({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.isCircle = false,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : AppColors.skeletonBase,
      highlightColor: isDark ? Colors.grey[700]! : AppColors.skeletonHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: isCircle ? null : (borderRadius ?? AppRadius.allSmall),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}

/// 骨架屏行
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 16,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonView(
      width: width,
      height: height,
      borderRadius: AppRadius.allTiny,
    );
  }
}

/// 骨架屏圆形
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({
    super.key,
    this.size = 40,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SkeletonView(
      width: size,
      height: size,
      isCircle: true,
    );
  }
}

/// 卡片骨架屏
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.height = 120,
    this.hasImage = true,
    this.imageSize = 80,
  });

  final double height;
  final bool hasImage;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            SkeletonView(
              width: imageSize,
              height: imageSize,
              borderRadius: AppRadius.allMedium,
            ),
            AppSpacing.hMd,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: double.infinity, height: 18),
                AppSpacing.vSm,
                const SkeletonLine(width: 200, height: 14),
                AppSpacing.vSm,
                const SkeletonLine(width: 100, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表骨架屏
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemBuilder,
  });

  final int itemCount;
  final Widget Function(BuildContext, int)? itemBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: AppSpacing.allMd,
      itemCount: itemCount,
      separatorBuilder: (context, index) => AppSpacing.vMd,
      itemBuilder: itemBuilder ?? (context, index) => const SkeletonCard(),
    );
  }
}

/// 网格骨架屏
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 6,
    this.aspectRatio = 1.0,
    this.spacing = 12,
  });

  final int crossAxisCount;
  final int itemCount;
  final double aspectRatio;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: AppSpacing.allMd,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonView(),
    );
  }
}

/// 详情页骨架屏
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片区域
          const SkeletonView(
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.zero,
          ),
          AppSpacing.vMd,
          // 标题
          const SkeletonLine(width: double.infinity, height: 24),
          AppSpacing.vSm,
          const SkeletonLine(width: 200, height: 16),
          AppSpacing.vLg,
          // 内容
          const SkeletonLine(width: double.infinity),
          AppSpacing.vSm,
          const SkeletonLine(width: double.infinity),
          AppSpacing.vSm,
          const SkeletonLine(width: double.infinity),
          AppSpacing.vSm,
          const SkeletonLine(width: 150),
          AppSpacing.vLg,
          // 用户信息
          Row(
            children: [
              const SkeletonCircle(size: 48),
              AppSpacing.hMd,
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 100, height: 16),
                  SizedBox(height: 4),
                  SkeletonLine(width: 60, height: 12),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
