import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/models/flea_market.dart';
import '../bloc/flea_market_bloc.dart';

/// 跳蚤市场页
/// 参考iOS FleaMarketView.swift
class FleaMarketView extends StatelessWidget {
  const FleaMarketView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FleaMarketBloc(
        fleaMarketRepository: context.read<FleaMarketRepository>(),
      )..add(const FleaMarketLoadRequested()),
      child: const _FleaMarketViewContent(),
    );
  }
}

class _FleaMarketViewContent extends StatelessWidget {
  const _FleaMarketViewContent();

  static const _categories = <(String, String)>[
    ('all', '全部'),
    ('电子产品', '电子产品'),
    ('书籍教材', '书籍教材'),
    ('生活用品', '生活用品'),
    ('服饰鞋包', '服饰鞋包'),
    ('运动户外', '运动户外'),
    ('其他', '其他'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.fleaMarketFleaMarket),
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.l10n.fleaMarketSearchItems,
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.skeletonBase,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.allPill,
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (query) {
                context.read<FleaMarketBloc>().add(FleaMarketSearchChanged(query));
              },
            ),
          ),

          // 分类筛选
          BlocBuilder<FleaMarketBloc, FleaMarketState>(
            buildWhen: (prev, curr) => prev.selectedCategory != curr.selectedCategory,
            builder: (context, state) {
              return SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final (value, label) = _categories[index];
                    final isSelected = state.selectedCategory == value;
                    return FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) {
                        context.read<FleaMarketBloc>().add(
                              FleaMarketCategoryChanged(value),
                            );
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : null,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.allPill,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  },
                ),
              );
            },
          ),

          // 商品列表
          Expanded(
            child: BlocBuilder<FleaMarketBloc, FleaMarketState>(
              builder: (context, state) {
                // Loading state
                if (state.isLoading && state.items.isEmpty) {
                  return const LoadingView();
                }

                // Error state
                if (state.status == FleaMarketStatus.error && state.items.isEmpty) {
                  return ErrorStateView.loadFailed(
                    message: state.errorMessage ?? '加载失败',
                    onRetry: () {
                      context.read<FleaMarketBloc>().add(const FleaMarketLoadRequested());
                    },
                  );
                }

                // Empty state
                if (state.isEmpty) {
                  return EmptyStateView.noData(
                    title: '暂无商品',
                    description: '还没有商品，点击下方按钮发布第一个商品',
                  );
                }

                // Content with pull-to-refresh
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<FleaMarketBloc>().add(const FleaMarketRefreshRequested());
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: GridView.builder(
                    padding: AppSpacing.allMd,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: state.items.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        context.read<FleaMarketBloc>().add(const FleaMarketLoadMore());
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final item = state.items[index];
                      return _FleaMarketItemCard(item: item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/flea-market/create');
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _FleaMarketItemCard extends StatelessWidget {
  const _FleaMarketItemCard({required this.item});

  final FleaMarketItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        // Parse item.id (String) to int for navigation
        final itemId = int.tryParse(item.id);
        if (itemId != null) {
          context.push('/flea-market/$itemId');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: AsyncImageView(
                      imageUrl: item.firstImage,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Status badge
                  if (!item.isActive)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.isSold
                              ? Colors.black.withValues(alpha: 0.7)
                              : AppColors.error.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.isSold ? '已售出' : '已下架',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Price
                  Text(
                    item.priceDisplay,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  // Seller info (optional)
                  if (item.sellerUserLevel != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          item.sellerUserLevel == 'vip' || item.sellerUserLevel == 'super'
                              ? Icons.verified
                              : Icons.person,
                          size: 12,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.sellerUserLevel == 'super'
                              ? '超级用户'
                              : item.sellerUserLevel == 'vip'
                                  ? 'VIP用户'
                                  : '普通用户',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
