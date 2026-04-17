import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/utils/l10n_extension.dart';
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
  void handleNegotiationResponse(BuildContext context, String action, {int? serviceId}) {
    context.read<TaskExpertBloc>().add(
      TaskExpertFleaMarketNegotiateResponse(applicationId, action: action),
    );
  }

  @override
  void onNegotiate(
    BuildContext context, {
    required double price,
    int? serviceId,
  }) {
    context.read<TaskExpertBloc>().add(
      TaskExpertFleaMarketNegotiate(applicationId, price: price),
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
      TaskExpertFleaMarketQuote(
        applicationId,
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
      TaskExpertFleaMarketNegotiateResponse(
        applicationId,
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
    // 闲置物品只需确认购买，不需要价格/消息（此方法仅供基类 dialog 调用，
    // 但因 FleaMarket override 了 showFormalApplyDialog 为纯确认弹窗，
    // 所以价格参数被忽略）
    context.read<TaskExpertBloc>().add(
      TaskExpertFleaMarketFormalBuy(applicationId),
    );
  }

  @override
  void onApprove(
    BuildContext context, {
    Map<String, dynamic>? consultationApp,
  }) {
    context.read<TaskExpertBloc>().add(
      TaskExpertApproveFleaMarketPurchase(applicationId),
    );
  }

  @override
  void onClose(BuildContext context) {
    context.read<TaskExpertBloc>().add(
      TaskExpertCloseFleaMarketConsultation(applicationId),
    );
  }

  /// FleaMarket 的"正式申请"是纯确认购买弹窗（无价格/消息表单），
  /// 与 Service/Task 的带表单弹窗不同，因此 override 父类默认实现。
  @override
  Future<void> showFormalApplyDialog(
    BuildContext context,
    String Function() getCurrencySymbol,
  ) async {
    await showDialog(
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
              onFormalApply(context);
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
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
                    : () => showNegotiateDialog(context, getCurrencySymbol),
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
            if (isPriceAgreed && isApplicant) ...[
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.fleaMarketConfirmPurchase,
                onTap: isSubmitting
                    ? null
                    : () => showFormalApplyDialog(context, getCurrencySymbol),
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
