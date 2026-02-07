import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/models/flea_market.dart';
import '../bloc/flea_market_bloc.dart';

/// 跳蚤市场商品详情页
/// 参考iOS FleaMarketDetailView.swift
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('商品详情'),
            actions: [
              // 编辑按钮（仅卖家可见）
              if (state.selectedItem != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '编辑',
                  onPressed: () => context.push(
                    '/flea-market/${state.selectedItem!.id}/edit',
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {},
              ),
            ],
          ),
          body: _buildBody(context, state),
          bottomNavigationBar: state.isDetailLoaded && state.selectedItem != null
              ? _buildBottomBar(context, state.selectedItem!)
              : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, FleaMarketState state) {
    // Loading state
    if (state.isDetailLoading) {
      return const LoadingView();
    }

    // Error state
    if (state.detailStatus == FleaMarketStatus.error) {
      return ErrorStateView.loadFailed(
        message: state.errorMessage ?? '加载失败',
        onRetry: () {
          context.read<FleaMarketBloc>().add(FleaMarketLoadDetailRequested(itemId));
        },
      );
    }

    final item = state.selectedItem;
    if (item == null) {
      return ErrorStateView.notFound();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image carousel
          if (item.images.isNotEmpty) _buildImageCarousel(item),
          if (item.images.isEmpty)
            Container(
              height: 300,
              color: AppColors.skeletonBase,
              child: const Center(
                child: Icon(Icons.image, size: 64, color: AppColors.textTertiaryLight),
              ),
            ),

          Padding(
            padding: AppSpacing.allMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price
                Text(
                  item.priceDisplay,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                AppSpacing.vMd,

                // Title
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.vLg,

                // Status badge
                if (!item.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.isSold
                          ? Colors.black.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: item.isSold ? Colors.black : AppColors.error,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      item.isSold ? '已售出' : '已下架',
                      style: TextStyle(
                        color: item.isSold ? Colors.black : AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (!item.isActive) AppSpacing.vMd,

                // Description
                if (item.description != null && item.description!.isNotEmpty) ...[
                  Text(
                    '商品描述',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  AppSpacing.vSm,
                  Text(
                    item.description!,
                    style: TextStyle(
                      color: AppColors.textSecondaryLight,
                      height: 1.5,
                      fontSize: 15,
                    ),
                  ),
                  AppSpacing.vLg,
                ],

                // Seller info
                Container(
                  padding: AppSpacing.allMd,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: AppRadius.allMedium,
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      AppSpacing.hMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '卖家',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Theme.of(context).textTheme.titleMedium?.color,
                                  ),
                                ),
                                if (item.sellerUserLevel != null) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    item.sellerUserLevel == 'vip' || item.sellerUserLevel == 'super'
                                        ? Icons.verified
                                        : null,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.sellerUserLevel == 'super'
                                  ? '超级用户'
                                  : item.sellerUserLevel == 'vip'
                                      ? 'VIP用户'
                                      : '普通用户',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Additional info
                AppSpacing.vLg,
                Row(
                  children: [
                    _buildInfoItem(Icons.visibility_outlined, '${item.viewCount} 次浏览'),
                    AppSpacing.hMd,
                    _buildInfoItem(Icons.favorite_outline, '${item.favoriteCount} 人收藏'),
                  ],
                ),

                if (item.location != null) ...[
                  AppSpacing.vMd,
                  _buildInfoItem(Icons.location_on_outlined, item.location!),
                ],

                if (item.createdAt != null) ...[
                  AppSpacing.vMd,
                  _buildInfoItem(
                    Icons.access_time,
                    _formatDate(item.createdAt!),
                  ),
                ],

                // Bottom spacing for bottom bar
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(FleaMarketItem item) {
    if (item.images.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 300,
      child: PageView.builder(
        itemCount: item.images.length,
        itemBuilder: (context, index) {
          return AsyncImageView(
            imageUrl: item.images[index],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiaryLight),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, FleaMarketItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconActionButton(
              icon: Icons.chat_bubble_outline,
              onPressed: () {
                // Navigate to chat with seller
                // context.push('/chat/${item.sellerId}');
              },
              backgroundColor: AppColors.skeletonBase,
            ),
            AppSpacing.hMd,
            Expanded(
              child: BlocBuilder<FleaMarketBloc, FleaMarketState>(
                builder: (context, state) {
                  final isSold = item.isSold;
                  final isSubmitting = state.isSubmitting;

                  return PrimaryButton(
                    text: isSold ? '已售出' : '联系卖家',
                    onPressed: isSold || isSubmitting
                        ? null
                        : () {
                            // Navigate to chat or contact seller
                            // For now, show a message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('联系卖家功能开发中')),
                            );
                          },
                    isLoading: isSubmitting,
                    isDisabled: isSold || isSubmitting,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}
