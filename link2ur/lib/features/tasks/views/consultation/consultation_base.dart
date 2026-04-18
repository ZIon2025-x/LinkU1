import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/models/task_expert.dart';
import '../../../../data/repositories/task_expert_repository.dart';
import 'service_consultation_actions.dart';
import 'task_consultation_actions.dart';
import 'flea_market_consultation_actions.dart';

/// 咨询类型枚举
enum ConsultationType { service, task, fleaMarket }

/// 咨询操作抽象接口
abstract class ConsultationActions {
  ConsultationActions({
    required this.applicationId,
    required this.taskId,
  });

  final int applicationId;
  final int taskId;

  /// 工厂方法 — 根据类型返回对应实现
  factory ConsultationActions.of({
    required ConsultationType type,
    required int applicationId,
    required int taskId,
  }) {
    switch (type) {
      case ConsultationType.service:
        return ServiceConsultationActions(
          applicationId: applicationId,
          taskId: taskId,
        );
      case ConsultationType.task:
        return TaskConsultationActions(
          applicationId: applicationId,
          taskId: taskId,
        );
      case ConsultationType.fleaMarket:
        return FleaMarketConsultationActions(
          applicationId: applicationId,
          taskId: taskId,
        );
    }
  }

  /// API endpoint: 加载咨询状态
  String get statusEndpoint;

  /// 判断当前用户是否为申请方
  bool isApplicant(String? currentUserId, Map<String, dynamic>? consultationApp);

  /// 消息加载/发送时是否需要 application_id 参数
  bool get needsApplicationIdInMessages;

  /// 构建操作按钮栏
  Widget buildActions({
    required BuildContext context,
    required String? appStatus,
    required bool isSubmitting,
    required bool isApplicant,
    required String Function() getCurrencySymbol,
    required Map<String, dynamic>? consultationApp,
    required VoidCallback onActionCompleted,
  });

  /// 处理议价回复（接受/拒绝/还价）
  void handleNegotiationResponse(BuildContext context, String action, {int? serviceId});

  // ---------------------------------------------------------------------------
  // Abstract action dispatchers — subclasses implement per-type bloc calls
  // ---------------------------------------------------------------------------

  /// 议价 — 申请方提出期望价格
  void onNegotiate(
    BuildContext context, {
    required double price,
    int? serviceId,
  });

  /// 报价 — 发布方/Owner 报价
  void onQuote(
    BuildContext context, {
    required double price,
    String? message,
    int? serviceId,
  });

  /// 还价 — 双方任一方在议价中还价
  void onCounterOffer(
    BuildContext context, {
    required double price,
    int? serviceId,
  });

  /// 正式申请 — 申请方提交最终申请（FleaMarket 里相当于"确认购买"）
  void onFormalApply(
    BuildContext context, {
    double? price,
    String? message,
  });

  /// 批准 — 发布方同意正式申请
  void onApprove(
    BuildContext context, {
    Map<String, dynamic>? consultationApp,
  });

  /// 关闭咨询
  void onClose(BuildContext context);

  // ---------------------------------------------------------------------------
  // Shared dialog UI — all 3 subclasses used to duplicate this code
  // ---------------------------------------------------------------------------

  /// 议价弹窗 — 申请方输入期望价格；Service 类型可选服务下拉
  Future<void> showNegotiateDialog(
    BuildContext context,
    String Function() getCurrencySymbol, {
    String? expertId,
  }) async {
    // Pre-fetch services for team consultation (only when expertId provided)
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
    String? errorText;
    int? selectedServiceId;

    await showDialog(
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
                onNegotiate(context, price: price, serviceId: selectedServiceId);
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
    priceController.dispose();
  }

  /// 报价弹窗 — 发布方输入报价+消息；Service 类型可选服务下拉
  Future<void> showQuoteDialog(
    BuildContext context,
    String Function() getCurrencySymbol, {
    String? expertId,
  }) async {
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
    String? errorText;
    int? selectedServiceId;

    await showDialog(
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
                onQuote(
                  context,
                  price: price,
                  message: msg.isNotEmpty ? msg : null,
                  serviceId: selectedServiceId,
                );
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
    priceController.dispose();
    messageController.dispose();
  }

  /// 还价弹窗 — 双方在议价过程中还价；Service 类型可选服务下拉
  Future<void> showCounterOfferDialog(
    BuildContext context, {
    required String Function() getCurrencySymbol,
    String? expertId,
  }) async {
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
    String? errorText;
    int? selectedServiceId;

    await showDialog(
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
                onCounterOffer(context, price: price, serviceId: selectedServiceId);
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
    priceController.dispose();
  }

  /// 正式申请弹窗 — 申请方提交价格+消息。
  /// 子类可 override 为不同 UI（如 FleaMarket 的纯确认弹窗）。
  Future<void> showFormalApplyDialog(
    BuildContext context,
    String Function() getCurrencySymbol,
  ) async {
    final priceController = TextEditingController();
    final messageController = TextEditingController();
    String? errorText;
    await showDialog(
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
                onFormalApply(
                  context,
                  price: price,
                  message: msg.isNotEmpty ? msg : null,
                );
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
    priceController.dispose();
    messageController.dispose();
  }

  /// 批准弹窗 — 发布方确认同意正式申请
  Future<void> showApproveConfirmation(
    BuildContext context, {
    Map<String, dynamic>? consultationApp,
  }) async {
    await showDialog(
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
              onApprove(context, consultationApp: consultationApp);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: Text(context.l10n.expertApplicationConfirmApprove),
          ),
        ],
      ),
    );
  }

  /// 关闭咨询弹窗
  Future<void> showCloseConfirmation(BuildContext context) async {
    await showDialog(
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
              onClose(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }
}

/// Pill 形状操作按钮
class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final disabled = onTap == null;
    final effectiveColor = disabled ? c.withValues(alpha: 0.4) : c;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: effectiveColor.withValues(alpha: 0.5)),
            borderRadius: AppRadius.allPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: effectiveColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: effectiveColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 议价卡片中的小按钮
class NegotiationActionButton extends StatelessWidget {
  const NegotiationActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
