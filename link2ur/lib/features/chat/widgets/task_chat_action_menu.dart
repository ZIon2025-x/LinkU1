import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';

/// 任务聊天功能菜单
/// 参考iOS TaskChatActionMenu.swift
/// 提供上传图片、查看任务详情、查看地址等快捷操作
class TaskChatActionMenu extends StatelessWidget {
  const TaskChatActionMenu({
    super.key,
    required this.onImagePicker,
    required this.onTaskDetail,
    this.onViewLocation,
    this.isExpanded = false,
  });

  final VoidCallback onImagePicker;
  final VoidCallback onTaskDetail;
  final VoidCallback? onViewLocation;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: isExpanded ? 100 : 0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(
          top: BorderSide(color: AppColors.dividerLight, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              _ChatActionButton(
                icon: Icons.photo_library,
                label: context.l10n.chatImageLabel,
                color: AppColors.success,
                onTap: onImagePicker,
              ),
              const SizedBox(width: AppSpacing.xl),
              _ChatActionButton(
                icon: Icons.description,
                label: context.l10n.chatTaskDetailLabel,
                color: AppColors.primary,
                onTap: onTaskDetail,
              ),
              if (onViewLocation != null) ...[
                const SizedBox(width: AppSpacing.xl),
                _ChatActionButton(
                  icon: Icons.location_on,
                  label: context.l10n.chatAddressLabel,
                  color: AppColors.warning,
                  onTap: onViewLocation!,
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatActionButton extends StatelessWidget {
  const _ChatActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.buttonTap();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppRadius.allMedium,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
