import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/utils/l10n_extension.dart';
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
  void onNegotiate(
    BuildContext context, {
    required double price,
    int? serviceId,
  }) {
    context.read<TaskExpertBloc>().add(
      TaskExpertNegotiatePrice(applicationId, price: price, serviceId: serviceId),
    );
  }

  @override
  void onQuote(
    BuildContext context, {
    required double price,
    String? message,
    int? serviceId,
  }) {
    context.read<TaskExpertBloc>().add(
      TaskExpertQuotePrice(
        applicationId,
        price: price,
        message: message,
        serviceId: serviceId,
      ),
    );
  }

  @override
  void onCounterOffer(
    BuildContext context, {
    required double price,
    int? serviceId,
  }) {
    context.read<TaskExpertBloc>().add(
      TaskExpertNegotiateResponse(
        applicationId,
        action: 'counter',
        counterPrice: price,
        serviceId: serviceId,
      ),
    );
  }

  @override
  void onFormalApply(
    BuildContext context, {
    double? price,
    String? message,
  }) {
    context.read<TaskExpertBloc>().add(
      TaskExpertFormalApply(
        applicationId,
        proposedPrice: price,
        message: message,
      ),
    );
  }

  /// 申请方在 price_agreed 下确认订单并进入付款（仅团队咨询）
  void onPayAndFinalize(BuildContext context) {
    context.read<TaskExpertBloc>().add(
      TaskExpertPayAndFinalize(applicationId),
    );
  }

  Future<void> _showConfirmPayDialog(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmAndPay),
        content: Text(l10n.confirmAndPayHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      onPayAndFinalize(context);
    }
  }

  @override
  void onApprove(
    BuildContext context, {
    Map<String, dynamic>? consultationApp,
  }) {
    final bloc = context.read<TaskExpertBloc>();
    final expertId = consultationApp?['expert_id'];
    if (expertId != null) {
      bloc.add(TaskExpertApproveApplication(applicationId));
    } else {
      bloc.add(TaskExpertOwnerApproveApplication(applicationId));
    }
  }

  @override
  void onClose(BuildContext context) {
    context.read<TaskExpertBloc>().add(TaskExpertCloseConsultation(applicationId));
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
                    : () => showNegotiateDialog(context, getCurrencySymbol, expertId: expertId),
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
                    : () => showFormalApplyDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            // 报价按钮对 owner 可见：consulting / negotiating 以及 pending 状态。
            // 加入 pending: 议价服务 + 无基础价的申请会在 approve 时被后端 400
            // 拒绝 (approval_price_not_set_negotiable)，此时 owner 必须先通过
            // Quote Price 发送还价，否则无下一步路径。
            if (canQuote && (isConsulting || isNegotiating || appStatus == 'pending')) ...[
              ActionPill(
                icon: Icons.request_quote,
                label: context.l10n.quotePrice,
                onTap: isSubmitting
                    ? null
                    : () => showQuoteDialog(context, getCurrencySymbol, expertId: expertId),
              ),
              const SizedBox(width: 8),
            ],
            // 价格已确认时：申请方确认订单并付款(团队 + 个人统一路径,后端 pay-and-finalize 创建订单 + PaymentIntent)
            if (isPriceAgreed && isApplicant) ...[
              ActionPill(
                icon: Icons.payment,
                label: context.l10n.confirmAndPay,
                color: AppColors.success,
                onTap: isSubmitting
                    ? null
                    : () => _showConfirmPayDialog(context),
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
                    : () => showApproveConfirmation(context, consultationApp: consultationApp),
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
                    : () => showCloseConfirmation(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
