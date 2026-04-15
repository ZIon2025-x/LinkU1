import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/models/task_expert.dart';
import '../../../../data/repositories/task_expert_repository.dart';
import '../../../task_expert/bloc/task_expert_bloc.dart';
import 'consultation_base.dart';

class ServiceConsultationActions extends ConsultationActions {
  ServiceConsultationActions({
    required super.applicationId,
    required super.taskId,
  });

  @override
  String get statusEndpoint =>
      ApiEndpoints.consultationStatus(applicationId);

  @override
  bool isApplicant(String? currentUserId, Map<String, dynamic>? consultationApp) {
    return currentUserId == consultationApp?['applicant_id']?.toString();
  }

  @override
  bool get needsApplicationIdInMessages => false;

  @override
  void handleNegotiationResponse(BuildContext context, String action, {int? serviceId}) {
    context.read<TaskExpertBloc>().add(
      TaskExpertNegotiateResponse(applicationId, action: action, serviceId: serviceId),
    );
  }

  @override
  Future<void> showCounterOfferDialog(
    BuildContext context, {
    required String Function() getCurrencySymbol,
    String? expertId,
  }) async {
    // Pre-fetch services for team consultation
    List<TaskExpertService>? services;
    if (expertId != null) {
      try {
        services = await context.read<TaskExpertRepository>().getExpertServices(expertId);
      } catch (_) {
        services = [];
      }
    }

    if (!context.mounted) return;
    final priceController = TextEditingController();
    final bloc = context.read<TaskExpertBloc>();
    String? errorText;
    int? selectedServiceId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.counterOffer),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (expertId != null && services != null && services.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  initialValue: selectedServiceId,
                  decoration: InputDecoration(
                    labelText: context.l10n.consultationSelectService,
                  ),
                  items: services.map((s) => DropdownMenuItem<int>(
                    value: s.id,
                    child: Text(s.serviceName, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedServiceId = v),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: context.l10n.counterOfferHint,
                  prefixText: getCurrencySymbol(),
                  errorText: errorText,
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
                if (expertId != null && services != null && services.isNotEmpty && selectedServiceId == null) {
                  setDialogState(() => errorText = context.l10n.consultationSelectServiceHint);
                  return;
                }
                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  setDialogState(() => errorText = context.l10n.counterOfferHint);
                  return;
                }
                Navigator.pop(dialogContext);
                bloc.add(
                  TaskExpertNegotiateResponse(
                    applicationId,
                    action: 'counter',
                    counterPrice: price,
                    serviceId: selectedServiceId,
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

    // Team consultation: service_id is null on the application
    final expertId = (consultationApp != null && consultationApp['service_id'] == null)
        ? consultationApp['new_expert_id'] as String?
        : null;
    // 只有 owner/admin 能报价（后端返回 can_quote）
    final canQuote = consultationApp?['can_quote'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 申请方：议价（consulting/negotiating）
            if (isApplicant && (isConsulting || isNegotiating)) ...[
              ActionPill(
                icon: Icons.local_offer,
                label: context.l10n.negotiatePrice,
                onTap: isSubmitting
                    ? null
                    : () => _showNegotiateDialog(context, getCurrencySymbol, expertId: expertId),
              ),
              const SizedBox(width: 8),
            ],
            // 申请方：正式申请（仅 consulting，negotiating 时不允许；团队咨询无正式申请）
            if (isApplicant && isConsulting && expertId == null) ...[
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.formalApply,
                onTap: isSubmitting
                    ? null
                    : () => _showFormalApplyDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            if (canQuote && (isConsulting || isNegotiating)) ...[
              ActionPill(
                icon: Icons.request_quote,
                label: context.l10n.quotePrice,
                onTap: isSubmitting
                    ? null
                    : () => _showQuoteDialog(context, getCurrencySymbol, expertId: expertId),
              ),
              const SizedBox(width: 8),
            ],
            // 价格已确认时：正式申请（团队咨询无正式申请）
            if (isPriceAgreed && isApplicant && expertId == null) ...[
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.formalApply,
                onTap: isSubmitting
                    ? null
                    : () => _showFormalApplyDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            if (appStatus == 'pending' && canQuote) ...[
              ActionPill(
                icon: Icons.check_circle,
                label: context.l10n.expertApplicationConfirmApprove,
                color: AppColors.success,
                onTap: isSubmitting
                    ? null
                    : () => _showApproveConfirmation(context, consultationApp),
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

  Future<void> _showNegotiateDialog(
    BuildContext context,
    String Function() getCurrencySymbol, {
    String? expertId,
  }) async {
    // Pre-fetch services for team consultation
    List<TaskExpertService>? services;
    if (expertId != null) {
      try {
        services = await context.read<TaskExpertRepository>().getExpertServices(expertId);
      } catch (_) {
        services = [];
      }
    }

    if (!context.mounted) return;
    final priceController = TextEditingController();
    final bloc = context.read<TaskExpertBloc>();
    String? errorText;
    int? selectedServiceId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.negotiatePrice),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (expertId != null && services != null && services.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  initialValue: selectedServiceId,
                  decoration: InputDecoration(
                    labelText: context.l10n.consultationSelectService,
                  ),
                  items: services.map((s) => DropdownMenuItem<int>(
                    value: s.id,
                    child: Text(s.serviceName, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedServiceId = v),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: context.l10n.negotiatePriceHint,
                  prefixText: getCurrencySymbol(),
                  errorText: errorText,
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
                if (expertId != null && services != null && services.isNotEmpty && selectedServiceId == null) {
                  setDialogState(() => errorText = context.l10n.consultationSelectServiceHint);
                  return;
                }
                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  setDialogState(() => errorText = context.l10n.negotiatePriceHint);
                  return;
                }
                Navigator.pop(dialogContext);
                bloc.add(
                  TaskExpertNegotiatePrice(applicationId, price: price, serviceId: selectedServiceId),
                );
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuoteDialog(
    BuildContext context,
    String Function() getCurrencySymbol, {
    String? expertId,
  }) async {
    // Pre-fetch services for team consultation
    List<TaskExpertService>? services;
    if (expertId != null) {
      try {
        services = await context.read<TaskExpertRepository>().getExpertServices(expertId);
      } catch (_) {
        services = [];
      }
    }

    if (!context.mounted) return;
    final priceController = TextEditingController();
    final messageController = TextEditingController();
    final bloc = context.read<TaskExpertBloc>();
    String? errorText;
    int? selectedServiceId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.quotePrice),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (expertId != null && services != null && services.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  initialValue: selectedServiceId,
                  decoration: InputDecoration(
                    labelText: context.l10n.consultationSelectService,
                  ),
                  items: services.map((s) => DropdownMenuItem<int>(
                    value: s.id,
                    child: Text(s.serviceName, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedServiceId = v),
                ),
                const SizedBox(height: 12),
              ],
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
                if (expertId != null && services != null && services.isNotEmpty && selectedServiceId == null) {
                  setDialogState(() => errorText = context.l10n.consultationSelectServiceHint);
                  return;
                }
                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  setDialogState(() => errorText = context.l10n.quotePriceHint);
                  return;
                }
                final msg = messageController.text.trim();
                Navigator.pop(dialogContext);
                bloc.add(
                  TaskExpertQuotePrice(
                    applicationId,
                    price: price,
                    message: msg.isNotEmpty ? msg : null,
                    serviceId: selectedServiceId,
                  ),
                );
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      priceController.dispose();
      messageController.dispose();
    });
  }

  void _showFormalApplyDialog(BuildContext context, String Function() getCurrencySymbol) {
    final priceController = TextEditingController();
    final messageController = TextEditingController();
    final bloc = context.read<TaskExpertBloc>();
    String? errorText;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.formalApply),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: context.l10n.negotiatePriceHint,
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
                  setDialogState(() => errorText = context.l10n.negotiatePriceHint);
                  return;
                }
                final msg = messageController.text.trim();
                Navigator.pop(dialogContext);
                bloc.add(
                  TaskExpertFormalApply(
                    applicationId,
                    proposedPrice: price,
                    message: msg.isNotEmpty ? msg : null,
                  ),
                );
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      priceController.dispose();
      messageController.dispose();
    });
  }

  void _showApproveConfirmation(BuildContext context, Map<String, dynamic>? consultationApp) {
    final bloc = context.read<TaskExpertBloc>();
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
              final expertId = consultationApp?['expert_id'];
              if (expertId != null) {
                bloc.add(TaskExpertApproveApplication(applicationId));
              } else {
                bloc.add(TaskExpertOwnerApproveApplication(applicationId));
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: Text(context.l10n.expertApplicationConfirmApprove),
          ),
        ],
      ),
    );
  }

  void _showCloseConfirmation(BuildContext context) {
    final bloc = context.read<TaskExpertBloc>();
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
              bloc.add(TaskExpertCloseConsultation(applicationId));
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }
}
