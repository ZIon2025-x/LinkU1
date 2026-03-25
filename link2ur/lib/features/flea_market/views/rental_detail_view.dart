import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/models/flea_market_rental.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/flea_market_rental_bloc.dart';

/// 租赁详情页
class RentalDetailView extends StatelessWidget {
  const RentalDetailView({super.key, required this.rentalId});

  final String rentalId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FleaMarketRentalBloc(
        repository: context.read<FleaMarketRepository>(),
      )..add(RentalLoadDetail(rentalId)),
      child: _RentalDetailContent(rentalId: rentalId),
    );
  }
}

class _RentalDetailContent extends StatelessWidget {
  const _RentalDetailContent({required this.rentalId});

  final String rentalId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fleaMarketRentalDetail)),
      body: BlocConsumer<FleaMarketRentalBloc, FleaMarketRentalState>(
        listenWhen: (prev, curr) =>
            (curr.actionMessage != null &&
                prev.actionMessage != curr.actionMessage) ||
            (curr.errorMessage != null &&
                prev.errorMessage != curr.errorMessage),
        listener: (context, state) {
          if (state.actionMessage != null) {
            final message = switch (state.actionMessage) {
              'rental_return_confirmed' => l10n.fleaMarketConfirmReturn,
              _ => state.actionMessage ?? '',
            };
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: AppColors.success,
              ),
            );
            context
                .read<FleaMarketRentalBloc>()
                .add(const RentalClearActionMessage());
          }
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
          if (state.isLoadingRequests && state.currentRental == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final rental = state.currentRental;
          if (rental == null) {
            return ErrorStateView(
              message: l10n.fleaMarketErrorGetRentalDetailFailed,
              onRetry: () => context
                  .read<FleaMarketRentalBloc>()
                  .add(RentalLoadDetail(rentalId)),
            );
          }

          return _RentalDetailBody(rental: rental, isSubmitting: state.isSubmitting);
        },
      ),
    );
  }
}

class _RentalDetailBody extends StatelessWidget {
  const _RentalDetailBody({
    required this.rental,
    required this.isSubmitting,
  });

  final FleaMarketRental rental;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentUserId = context.select<AuthBloc, String?>(
      (bloc) => bloc.state.user?.id,
    );

    // 判断当前用户是否为物品所有者（owner 信息从 rental model 无法判断时，
    // 通过 renterId 反推：如果当前用户不是 renter，则为 owner）
    // 注意：更准确的做法需要后端返回 ownerId，这里先用简单逻辑
    final isOwner = currentUserId != null && currentUserId != rental.renterId;
    final canConfirmReturn =
        isOwner && (rental.status == 'active' || rental.status == 'overdue');

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              context
                  .read<FleaMarketRentalBloc>()
                  .add(RentalLoadDetail(rental.id.toString()));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // 物品信息
                _ItemInfoSection(rental: rental),
                const SizedBox(height: AppSpacing.md),

                // 租赁信息
                _RentalInfoSection(rental: rental),
                const SizedBox(height: AppSpacing.md),

                // 财务信息
                _FinancialSection(rental: rental),
                const SizedBox(height: AppSpacing.md),

                // 押金状态
                _DepositStatusSection(rental: rental),

                // 归还日期
                if (rental.status == 'returned' && rental.returnedAt != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _InfoRow(
                    label: l10n.fleaMarketRentalReturned,
                    value: _formatDate(rental.returnedAt!),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 确认归还按钮
        if (canConfirmReturn)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () => _confirmReturn(context),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.fleaMarketConfirmReturn),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _confirmReturn(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.fleaMarketConfirmReturn),
        content: Text(l10n.fleaMarketConfirmReturnMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context
                  .read<FleaMarketRentalBloc>()
                  .add(RentalConfirmReturn(rental.id.toString()));
            },
            child: Text(l10n.fleaMarketConfirm),
          ),
        ],
      ),
    );
  }

  static String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ==================== Sections ====================

class _ItemInfoSection extends StatelessWidget {
  const _ItemInfoSection({required this.rental});
  final FleaMarketRental rental;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          if (rental.itemImage != null && rental.itemImage!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: AsyncImageView(
                imageUrl: rental.itemImage!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(
                Icons.image_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              rental.itemTitle ?? 'Item #${rental.itemId}',
              style: AppTypography.title3.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RentalInfoSection extends StatelessWidget {
  const _RentalInfoSection({required this.rental});
  final FleaMarketRental rental;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final unitLabel = switch (rental.rentalUnit) {
      'day' => l10n.fleaMarketRentalUnitDay,
      'week' => l10n.fleaMarketRentalUnitWeek,
      'month' => l10n.fleaMarketRentalUnitMonth,
      _ => rental.rentalUnit,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.fleaMarketRentalDuration,
                style: AppTypography.subheadlineBold.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              _StatusBadge(status: rental.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: l10n.fleaMarketRentalDuration,
            value: '${rental.rentalDuration} $unitLabel',
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            label: l10n.fleaMarketDesiredTime,
            value: _RentalDetailBody._formatDate(rental.startDate),
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            label: '${l10n.fleaMarketRentalDetail} - End',
            value: _RentalDetailBody._formatDate(rental.endDate),
          ),
        ],
      ),
    );
  }
}

class _FinancialSection extends StatelessWidget {
  const _FinancialSection({required this.rental});
  final FleaMarketRental rental;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currencySymbol = rental.currency == 'GBP' ? '\u00A3' : rental.currency;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.fleaMarketRentalCostPreview,
            style: AppTypography.subheadlineBold.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: l10n.fleaMarketRentalSubtotal,
            value: '$currencySymbol${rental.totalRent.toStringAsFixed(2)}',
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            label: l10n.fleaMarketDeposit,
            value: '$currencySymbol${rental.depositAmount.toStringAsFixed(2)}',
          ),
          const Divider(height: AppSpacing.md),
          _InfoRow(
            label: l10n.fleaMarketRentalTotal,
            value: '$currencySymbol${rental.totalPaid.toStringAsFixed(2)}',
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class _DepositStatusSection extends StatelessWidget {
  const _DepositStatusSection({required this.rental});
  final FleaMarketRental rental;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final (label, color) = switch (rental.depositStatus) {
      'held' => (l10n.fleaMarketDepositHeld, AppColors.warning),
      'refunded' => (l10n.fleaMarketDepositRefunded, AppColors.success),
      'forfeited' => ('Deposit Forfeited', AppColors.error),
      _ => (rental.depositStatus, theme.colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.fleaMarketDeposit,
            style: AppTypography.subheadline.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Text(
              label,
              style: AppTypography.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Shared Widgets ====================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final (label, color) = switch (status) {
      'active' => (l10n.fleaMarketRentalActive, AppColors.success),
      'returned' => (l10n.fleaMarketRentalReturned, AppColors.info),
      'overdue' => (l10n.fleaMarketRentalOverdue, AppColors.error),
      'disputed' => ('Disputed', AppColors.warning),
      _ => (status, AppColors.info),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.subheadline.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: (isBold ? AppTypography.subheadlineBold : AppTypography.subheadline)
              .copyWith(color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }
}
