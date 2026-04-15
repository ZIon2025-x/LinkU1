import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/widgets/async_image_view.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../data/models/flea_market_rental.dart';
import '../../../../data/repositories/flea_market_repository.dart';

/// "租入中" Tab — 我租用他人的闲置
///
/// 迁移自 `features/flea_market/views/my_rentals_view.dart`，
/// 作为 my_posts_view 新增的第 6 个 Tab，复用原 `_RentalCard` 视觉与交互。
/// 不再依赖 `FleaMarketRentalBloc`，改为直接调用 `FleaMarketRepository.getMyRentals`
/// 管理本地状态（首屏加载 / 下拉刷新 / 触底加载更多）。
class RentedInTab extends StatefulWidget {
  const RentedInTab({super.key});

  @override
  State<RentedInTab> createState() => _RentedInTabState();
}

class _RentedInTabState extends State<RentedInTab>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 20;

  final List<FleaMarketRental> _rentals = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _errorCode;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorCode = null;
    });
    try {
      final repo = context.read<FleaMarketRepository>();
      final list = await repo.getMyRentals(page: _page);
      if (!mounted) return;
      setState(() {
        _rentals.addAll(list);
        _hasMore = list.length >= _pageSize;
        _page++;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorCode = 'my_posts_rentals_load_failed';
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _rentals.clear();
      _page = 1;
      _hasMore = true;
      _errorCode = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    // 错误态 (首屏加载失败)
    if (_errorCode != null && _rentals.isEmpty) {
      return ErrorStateView(
        message: context.localizeError(_errorCode),
        onRetry: _refresh,
      );
    }

    // 首屏加载中
    if (_loading && _rentals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 空态
    if (_rentals.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.fleaMarketNoRentalRequests,
                        style: AppTypography.body.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _rentals.length + (_hasMore ? 1 : 0),
        itemBuilder: (ctx, index) {
          if (index >= _rentals.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Padding(
            key: ValueKey('rental_${_rentals[index].id}'),
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _RentalCard(rental: _rentals[index]),
          );
        },
      ),
    );
  }
}

/// 租赁卡片 — 迁移自 `my_rentals_view.dart` (lines 152-283)。
/// 与原实现保持视觉/交互一致；新增 `pending_return` 状态映射。
class _RentalCard extends StatelessWidget {
  const _RentalCard({required this.rental});
  final FleaMarketRental rental;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currencySymbol = Helpers.currencySymbolFor(rental.currency);

    final (statusLabel, statusColor) = switch (rental.status) {
      'active' => (l10n.fleaMarketRentalActive, AppColors.success),
      'returned' => (l10n.fleaMarketRentalReturned, AppColors.info),
      'overdue' => (l10n.fleaMarketRentalOverdue, AppColors.error),
      'pending_return' => (
        l10n.fleaMarketRentalPendingReturn,
        AppColors.warning,
      ),
      'disputed' => ('Disputed', AppColors.warning),
      _ => (rental.status, AppColors.info),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/flea-market/rental/${rental.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: rental.itemImage != null && rental.itemImage!.isNotEmpty
                    ? AsyncImageView(
                        imageUrl: Helpers.getThumbnailUrl(rental.itemImage!),
                        fallbackUrl: Helpers.getImageUrl(rental.itemImage!),
                        width: 72,
                        height: 72,
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: Icon(
                          Icons.image_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),

              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题 + 状态
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rental.itemTitle ?? 'Item #${rental.itemId}',
                            style: AppTypography.subheadlineBold.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.tiny),
                          ),
                          child: Text(
                            statusLabel,
                            style: AppTypography.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // 日期
                    Text(
                      '${_formatDate(rental.startDate)} - ${_formatDate(rental.endDate)}',
                      style: AppTypography.footnote.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // 金额
                    Text(
                      '${l10n.fleaMarketRentalTotal}: $currencySymbol${rental.totalPaid.toStringAsFixed(2)}',
                      style: AppTypography.footnote.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // 箭头
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
