import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/repositories/personal_service_repository.dart';
import '../bloc/personal_service_bloc.dart';

/// "我的服务" — lists the current user's personal services with CRUD actions.
class MyServicesView extends StatelessWidget {
  const MyServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PersonalServiceBloc>(
      create: (context) => PersonalServiceBloc(
        repository: context.read<PersonalServiceRepository>(),
      )..add(const PersonalServiceLoadRequested()),
      child: const _MyServicesBody(),
    );
  }
}

class _MyServicesBody extends StatelessWidget {
  const _MyServicesBody();

  @override
  Widget build(BuildContext context) {
    return BlocListener<PersonalServiceBloc, PersonalServiceState>(
      listenWhen: (prev, curr) =>
          prev.actionMessage != curr.actionMessage &&
          curr.actionMessage != null,
      listener: (context, state) {
        final msg = state.actionMessage;
        if (msg == null) return;
        final l10n = context.l10n;
        final text = switch (msg) {
          'service_activated' => l10n.serviceStatusActivated,
          'service_deactivated' => l10n.serviceStatusDeactivated,
          'toggle_status_failed' => l10n.serviceStatusToggleFailed,
          _ => context.localizeError(msg),
        };
        final isError = msg.contains('failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            backgroundColor: isError ? AppColors.error : null,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.profileMyServices),
          actions: [
            IconButton(
              icon: const Icon(Icons.explore_outlined),
              tooltip: context.l10n.browseServicesTitle,
              onPressed: () => context.push('/services/browse'),
            ),
            IconButton(
              icon: const Icon(Icons.inbox_outlined),
              tooltip: context.l10n.expertApplicationsTitle,
              onPressed: () => context.push('/services/my/applications'),
            ),
          ],
        ),
        body: BlocBuilder<PersonalServiceBloc, PersonalServiceState>(
          buildWhen: (prev, curr) =>
              prev.services != curr.services || prev.status != curr.status,
          builder: (context, state) {
            // Loading skeleton
            if ((state.status == PersonalServiceStatus.initial ||
                    state.status == PersonalServiceStatus.loading) &&
                state.services.isEmpty) {
              return const _LoadingSkeleton();
            }

            // Error with retry
            if (state.status == PersonalServiceStatus.error &&
                state.services.isEmpty) {
              return ErrorStateView(
                message: context.localizeError(
                  state.errorMessage ?? 'personal_service_load_failed',
                ),
                onRetry: () => context
                    .read<PersonalServiceBloc>()
                    .add(const PersonalServiceLoadRequested()),
              );
            }

            // Empty state
            if (state.services.isEmpty) {
              return _EmptyServicesView(
                onCreateTap: () async {
                  final result = await context.push('/services/create');
                  if (result == true && context.mounted) {
                    context.read<PersonalServiceBloc>().add(const PersonalServiceLoadRequested());
                  }
                },
              );
            }

            // Loaded list with pull-to-refresh
            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<PersonalServiceBloc>()
                    .add(const PersonalServiceLoadRequested());
                // Wait for the bloc to finish loading
                await context
                    .read<PersonalServiceBloc>()
                    .stream
                    .firstWhere((s) =>
                        s.status != PersonalServiceStatus.loading);
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  100,
                ),
                itemCount: state.services.length,
                itemBuilder: (context, index) {
                  final service = state.services[index];
                  return Padding(
                    key: ValueKey(service['id']),
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ServiceCard(
                      service: service,
                      onTap: () => context.push('/service/${service['id']}'),
                      onEdit: () async {
                        final result = await context.push(
                          '/services/edit/${service['id']}',
                          extra: service,
                        );
                        if (result == true && context.mounted) {
                          context.read<PersonalServiceBloc>().add(const PersonalServiceLoadRequested());
                        }
                      },
                      onDelete: () => _confirmDelete(context, service),
                      onToggleStatus: () {
                        context.read<PersonalServiceBloc>().add(
                              PersonalServiceToggleStatus(
                                service['id']?.toString() ?? '',
                              ),
                            );
                      },
                      onViewReviews: () {
                        final id = service['id'];
                        context.push(
                          '/services/$id/reviews',
                          extra: {'serviceName': service['service_name']},
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await context.push('/services/create');
            if (result == true && context.mounted) {
              context.read<PersonalServiceBloc>().add(const PersonalServiceLoadRequested());
            }
          },
          tooltip: context.l10n.expertServiceCreate,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Map<String, dynamic> service,
  ) async {
    final confirmed = await AdaptiveDialogs.showConfirmDialog<bool>(
      context: context,
      title: context.l10n.expertServiceConfirmDelete,
      content: context.l10n.expertServiceConfirmDeleteMessage,
      isDestructive: true,
      onConfirm: () => true,
    );
    if (confirmed == true && context.mounted) {
      context.read<PersonalServiceBloc>().add(
            PersonalServiceDeleteRequested(service['id']?.toString() ?? ''),
          );
    }
  }
}

// =============================================================================
// Loading skeleton
// =============================================================================

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.allMedium,
              side: BorderSide(color: baseColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Thumbnail placeholder
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: AppRadius.allSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: AppRadius.allTiny,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: AppRadius.allTiny,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          height: 10,
                          width: 50,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: AppRadius.allTiny,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyServicesView extends StatelessWidget {
  const _EmptyServicesView({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.handyman_outlined,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.expertServicesEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.expertServicesEmptyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.expertServiceCreate),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Service card
// =============================================================================

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onToggleStatus,
    this.onViewReviews,
  });

  final Map<String, dynamic> service;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onViewReviews;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (service['service_name'] as String?) ?? '';
    final price = (service['base_price'] as num?)?.toDouble() ?? 0.0;
    final currency = (service['currency'] as String?) ?? 'GBP';
    final pricingType = (service['pricing_type'] as String?) ?? 'fixed';
    final status = (service['status'] as String?) ?? 'pending';
    final images = service['images'] as List<dynamic>?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.allMedium,
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.allMedium,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Thumbnail
              _ServiceThumbnail(images: images),
              const SizedBox(width: AppSpacing.md),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text(
                          '$currency ${price.toStringAsFixed(2)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _PricingTypeBadge(pricingType: pricingType),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _StatusBadge(status: status),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'toggle') onToggleStatus?.call();
                  if (value == 'reviews') onViewReviews?.call();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(
                        status == 'active'
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      title: Text(
                        status == 'active'
                            ? context.l10n.serviceStatusDeactivate
                            : context.l10n.serviceStatusActivate,
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reviews',
                    child: ListTile(
                      leading: const Icon(Icons.rate_review_outlined),
                      title: Text(context.l10n.serviceReviewTitle),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(context.l10n.commonEdit),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        context.l10n.commonDelete,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Thumbnail with image preview
// =============================================================================

class _ServiceThumbnail extends StatelessWidget {
  const _ServiceThumbnail({this.images});

  final List<dynamic>? images;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstImage =
        (images != null && images!.isNotEmpty) ? images!.first as String? : null;

    return ClipRRect(
      borderRadius: AppRadius.allSmall,
      child: Container(
        width: 60,
        height: 60,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        child: firstImage != null
            ? Stack(
                children: [
                  Image.network(
                    firstImage,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.handyman_outlined,
                      size: 28,
                      color: AppColors.primary,
                    ),
                  ),
                  // Image count badge
                  if (images != null && images!.length > 1)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: AppRadius.allTiny,
                        ),
                        child: Text(
                          '${images!.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : const Icon(
                Icons.handyman_outlined,
                size: 28,
                color: AppColors.primary,
              ),
      ),
    );
  }
}

// =============================================================================
// Pricing type badge
// =============================================================================

class _PricingTypeBadge extends StatelessWidget {
  const _PricingTypeBadge({required this.pricingType});

  final String pricingType;

  @override
  Widget build(BuildContext context) {
    final label = switch (pricingType) {
      'fixed' => context.l10n.personalServicePricingFixed,
      'hourly' => context.l10n.personalServicePricingHourly,
      'negotiable' => context.l10n.personalServicePricingNegotiable,
      _ => pricingType,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.allTiny,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// =============================================================================
// Status badge
// =============================================================================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => (context.l10n.expertServiceStatusActive, AppColors.success),
      'pending' => (
          context.l10n.expertServiceStatusPending,
          AppColors.warning,
        ),
      'rejected' => (
          context.l10n.expertServiceStatusRejected,
          AppColors.error,
        ),
      'inactive' => (
          context.l10n.expertServiceStatusInactive,
          AppColors.textSecondaryLight,
        ),
      _ => (status, AppColors.textSecondaryLight),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.allSmall,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
