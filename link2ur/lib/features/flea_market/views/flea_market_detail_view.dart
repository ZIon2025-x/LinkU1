import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/models/flea_market.dart';
import '../bloc/flea_market_bloc.dart';

/// 跳蚤市场商品详情页 - 对标iOS FleaMarketDetailView.swift
class FleaMarketDetailView extends StatelessWidget {
  const FleaMarketDetailView({
    super.key,
    required this.itemId,
  });

  final int itemId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FleaMarketBloc(
        fleaMarketRepository: context.read<FleaMarketRepository>(),
      )..add(FleaMarketLoadDetailRequested(itemId)),
      child: _FleaMarketDetailContent(itemId: itemId),
    );
  }
}

class _FleaMarketDetailContent extends StatelessWidget {
  const _FleaMarketDetailContent({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FleaMarketBloc, FleaMarketState>(
      builder: (context, state) {
        final hasImages =
            state.selectedItem != null && state.selectedItem!.images.isNotEmpty;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(context, state, hasImages),
          body: _buildBody(context, state),
          bottomNavigationBar:
              state.isDetailLoaded && state.selectedItem != null
                  ? _buildBottomBar(context, state)
                  : null,
        );
      },
    );
  }

  /// 透明AppBar - 始终透明
  PreferredSizeWidget _buildAppBar(
      BuildContext context, FleaMarketState state, bool hasImages) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: true,
      leading: _buildCircleButton(
        context,
        icon: Icons.arrow_back_ios_new,
        onTap: () => Navigator.of(context).pop(),
      ),
      actions: [
        if (state.selectedItem != null)
          _buildCircleButton(
            context,
            icon: Icons.share_outlined,
            onTap: () {
              HapticFeedback.selectionClick();
            },
          ),
        _buildCircleButton(
          context,
          icon: Icons.favorite_border,
          onTap: () {
            HapticFeedback.selectionClick();
          },
        ),
      ],
    );
  }

  Widget _buildCircleButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FleaMarketState state) {
    if (state.isDetailLoading) return const LoadingView();

    if (state.detailStatus == FleaMarketStatus.error) {
      return ErrorStateView.loadFailed(
        message: state.errorMessage ?? context.l10n.fleaMarketLoadFailed,
        onRetry: () {
          context
              .read<FleaMarketBloc>()
              .add(FleaMarketLoadDetailRequested(itemId));
        },
      );
    }

    final item = state.selectedItem;
    if (item == null) return ErrorStateView.notFound();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片轮播 - 对标iOS image gallery (10:9 ratio)
          _ImageGallery(item: item),

          // 内容区域 - 上移重叠图片 - 对标iOS padding(.top, -20)
          Transform.translate(
            offset: const Offset(0, -20),
            child: Column(
              children: [
                // 圆角重叠层 - 对标iOS 24pt rounded overlay
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.backgroundDark
                        : AppColors.backgroundLight,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 价格和标题卡片
                      _PriceTitleCard(item: item, isDark: isDark),
                      const SizedBox(height: AppSpacing.md),

                      // 详情卡片
                      if (item.description != null &&
                          item.description!.isNotEmpty)
                        _DetailsCard(item: item, isDark: isDark),
                      if (item.description != null &&
                          item.description!.isNotEmpty)
                        const SizedBox(height: AppSpacing.md),

                      // 卖家卡片
                      _SellerCard(item: item, isDark: isDark),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, FleaMarketState state) {
    final item = state.selectedItem!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (item.status != AppConstants.fleaMarketStatusActive) return const SizedBox.shrink();

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark
                    ? AppColors.cardBackgroundDark
                    : AppColors.cardBackgroundLight)
                .withValues(alpha: 0.85),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 12),
              child: Row(
                children: [
                  // 聊天按钮 - 对标iOS 小按钮
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange,
                            Colors.orange.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble, size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(context.l10n.fleaMarketChat,
                              style: AppTypography.bodyBold
                                  .copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 购买按钮 - 对标iOS red gradient CTA
                  Expanded(
                    child: GestureDetector(
                      onTap: state.isSubmitting
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(context.l10n.fleaMarketPurchaseInDev)),
                              );
                            },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFE64D4D),
                              Color(0xFFFF6B6B),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE64D4D)
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: state.isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  item.isSold ? context.l10n.fleaMarketSold : context.l10n.fleaMarketBuyNow,
                                  style: AppTypography.bodyBold
                                      .copyWith(color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 图片画廊 ====================

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.item});
  final FleaMarketItem item;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.item.images;

    if (images.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.skeletonBase,
              AppColors.skeletonBase.withValues(alpha: 0.5),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library,
                size: 48, color: AppColors.textTertiaryLight),
            const SizedBox(height: AppSpacing.md),
            Text(context.l10n.fleaMarketNoImage,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiaryLight)),
          ],
        ),
      );
    }

    return SizedBox(
      height: 340,
      child: Stack(
        children: [
          // 图片
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) =>
                setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FullScreenImageView(
                      images: images,
                      initialIndex: index,
                    ),
                  ));
                },
                child: index == 0
                    ? Hero(
                        tag: 'flea_market_image_${widget.item.id}',
                        child: AsyncImageView(
                          imageUrl: images[index],
                          width: double.infinity,
                          height: 340,
                          fit: BoxFit.cover,
                        ),
                      )
                    : AsyncImageView(
                        imageUrl: images[index],
                        width: double.infinity,
                        height: 340,
                        fit: BoxFit.cover,
                      ),
              );
            },
          ),

          // 图片计数器 - 对标iOS counter badge (top-right)
          if (images.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 50,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_currentPage + 1}/${images.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // 页面指示器 - 对标iOS custom dots in capsule
          if (images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(images.length, (index) {
                      final isSelected = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: isSelected ? 8 : 6,
                        height: isSelected ? 8 : 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== 价格和标题卡片 ====================

class _PriceTitleCard extends StatelessWidget {
  const _PriceTitleCard({required this.item, required this.isDark});
  final FleaMarketItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 价格 - 对标iOS rounded 32pt bold red
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '£',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE64D4D),
                    height: 1.5,
                  ),
                ),
                Text(
                  _priceNumber,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE64D4D),
                    height: 1.1,
                  ),
                ),
                const Spacer(),
                // 状态
                if (!item.isActive)
                  _StatusBadge(item: item),
              ],
            ),
            const SizedBox(height: 12),

            // 标题
            Text(
              item.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // 标签和统计
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (item.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.category!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                _InfoChip(
                    icon: Icons.favorite_border,
                    text: '${item.favoriteCount}'),
                _InfoChip(
                    icon: Icons.visibility_outlined,
                    text: '${item.viewCount}'),
                if (item.createdAt != null)
                  _InfoChip(
                    icon: Icons.access_time,
                    text: _formatDate(context, item.createdAt!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _priceNumber {
    return item.price.toStringAsFixed(2);
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 7) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } else if (difference.inDays > 0) {
      return context.l10n.timeDaysAgo(difference.inDays);
    } else if (difference.inHours > 0) {
      return context.l10n.timeHoursAgo(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return context.l10n.timeMinutesAgo(difference.inMinutes);
    }
    return context.l10n.timeJustNow;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.item});
  final FleaMarketItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.isSold ? AppColors.textSecondaryLight : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            item.isSold ? context.l10n.fleaMarketSold : context.l10n.fleaMarketDelisted,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiaryLight),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }
}

// ==================== 详情卡片 ====================

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.item, required this.isDark});
  final FleaMarketItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左竖条 + 标题 - 对标iOS 4x18 accent bar
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.fleaMarketDescription,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.description!,
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.6,
              ),
            ),
            // 位置
            if (item.location != null && item.location!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.location!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== 卖家卡片 ====================

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.item, required this.isDark});
  final FleaMarketItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 头像 - 对标iOS 56pt with white stroke and shadow
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        context.l10n.fleaMarketSeller,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        context.l10n.fleaMarketActiveSeller,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 联系按钮 - 对标iOS gradient capsule
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.l10n.fleaMarketContactSeller,
                  style: AppTypography.caption
                      .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
