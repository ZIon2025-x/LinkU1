import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/flea_market.dart';
import '../../../data/repositories/flea_market_repository.dart';

/// 我的闲置商品视图（对齐iOS MyPostsView.swift）
/// 4个分类Tab：出售中 / 收的闲置 / 收藏的 / 已售出
class MyPostsView extends StatefulWidget {
  const MyPostsView({super.key});

  @override
  State<MyPostsView> createState() => _MyPostsViewState();
}

/// 闲置商品分类
enum _MyItemsCategory {
  selling,
  purchased,
  favorites,
  sold,
}

class _MyPostsViewState extends State<MyPostsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 各分类数据
  List<FleaMarketItem> _sellingItems = [];
  List<FleaMarketItem> _purchasedItems = [];
  List<FleaMarketItem> _favoriteItems = [];
  List<FleaMarketItem> _soldItems = [];

  // 收的闲置分页
  int _purchasedPage = 1;
  bool _purchasedHasMore = false;
  bool _isLoadingPurchasedMore = false;
  final ScrollController _purchasedScrollController = ScrollController();

  // 各分类加载状态
  bool _isLoadingSelling = true;
  bool _isLoadingPurchased = true;
  bool _isLoadingFavorites = true;
  bool _isLoadingSold = true;

  // 各分类错误状态
  final Map<_MyItemsCategory, String?> _categoryErrors = {};


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        AppHaptics.tabSwitch();
      }
    });
    _purchasedScrollController.addListener(_onPurchasedScroll);
    // 延迟加载，确保context可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllCategories();
    });
  }

  void _onPurchasedScroll() {
    if (_isLoadingPurchasedMore || !_purchasedHasMore) return;
    final pos = _purchasedScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadPurchasedMore();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _purchasedScrollController.removeListener(_onPurchasedScroll);
    _purchasedScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCategories({bool forceRefresh = false}) async {
    if (!mounted) return;
    final repo = context.read<FleaMarketRepository>();

    // 并行加载所有分类（forceRefresh 时收的闲置会刷新缓存）
    await Future.wait([
      _loadSellingItems(repo),
      _loadPurchasedItems(repo, page: 1, forceRefresh: forceRefresh),
      _loadFavoriteItems(repo),
      _loadSoldItems(repo),
    ]);
  }

  Future<void> _loadSellingItems(FleaMarketRepository repo) async {
    setState(() => _isLoadingSelling = true);
    try {
      final response = await repo.getMyItems(page: 1, pageSize: 100);
      if (mounted) {
        setState(() {
          _sellingItems = response.items;
          _isLoadingSelling = false;
          _categoryErrors[_MyItemsCategory.selling] = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSelling = false;
          _categoryErrors[_MyItemsCategory.selling] = e.toString();
        });
      }
    }
  }

  Future<void> _loadPurchasedItems(
    FleaMarketRepository repo, {
    int page = 1,
    bool forceRefresh = false,
  }) async {
    if (page == 1) {
      setState(() => _isLoadingPurchased = true);
    } else {
      setState(() => _isLoadingPurchasedMore = true);
    }
    try {
      final response = await repo.getMyPurchases(
        page: page,
        pageSize: 100,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          final items = response.items
              .map((e) => FleaMarketItem.fromJson(e))
              .toList();
          if (page == 1) {
            _purchasedItems = items;
            _purchasedPage = 1;
          } else {
            _purchasedItems = [..._purchasedItems, ...items];
            _purchasedPage = page;
          }
          _purchasedHasMore = response.hasMore;
          _isLoadingPurchased = false;
          _isLoadingPurchasedMore = false;
          _categoryErrors[_MyItemsCategory.purchased] = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPurchased = false;
          _isLoadingPurchasedMore = false;
          _categoryErrors[_MyItemsCategory.purchased] = e.toString();
        });
      }
    }
  }

  Future<void> _loadPurchasedMore() async {
    if (_isLoadingPurchasedMore || !_purchasedHasMore || !mounted) return;
    final repo = context.read<FleaMarketRepository>();
    await _loadPurchasedItems(repo, page: _purchasedPage + 1);
  }

  Future<void> _loadFavoriteItems(FleaMarketRepository repo) async {
    setState(() => _isLoadingFavorites = true);
    try {
      final response = await repo.getFavoriteItems(page: 1, pageSize: 100);
      if (mounted) {
        setState(() {
          _favoriteItems = response.items;
          _isLoadingFavorites = false;
          _categoryErrors[_MyItemsCategory.favorites] = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFavorites = false;
          _categoryErrors[_MyItemsCategory.favorites] = e.toString();
        });
      }
    }
  }

  Future<void> _loadSoldItems(FleaMarketRepository repo) async {
    setState(() => _isLoadingSold = true);
    try {
      final response = await repo.getMySales(page: 1, pageSize: 100);
      if (mounted) {
        setState(() {
          _soldItems = response.items;
          _isLoadingSold = false;
          _categoryErrors[_MyItemsCategory.sold] = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSold = false;
          _categoryErrors[_MyItemsCategory.sold] = e.toString();
        });
      }
    }
  }

  List<FleaMarketItem> _getItems(_MyItemsCategory category) {
    switch (category) {
      case _MyItemsCategory.selling:
        return _sellingItems;
      case _MyItemsCategory.purchased:
        return _purchasedItems;
      case _MyItemsCategory.favorites:
        return _favoriteItems;
      case _MyItemsCategory.sold:
        return _soldItems;
    }
  }

  bool _isLoading(_MyItemsCategory category) {
    switch (category) {
      case _MyItemsCategory.selling:
        return _isLoadingSelling;
      case _MyItemsCategory.purchased:
        return _isLoadingPurchased;
      case _MyItemsCategory.favorites:
        return _isLoadingFavorites;
      case _MyItemsCategory.sold:
        return _isLoadingSold;
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
            onPressed: () async {
              await context.push('/flea-market/create');
              if (mounted) _loadAllCategories(forceRefresh: true);
            },
          ),
        ],
        bottom: TabBar(
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
              icon: const Icon(Icons.shopping_bag, size: 18),
              text: l10n.myItemsPurchased,
            ),
            Tab(
              icon: const Icon(Icons.favorite, size: 18),
              text: l10n.myItemsFavorites,
            ),
            Tab(
              icon: const Icon(Icons.check_circle, size: 18),
              text: l10n.myItemsSold,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryContent(_MyItemsCategory.selling),
          _buildCategoryContent(_MyItemsCategory.purchased),
          _buildCategoryContent(_MyItemsCategory.favorites),
          _buildCategoryContent(_MyItemsCategory.sold),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(_MyItemsCategory category) {
    final items = _getItems(category);
    final loading = _isLoading(category);
    final error = _categoryErrors[category];
    final l10n = context.l10n;

    if (loading && items.isEmpty) {
      return const SkeletonList();
    }

    if (error != null && items.isEmpty) {
      return ErrorStateView(
        message: error,
        onRetry: () => _loadAllCategories(forceRefresh: true),
      );
    }

    if (items.isEmpty) {
      String emptyTitle;
      String emptyMessage;
      switch (category) {
        case _MyItemsCategory.selling:
          emptyTitle = l10n.myItemsEmptySelling;
          emptyMessage = l10n.myItemsEmptySellingMessage;
        case _MyItemsCategory.purchased:
          emptyTitle = l10n.myItemsEmptyPurchased;
          emptyMessage = l10n.myItemsEmptyPurchasedMessage;
        case _MyItemsCategory.favorites:
          emptyTitle = l10n.myItemsEmptyFavorites;
          emptyMessage = l10n.myItemsEmptyFavoritesMessage;
        case _MyItemsCategory.sold:
          emptyTitle = l10n.myItemsEmptySold;
          emptyMessage = l10n.myItemsEmptySoldMessage;
      }
      return EmptyStateView(
        icon: _categoryIcon(category),
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    final isPurchased = category == _MyItemsCategory.purchased;
    final itemCount = items.length +
        (isPurchased && _isLoadingPurchasedMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => _loadAllCategories(forceRefresh: true),
      child: ListView.separated(
        controller: isPurchased ? _purchasedScrollController : null,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (isPurchased && index == items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = items[index];
          return AnimatedListItem(
            index: index,
            child: _FleaMarketItemCard(
              item: item,
              category: category,
              onTap: () {
                if (item.id.isNotEmpty) context.safePush('/flea-market/${item.id}');
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
      case _MyItemsCategory.purchased:
        return Icons.shopping_bag;
      case _MyItemsCategory.favorites:
        return Icons.favorite;
      case _MyItemsCategory.sold:
        return Icons.check_circle;
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

    return GestureDetector(
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
                          imageUrl: item.firstImage!,
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
      case _MyItemsCategory.purchased:
        // 待支付商品显示「待支付」，方便用户识别并完成支付
        text = item.hasPendingPayment
            ? l10n.taskStatusPendingPayment
            : l10n.myItemsStatusPurchased;
        color = item.hasPendingPayment ? AppColors.warning : AppColors.primary;
      case _MyItemsCategory.favorites:
        return const SizedBox.shrink();
      case _MyItemsCategory.sold:
        text = l10n.myItemsStatusSold;
        color = AppColors.textTertiaryLight;
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
