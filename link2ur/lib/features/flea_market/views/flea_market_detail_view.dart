import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/custom_share_panel.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/models/flea_market.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/flea_market_bloc.dart';

/// 跳蚤市场商品详情页 - 对标iOS FleaMarketDetailView.swift
class FleaMarketDetailView extends StatelessWidget {
  const FleaMarketDetailView({
    super.key,
    required this.itemId,
  });

  final String itemId;

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

  final String itemId;

  @override
  Widget build(BuildContext context) {
    // 获取当前用户 ID (响应式) - 对标iOS appState.currentUser?.id
    final currentUserId = context.select<AuthBloc, String?>(
      (bloc) => bloc.state.user?.id,
    );

    return BlocConsumer<FleaMarketBloc, FleaMarketState>(
      listenWhen: (prev, curr) =>
          // 详情加载完成时自动加载购买申请（卖家）
          (prev.detailStatus != FleaMarketStatus.loaded &&
              curr.detailStatus == FleaMarketStatus.loaded) ||
          // 操作消息提示
          (curr.actionMessage != null &&
              prev.actionMessage != curr.actionMessage),
      listener: (context, state) {
        // 操作提示
        if (state.actionMessage != null) {
          final l10n = context.l10n;
          final message = switch (state.actionMessage) {
            'item_published' => l10n.actionItemPublished,
            'publish_failed' => l10n.actionPublishFailed,
            'purchase_success' => l10n.actionPurchaseSuccess,
            'purchase_failed' => l10n.actionPurchaseFailed,
            'item_updated' => l10n.actionItemUpdated,
            'update_failed' => l10n.actionUpdateFailed,
            'refresh_success' => l10n.actionRefreshSuccess,
            'refresh_failed' => l10n.actionRefreshFailed,
            _ => state.actionMessage ?? '',
          };
          final displayMessage = state.errorMessage != null
              ? '$message: ${state.errorMessage}'
              : message;
          final isSuccess = state.actionMessage == 'item_published' ||
              state.actionMessage == 'purchase_success' ||
              state.actionMessage == 'item_updated' ||
              state.actionMessage == 'refresh_success';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(displayMessage),
              backgroundColor: isSuccess ? AppColors.success : AppColors.error,
            ),
          );
        }

        // 卖家自动加载购买申请列表 - 对标iOS onAppear loadPurchaseRequests
        if (state.isDetailLoaded && state.selectedItem != null) {
          final isSeller = currentUserId != null &&
              state.selectedItem!.sellerId == currentUserId;
          if (isSeller &&
              state.selectedItem!.isActive &&
              state.purchaseRequests.isEmpty &&
              !state.isLoadingPurchaseRequests) {
            context
                .read<FleaMarketBloc>()
                .add(FleaMarketLoadPurchaseRequests(itemId));
          }
        }
      },
      builder: (context, state) {
        final hasImages =
            state.selectedItem != null && state.selectedItem!.images.isNotEmpty;
        final isSeller = state.selectedItem != null &&
            currentUserId != null &&
            state.selectedItem!.sellerId == currentUserId;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(context, state, hasImages),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveUtils.detailMaxWidth(context)),
              child: _buildBody(context, state, isSeller),
            ),
          ),
          bottomNavigationBar:
              state.isDetailLoaded && state.selectedItem != null
                  ? _buildBottomBar(context, state, isSeller)
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
        onTap: () {
          AppHaptics.selection();
          Navigator.of(context).pop();
        },
      ),
      actions: [
        if (state.selectedItem != null)
          _buildCircleButton(
            context,
            icon: Icons.share_outlined,
            onTap: () {
              AppHaptics.selection();
              final item = state.selectedItem!;
              CustomSharePanel.show(
                context,
                title: item.title,
                description: item.description ?? '',
                url: 'https://link2ur.com/flea-market/${item.id}',
              );
            },
          ),
        // 收藏按钮 - 对标iOS heart button
        _buildCircleButton(
          context,
          icon: state.isFavorited
              ? Icons.favorite
              : Icons.favorite_border,
          color: state.isFavorited ? AppColors.error : Colors.white,
          onTap: () {
            AppHaptics.selection();
            if (state.selectedItem != null) {
              context.read<FleaMarketBloc>().add(
                    FleaMarketToggleFavorite(state.selectedItem!.id),
                  );
            }
          },
        ),
      ],
    );
  }

  Widget _buildCircleButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
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
          child: Icon(icon, size: 14, color: color ?? Colors.white),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FleaMarketState state, bool isSeller) {
    if (state.isDetailLoading) return const SkeletonFleaMarketDetail();

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

    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<FleaMarketBloc>();
        bloc.add(FleaMarketLoadDetailRequested(item.id));
        await bloc.stream.firstWhere((s) =>
            s.isDetailLoaded || s.detailStatus == FleaMarketStatus.error);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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

                      // 卖家视角：自动下架倒计时警告 - 对标iOS daysUntilExpiryView
                      if (isSeller && item.isActive)
                        _AutoDelistWarning(item: item, isDark: isDark),
                      if (isSeller && item.isActive)
                        const SizedBox(height: AppSpacing.md),

                      // 详情卡片
                      if (item.description != null &&
                          item.description!.isNotEmpty)
                        _DetailsCard(item: item, isDark: isDark),
                      if (item.description != null &&
                          item.description!.isNotEmpty)
                        const SizedBox(height: AppSpacing.md),

                      // 卖家卡片（买家视角显示卖家信息）
                      if (!isSeller)
                        _SellerCard(item: item, isDark: isDark),
                      if (!isSeller)
                        const SizedBox(height: AppSpacing.md),

                      // 卖家视角：购买申请列表 - 对标iOS purchaseRequestsCard
                      if (isSeller && item.isActive)
                        _PurchaseRequestsCard(
                          state: state,
                          isDark: isDark,
                        ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, FleaMarketState state, bool isSeller) {
    final item = state.selectedItem!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 只有 active 状态才显示底部栏 - 对标iOS
    if (!item.isActive) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: (isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight)
            .withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          child: isSeller
              ? _buildSellerBottomBar(context, state, item)
              : _buildBuyerBottomBar(context, state, item),
        ),
      ),
    );
  }

  /// 卖家底部栏 - 对标iOS: 刷新按钮 + 编辑按钮
  Widget _buildSellerBottomBar(
      BuildContext context, FleaMarketState state, FleaMarketItem item) {
    return Row(
      children: [
        // 刷新按钮 - 对标iOS orange gradient
        GestureDetector(
          onTap: state.isSubmitting
              ? null
              : () {
                  AppHaptics.selection();
                  context
                      .read<FleaMarketBloc>()
                      .add(FleaMarketRefreshItem(itemId));
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
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.isSubmitting)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                else
                  const Icon(Icons.refresh, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  state.isSubmitting
                      ? context.l10n.fleaMarketRefreshing
                      : context.l10n.fleaMarketRefresh,
                  style: AppTypography.bodyBold.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 编辑按钮 - 对标iOS primary gradient（路径须为 /flea-market/:id/edit，传 extra 供编辑页使用）
        Expanded(
          child: GestureDetector(
            onTap: () {
              AppHaptics.selection();
              final item = state.selectedItem;
              if (item != null) {
                context.push('/flea-market/${item.id}/edit', extra: item);
              }
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.fleaMarketEditItemTitle,
                    style:
                        AppTypography.bodyBold.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 买家底部栏 - 对标iOS: 聊天 + 继续支付/立即购买
  Widget _buildBuyerBottomBar(
      BuildContext context, FleaMarketState state, FleaMarketItem item) {
    return Row(
      children: [
        // 聊天按钮 - 对标iOS 小按钮
        GestureDetector(
          onTap: () {
            AppHaptics.selection();
            context.push('/chat/${item.sellerId}');
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
                    style:
                        AppTypography.bodyBold.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 主操作按钮：继续支付 或 立即购买 - 对标iOS
        Expanded(
          child: _buildBuyerCTAButton(context, state, item),
        ),
      ],
    );
  }

  /// 买家CTA按钮 - 对标iOS: pendingPayment → 继续支付, 否则 → 立即购买
  Widget _buildBuyerCTAButton(
      BuildContext context, FleaMarketState state, FleaMarketItem item) {
    final hasPendingPayment = item.hasPendingPayment;
    final buttonText = hasPendingPayment
        ? context.l10n.fleaMarketContinuePayment
        : context.l10n.fleaMarketBuyNow;
    final buttonIcon =
        hasPendingPayment ? Icons.credit_card : Icons.shopping_cart;

    return GestureDetector(
      onTap: state.isSubmitting
          ? null
          : () {
              AppHaptics.selection();
              if (hasPendingPayment) {
                // TODO: 跳转支付页面 (Stripe)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(context.l10n.fleaMarketProcessingPurchase)),
                );
              } else {
                // 购买流程
                context
                    .read<FleaMarketBloc>()
                    .add(FleaMarketPurchaseItem(itemId));
              }
            },
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.gradientRed,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: AppColors.priceRed.withValues(alpha: 0.4),
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
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(buttonIcon, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      buttonText,
                      style: AppTypography.bodyBold
                          .copyWith(color: Colors.white),
                    ),
                  ],
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
                    color: AppColors.priceRed,
                    height: 1.5,
                  ),
                ),
                Text(
                  _priceNumber,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.priceRed,
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
            // 联系按钮已移至 bottomNavigationBar，避免重复
          ],
        ),
      ),
    );
  }
}

// ==================== 自动下架倒计时警告 ====================

class _AutoDelistWarning extends StatelessWidget {
  const _AutoDelistWarning({required this.item, required this.isDark});
  final FleaMarketItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilAutoDelist;
    if (days == null) return const SizedBox.shrink();

    final isUrgent = days <= 3;
    final color = isUrgent ? AppColors.error : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              isUrgent ? Icons.warning_amber_rounded : Icons.schedule,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isUrgent
                    ? context.l10n.fleaMarketAutoRemovalSoon
                    : context.l10n.fleaMarketAutoRemovalDays(days),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 购买申请列表卡片（卖家可见） ====================

class _PurchaseRequestsCard extends StatelessWidget {
  const _PurchaseRequestsCard({
    required this.state,
    required this.isDark,
  });
  final FleaMarketState state;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final requestCount = state.purchaseRequests.length;

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
            // 标题行
            Row(
              children: [
                const Icon(Icons.people, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.fleaMarketPurchaseRequestsCount(requestCount),
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

            if (state.isLoadingPurchaseRequests)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: LoadingView(),
                ),
              )
            else if (state.purchaseRequests.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.backgroundDark
                          : AppColors.backgroundLight)
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox,
                        size: 40,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.l10n.fleaMarketNoPurchaseRequests,
                      style: AppTypography.body.copyWith(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...state.purchaseRequests.map((request) =>
                  _PurchaseRequestItem(
                    request: request,
                    isDark: isDark,
                  )),
          ],
        ),
      ),
    );
  }
}

// ==================== 单个购买申请项 ====================

class _PurchaseRequestItem extends StatelessWidget {
  const _PurchaseRequestItem({
    required this.request,
    required this.isDark,
  });
  final PurchaseRequest request;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 买家信息行
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(Icons.person, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.buyerName ?? 'Buyer',
                      style: AppTypography.bodyBold.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (request.proposedPrice != null)
                      Text(
                        '£${request.proposedPrice!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.priceRed,
                        ),
                      ),
                  ],
                ),
              ),
              // 状态标签
              _buildStatusLabel(context, request.status),
            ],
          ),
          // 卖家议价显示
          if (request.status == 'seller_negotiating' &&
              request.sellerCounterPrice != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_offer,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '${context.l10n.fleaMarketSellerNegotiateLabel} £${request.sellerCounterPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusLabel(BuildContext context, String status) {
    Color color;
    String text;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = context.l10n.fleaMarketWaitingSellerConfirm;
        break;
      case 'seller_negotiating':
        color = AppColors.primary;
        text = context.l10n.fleaMarketRequestStatusSellerNegotiating;
        break;
      case 'accepted':
        color = AppColors.success;
        text = context.l10n.actionsConfirmComplete;
        break;
      case 'rejected':
        color = AppColors.error;
        text = context.l10n.actionsReject;
        break;
      default:
        color = AppColors.textTertiaryLight;
        text = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
