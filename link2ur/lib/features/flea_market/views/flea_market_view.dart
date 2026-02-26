import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/content_constraint.dart';
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
  final Debouncer _debouncer = Debouncer();

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
    _debouncer.dispose();
    super.dispose();
  }

  void _showCategoryFilter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = _getCategories(context);
    final bloc = context.read<FleaMarketBloc>();

    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardBackgroundDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: bloc,
          child: BlocBuilder<FleaMarketBloc, FleaMarketState>(
            buildWhen: (prev, curr) => prev.selectedCategory != curr.selectedCategory,
            builder: (ctx, state) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 顶部拖拽条
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.fleaMarketCategoryAll.replaceAll(RegExp(r'全部|All'), '') + context.l10n.fleaMarketFleaMarket,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: categories.map((cat) {
                          final (value, label) = cat;
                          final isSelected = state.selectedCategory == value;
                          return GestureDetector(
                            onTap: () {
                              AppHaptics.selection();
                              bloc.add(FleaMarketCategoryChanged(value));
                              Navigator.pop(sheetContext);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? const LinearGradient(colors: AppColors.gradientPrimary)
                                    : null,
                                color: isSelected
                                    ? null
                                    : (isDark
                                        ? AppColors.surface2(Brightness.dark)
                                        : AppColors.surface1(Brightness.light)),
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                                            .withValues(alpha: 0.3),
                                      ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 12,
        title: BlocBuilder<FleaMarketBloc, FleaMarketState>(
          buildWhen: (prev, curr) => prev.selectedCategory != curr.selectedCategory,
          builder: (context, state) {
            final hasFilter = state.selectedCategory != 'all';
            return Row(
              children: [
                // 搜索框
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: context.l10n.fleaMarketSearchItems,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.skeletonBase,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.allPill,
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (query) {
                        _debouncer.call(() {
                          if (!mounted) return;
                          context.read<FleaMarketBloc>().add(FleaMarketSearchChanged(query));
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 筛选按钮
                GestureDetector(
                  onTap: () => _showCategoryFilter(context),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: hasFilter
                          ? const LinearGradient(colors: AppColors.gradientPrimary)
                          : null,
                      color: hasFilter
                          ? null
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppColors.skeletonBase),
                      borderRadius: AppRadius.allPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: hasFilter
                              ? Colors.white
                              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasFilter
                              ? _getCategories(context)
                                  .firstWhere((c) => c.$1 == state.selectedCategory, orElse: () => ('', ''))
                                  .$2
                              : context.l10n.fleaMarketCategoryAll,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: hasFilter ? FontWeight.w600 : FontWeight.normal,
                            color: hasFilter
                                ? Colors.white
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: BlocBuilder<FleaMarketBloc, FleaMarketState>(
        buildWhen: (prev, curr) =>
            prev.items != curr.items ||
            prev.status != curr.status ||
            prev.hasMore != curr.hasMore ||
            prev.isEmpty != curr.isEmpty,
        builder: (context, state) {
          final content = AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildFleaMarketContent(context, state),
          );
          return isDesktop ? ContentConstraint(child: content) : content;
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/flea-market/create');
          if (context.mounted) {
            context.read<FleaMarketBloc>().add(const FleaMarketRefreshRequested());
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFleaMarketContent(BuildContext context, FleaMarketState state) {
    // Loading state
    if (state.isLoading && state.items.isEmpty) {
      return const SkeletonGrid(
        key: ValueKey('skeleton'),
        aspectRatio: 0.7,
      );
    }

    // Error state
    if (state.status == FleaMarketStatus.error && state.items.isEmpty) {
      return ErrorStateView.loadFailed(
        message: state.errorMessage != null
            ? ErrorLocalizer.localize(context, state.errorMessage)
            : context.l10n.fleaMarketLoadFailed,
        onRetry: () {
          context.read<FleaMarketBloc>().add(const FleaMarketLoadRequested());
        },
      );
    }

    // Empty state
    if (state.isEmpty) {
      return EmptyStateView.noData(
        context,
        title: context.l10n.fleaMarketNoItems,
        description: context.l10n.fleaMarketNoItemsHint,
      );
    }

    // Content with pull-to-refresh
    final columnCount = ResponsiveUtils.gridColumnCount(context, type: GridItemType.fleaMarket);
    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: () async {
        final bloc = context.read<FleaMarketBloc>();
        bloc.add(const FleaMarketRefreshRequested());
        await bloc.stream.firstWhere(
          (s) => !s.isRefreshing,
          orElse: () => state,
        );
      },
      child: MasonryGridView.count(
        crossAxisCount: columnCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        cacheExtent: 500,
        padding: const EdgeInsets.all(8),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            context.read<FleaMarketBloc>().add(const FleaMarketLoadMore());
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: LoadingIndicator(),
              ),
            );
          }
          final item = state.items[index];
          return RepaintBoundary(
            child: AnimatedListItem(
              key: ValueKey(item.id),
              index: index,
              maxAnimatedIndex: columnCount * 3 - 1,
              child: _FleaMarketItemCard(item: item),
            ),
          );
        },
      ),
    );
  }
}

/// 商品卡片 - 小红书风格瀑布流卡片
/// 图片（限定比例范围）+ 标题 + 描述 + 价格 + 收藏
class _FleaMarketItemCard extends StatelessWidget {
  const _FleaMarketItemCard({required this.item});

  final FleaMarketItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        if (item.id.isNotEmpty) {
          // 等待详情页返回后刷新列表（对标 iOS: CacheManager.shared.invalidateFleaMarketCache()）
          // 用户可能在详情页中购买/支付，返回后列表需要反映最新状态
          await context.push('/flea-market/${item.id}');
          if (context.mounted) {
            context.read<FleaMarketBloc>().add(const FleaMarketRefreshRequested());
          }
        }
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域 - 限定比例范围的瀑布流高度
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth;
                // 限定比例范围: 最矮 3:4, 最高 4:3
                final minHeight = cardWidth * 0.75;
                final maxHeight = cardWidth * 1.33;
                // 用 hashCode 映射到合理范围内（后续可改为真实图片比例）
                final ratio = (item.id.hashCode.abs() % 1000) / 1000.0;
                final imageHeight = minHeight + ratio * (maxHeight - minHeight);

                return SizedBox(
                  height: imageHeight,
                  width: cardWidth,
                  child: Stack(
                    children: [
                      // 商品图片
                      Positioned.fill(
                        child: item.firstImage != null
                            ? Hero(
                                tag: 'flea_market_image_${item.id}',
                                child: AsyncImageView(
                                  imageUrl: item.firstImage!,
                                  width: cardWidth,
                                  height: imageHeight,
                                ),
                              )
                            : Container(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : AppColors.skeletonBase,
                                child: Icon(
                                  Icons.image_outlined,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : AppColors.textTertiaryLight.withValues(alpha: 0.3),
                                  size: 40,
                                ),
                              ),
                      ),
                      // 左上: 分类标签
                      if (item.category != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
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
                      // 左下: VIP/Super卖家标签
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
                                colors: AppColors.gradientOrange,
                              ),
                              borderRadius: AppRadius.allPill,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gradientOrange[0].withValues(alpha: 0.4),
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
                );
              },
            ),
            // 内容区域
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题（最多1行）
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 描述（最多1行）
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  // 价格 + 收藏
                  Row(
                    children: [
                      // 价格
                      Expanded(
                        child: Text(
                          item.isFree
                              ? context.l10n.commonFree
                              : item.priceDisplay,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: item.isFree
                                ? AppColors.success
                                : AppColors.priceRed,
                          ),
                        ),
                      ),
                      // 收藏数
                      Icon(
                        Icons.favorite_border,
                        size: 14,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                      if (item.favoriteCount > 0) ...[
                        const SizedBox(width: 2),
                        Text(
                          '${item.favoriteCount}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
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
