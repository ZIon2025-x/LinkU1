import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';

/// 通知菜单弹窗
/// 参考iOS NotificationMenuView.swift
/// 包含三个入口：通知、客服中心、任务聊天
class NotificationMenu extends StatelessWidget {
  const NotificationMenu({super.key});

  /// 从右上角弹出菜单
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const NotificationMenu(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerLight,
                  borderRadius: AppRadius.allPill,
                ),
              ),
            ),
            AppSpacing.vLg,

            // 标题
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '消息中心',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            AppSpacing.vLg,

            // 通知
            _MenuTile(
              icon: Icons.notifications,
              title: '通知',
              subtitle: '系统消息与通知',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                context.push('/notifications');
              },
            ),
            const Divider(indent: 60),

            // 客服中心
            _MenuTile(
              icon: Icons.headset_mic,
              title: '客服中心',
              subtitle: '联系在线客服',
              color: AppColors.success,
              onTap: () {
                Navigator.pop(context);
                context.push('/customer-service');
              },
            ),
            const Divider(indent: 60),

            // 任务聊天
            _MenuTile(
              icon: Icons.chat,
              title: '任务聊天',
              subtitle: '与任务相关方沟通',
              color: AppColors.accent,
              onTap: () {
                Navigator.pop(context);
                context.push('/task-chats');
              },
            ),
            AppSpacing.vLg,
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.allMedium,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiaryLight, size: 20),
    );
  }
}
