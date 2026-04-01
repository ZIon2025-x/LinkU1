import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/services/api_service.dart';
import '../../../task_expert/bloc/task_expert_bloc.dart';
import 'consultation_base.dart';

class FleaMarketConsultationActions extends ConsultationActions {
  FleaMarketConsultationActions({
    required super.applicationId,
    required super.taskId,
  });

  @override
  String get statusEndpoint =>
      ApiEndpoints.fleaMarketConsultStatus(applicationId);

  @override
  bool isApplicant(String? currentUserId, Map<String, dynamic>? consultationApp) {
    return currentUserId == consultationApp?['buyer_id']?.toString();
  }

  @override
  bool get needsApplicationIdInMessages => false;

  @override
  void handleNegotiationResponse(BuildContext context, String action) {
    context.read<TaskExpertBloc>().add(
      TaskExpertFleaMarketNegotiateResponse(applicationId, action: action),
    );
  }

  @override
  void showCounterOfferDialog(
    BuildContext context, {
    required String Function() getCurrencySymbol,
  }) {
    final priceController = TextEditingController();
    String? errorText;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.counterOffer),
          content: TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: context.l10n.counterOfferHint,
              prefixText: getCurrencySymbol(),
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () {
                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  setDialogState(() => errorText = context.l10n.counterOfferHint);
                  return;
                }
                Navigator.pop(dialogContext);
                context.read<TaskExpertBloc>().add(
                  TaskExpertFleaMarketNegotiateResponse(
                    applicationId,
                    action: 'counter',
                    counterPrice: price,
                  ),
                );
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildActions({
    required BuildContext context,
    required String? appStatus,
    required bool isSubmitting,
    required bool isApplicant,
    required String Function() getCurrencySymbol,
    required Map<String, dynamic>? consultationApp,
    required VoidCallback onActionCompleted,
  }) {
    final isConsulting = appStatus == 'consulting';
    final isNegotiating = appStatus == 'negotiating';
    final isPriceAgreed = appStatus == 'price_agreed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 买家：议价（consulting/negotiating）
            if (isApplicant && (isConsulting || isNegotiating)) ...[
              ActionPill(
                icon: Icons.local_offer,
                label: context.l10n.negotiatePrice,
                onTap: isSubmitting
                    ? null
                    : () => _showNegotiateDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            // 买家：购买（仅 consulting，negotiating 时不允许）
            if (isApplicant && isConsulting) ...[
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.fleaMarketBuyNow,
                onTap: isSubmitting
                    ? null
                    : () => _showFormalApplyDialog(context),
              ),
              const SizedBox(width: 8),
            ],
            if (!isApplicant && (isConsulting || isNegotiating)) ...[
              ActionPill(
                icon: Icons.request_quote,
                label: context.l10n.quotePrice,
                onTap: isSubmitting
                    ? null
                    : () => _showQuoteDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            if (isPriceAgreed && isApplicant) ...[
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.fleaMarketConfirmPurchase,
                onTap: isSubmitting
                    ? null
                    : () => _showFormalApplyDialog(context),
              ),
              const SizedBox(width: 8),
            ],
            if (appStatus == 'pending' && !isApplicant) ...[
              ActionPill(
                icon: Icons.check_circle,
                label: context.l10n.expertApplicationConfirmApprove,
                color: AppColors.success,
                onTap: isSubmitting
                    ? null
                    : () => _showApproveConfirmation(context, onActionCompleted),
              ),
              const SizedBox(width: 8),
            ],
            if (isConsulting || isNegotiating) ...[
              ActionPill(
                icon: Icons.close,
                label: context.l10n.closeConsultation,
                color: AppColors.error.withValues(alpha: 0.8),
                onTap: isSubmitting
                    ? null
                    : () => _showCloseConfirmation(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showNegotiateDialog(BuildContext context, String Function() getCurrencySymbol) {
    final priceController = TextEditingController();
    String? errorText;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.negotiatePrice),
          content: TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: context.l10n.negotiatePriceHint,
              prefixText: getCurrencySymbol(),
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () {
                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  setDialogState(() => errorText = context.l10n.negotiatePriceHint);
                  return;
                }
                Navigator.pop(dialogContext);
                context.read<TaskExpertBloc>().add(
                  TaskExpertFleaMarketNegotiate(applicationId, price: price),
                );
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuoteDialog(BuildContext context, String Function() getCurrencySymbol) {
    final priceController = TextEditingController();
    final messageController = TextEditingController();
    String? errorText;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.quotePrice),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: context.l10n.quotePriceHint,
                  prefixText: getCurrencySymbol(),
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.l10n.quoteMessageHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () {
                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  setDialogState(() => errorText = context.l10n.quotePriceHint);
                  return;
                }
                Navigator.pop(dialogContext);
                final msg = messageController.text.trim();
                context.read<TaskExpertBloc>().add(
                  TaskExpertFleaMarketQuote(
                    applicationId,
                    price: price,
                    message: msg.isNotEmpty ? msg : null,
                  ),
                );
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _showFormalApplyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.fleaMarketConfirmPurchase),
        content: Text(context.l10n.fleaMarketConfirmPurchaseMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<TaskExpertBloc>().add(
                TaskExpertFleaMarketFormalBuy(applicationId),
              );
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  void _showApproveConfirmation(BuildContext context, VoidCallback onActionCompleted) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.expertApplicationConfirmApprove),
        content: Text(context.l10n.expertApplicationConfirmApproveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _approveFleaMarketPurchase(context, onActionCompleted);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: Text(context.l10n.expertApplicationConfirmApprove),
          ),
        ],
      ),
    );
  }

  Future<void> _approveFleaMarketPurchase(BuildContext context, VoidCallback onActionCompleted) async {
    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.post<Map<String, dynamic>>(
        ApiEndpoints.fleaMarketApprovePurchaseRequest(applicationId.toString()),
      );
      if (!context.mounted) return;
      if (response.isSuccess) {
        onActionCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.expertApplicationApproved)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.localizeError(response.message ?? 'unknown_error'))),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizeError(e.toString()))),
      );
    }
  }

  void _showCloseConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.closeConsultation),
        content: Text(context.l10n.closeConsultationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<TaskExpertBloc>().add(
                TaskExpertCloseFleaMarketConsultation(applicationId),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }
}
