import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/router/go_router_extensions.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../data/models/service_application.dart';
import '../../../data/repositories/personal_service_repository.dart';
import '../bloc/personal_service_bloc.dart';

/// 申请者查看自己提交的所有服务申请
class MyServiceApplicationsListView extends StatelessWidget {
  const MyServiceApplicationsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PersonalServiceBloc(
        repository: context.read<PersonalServiceRepository>(),
      )..add(const PersonalServiceLoadMyApplications()),
      child: const _Content(),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content();

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  String _selectedFilter = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myServiceApplicationsTitle),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.myServiceApplicationsFilterAll,
                  selected: _selectedFilter.isEmpty,
                  onTap: () => _applyFilter(''),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: l10n.myServiceApplicationsFilterPending,
                  selected: _selectedFilter == 'pending',
                  onTap: () => _applyFilter('pending'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: l10n.expertApplicationStatusConsulting,
                  selected: _selectedFilter == 'consulting',
                  onTap: () => _applyFilter('consulting'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: l10n.myServiceApplicationsFilterNegotiating,
                  selected: _selectedFilter == 'negotiating',
                  onTap: () => _applyFilter('negotiating'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: l10n.expertApplicationStatusPriceAgreed,
                  selected: _selectedFilter == 'price_agreed',
                  onTap: () => _applyFilter('price_agreed'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: l10n.myServiceApplicationsFilterApproved,
                  selected: _selectedFilter == 'approved',
                  onTap: () => _applyFilter('approved'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: l10n.myServiceApplicationsFilterRejected,
                  selected: _selectedFilter == 'rejected',
                  onTap: () => _applyFilter('rejected'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: l10n.expertApplicationStatusCancelled,
                  selected: _selectedFilter == 'cancelled',
                  onTap: () => _applyFilter('cancelled'),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: BlocConsumer<PersonalServiceBloc, PersonalServiceState>(
              listenWhen: (prev, curr) =>
                  prev.actionMessage != curr.actionMessage,
              listener: (context, state) {
                if (state.actionMessage == null) return;
                final l10n = context.l10n;
                final msg = switch (state.actionMessage) {
                  'counter_offer_accepted' => l10n.serviceCounterOfferAccepted,
                  'counter_offer_rejected' => l10n.serviceCounterOfferRejected,
                  'application_cancelled' =>
                    l10n.serviceApplicationCancelSuccess,
                  'counter_offer_respond_failed' => state.errorMessage != null
                      ? context.localizeError(state.errorMessage)
                      : l10n.serviceCounterOfferRespondFailed,
                  'cancel_application_failed' => state.errorMessage != null
                      ? context.localizeError(state.errorMessage)
                      : l10n.serviceApplicationCancelFailed,
                  _ => null,
                };
                if (msg != null) {
                  final isError =
                      state.actionMessage?.contains('failed') ?? false;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor:
                          isError ? AppColors.error : AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              builder: (context, state) {
                final items = state.myApplications;
                if (state.status == PersonalServiceStatus.loading &&
                    items.isEmpty) {
                  return const SkeletonList();
                }

                if (state.status == PersonalServiceStatus.error &&
                    items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48,
                            color: AppColors.error.withValues(alpha: 0.5)),
                        AppSpacing.vMd,
                        Text(state.errorMessage != null
                            ? context.localizeError(state.errorMessage)
                            : l10n.expertApplicationActionFailed),
                        AppSpacing.vMd,
                        TextButton(
                          onPressed: () => _reload(context),
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  );
                }

                if (items.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.assignment_outlined,
                    title: l10n.myServiceApplicationsEmpty,
                    message: _emptyMessageForFilter(l10n, _selectedFilter),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _reload(context);
                    await context.read<PersonalServiceBloc>().stream.firstWhere(
                          (s) => s.status != PersonalServiceStatus.loading,
                        );
                  },
                  child: ListView.separated(
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final application = items[index];
                      final isThisSubmitting = state.isSubmitting &&
                          state.submittingApplicationId != null &&
                          state.submittingApplicationId == application.id;
                      return AnimatedListItem(
                        key: ValueKey(application.id),
                        index: index,
                        maxAnimatedIndex: 11,
                        child: _MyApplicationCard(
                          application: application,
                          isSubmitting: isThisSubmitting,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilter(String filter) {
    setState(() => _selectedFilter = filter);
    context.read<PersonalServiceBloc>().add(
          PersonalServiceLoadMyApplications(
            statusFilter: filter.isEmpty ? null : filter,
          ),
        );
  }

  void _reload(BuildContext context) {
    context.read<PersonalServiceBloc>().add(
          PersonalServiceLoadMyApplications(
            statusFilter: _selectedFilter.isEmpty ? null : _selectedFilter,
          ),
        );
  }

  /// AUDIT-8: Context-aware empty state message — surfaces which filter is
  /// active so the user can tell "no data" from "filter matched nothing".
  String _emptyMessageForFilter(dynamic l10n, String filter) {
    switch (filter) {
      case 'pending':
        return l10n.myServiceApplicationsEmptyPending as String;
      case 'consulting':
        return l10n.myServiceApplicationsEmptyConsulting as String;
      case 'negotiating':
        return l10n.myServiceApplicationsEmptyNegotiating as String;
      case 'price_agreed':
        return l10n.myServiceApplicationsEmptyPriceAgreed as String;
      case 'approved':
        return l10n.myServiceApplicationsEmptyApproved as String;
      case 'rejected':
        return l10n.myServiceApplicationsEmptyRejected as String;
      case 'cancelled':
        return l10n.myServiceApplicationsEmptyCancelled as String;
      default:
        return l10n.myServiceApplicationsEmptyMessage as String;
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      side: BorderSide(
        color: selected ? AppColors.primary : Theme.of(context).dividerColor,
      ),
    );
  }
}

class _MyApplicationCard extends StatelessWidget {
  const _MyApplicationCard({
    required this.application,
    required this.isSubmitting,
  });

  final ServiceApplication application;
  final bool isSubmitting;

  String _statusLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (application.status) {
      ServiceApplicationStatus.pending => l10n.expertApplicationStatusPending,
      ServiceApplicationStatus.consulting =>
        l10n.expertApplicationStatusConsulting,
      ServiceApplicationStatus.negotiating =>
        l10n.expertApplicationStatusNegotiating,
      ServiceApplicationStatus.priceAgreed =>
        l10n.expertApplicationStatusPriceAgreed,
      ServiceApplicationStatus.approved => l10n.expertApplicationStatusApproved,
      ServiceApplicationStatus.rejected => l10n.expertApplicationStatusRejected,
      ServiceApplicationStatus.cancelled =>
        l10n.expertApplicationStatusCancelled,
      ServiceApplicationStatus.unknown => application.status.name,
    };
  }

  Color _statusColor() {
    return switch (application.status) {
      ServiceApplicationStatus.pending => AppColors.warning,
      ServiceApplicationStatus.consulting => AppColors.info,
      ServiceApplicationStatus.negotiating => AppColors.accent,
      ServiceApplicationStatus.priceAgreed => AppColors.primary,
      ServiceApplicationStatus.approved => AppColors.success,
      ServiceApplicationStatus.rejected => AppColors.error,
      ServiceApplicationStatus.cancelled => AppColors.textTertiaryLight,
      ServiceApplicationStatus.unknown => AppColors.textSecondaryLight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final serviceName = application.serviceName ?? '';
    final ownerName = application.ownerName ?? application.expertName ?? '';
    final message = application.applicationMessage;
    final negotiatedPrice = application.negotiatedPrice;
    final counterPrice = application.expertCounterPrice;
    final currency = application.currency;
    final statusColor = _statusColor();

    return GestureDetector(
      onTap: () => context.goToServiceDetail(application.serviceId),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(AppRadius.medium),
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (serviceName.isNotEmpty)
                          Text(
                            serviceName,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (ownerName.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                ownerName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.tiny),
                    ),
                    child: Text(
                      _statusLabel(context),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            // Price info
            if (negotiatedPrice != null || counterPrice != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    if (negotiatedPrice != null) ...[
                      Text(
                        '${l10n.expertApplicationPrice}: ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                      ),
                      Text(
                        '${Helpers.currencySymbolFor(currency)}${Helpers.formatAmountNumber(negotiatedPrice)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                      ),
                    ],
                    if (negotiatedPrice != null && counterPrice != null)
                      const SizedBox(width: AppSpacing.md),
                    if (counterPrice != null) ...[
                      Text(
                        '${l10n.expertApplicationCounterPrice}: ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                      ),
                      Text(
                        '${Helpers.currencySymbolFor(currency)}${Helpers.formatAmountNumber(counterPrice)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                      ),
                    ],
                  ],
                ),
              ),

            // Message
            if (message != null && message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.message_outlined,
                        size: 14,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Row(
                children: [
                  Icon(Icons.access_time,
                      size: 12,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.serviceApplicationCreatedAt(
                      DateFormatter.formatSmart(application.createdAt,
                          l10n: l10n),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                  ),
                  if (application.status == ServiceApplicationStatus.approved &&
                      application.approvedAt != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      l10n.serviceApplicationApprovedAt(
                        DateFormatter.formatSmart(application.approvedAt!,
                            l10n: l10n),
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: AppColors.success,
                          ),
                    ),
                  ],
                ],
              ),
            ),

            // Counter-offer response buttons
            if (application.canRespondCounterOffer) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () => _confirmRejectCounterOffer(context),
                        icon: const Icon(Icons.close, size: 16),
                        label: Text(l10n.serviceCounterOfferRejectConfirm,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () => _confirmAcceptCounterOffer(context),
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(l10n.serviceCounterOfferAcceptConfirm,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]
            // Cancel button
            else if (application.canCancel) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        isSubmitting ? null : () => _confirmCancel(context),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(l10n.serviceApplicationConfirmCancel),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
            ]
            // View task link
            else if (application.canViewTask) ...[
              const SizedBox(height: AppSpacing.xs),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final taskId = application.taskId;
                      if (taskId != null) context.goToTaskDetail(taskId);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(l10n.expertApplicationViewTask),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
            ] else
              const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _confirmAcceptCounterOffer(BuildContext context) {
    final l10n = context.l10n;
    final appId = application.id;
    final counterPrice = application.expertCounterPrice ?? 0;
    final currency = application.currency;
    final priceStr =
        '${Helpers.currencySymbolFor(currency)}${Helpers.formatAmountNumber(counterPrice)}';
    AppHaptics.light();

    AdaptiveDialogs.showConfirmDialog(
      context: context,
      title: l10n.serviceCounterOfferAcceptConfirm,
      content: l10n.serviceCounterOfferAcceptConfirmMessage(priceStr),
      // AUDIT-10: Explicit action label mirrors the reject-counter-offer dialog.
      confirmText: l10n.serviceCounterOfferAcceptConfirm,
      cancelText: l10n.commonCancel,
      onConfirm: () {
        context.read<PersonalServiceBloc>().add(
              PersonalServiceRespondCounterOffer(appId, accept: true),
            );
      },
    );
  }

  void _confirmRejectCounterOffer(BuildContext context) {
    final l10n = context.l10n;
    final appId = application.id;
    AppHaptics.light();

    AdaptiveDialogs.showConfirmDialog(
      context: context,
      title: l10n.serviceCounterOfferRejectConfirm,
      content: l10n.serviceCounterOfferRejectConfirmMessage,
      // AUDIT-10: Explicit action label so reject-counter-offer isn't confused
      // with cancel-application.
      confirmText: l10n.serviceCounterOfferRejectConfirm,
      cancelText: l10n.commonCancel,
      isDestructive: true,
      onConfirm: () {
        context.read<PersonalServiceBloc>().add(
              PersonalServiceRespondCounterOffer(appId, accept: false),
            );
      },
    );
  }

  void _confirmCancel(BuildContext context) {
    final l10n = context.l10n;
    final appId = application.id;
    AppHaptics.light();

    AdaptiveDialogs.showConfirmDialog(
      context: context,
      title: l10n.serviceApplicationConfirmCancel,
      content: l10n.serviceApplicationConfirmCancelMessage,
      // AUDIT-10: Explicit action label ("取消申请") rather than generic
      // "confirm/cancel" so the user knows which action fires.
      confirmText: l10n.serviceApplicationConfirmCancel,
      cancelText: l10n.commonCancel,
      isDestructive: true,
      onConfirm: () {
        context.read<PersonalServiceBloc>().add(
              PersonalServiceCancelApplication(appId),
            );
      },
    );
  }
}
