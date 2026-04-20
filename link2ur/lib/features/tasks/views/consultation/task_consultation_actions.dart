import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../task_expert/bloc/task_expert_bloc.dart';
import '../../bloc/task_detail_bloc.dart';
import 'consultation_base.dart';

class TaskConsultationActions extends ConsultationActions {
  TaskConsultationActions({
    required super.applicationId,
    required super.taskId,
  });

  @override
  String get statusEndpoint =>
      ApiEndpoints.taskConsultStatus(taskId, applicationId);

  @override
  bool isApplicant(String? currentUserId, Map<String, dynamic>? consultationApp) {
    return currentUserId == consultationApp?['applicant_id']?.toString();
  }

  @override
  bool get needsApplicationIdInMessages => true;

  @override
  void handleNegotiationResponse(BuildContext context, String action, {int? serviceId}) {
    context.read<TaskExpertBloc>().add(
      TaskExpertTaskNegotiateResponse(taskId, applicationId, action: action),
    );
  }

  @override
  void onNegotiate(
    BuildContext context, {
    required double price,
    int? serviceId,
  }) {
    context.read<TaskExpertBloc>().add(
      TaskExpertTaskNegotiate(taskId, applicationId, price: price),
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
      TaskExpertTaskQuote(
        taskId, applicationId,
        price: price,
        message: message,
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
      TaskExpertTaskNegotiateResponse(
        taskId, applicationId,
        action: 'counter',
        counterPrice: price,
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
      TaskExpertTaskFormalApply(
        taskId, applicationId,
        proposedPrice: price,
        message: message,
      ),
    );
  }

  @override
  void onApprove(
    BuildContext context, {
    Map<String, dynamic>? consultationApp,
  }) {
    // Task 审批走 TaskDetailBloc（页面级 bloc）
    context.read<TaskDetailBloc>().add(TaskDetailAcceptApplicant(applicationId));
  }

  @override
  void onClose(BuildContext context) {
    context.read<TaskExpertBloc>().add(
      TaskExpertCloseTaskConsultation(taskId, applicationId),
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
    // 后端 consult-status 返回 can_formal_apply=false 时,表示 applicant
    // 在原任务上已有活跃申请(发布者代理发起的咨询就是这种情况),
    // 按"正式申请"会被后端拒,UI 应隐藏按钮。
    final canFormalApply = consultationApp?['can_formal_apply'] != false;

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
                    : () => showNegotiateDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            // 申请方：正式申请（仅 consulting，negotiating 时不允许；
            // 已在原任务 pending 的发布者代理场景下 canFormalApply=false,隐藏）
            if (isApplicant && isConsulting && canFormalApply) ...[
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.formalApply,
                onTap: isSubmitting
                    ? null
                    : () => showFormalApplyDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            if (!isApplicant && (isConsulting || isNegotiating)) ...[
              ActionPill(
                icon: Icons.request_quote,
                label: context.l10n.quotePrice,
                onTap: isSubmitting
                    ? null
                    : () => showQuoteDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            // price_agreed: 申请方可正式申请(同样受 canFormalApply 约束)
            if (isPriceAgreed && isApplicant && canFormalApply) ...[
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.formalApply,
                onTap: isSubmitting
                    ? null
                    : () => showFormalApplyDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            // pending: 发布方可审批（后端只接受 pending 状态）
            if (appStatus == 'pending' && !isApplicant) ...[
              ActionPill(
                icon: Icons.check_circle,
                label: context.l10n.expertApplicationConfirmApprove,
                color: AppColors.success,
                onTap: isSubmitting
                    ? null
                    : () => showApproveConfirmation(context),
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
