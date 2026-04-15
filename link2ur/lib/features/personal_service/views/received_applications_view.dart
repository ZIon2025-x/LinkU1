import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/router/go_router_extensions.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../data/repositories/personal_service_repository.dart';
import '../bloc/personal_service_bloc.dart';

/// 个人服务收到的申请管理页面
/// 服务所有者查看并处理收到的服务申请（同意/拒绝/议价）
class ReceivedApplicationsView extends StatelessWidget {
  const ReceivedApplicationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PersonalServiceBloc(
        repository: context.read<PersonalServiceRepository>(),
      )..add(const PersonalServiceLoadReceivedApplications()),
      child: const _ReceivedApplicationsContent(),
    );
  }
}

class _ReceivedApplicationsContent extends StatelessWidget {
  const _ReceivedApplicationsContent();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expertApplicationsTitle),
      ),
      body: BlocConsumer<PersonalServiceBloc, PersonalServiceState>(
        listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage,
        listener: (context, state) {
          if (state.actionMessage == null) return;
          final l10n = context.l10n;
          final msg = switch (state.actionMessage) {
            'application_approved' => l10n.expertApplicationApproved,
            'application_rejected' => l10n.expertApplicationRejected,
            'counter_offer_sent' => l10n.expertApplicationCounterOfferSent,
            'application_action_failed' => state.errorMessage != null
                ? context.localizeError(state.errorMessage)
                : l10n.expertApplicationActionFailed,
            _ => null,
          };
          if (msg != null) {
            final isError = state.actionMessage == 'application_action_failed';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: isError ? AppColors.error : AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final l10n = context.l10n;

          if (state.status == PersonalServiceStatus.loading &&
              state.receivedApplications.isEmpty) {
            return const SkeletonList();
          }

          if (state.status == PersonalServiceStatus.error &&
              state.receivedApplications.isEmpty) {
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
                    onPressed: () => context
                        .read<PersonalServiceBloc>()
                        .add(const PersonalServiceLoadReceivedApplications()),
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            );
          }

          if (state.receivedApplications.isEmpty) {
            return EmptyStateView(
              icon: Icons.inbox_outlined,
              title: l10n.expertApplicationsEmpty,
              message: l10n.expertApplicationsEmptyMessage,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<PersonalServiceBloc>();
              bloc.add(const PersonalServiceLoadReceivedApplications());
              await bloc.stream.firstWhere(
                (s) => s.status != PersonalServiceStatus.loading,
              );
            },
            child: ListView.separated(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: state.receivedApplications.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final app = state.receivedApplications[index];
                final appId = app['id'];
                final isThisSubmitting = state.isSubmitting &&
                    state.submittingApplicationId != null &&
                    state.submittingApplicationId == appId;
                return AnimatedListItem(
                  key: ValueKey(appId),
                  index: index,
                  maxAnimatedIndex: 11,
                  child: _ApplicationCard(
                    application: app,
                    isSubmitting: isThisSubmitting,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.isSubmitting,
  });

  final Map<String, dynamic> application;
  final bool isSubmitting;

  String _statusLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (application['status'] as String?) {
      'pending' => l10n.expertApplicationStatusPending,
      'negotiating' => l10n.expertApplicationStatusNegotiating,
      'price_agreed' => l10n.expertApplicationStatusPriceAgreed,
      'approved' => l10n.expertApplicationStatusApproved,
      'rejected' => l10n.expertApplicationStatusRejected,
      'cancelled' => l10n.expertApplicationStatusCancelled,
      _ => application['status']?.toString() ?? '',
    };
  }

  Color _statusColor() {
    return switch (application['status'] as String?) {
      'pending' => AppColors.warning,
      'negotiating' => AppColors.accent,
      'price_agreed' => AppColors.primary,
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      'cancelled' => AppColors.textTertiaryLight,
      _ => AppColors.textSecondaryLight,
    };
  }

  // Backend (user_service_application_routes.py):
  //   approve allowed in: pending, price_agreed
  //   reject  allowed in: pending, negotiating, price_agreed
  bool get _canApprove {
    final status = application['status'] as String?;
    return status == 'pending' || status == 'price_agreed';
  }

  bool get _canReject {
    final status = application['status'] as String?;
    return status == 'pending' ||
        status == 'negotiating' ||
        status == 'price_agreed';
  }

  bool get _canCounterOffer {
    final status = application['status'] as String?;
    return status == 'pending' || status == 'negotiating';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final applicantName =
        application['applicant_name'] as String? ?? 'Unknown';
    final serviceName =
        application['service_name'] as String? ?? '';
    final message =
        application['application_message'] as String?;
    final negotiatedPrice = application['negotiated_price'];
    final expertCounterPrice = application['expert_counter_price'];
    final statusColor = _statusColor();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
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
          // Header with status badge
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
                            applicantName,
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
          if (negotiatedPrice != null || expertCounterPrice != null)
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
                      '${Helpers.currencySymbolFor(application['currency'] as String? ?? 'GBP')}${_formatPrice(negotiatedPrice)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                    ),
                  ],
                  if (negotiatedPrice != null && expertCounterPrice != null)
                    const SizedBox(width: AppSpacing.md),
                  if (expertCounterPrice != null) ...[
                    Text(
                      '${l10n.expertApplicationCounterPrice}: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                    ),
                    Text(
                      '${Helpers.currencySymbolFor(application['currency'] as String? ?? 'GBP')}${_formatPrice(expertCounterPrice)}',
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

          // Action buttons
          if (_canReject || _canApprove || _canCounterOffer) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  if (_canCounterOffer)
                    Expanded(
                      child: _ActionButton(
                        label: l10n.expertApplicationCounterOffer,
                        icon: Icons.price_change_outlined,
                        color: AppColors.accent,
                        isSubmitting: isSubmitting,
                        onPressed: () =>
                            _showCounterOfferDialog(context),
                      ),
                    ),
                  if (_canCounterOffer && _canReject)
                    const SizedBox(width: AppSpacing.sm),
                  if (_canReject)
                    Expanded(
                      child: _ActionButton(
                        label: l10n.expertApplicationReject,
                        icon: Icons.close,
                        color: AppColors.error,
                        isSubmitting: isSubmitting,
                        onPressed: () =>
                            _showRejectDialog(context),
                      ),
                    ),
                  if (_canApprove) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ActionButton(
                        label: l10n.expertApplicationApprove,
                        icon: Icons.check,
                        color: AppColors.success,
                        isSubmitting: isSubmitting,
                        onPressed: () =>
                            _showApproveConfirmation(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            if (application['status'] == 'approved' &&
                application['task_id'] != null) ...[
              const SizedBox(height: AppSpacing.xs),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final rawId = application['task_id'];
                      final taskId =
                          rawId is int ? rawId : int.tryParse(rawId.toString());
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
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num p = price is num ? price : num.tryParse(price.toString()) ?? 0;
    return Helpers.formatAmountNumber(p);
  }

  void _showApproveConfirmation(BuildContext context) {
    final l10n = context.l10n;
    final appId = application['id'] as int;
    AppHaptics.light();

    AdaptiveDialogs.showConfirmDialog(
      context: context,
      title: l10n.expertApplicationConfirmApprove,
      content: l10n.expertApplicationConfirmApproveMessage,
      confirmText: l10n.expertApplicationApprove,
      cancelText: l10n.commonCancel,
      onConfirm: () {
        context
            .read<PersonalServiceBloc>()
            .add(PersonalServiceApproveApplication(appId));
      },
    );
  }

  void _showRejectDialog(BuildContext context) async {
    final l10n = context.l10n;
    final appId = application['id'] as int;
    AppHaptics.light();

    final reason = await AdaptiveDialogs.showInputDialog(
      context: context,
      title: l10n.expertApplicationConfirmReject,
      message: l10n.expertApplicationConfirmRejectMessage,
      placeholder: l10n.expertApplicationRejectReasonHint,
      maxLines: 3,
      confirmText: l10n.expertApplicationReject,
      cancelText: l10n.commonCancel,
    );
    if (reason != null && context.mounted) {
      context.read<PersonalServiceBloc>().add(
            PersonalServiceRejectApplication(
              appId,
              reason: reason.trim().isNotEmpty ? reason.trim() : null,
            ),
          );
    }
  }

  void _showCounterOfferDialog(BuildContext context) {
    final l10n = context.l10n;
    final appId = application['id'] as int;
    final priceController = TextEditingController();
    final messageController = TextEditingController();
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    AppHaptics.light();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final counterOfferContent = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isIOS
                ? CupertinoTextField(
                    controller: priceController,
                    placeholder: l10n.expertApplicationCounterPriceHint,
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('${Helpers.currencySymbolFor(application['currency'] as String? ?? 'GBP')} '),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  )
                : TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: l10n.expertApplicationCounterPrice,
                      hintText: l10n.expertApplicationCounterPriceHint,
                      prefixText: '${Helpers.currencySymbolFor(application['currency'] as String? ?? 'GBP')} ',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
            const SizedBox(height: AppSpacing.md),
            isIOS
                ? CupertinoTextField(
                    controller: messageController,
                    placeholder: l10n.expertApplicationCounterMessageHint,
                    maxLines: 3,
                  )
                : TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      labelText: l10n.expertApplicationCounterMessage,
                      hintText: l10n.expertApplicationCounterMessageHint,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
          ],
        );

        if (isIOS) {
          return CupertinoAlertDialog(
            title: Text(l10n.expertApplicationCounterOffer),
            content: counterOfferContent,
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonCancel),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  final price = double.tryParse(priceController.text.trim());
                  if (price == null || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(l10n.fleaMarketNegotiatePriceTooLow)),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  context.read<PersonalServiceBloc>().add(
                        PersonalServiceCounterOffer(
                          appId,
                          counterPrice: price,
                          message: messageController.text.trim().isNotEmpty
                              ? messageController.text.trim()
                              : null,
                        ),
                      );
                },
                child: Text(l10n.commonConfirm),
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(l10n.expertApplicationCounterOffer),
          content: counterOfferContent,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(l10n.fleaMarketNegotiatePriceTooLow)),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop();
                context.read<PersonalServiceBloc>().add(
                      PersonalServiceCounterOffer(
                        appId,
                        counterPrice: price,
                        message: messageController.text.trim().isNotEmpty
                            ? messageController.text.trim()
                            : null,
                      ),
                    );
              },
              child: Text(l10n.commonConfirm),
            ),
          ],
        );
      },
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 300), () {
        priceController.dispose();
        messageController.dispose();
      });
    });
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSubmitting,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isSubmitting ? null : onPressed,
      icon: isSubmitting
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          : Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
