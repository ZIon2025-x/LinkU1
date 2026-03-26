import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/flea_market_rental.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../bloc/flea_market_rental_bloc.dart';

/// 我的租赁列表页
class MyRentalsView extends StatelessWidget {
  const MyRentalsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FleaMarketRentalBloc(
        repository: context.read<FleaMarketRepository>(),
      )..add(const RentalLoadMyRentals()),
      child: const _MyRentalsContent(),
    );
  }
}

class _MyRentalsContent extends StatelessWidget {
  const _MyRentalsContent();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fleaMarketMyRentals)),
      body: BlocConsumer<FleaMarketRentalBloc, FleaMarketRentalState>(
        listenWhen: (prev, curr) =>
            curr.errorMessage != null &&
            prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.localizeError(state.errorMessage!)),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoadingMyRentals && state.myRentals.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!state.isLoadingMyRentals && state.myRentals.isEmpty) {
            return _EmptyState(
              onRefresh: () => context
                  .read<FleaMarketRentalBloc>()
                  .add(const RentalLoadMyRentals()),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<FleaMarketRentalBloc>()
                  .add(const RentalLoadMyRentals());
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200) {
                  // 加载更多
                  if (!state.isLoadingMyRentals && state.hasMoreRentals) {
                    context.read<FleaMarketRentalBloc>().add(
                          RentalLoadMyRentals(page: state.rentalsPage + 1),
                        );
                  }
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount:
                    state.myRentals.length + (state.hasMoreRentals ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.myRentals.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _RentalCard(rental: state.myRentals[index]),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha:0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.fleaMarketNoRentalRequests,
              style: AppTypography.body.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onRefresh,
              child: Text(l10n.fleaMarketRefresh),
            ),
          ],
        ),
      ),
    );
  }
}

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
                        imageUrl: rental.itemImage!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
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
                            color: statusColor.withValues(alpha:0.12),
                            borderRadius: BorderRadius.circular(AppRadius.tiny),
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
