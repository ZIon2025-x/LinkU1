import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/flea_market.dart';
import '../../../data/repositories/flea_market_repository.dart';
import 'widgets/rented_in_tab.dart';

/// 我的闲置商品视图
/// 6个分类Tab：出售中 / 已售出 / 收的闲置 / 租出 / 租入 / 收藏的
class MyPostsView extends StatefulWidget {
  final int initialTab;
  const MyPostsView({super.key, this.initialTab = 0});

  @override
  State<MyPostsView> createState() => _MyPostsViewState();
}

/// 闲置商品分类（rentedIn 不在此枚举，由 RentedInTab widget 直接处理）
enum _MyItemsCategory {
  selling,
  sold,
  purchased,
  rentedOut,
  favorites,
}

class _MyPostsViewState extends State<MyPostsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// 一次拉取「与我相关且任务来源为跳蚤市场」的商品，本地按 tab 筛选
  List<FleaMarketItem> _allRelatedItems = [];
  bool _allRelatedLoading = true;

  List<FleaMarketItem> _favoriteItems = [];
  bool _favoriteLoading = true;

  final ScrollController _purchasedScrollController = ScrollController();
  final Map<_MyItemsCategory, String?> _categoryErrors = {};


  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 5),
    );
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllRelated();
      _loadFavorites();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _purchasedScrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      AppHaptics.tabSwitch();
    }
  }

  /// 根据 tab 从「与我相关」列表中筛选
  List<FleaMarketItem> _getFilteredItems(_MyItemsCategory category) {
    switch (category) {
      case _MyItemsCategory.selling:
        return _allRelatedItems
            .where((e) =>
                e.myRole == 'seller' &&
                e.listingType == 'sale' &&
                e.status == AppConstants.fleaMarketStatusActive)
            .toList();
      case _MyItemsCategory.sold:
        return _allRelatedItems
            .where((e) =>
                e.myRole == 'seller' &&
                e.listingType == 'sale' &&
                e.status == AppConstants.fleaMarketStatusSold)
            .toList();
      case _MyItemsCategory.purchased:
        return _allRelatedItems.where((e) => e.myRole == 'buyer').toList();
      case _MyItemsCategory.rentedOut:
        return _allRelatedItems
            .where((e) =>
                e.myRole == 'seller' && e.listingType == 'rental')
            .toList();
      case _MyItemsCategory.favorites:
        return _favoriteItems;
    }
  }

  bool _isLoading(_MyItemsCategory category) {
    switch (category) {
      case _MyItemsCategory.selling:
      case _MyItemsCategory.sold:
      case _MyItemsCategory.purchased:
      case _MyItemsCategory.rentedOut:
        return _allRelatedLoading;
      case _MyItemsCategory.favorites:
        return _favoriteLoading;
    }
  }

  Future<void> _loadAllRelated({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _allRelatedLoading = true);
    try {
      final repo = context.read<FleaMarketRepository>();
      final items = await repo.getMyRelatedFleaItems(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _allRelatedItems = items;
          _allRelatedLoading = false;
          _categoryErrors[_MyItemsCategory.selling] = null;
          _categoryErrors[_MyItemsCategory.sold] = null;
          _categoryErrors[_MyItemsCategory.purchased] = null;
          _categoryErrors[_MyItemsCategory.rentedOut] = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allRelatedLoading = false;
          _categoryErrors[_MyItemsCategory.selling] = e.toString();
          _categoryErrors[_MyItemsCategory.sold] = e.toString();
          _categoryErrors[_MyItemsCategory.purchased] = e.toString();
          _categoryErrors[_MyItemsCategory.rentedOut] = e.toString();
        });
      }
    }
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    setState(() => _favoriteLoading = true);
    try {
      final repo = context.read<FleaMarketRepository>();
      final response = await repo.getFavoriteItems(pageSize: 100);
      if (mounted) {
        setState(() {
          _favoriteItems = response.items;
          _favoriteLoading = false;
          _categoryErrors[_MyItemsCategory.favorites] = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _favoriteLoading = false;
          _categoryErrors[_MyItemsCategory.favorites] = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileMyPosts),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, size: 28),
            color: AppColors.primary,
            tooltip: 'New post',
            onPressed: () async {
              await context.push('/flea-market/create');
              if (mounted) { _loadAllRelated(forceRefresh: true); _loadFavorites(); }
            },
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              icon: const Icon(Icons.sell, size: 18),
              text: l10n.myItemsSelling,
            ),
            Tab(
              icon: const Icon(Icons.check_circle, size: 18),
              text: l10n.myItemsSold,
            ),
            Tab(
              icon: const Icon(Icons.shopping_bag, size: 18),
              text: l10n.myItemsPurchased,
            ),
            Tab(
              icon: const Icon(Icons.outbox, size: 18),
              text: l10n.myPostsTabRentedOut,
            ),
            Tab(
              icon: const Icon(Icons.inbox, size: 18),
              text: l10n.myPostsTabRentedIn,
            ),
            Tab(
              icon: const Icon(Icons.favorite, size: 18),
              text: l10n.myItemsFavorites,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryContent(_MyItemsCategory.selling),
          _buildCategoryContent(_MyItemsCategory.sold),
          _buildCategoryContent(_MyItemsCategory.purchased),
          _buildCategoryContent(_MyItemsCategory.rentedOut),
          const RentedInTab(),
          _buildCategoryContent(_MyItemsCategory.favorites),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(_MyItemsCategory category) {
    final items = _getFilteredItems(category);
    final loading = _isLoading(category);
    final error = _categoryErrors[category];
    final l10n = context.l10n;

    if (loading && items.isEmpty) {
      return const SkeletonList();
    }

    if (error != null && items.isEmpty) {
      return ErrorStateView(
        message: context.localizeError(error),
        onRetry: () { _loadAllRelated(); if (category == _MyItemsCategory.favorites) _loadFavorites(); },
      );
    }

    if (items.isEmpty) {
      String emptyTitle;
      String emptyMessage;
      switch (category) {
        case _MyItemsCategory.selling:
          emptyTitle = l10n.myItemsEmptySelling;
          emptyMessage = l10n.myItemsEmptySellingMessage;
        case _MyItemsCategory.sold:
          emptyTitle = l10n.myItemsEmptySold;
          emptyMessage = l10n.myItemsEmptySoldMessage;
        case _MyItemsCategory.purchased:
          emptyTitle = l10n.myItemsEmptyPurchased;
          emptyMessage = l10n.myItemsEmptyPurchasedMessage;
        case _MyItemsCategory.rentedOut:
          emptyTitle = l10n.myItemsEmptyRentedOut;
          emptyMessage = l10n.myItemsEmptyRentedOutMessage;
        case _MyItemsCategory.favorites:
          emptyTitle = l10n.myItemsEmptyFavorites;
          emptyMessage = l10n.myItemsEmptyFavoritesMessage;
      }
      return EmptyStateView(
        icon: _categoryIcon(category),
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    final isPurchased = category == _MyItemsCategory.purchased;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadAllRelated(forceRefresh: true);
        if (category == _MyItemsCategory.favorites) await _loadFavorites();
      },
      child: ListView.separated(
        controller: isPurchased ? _purchasedScrollController : null,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final item = items[index];
          return AnimatedListItem(
            key: ValueKey(item.id),
            index: index,
            maxAnimatedIndex: 11,
            child: _FleaMarketItemCard(
              item: item,
              category: category,
              onTap: () async {
                if (item.id.isEmpty) return;
                await context.push('/flea-market/${item.id}');
                if (context.mounted) {
                  _loadAllRelated(forceRefresh: true);
                  if (category == _MyItemsCategory.favorites) _loadFavorites();
                }
              },
            ),
          );
        },
      ),
    );
  }

  IconData _categoryIcon(_MyItemsCategory category) {
    switch (category) {
      case _MyItemsCategory.selling:
        return Icons.sell;
      case _MyItemsCategory.sold:
        return Icons.check_circle;
      case _MyItemsCategory.purchased:
        return Icons.shopping_bag;
      case _MyItemsCategory.rentedOut:
        return Icons.outbox;
      case _MyItemsCategory.favorites:
        return Icons.favorite;
    }
  }
}

/// 闲置商品卡片（对齐iOS MyItemCard）
class _FleaMarketItemCard extends StatelessWidget {
  const _FleaMarketItemCard({
    required this.item,
    required this.category,
    required this.onTap,
  });

  final FleaMarketItem item;
  final _MyItemsCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: 'View details',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allLarge,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域 + 状态标签
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: item.hasImages
                      ? AsyncImageView(
                          imageUrl: Helpers.getThumbnailUrl(item.firstImage!, size: 'large'),
                          fallbackUrl: Helpers.getImageUrl(item.firstImage!),
                          width: double.infinity,
                          height: 200,
                        )
                      : Container(
                          width: double.infinity,
                          height: 200,
                          color: isDark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          child: Icon(
                            Icons.photo,
                            size: 48,
                            color: isDark
                                ? Colors.grey[600]
                                : Colors.grey[400],
                          ),
                        ),
                ),
                // 状态标签
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildStatusBadge(context),
                ),
              ],
            ),

            // 内容区域
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 价格
                  Text(
                    item.priceDisplay,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 收藏数和浏览量
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 14,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.favoriteCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.visibility,
                        size: 14,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.viewCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final l10n = context.l10n;
    String? text;
    Color color;

    switch (category) {
      case _MyItemsCategory.selling:
        text = l10n.myItemsStatusSelling;
        color = AppColors.success;
      case _MyItemsCategory.sold:
        text = l10n.myItemsStatusSold;
        color = AppColors.textTertiaryLight;
      case _MyItemsCategory.purchased:
        // 待支付商品显示「待支付」，方便用户识别并完成支付
        text = item.hasPendingPayment
            ? l10n.taskStatusPendingPayment
            : l10n.myItemsStatusPurchased;
        color = item.hasPendingPayment ? AppColors.warning : AppColors.primary;
      case _MyItemsCategory.rentedOut:
        final rentalStatus = item.currentRentalStatus;
        switch (rentalStatus) {
          case 'available':
            text = l10n.rentalListingStatusAvailable;
            color = AppColors.success;
          case 'renting':
            text = l10n.rentalListingStatusRenting;
            color = AppColors.info;
          case 'overdue':
            text = l10n.rentalListingStatusOverdue;
            color = AppColors.error;
          default:
            return const SizedBox.shrink();
        }
      case _MyItemsCategory.favorites:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
