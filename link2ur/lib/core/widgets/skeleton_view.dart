import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_radius.dart';

// ============================================================
// 私有色块组件 — 无动画，用于组合到统一 Shimmer 流光中
// ============================================================

/// 基础色块（无流光）
class _Block extends StatelessWidget {
  const _Block({
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
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isCircle ? null : (borderRadius ?? AppRadius.allSmall),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

/// 行色块（无流光）
class _Line extends StatelessWidget {
  const _Line({this.width, this.height = 16});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _Block(width: width, height: height, borderRadius: AppRadius.allTiny);
  }
}

/// 圆形色块（无流光）
class _Circle extends StatelessWidget {
  const _Circle({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _Block(width: size, height: size, isCircle: true);
  }
}

/// 卡片色块内容（无流光，供列表统一包裹）
class _CardContent extends StatelessWidget {
  const _CardContent({
    this.hasImage = true,
    this.imageSize = 80,
  });

  final bool hasImage;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage) ...[
          _Block(
            width: imageSize,
            height: imageSize,
            borderRadius: AppRadius.allMedium,
          ),
          AppSpacing.hMd,
        ],
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Line(width: double.infinity, height: 18),
              AppSpacing.vSm,
              _Line(width: 200, height: 14),
              AppSpacing.vSm,
              _Line(width: 100, height: 14),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 统一 Shimmer 流光包装器
// ============================================================

/// 统一流光包装器 — 整个子树共享同一道光带扫过
class _ShimmerWrap extends StatelessWidget {
  const _ShimmerWrap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : AppColors.skeletonBase,
      highlightColor: isDark ? Colors.grey[700]! : AppColors.skeletonHighlight,
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }
}

// ============================================================
// 公开 API — 独立使用时自带流光
// ============================================================

/// 骨架屏视图（单个元素，独立使用时自带流光）
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
    return _ShimmerWrap(
      child: _Block(
        width: width,
        height: height,
        borderRadius: borderRadius,
        isCircle: isCircle,
      ),
    );
  }
}

/// 骨架屏行（独立使用时自带流光）
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
    return _ShimmerWrap(
      child: _Line(width: width, height: height),
    );
  }
}

/// 骨架屏圆形（独立使用时自带流光）
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({
    super.key,
    this.size = 40,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: _Circle(size: size),
    );
  }
}

// ============================================================
// 组合骨架屏 — 统一流光，整体扫过
// ============================================================

/// 卡片骨架屏（独立使用时自带统一流光）
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

    return _ShimmerWrap(
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.card,
        ),
        child: _CardContent(hasImage: hasImage, imageSize: imageSize),
      ),
    );
  }
}

/// 列表骨架屏 — 所有卡片共享同一道流光
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.hasImage = true,
    this.imageSize = 80,
  });

  final int itemCount;
  final bool hasImage;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _ShimmerWrap(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.allMd,
        itemCount: itemCount,
        separatorBuilder: (context, index) => AppSpacing.vMd,
        itemBuilder: (context, index) => Container(
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.card,
          ),
          child: _CardContent(hasImage: hasImage, imageSize: imageSize),
        ),
      ),
    );
  }
}

/// 网格骨架屏 — 所有格子共享同一道流光
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
    return _ShimmerWrap(
      child: GridView.builder(
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
        itemBuilder: (context, index) => const _Block(),
      ),
    );
  }
}

/// 详情页骨架屏 — 所有元素共享同一道流光
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: const SingleChildScrollView(
        padding: AppSpacing.allMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域
            _Block(
              width: double.infinity,
              height: 200,
              borderRadius: BorderRadius.zero,
            ),
            AppSpacing.vMd,
            // 标题
            _Line(width: double.infinity, height: 24),
            AppSpacing.vSm,
            _Line(width: 200, height: 16),
            AppSpacing.vLg,
            // 内容段落
            _Line(width: double.infinity),
            AppSpacing.vSm,
            _Line(width: double.infinity),
            AppSpacing.vSm,
            _Line(width: double.infinity),
            AppSpacing.vSm,
            _Line(width: 150),
            AppSpacing.vLg,
            // 用户信息
            Row(
              children: [
                _Circle(size: 48),
                AppSpacing.hMd,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Line(width: 100, height: 16),
                    SizedBox(height: 4),
                    _Line(width: 60, height: 12),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
