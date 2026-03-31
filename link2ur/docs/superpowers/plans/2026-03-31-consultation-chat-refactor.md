# 咨询聊天页面重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `application_chat_view.dart`（1800行）按咨询类型拆分为 4 个文件，消除所有 `switch(consultationType)` 分支。

**Architecture:** 抽象接口 `ConsultationActions` 定义在 `consultation_base.dart`，三种类型各自实现。主页面通过工厂方法获取实例，完全不感知类型差异。

**Tech Stack:** Flutter, BLoC, Dart

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `lib/features/tasks/views/consultation/consultation_base.dart` | 新建 | 枚举、抽象接口、共享 widget (ActionPill, NegotiationActionButton) |
| `lib/features/tasks/views/consultation/service_consultation_actions.dart` | 新建 | 服务咨询：actions + dialogs + dispatch |
| `lib/features/tasks/views/consultation/task_consultation_actions.dart` | 新建 | 任务咨询：actions + dialogs + dispatch |
| `lib/features/tasks/views/consultation/flea_market_consultation_actions.dart` | 新建 | 跳蚤市场：actions + dialogs + dispatch |
| `lib/features/tasks/views/application_chat_view.dart` | 修改 | 移除所有咨询类型分支，改用 ConsultationActions 接口 |

---

### Task 1: 创建 consultation_base.dart — 枚举、抽象接口、共享 widget

**Files:**
- Create: `lib/features/tasks/views/consultation/consultation_base.dart`

- [ ] **Step 1: 创建 consultation_base.dart**

```dart
import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';

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

  /// 处理议价回复（接受/拒绝/还价）— 用于消息列表中的议价卡片按钮
  void handleNegotiationResponse(BuildContext context, String action);

  /// 显示还价弹窗 — 用于消息列表中的议价卡片按钮
  void showCounterOfferDialog(
    BuildContext context, {
    required String Function() getCurrencySymbol,
  });
}

// 延迟导入实现类（避免循环依赖，在文件底部导入）
// 注：实际工厂方法中的类型引用由各文件的 export 提供

/// Pill 形状操作按钮 — 匹配任务聊天 _QuickActionChip 样式
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

    return GestureDetector(
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
```

注意：工厂方法中引用了三个实现类，需要在文件顶部导入它们。暂时先写文件框架，import 在 Step 2 各实现类创建后补全。

- [ ] **Step 2: 添加实现类的 import（创建完三个类型文件后补全）**

在 `consultation_base.dart` 顶部添加：
```dart
import 'service_consultation_actions.dart';
import 'task_consultation_actions.dart';
import 'flea_market_consultation_actions.dart';
```

- [ ] **Step 3: 运行 analyze 确认无误**

Run: `cd link2ur && flutter analyze lib/features/tasks/views/consultation/consultation_base.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/features/tasks/views/consultation/consultation_base.dart
git commit -m "refactor: add ConsultationActions base interface and shared widgets"
```

---

### Task 2: 创建 service_consultation_actions.dart

**Files:**
- Create: `lib/features/tasks/views/consultation/service_consultation_actions.dart`

- [ ] **Step 1: 创建文件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
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
  void handleNegotiationResponse(BuildContext context, String action) {
    context.read<TaskExpertBloc>().add(
      TaskExpertNegotiateResponse(applicationId, action: action),
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
                  TaskExpertNegotiateResponse(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConsulting = appStatus == 'consulting';
    final isNegotiating = appStatus == 'negotiating';
    final isPriceAgreed = appStatus == 'price_agreed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark.withValues(alpha: 0.85)
            : AppColors.cardBackgroundLight.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Applicant: negotiate & formal apply
            if (isApplicant && (isConsulting || isNegotiating)) ...[
              ActionPill(
                icon: Icons.local_offer,
                label: context.l10n.negotiatePrice,
                onTap: isSubmitting
                    ? null
                    : () => _showNegotiateDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.formalApply,
                onTap: isSubmitting
                    ? null
                    : () => _showFormalApplyDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            // Expert: quote
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
            // Price agreed: applicant can formal apply
            if (isPriceAgreed && isApplicant) ...[
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.formalApply,
                onTap: isSubmitting
                    ? null
                    : () => _showFormalApplyDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            // Price agreed: expert can approve
            if (isPriceAgreed && !isApplicant) ...[
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
            // Pending: non-applicant can approve
            if (appStatus == 'pending' && !isApplicant) ...[
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
            // Close consultation
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

  // ── Dialogs ───────────────────────────────────────────────────────────

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
                  TaskExpertNegotiatePrice(applicationId, price: price),
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
                  TaskExpertQuotePrice(
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

  void _showFormalApplyDialog(BuildContext context, String Function() getCurrencySymbol) {
    final priceController = TextEditingController();
    final messageController = TextEditingController();
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
                Navigator.pop(dialogContext);
                final msg = messageController.text.trim();
                context.read<TaskExpertBloc>().add(
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
    );
  }

  void _showApproveConfirmation(BuildContext context, Map<String, dynamic>? consultationApp) {
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
                context.read<TaskExpertBloc>().add(
                  TaskExpertApproveApplication(applicationId),
                );
              } else {
                context.read<TaskExpertBloc>().add(
                  TaskExpertOwnerApproveApplication(applicationId),
                );
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
                TaskExpertCloseConsultation(applicationId),
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
```

- [ ] **Step 2: 运行 analyze**

Run: `cd link2ur && flutter analyze lib/features/tasks/views/consultation/service_consultation_actions.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/tasks/views/consultation/service_consultation_actions.dart
git commit -m "refactor: add ServiceConsultationActions with actions, dialogs, dispatch"
```

---

### Task 3: 创建 task_consultation_actions.dart

**Files:**
- Create: `lib/features/tasks/views/consultation/task_consultation_actions.dart`

- [ ] **Step 1: 创建文件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
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
  void handleNegotiationResponse(BuildContext context, String action) {
    context.read<TaskExpertBloc>().add(
      TaskExpertTaskNegotiateResponse(taskId, applicationId, action: action),
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
                  TaskExpertTaskNegotiateResponse(
                    taskId, applicationId,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConsulting = appStatus == 'consulting';
    final isNegotiating = appStatus == 'negotiating';
    final isPriceAgreed = appStatus == 'price_agreed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark.withValues(alpha: 0.85)
            : AppColors.cardBackgroundLight.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Applicant: negotiate & formal apply
            if (isApplicant && (isConsulting || isNegotiating)) ...[
              ActionPill(
                icon: Icons.local_offer,
                label: context.l10n.negotiatePrice,
                onTap: isSubmitting
                    ? null
                    : () => _showNegotiateDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.formalApply,
                onTap: isSubmitting
                    ? null
                    : () => _showFormalApplyDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            // Expert: quote
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
            // Price agreed: applicant can formal apply
            if (isPriceAgreed && isApplicant) ...[
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.formalApply,
                onTap: isSubmitting
                    ? null
                    : () => _showFormalApplyDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
            ],
            // Price agreed or pending: non-applicant can approve (uses TaskDetailBloc)
            if ((isPriceAgreed || appStatus == 'pending') && !isApplicant) ...[
              ActionPill(
                icon: Icons.check_circle,
                label: context.l10n.expertApplicationConfirmApprove,
                color: AppColors.success,
                onTap: isSubmitting
                    ? null
                    : () => _showApproveConfirmation(context),
              ),
              const SizedBox(width: 8),
            ],
            // Close consultation
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

  // ── Dialogs ───────────────────────────────────────────────────────────

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
                  TaskExpertTaskNegotiate(taskId, applicationId, price: price),
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
                  TaskExpertTaskQuote(
                    taskId, applicationId,
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

  void _showFormalApplyDialog(BuildContext context, String Function() getCurrencySymbol) {
    final priceController = TextEditingController();
    final messageController = TextEditingController();
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
                Navigator.pop(dialogContext);
                final msg = messageController.text.trim();
                context.read<TaskExpertBloc>().add(
                  TaskExpertTaskFormalApply(
                    taskId, applicationId,
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
    );
  }

  void _showApproveConfirmation(BuildContext context) {
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
              // Task consultation: poster accepts the applicant
              context.read<TaskDetailBloc>().add(
                TaskDetailAcceptApplicant(applicationId),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: Text(context.l10n.expertApplicationConfirmApprove),
          ),
        ],
      ),
    );
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
                TaskExpertCloseTaskConsultation(taskId, applicationId),
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
```

- [ ] **Step 2: 运行 analyze**

Run: `cd link2ur && flutter analyze lib/features/tasks/views/consultation/task_consultation_actions.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/tasks/views/consultation/task_consultation_actions.dart
git commit -m "refactor: add TaskConsultationActions with actions, dialogs, dispatch"
```

---

### Task 4: 创建 flea_market_consultation_actions.dart

**Files:**
- Create: `lib/features/tasks/views/consultation/flea_market_consultation_actions.dart`

- [ ] **Step 1: 创建文件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConsulting = appStatus == 'consulting';
    final isNegotiating = appStatus == 'negotiating';
    final isPriceAgreed = appStatus == 'price_agreed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark.withValues(alpha: 0.85)
            : AppColors.cardBackgroundLight.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Buyer: negotiate & buy
            if (isApplicant && (isConsulting || isNegotiating)) ...[
              ActionPill(
                icon: Icons.local_offer,
                label: context.l10n.negotiatePrice,
                onTap: isSubmitting
                    ? null
                    : () => _showNegotiateDialog(context, getCurrencySymbol),
              ),
              const SizedBox(width: 8),
              ActionPill(
                icon: Icons.assignment,
                label: context.l10n.fleaMarketBuyNow,
                onTap: isSubmitting
                    ? null
                    : () => _showFormalApplyDialog(context),
              ),
              const SizedBox(width: 8),
            ],
            // Seller: quote
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
            // Price agreed: buyer can confirm purchase
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
            // Pending: seller can approve
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
            // Close consultation
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

  // ── Dialogs ───────────────────────────────────────────────────────────

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

  /// Flea market: simple confirmation, no price/message form
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

  /// Flea market approval: direct API call (not through bloc)
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
```

- [ ] **Step 2: 运行 analyze**

Run: `cd link2ur && flutter analyze lib/features/tasks/views/consultation/flea_market_consultation_actions.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/tasks/views/consultation/flea_market_consultation_actions.dart
git commit -m "refactor: add FleaMarketConsultationActions with actions, dialogs, dispatch"
```

---

### Task 5: 补全 consultation_base.dart 的 import 并验证整个 consultation 目录

**Files:**
- Modify: `lib/features/tasks/views/consultation/consultation_base.dart` (顶部 import)

- [ ] **Step 1: 在 consultation_base.dart 顶部添加三个实现类的 import**

在 `import '../../../../core/design/app_radius.dart';` 之后添加：
```dart
import 'service_consultation_actions.dart';
import 'task_consultation_actions.dart';
import 'flea_market_consultation_actions.dart';
```

- [ ] **Step 2: 运行 analyze 验证整个 consultation 目录**

Run: `cd link2ur && flutter analyze lib/features/tasks/views/consultation/`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/tasks/views/consultation/
git commit -m "refactor: wire up ConsultationActions factory with all three implementations"
```

---

### Task 6: 改造 application_chat_view.dart — 接入 ConsultationActions 接口

**Files:**
- Modify: `lib/features/tasks/views/application_chat_view.dart`

这是最关键的一步。需要：
1. 替换 import，移除 `ConsultationType` 枚举
2. 在 State 中初始化 `ConsultationActions`
3. 用接口方法替代所有 switch 分支
4. 删除所有已迁移的方法和 widget 类

- [ ] **Step 1: 替换 import 和移除 ConsultationType 枚举**

在 `application_chat_view.dart` 顶部：
- 删除 `enum ConsultationType { service, task, fleaMarket }` (line 28)
- 添加 `import 'consultation/consultation_base.dart';`

- [ ] **Step 2: 在 _ApplicationChatContentState 中添加 ConsultationActions 引用**

在 `_isLoadingConsultation` 字段之后添加：
```dart
ConsultationActions? _consultationActions;
```

在 `initState()` 中，`_loadConsultationStatus()` 调用之前添加：
```dart
if (widget.isConsultation) {
  _consultationActions = ConsultationActions.of(
    type: widget.consultationType,
    applicationId: widget.applicationId,
    taskId: widget.taskId,
  );
}
```

- [ ] **Step 3: 简化 _loadConsultationStatus() — 消除 switch**

将整个 switch 替换为：
```dart
final endpoint = _consultationActions!.statusEndpoint;
```

替换前：
```dart
final String endpoint;
switch (widget.consultationType) {
  case ConsultationType.service:
    endpoint = ApiEndpoints.consultationStatus(widget.applicationId);
  case ConsultationType.task:
    endpoint = ApiEndpoints.taskConsultStatus(widget.taskId, widget.applicationId);
  case ConsultationType.fleaMarket:
    endpoint = ApiEndpoints.fleaMarketConsultStatus(widget.applicationId);
}
```

- [ ] **Step 4: 简化 _isApplicantInConsultation() — 消除 switch**

将整个方法体替换为：
```dart
bool _isApplicantInConsultation() {
  if (!widget.isConsultation || _consultationActions == null) return false;
  return _consultationActions!.isApplicant(_currentUserId, _consultationApp);
}
```

- [ ] **Step 5: 简化 _loadMessages 和 _sendMessage 中的 application_id 条件**

在 `_loadMessages()` 中替换：
```dart
// 替换前
if (!widget.isConsultation || widget.consultationType == ConsultationType.task)
  'application_id': widget.applicationId,

// 替换后
if (_consultationActions?.needsApplicationIdInMessages ?? true)
  'application_id': widget.applicationId,
```

在 `_sendMessage()` 中做同样的替换。

- [ ] **Step 6: 替换 _buildConsultingActions2 调用**

在 `_buildMainContent` 的 builder 中，替换：
```dart
// 替换前
_buildConsultingActions2(appStatus),

// 替换后
_consultationActions!.buildActions(
  context: context,
  appStatus: appStatus,
  isSubmitting: context.watch<TaskExpertBloc>().state.isSubmitting,
  isApplicant: _isApplicantInConsultation(),
  getCurrencySymbol: _getCurrencySymbol,
  consultationApp: _consultationApp,
  onActionCompleted: () {
    _loadMessages();
    _loadConsultationStatus();
  },
),
```

- [ ] **Step 7: 替换议价卡片中的 _handleNegotiationResponse 和 _showCounterOfferDialog**

在 `_buildNegotiationCard` 中的按钮回调中替换：
```dart
// 替换前
onPressed: () => _handleNegotiationResponse('accept'),
// ...
onPressed: () => _handleNegotiationResponse('reject'),
// ...
onPressed: _showCounterOfferDialog,

// 替换后
onPressed: () => _consultationActions?.handleNegotiationResponse(context, 'accept'),
// ...
onPressed: () => _consultationActions?.handleNegotiationResponse(context, 'reject'),
// ...
onPressed: () => _consultationActions?.showCounterOfferDialog(
  context,
  getCurrencySymbol: _getCurrencySymbol,
),
```

注意：这些按钮只在 consultation 模式下的议价卡片中显示（`!isMe && isLatestNegotiation`），而非 consultation 模式下也有可能显示议价卡片（regular mode 的 `_showProposePriceDialog` / `_showCounterOfferDialog`）。需要检查 regular mode 是否也需要处理。

如果 regular mode（`!widget.isConsultation`）也显示议价按钮，则需要保留 `_handleNegotiationResponse` 和 `_showCounterOfferDialog` 方法作为 regular mode 的 fallback。在这种情况下：
```dart
onPressed: () {
  if (_consultationActions != null) {
    _consultationActions!.handleNegotiationResponse(context, 'accept');
  } else {
    _handleNegotiationResponse('accept');
  }
},
```

- [ ] **Step 8: 删除已迁移的方法**

从 `_ApplicationChatContentState` 中删除以下方法：
- `_buildConsultingActions2()`
- `_dispatchNegotiate()`
- `_dispatchQuote()`
- `_dispatchNegotiateResponse()`
- `_dispatchFormalApply()`
- `_dispatchClose()`
- `_showNegotiateDialog()`
- `_showQuoteDialog()`
- `_showFormalApplyDialog()`
- `_showApproveConfirmation()` — 注意：regular mode 中 `_buildConfirmAndPayButton` 走的是 `TaskDetailConfirmAndPay`，不经过此方法。但 `_showApproveConfirmation` 在 regular mode 中也被使用（line 1613-1618 的 else 分支）。**保留 regular mode 的审批逻辑**，只删除 consultation mode 的 switch 分支。
- `_showCloseConfirmation()`
- `_showCounterOfferDialog()` — 如果 regular mode 也用到则保留
- `_handleNegotiationResponse()` — 如果 regular mode 也用到则保留
- `_approveFleaMarketPurchase()`

删除文件底部的 widget 类：
- `_NegotiationActionButton` — 已迁移到 `consultation_base.dart` 的 `NegotiationActionButton`
- `_ActionPill` — 已迁移到 `consultation_base.dart` 的 `ActionPill`

更新 `_buildNegotiationCard` 中对 `_NegotiationActionButton` 的引用：
```dart
// 替换前
_NegotiationActionButton(...)

// 替换后
NegotiationActionButton(...)
```

- [ ] **Step 9: 清理不再需要的 import**

检查并删除不再直接使用的 import：
- `task_expert_repository.dart` — 仍在顶层 `ApplicationChatView.build()` 中使用（提供 BlocProvider），保留
- `activity_repository.dart` — 同上，保留
- `api_endpoints.dart` — 检查是否仍在 `_loadConsultationStatus` 和 `_loadMessages` 中使用。`_loadMessages` 使用 `ApiEndpoints.taskChatMessages`，`_loadConsultationStatus` 现在用 `_consultationActions!.statusEndpoint`，但 `_sendMessage` 使用 `ApiEndpoints.taskChatSend`。保留。

- [ ] **Step 10: 运行 analyze**

Run: `cd link2ur && flutter analyze lib/features/tasks/views/application_chat_view.dart`
Expected: No issues found

- [ ] **Step 11: Commit**

```bash
git add lib/features/tasks/views/application_chat_view.dart
git commit -m "refactor: replace consultation switch branches with ConsultationActions interface

Eliminates all switch(consultationType) from application_chat_view.dart.
Type-specific logic now lives in consultation/ subdirectory."
```

---

### Task 7: 全量验证 — analyze 整个项目 + 检查 import 链

**Files:**
- No file changes, verification only

- [ ] **Step 1: 运行项目级 analyze**

Run: `cd link2ur && flutter analyze lib/`
Expected: No new issues introduced (existing warnings are acceptable)

- [ ] **Step 2: 验证路由文件 import 正确**

路由文件 `lib/core/router/routes/task_routes.dart` 引用了 `ConsultationType`，确认它现在从 `consultation_base.dart` 导入。

Run: `grep -n 'ConsultationType' lib/core/router/routes/task_routes.dart`

如果它之前 import 的是 `application_chat_view.dart`，需要改为：
```dart
import '../../../features/tasks/views/consultation/consultation_base.dart';
```

或者在 `application_chat_view.dart` 中 re-export：
```dart
export 'consultation/consultation_base.dart' show ConsultationType;
```

推荐使用 re-export，这样其他文件的 import 不需要改动。

- [ ] **Step 3: 搜索所有引用 ConsultationType 的文件并确认 import 正确**

Run: `grep -rl 'ConsultationType' lib/`

逐一检查每个文件的 import 是否能正确解析到 `ConsultationType`。

- [ ] **Step 4: Commit（如有修复）**

```bash
git add -A
git commit -m "fix: update ConsultationType imports after refactor"
```
