import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/skeleton_view.dart';
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

class _FleaMarketViewContent extends StatefulWidget {
  const _FleaMarketViewContent();

  @override
  State<_FleaMarketViewContent> createState() =>
      _FleaMarketViewContentState();
}

class _FleaMarketViewContentState extends State<_FleaMarketViewContent> {
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 400);

  List<(String, String)> _getCategories(BuildContext context) => [
    ('all', context.l10n.fleaMarketCategoryAll),
    (context.l10n.fleaMarketCategoryKeyElectronics, context.l10n.fleaMarketCategoryElectronics),
    (context.l10n.fleaMarketCategoryKeyBooks, context.l10n.fleaMarketCategoryBooks),
    (context.l10n.fleaMarketCategoryKeyDaily, context.l10n.fleaMarketCategoryDailyUse),
    (context.l10n.fleaMarketCategoryKeyClothing, context.l10n.fleaMarketCategoryClothing),
    (context.l10n.fleaMarketCategoryKeySports, context.l10n.fleaMarketCategorySports),
    (context.l10n.fleaMarketCategoryKeyOther, context.l10n.fleaMarketCategoryOther),
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

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
                _debounceTimer?.cancel();
                _debounceTimer = Timer(_debounceDuration, () {
                  if (!mounted) return;
                  context.read<FleaMarketBloc>().add(FleaMarketSearchChanged(query));
                });
              },
            ),
          ),

          // 分类筛选
          BlocBuilder<FleaMarketBloc, FleaMarketState>(
            buildWhen: (prev, curr) => prev.selectedCategory != curr.selectedCategory,
            builder: (context, state) {
              final categories = _getCategories(context);
              return SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final (value, label) = categories[index];
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
                  return const SkeletonList();
                }

                // Error state
                if (state.status == FleaMarketStatus.error && state.items.isEmpty) {
                  return ErrorStateView.loadFailed(
                    message: state.errorMessage ?? context.l10n.fleaMarketLoadFailed,
                    onRetry: () {
                      context.read<FleaMarketBloc>().add(const FleaMarketLoadRequested());
                    },
                  );
                }

                // Empty state
                if (state.isEmpty) {
                  return EmptyStateView.noData(
                    title: context.l10n.fleaMarketNoItems,
                    description: context.l10n.fleaMarketNoItemsHint,
                  );
                }

                // Content with pull-to-refresh
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<FleaMarketBloc>().add(const FleaMarketRefreshRequested());
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: GridView.builder(
                    clipBehavior: Clip.none,
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
                      return AnimatedListItem(
                        index: index,
                        child: _FleaMarketItemCard(item: item),
                      );
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

/// 商品卡片 - 对齐iOS FleaMarketView.ItemCard
/// (渐变遮罩 + 分类胶囊 + 会员标签 + 统计)
class _FleaMarketItemCard extends StatelessWidget {
  const _FleaMarketItemCard({required this.item});

  final FleaMarketItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        final itemId = int.tryParse(item.id);
        if (itemId != null) {
          context.push('/flea-market/$itemId');
        }
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域 - 对齐iOS: 渐变遮罩 + 分类标签 + 状态标签
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 商品图片
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: item.firstImage != null
                        ? Hero(
                            tag: 'flea_market_image_${item.id}',
                            child: AsyncImageView(
                              imageUrl: item.firstImage!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            child: Icon(
                              Icons.image_outlined,
                              color: AppColors.primary.withValues(alpha: 0.3),
                              size: 40,
                            ),
                          ),
                  ),
                  // 底部渐变遮罩 (iOS style)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 左上: 分类标签 (对齐iOS: Capsule + black 40%)
                  if (item.category != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: AppRadius.allPill,
                        ),
                        child: Text(
                          item.category!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // 右上: 状态标签 (已售出/已下架)
                  if (!item.isActive)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.isSold
                              ? Colors.black.withValues(alpha: 0.7)
                              : AppColors.error.withValues(alpha: 0.9),
                          borderRadius: AppRadius.allPill,
                        ),
                        child: Text(
                          item.isSold ? context.l10n.fleaMarketSold : context.l10n.fleaMarketDelisted,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // 左下: VIP/Super卖家标签 (对齐iOS: orange gradient badge)
                  if (item.sellerUserLevel == 'vip' ||
                      item.sellerUserLevel == 'super')
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF9500), Color(0xFFFF6B00)],
                          ),
                          borderRadius: AppRadius.allPill,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 2),
                            Text(
                              item.sellerUserLevel == 'super'
                                  ? 'Super'
                                  : 'VIP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 内容区域 - 对齐iOS: title + price (red) + stats
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  SizedBox(
                    height: 38,
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 价格 + 统计
                  Row(
                    children: [
                      // 价格 (对齐iOS: red color, rounded font)
                      Text(
                        item.priceDisplay,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE64D3D), // iOS red price
                        ),
                      ),
                      const Spacer(),
                      // 浏览量 (对齐iOS: eye icon + count)
                      if (item.viewCount > 0) ...[
                        Icon(
                          Icons.remove_red_eye_outlined,
                          size: 12,
                          color: isDark
                              ? AppColors.textTertiaryDark.withValues(alpha: 0.6)
                              : AppColors.textTertiaryLight.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${item.viewCount}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.textTertiaryDark.withValues(alpha: 0.6)
                                : AppColors.textTertiaryLight.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
