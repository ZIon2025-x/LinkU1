import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
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
  void handleNegotiationResponse(BuildContext context, String action);

  /// 显示还价弹窗
  void showCounterOfferDialog(
    BuildContext context, {
    required String Function() getCurrencySymbol,
  });
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
