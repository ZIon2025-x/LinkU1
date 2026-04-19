import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../l10n/app_localizations.dart';
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

    // Capture context-dependent values before showDialog to avoid using
    // the outer BuildContext inside the dialog's widget tree.
    final capturedContext = context;
    await showDialog(
      context: context,
      builder: (_) => _NegotiateDialog(
        currencySymbol: getCurrencySymbol(),
        services: services,
        expertId: expertId,
        onSubmit: (price, serviceId) =>
            onNegotiate(capturedContext, price: price, serviceId: serviceId),
        getLocalizations: () => capturedContext.l10n,
      ),
    );
    // No manual dispose — _NegotiateDialogState.dispose() handles it after
    // the dialog fade-out animation completes.
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

    final capturedContext = context;
    await showDialog(
      context: context,
      builder: (_) => _QuoteDialog(
        currencySymbol: getCurrencySymbol(),
        services: services,
        expertId: expertId,
        onSubmit: (price, message, serviceId) =>
            onQuote(capturedContext, price: price, message: message, serviceId: serviceId),
        getLocalizations: () => capturedContext.l10n,
      ),
    );
    // No manual dispose — _QuoteDialogState.dispose() handles it.
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

    final capturedContext = context;
    await showDialog(
      context: context,
      builder: (_) => _CounterOfferDialog(
        currencySymbol: getCurrencySymbol(),
        services: services,
        expertId: expertId,
        onSubmit: (price, serviceId) =>
            onCounterOffer(capturedContext, price: price, serviceId: serviceId),
        getLocalizations: () => capturedContext.l10n,
      ),
    );
    // No manual dispose — _CounterOfferDialogState.dispose() handles it.
  }

  /// 正式申请弹窗 — 申请方提交价格+消息。
  /// 子类可 override 为不同 UI（如 FleaMarket 的纯确认弹窗）。
  Future<void> showFormalApplyDialog(
    BuildContext context,
    String Function() getCurrencySymbol,
  ) async {
    if (!context.mounted) return;

    final capturedContext = context;
    await showDialog(
      context: context,
      builder: (_) => _FormalApplyDialog(
        currencySymbol: getCurrencySymbol(),
        onSubmit: (price, message) =>
            onFormalApply(capturedContext, price: price, message: message),
        getLocalizations: () => capturedContext.l10n,
      ),
    );
    // No manual dispose — _FormalApplyDialogState.dispose() handles it.
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

// =============================================================================
// Private StatefulWidget dialogs — controllers live in State.dispose(), which
// is called AFTER the dialog fade-out animation completes. This prevents the
// "TextEditingController used after being disposed" crash that occurred when
// controllers were disposed immediately after `await showDialog()`.
// =============================================================================

// -----------------------------------------------------------------------------
// _NegotiateDialog
// -----------------------------------------------------------------------------

class _NegotiateDialog extends StatefulWidget {
  const _NegotiateDialog({
    required this.currencySymbol,
    required this.onSubmit,
    required this.getLocalizations,
    this.services,
    this.expertId,
  });

  final String currencySymbol;
  final List<TaskExpertService>? services;
  final String? expertId;
  final void Function(double price, int? serviceId) onSubmit;
  final AppLocalizations Function() getLocalizations;

  @override
  State<_NegotiateDialog> createState() => _NegotiateDialogState();
}

class _NegotiateDialogState extends State<_NegotiateDialog> {
  final TextEditingController _priceController = TextEditingController();
  String? _errorText;
  int? _selectedServiceId;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.getLocalizations();
    final hasServices = widget.expertId != null &&
        widget.services != null &&
        widget.services!.isNotEmpty;
    return AlertDialog(
      title: Text(l10n.negotiatePrice),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasServices) ...[
            DropdownButtonFormField<int>(
              initialValue: _selectedServiceId,
              decoration: InputDecoration(
                labelText: l10n.consultationSelectService,
              ),
              items: widget.services!
                  .map((s) => DropdownMenuItem<int>(
                        value: s.id,
                        child: Text(s.serviceName, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedServiceId = v),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: l10n.negotiatePriceHint,
              prefixText: widget.currencySymbol,
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () {
            if (hasServices && _selectedServiceId == null) {
              setState(() => _errorText = widget.getLocalizations().consultationSelectServiceHint);
              return;
            }
            final price = double.tryParse(_priceController.text.trim());
            if (price == null || price <= 0) {
              setState(() => _errorText = widget.getLocalizations().negotiatePriceHint);
              return;
            }
            Navigator.pop(context);
            widget.onSubmit(price, _selectedServiceId);
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// _QuoteDialog
// -----------------------------------------------------------------------------

class _QuoteDialog extends StatefulWidget {
  const _QuoteDialog({
    required this.currencySymbol,
    required this.onSubmit,
    required this.getLocalizations,
    this.services,
    this.expertId,
  });

  final String currencySymbol;
  final List<TaskExpertService>? services;
  final String? expertId;
  final void Function(double price, String? message, int? serviceId) onSubmit;
  final AppLocalizations Function() getLocalizations;

  @override
  State<_QuoteDialog> createState() => _QuoteDialogState();
}

class _QuoteDialogState extends State<_QuoteDialog> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String? _errorText;
  int? _selectedServiceId;

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.getLocalizations();
    final hasServices = widget.expertId != null &&
        widget.services != null &&
        widget.services!.isNotEmpty;
    return AlertDialog(
      title: Text(l10n.quotePrice),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasServices) ...[
            DropdownButtonFormField<int>(
              initialValue: _selectedServiceId,
              decoration: InputDecoration(
                labelText: l10n.consultationSelectService,
              ),
              items: widget.services!
                  .map((s) => DropdownMenuItem<int>(
                        value: s.id,
                        child: Text(s.serviceName, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedServiceId = v),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: l10n.quotePriceHint,
              prefixText: widget.currencySymbol,
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.quoteMessageHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () {
            if (hasServices && _selectedServiceId == null) {
              setState(() => _errorText = widget.getLocalizations().consultationSelectServiceHint);
              return;
            }
            final price = double.tryParse(_priceController.text.trim());
            if (price == null || price <= 0) {
              setState(() => _errorText = widget.getLocalizations().quotePriceHint);
              return;
            }
            final msg = _messageController.text.trim();
            Navigator.pop(context);
            widget.onSubmit(price, msg.isNotEmpty ? msg : null, _selectedServiceId);
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// _CounterOfferDialog
// -----------------------------------------------------------------------------

class _CounterOfferDialog extends StatefulWidget {
  const _CounterOfferDialog({
    required this.currencySymbol,
    required this.onSubmit,
    required this.getLocalizations,
    this.services,
    this.expertId,
  });

  final String currencySymbol;
  final List<TaskExpertService>? services;
  final String? expertId;
  final void Function(double price, int? serviceId) onSubmit;
  final AppLocalizations Function() getLocalizations;

  @override
  State<_CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<_CounterOfferDialog> {
  final TextEditingController _priceController = TextEditingController();
  String? _errorText;
  int? _selectedServiceId;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.getLocalizations();
    final hasServices = widget.expertId != null &&
        widget.services != null &&
        widget.services!.isNotEmpty;
    return AlertDialog(
      title: Text(l10n.counterOffer),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasServices) ...[
            DropdownButtonFormField<int>(
              initialValue: _selectedServiceId,
              decoration: InputDecoration(
                labelText: l10n.consultationSelectService,
              ),
              items: widget.services!
                  .map((s) => DropdownMenuItem<int>(
                        value: s.id,
                        child: Text(s.serviceName, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedServiceId = v),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: l10n.counterOfferHint,
              prefixText: widget.currencySymbol,
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () {
            if (hasServices && _selectedServiceId == null) {
              setState(() => _errorText = widget.getLocalizations().consultationSelectServiceHint);
              return;
            }
            final price = double.tryParse(_priceController.text.trim());
            if (price == null || price <= 0) {
              setState(() => _errorText = widget.getLocalizations().counterOfferHint);
              return;
            }
            Navigator.pop(context);
            widget.onSubmit(price, _selectedServiceId);
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// _FormalApplyDialog
// -----------------------------------------------------------------------------

class _FormalApplyDialog extends StatefulWidget {
  const _FormalApplyDialog({
    required this.currencySymbol,
    required this.onSubmit,
    required this.getLocalizations,
  });

  final String currencySymbol;
  final void Function(double price, String? message) onSubmit;
  final AppLocalizations Function() getLocalizations;

  @override
  State<_FormalApplyDialog> createState() => _FormalApplyDialogState();
}

class _FormalApplyDialogState extends State<_FormalApplyDialog> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.getLocalizations();
    return AlertDialog(
      title: Text(l10n.formalApply),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: l10n.negotiatePriceHint,
              prefixText: widget.currencySymbol,
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.quoteMessageHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () {
            final price = double.tryParse(_priceController.text.trim());
            if (price == null || price <= 0) {
              setState(() => _errorText = widget.getLocalizations().negotiatePriceHint);
              return;
            }
            final msg = _messageController.text.trim();
            Navigator.pop(context);
            widget.onSubmit(price, msg.isNotEmpty ? msg : null);
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
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
