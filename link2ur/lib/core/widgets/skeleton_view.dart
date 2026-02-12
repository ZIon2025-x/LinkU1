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
        shrinkWrap: true,
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
/// 每个格子模拟「顶部图片 + 底部文字」的卡片结构
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 6,
    this.aspectRatio = 1.0,
    this.spacing = 12,
    this.imageFlex = 5,
    this.contentFlex = 3,
  });

  final int crossAxisCount;
  final int itemCount;
  final double aspectRatio;
  final double spacing;

  /// 图片区域与内容区域的 flex 比例（默认 5:3，匹配任务卡片）
  final int imageFlex;
  final int contentFlex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        itemBuilder: (context, index) => Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片区域
              Expanded(
                flex: imageFlex,
                child: const _Block(borderRadius: BorderRadius.zero),
              ),
              // 内容区域
              Expanded(
                flex: contentFlex,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Line(width: double.infinity, height: 14),
                      AppSpacing.vXs,
                      _Line(width: 80, height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部图片卡片列表骨架屏 — 匹配「图片在上 + 内容在下」的卡片布局
/// 适用于活动列表、附近任务等
class SkeletonTopImageCardList extends StatelessWidget {
  const SkeletonTopImageCardList({
    super.key,
    this.itemCount = 3,
    this.imageHeight = 140,
  });

  final int itemCount;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _ShimmerWrap(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.allMd,
        itemCount: itemCount,
        separatorBuilder: (_, __) => AppSpacing.vMd,
        itemBuilder: (_, __) => Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部图片区域
              _Block(
                width: double.infinity,
                height: imageHeight,
                borderRadius: BorderRadius.zero,
              ),
              // 底部内容区域
              const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Line(width: double.infinity, height: 18),
                    AppSpacing.vSm,
                    _Line(width: 200, height: 14),
                    AppSpacing.vSm,
                    _Line(width: 120, height: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 通用详情页骨架屏 — 所有元素共享同一道流光
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ShimmerWrap(
      child: SingleChildScrollView(
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

/// 帖子详情骨架屏 — 匹配 ForumPostDetailView 布局
/// 头部(头像+昵称+时间) → 标题 → 正文 → 图片 → 互动栏 → 评论列表
class SkeletonPostDetail extends StatelessWidget {
  const SkeletonPostDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ShimmerWrap(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 帖子头部：头像 + 昵称 + 时间 =====
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  _Circle(size: 44),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Line(width: 100, height: 16),
                        SizedBox(height: 6),
                        _Line(width: 70, height: 12),
                      ],
                    ),
                  ),
                  // 分类标签
                  _Block(width: 60, height: 24),
                ],
              ),
            ),

            // ===== 分隔线 =====
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _Line(width: double.infinity, height: 0.5),
            ),

            // ===== 帖子内容：标题 + 正文 =====
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  _Line(width: double.infinity, height: 22),
                  SizedBox(height: 6),
                  _Line(width: 200, height: 22),
                  SizedBox(height: 16),
                  // 正文段落
                  _Line(width: double.infinity, height: 15),
                  SizedBox(height: 8),
                  _Line(width: double.infinity, height: 15),
                  SizedBox(height: 8),
                  _Line(width: double.infinity, height: 15),
                  SizedBox(height: 8),
                  _Line(width: 240, height: 15),
                ],
              ),
            ),

            // ===== 图片区域：2 张图占位 =====
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _Block(height: 160),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _Block(height: 160),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // ===== 互动栏：点赞 / 评论 / 浏览 =====
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Block(width: 48, height: 28),
                  SizedBox(width: 16),
                  _Block(width: 48, height: 28),
                  SizedBox(width: 16),
                  _Block(width: 48, height: 28),
                  Spacer(),
                  _Block(width: 28, height: 28),
                ],
              ),
            ),

            SizedBox(height: 16),

            // ===== 分隔线 =====
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _Line(width: double.infinity, height: 0.5),
            ),

            SizedBox(height: 16),

            // ===== 评论区占位：3 条评论 =====
            _SkeletonReplyItem(),
            SizedBox(height: 12),
            _SkeletonReplyItem(),
            SizedBox(height: 12),
            _SkeletonReplyItem(),
          ],
        ),
      ),
    );
  }
}

/// 评论项骨架（内部使用）
class _SkeletonReplyItem extends StatelessWidget {
  const _SkeletonReplyItem();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Circle(size: 36),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Line(width: 80, height: 14),
                SizedBox(height: 6),
                _Line(width: double.infinity, height: 14),
                SizedBox(height: 4),
                _Line(width: 180, height: 14),
                SizedBox(height: 6),
                _Line(width: 50, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 闲置详情骨架屏 — 匹配 FleaMarketDetailView 布局
/// 大图轮播 → 圆角重叠层（价格 + 标题 + 描述 + 卖家信息）
class SkeletonFleaMarketDetail extends StatelessWidget {
  const SkeletonFleaMarketDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 图片轮播区域 (10:9 ratio) =====
            AspectRatio(
              aspectRatio: 10 / 9,
              child: Container(
                color: Colors.white,
              ),
            ),

            // ===== 圆角重叠区域 (模拟 -20pt 偏移) =====
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),

                    // ===== 价格 + 标题卡片 =====
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 价格
                          _Line(width: 120, height: 32),
                          SizedBox(height: 4),
                          // 原价
                          _Line(width: 80, height: 14),
                          SizedBox(height: 12),
                          // 标题
                          _Line(width: double.infinity, height: 20),
                          SizedBox(height: 6),
                          _Line(width: 200, height: 20),
                          SizedBox(height: 12),
                          // 标签行
                          Row(
                            children: [
                              _Block(width: 60, height: 24),
                              SizedBox(width: 8),
                              _Block(width: 50, height: 24),
                              SizedBox(width: 8),
                              _Block(width: 70, height: 24),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // ===== 详情描述卡片 =====
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 区标题
                          _Line(width: 80, height: 18),
                          SizedBox(height: 12),
                          // 描述文本
                          _Line(width: double.infinity, height: 14),
                          SizedBox(height: 6),
                          _Line(width: double.infinity, height: 14),
                          SizedBox(height: 6),
                          _Line(width: 260, height: 14),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // ===== 卖家信息卡片 =====
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _Circle(size: 48),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Line(width: 100, height: 16),
                                SizedBox(height: 6),
                                _Line(width: 140, height: 12),
                              ],
                            ),
                          ),
                          // 聊天按钮占位
                          _Block(width: 80, height: 36),
                        ],
                      ),
                    ),

                    SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 排行榜详情骨架屏 — 匹配 LeaderboardDetailView 布局
/// Hero 封面 → 描述 → 统计栏 → 排序筛选 → 列表条目
class SkeletonLeaderboardDetail extends StatelessWidget {
  const SkeletonLeaderboardDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Hero 封面区域 (240pt) =====
            Container(
              height: 240,
              width: double.infinity,
              color: Colors.white,
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Line(width: 200, height: 28),
                      SizedBox(height: 8),
                      _Line(width: 140, height: 16),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ===== 描述文本 =====
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Line(width: double.infinity, height: 14),
                  SizedBox(height: 6),
                  _Line(width: 280, height: 14),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ===== 统计栏卡片 =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 条目数
                    Column(
                      children: [
                        _Line(width: 40, height: 20),
                        SizedBox(height: 4),
                        _Line(width: 50, height: 12),
                      ],
                    ),
                    SizedBox(width: 1, height: 30),
                    // 投票数
                    Column(
                      children: [
                        _Line(width: 40, height: 20),
                        SizedBox(height: 4),
                        _Line(width: 50, height: 12),
                      ],
                    ),
                    SizedBox(width: 1, height: 30),
                    // 浏览数
                    Column(
                      children: [
                        _Line(width: 40, height: 20),
                        SizedBox(height: 4),
                        _Line(width: 50, height: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ===== 排序筛选行 =====
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Block(width: 70, height: 34),
                  SizedBox(width: 8),
                  _Block(width: 60, height: 34),
                  SizedBox(width: 8),
                  _Block(width: 60, height: 34),
                  SizedBox(width: 8),
                  _Block(width: 55, height: 34),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ===== 列表条目 x 5 =====
            for (int i = 0; i < 5; i++) ...[
              const _SkeletonRankItem(),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// 排名条目骨架（内部使用）
class _SkeletonRankItem extends StatelessWidget {
  const _SkeletonRankItem();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 排名圆圈
          _Circle(size: 32),
          SizedBox(width: 12),
          // 图片缩略图
          _Block(width: 64, height: 64),
          SizedBox(width: 12),
          // 名称 + 票数信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Line(width: 140, height: 16),
                SizedBox(height: 6),
                _Line(width: 100, height: 12),
              ],
            ),
          ),
          // 分数
          _Block(width: 44, height: 28),
        ],
      ),
    );
  }
}

/// 竞品详情骨架屏 — 匹配 LeaderboardItemDetailView 布局
/// 大图 → 名称卡片(-40pt重叠) → 统计行 → 描述 → 评论
class SkeletonLeaderboardItemDetail extends StatelessWidget {
  const SkeletonLeaderboardItemDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final imageHeight =
        (MediaQuery.sizeOf(context).width * 17 / 20).clamp(200, 400).toDouble();

    return _ShimmerWrap(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // ===== 图片区域 (17:20 ratio, clamp 200~400) =====
            Container(
              height: imageHeight,
              width: double.infinity,
              color: Colors.white,
            ),

            // ===== 名称卡片 (-40pt 偏移) =====
            Transform.translate(
              offset: const Offset(0, -40),
              child: Column(
                children: [
                  // 名称卡片
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Column(
                        children: [
                          // 名称
                          _Line(width: 180, height: 26),
                          SizedBox(height: 12),
                          // 提交者信息标签
                          _Block(width: 150, height: 36),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===== 统计行 =====
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 净得分
                      Column(
                        children: [
                          _Line(width: 50, height: 24),
                          SizedBox(height: 4),
                          _Line(width: 40, height: 12),
                        ],
                      ),
                      SizedBox(width: 24),
                      // 总票数
                      Column(
                        children: [
                          _Line(width: 40, height: 24),
                          SizedBox(height: 4),
                          _Line(width: 40, height: 12),
                        ],
                      ),
                      SizedBox(width: 24),
                      // 排名
                      Column(
                        children: [
                          _Line(width: 40, height: 24),
                          SizedBox(height: 4),
                          _Line(width: 40, height: 12),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ===== 描述卡片 =====
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Line(width: 60, height: 18),
                        SizedBox(height: 12),
                        _Line(width: double.infinity, height: 14),
                        SizedBox(height: 6),
                        _Line(width: double.infinity, height: 14),
                        SizedBox(height: 6),
                        _Line(width: 220, height: 14),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== 联系方式卡片 =====
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Line(width: 80, height: 18),
                        SizedBox(height: 12),
                        _SkeletonContactRow(),
                        SizedBox(height: 10),
                        _SkeletonContactRow(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== 评论区占位 =====
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Line(width: 80, height: 18),
                        SizedBox(height: 12),
                        _SkeletonVoteComment(),
                        SizedBox(height: 12),
                        _SkeletonVoteComment(),
                        SizedBox(height: 12),
                        _SkeletonVoteComment(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 140),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 联系方式行骨架（内部使用）
class _SkeletonContactRow extends StatelessWidget {
  const _SkeletonContactRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _Circle(size: 24),
        SizedBox(width: 10),
        _Line(width: 180, height: 14),
      ],
    );
  }
}

/// 投票评论骨架（内部使用）
class _SkeletonVoteComment extends StatelessWidget {
  const _SkeletonVoteComment();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Circle(size: 36),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Line(width: 70, height: 14),
                  SizedBox(width: 8),
                  _Block(width: 36, height: 20),
                ],
              ),
              SizedBox(height: 6),
              _Line(width: double.infinity, height: 14),
              SizedBox(height: 4),
              _Line(width: 160, height: 14),
            ],
          ),
        ),
      ],
    );
  }
}
