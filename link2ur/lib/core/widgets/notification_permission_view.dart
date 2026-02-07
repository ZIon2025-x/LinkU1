import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';

/// 通知权限引导视图
/// 参考iOS NotificationPermissionView.swift
/// 在首次启动时引导用户开启推送通知
class NotificationPermissionView extends StatelessWidget {
  const NotificationPermissionView({
    super.key,
    required this.onComplete,
  });

  /// 完成回调（无论授权与否）
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.allXl,
          child: Column(
            children: [
              const Spacer(),

              // 图标
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              AppSpacing.vXl,

              // 标题
              const Text(
                '开启推送通知',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.vMd,

              // 说明
              Text(
                '开启通知后，您可以及时收到：\n\n'
                '• 任务状态更新\n'
                '• 新消息提醒\n'
                '• 任务匹配推荐\n'
                '• 优惠活动通知',
                style: AppTypography.body.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // 开启按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _requestPermission(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.allMedium,
                    ),
                  ),
                  child: const Text(
                    '开启通知',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              AppSpacing.vMd,

              // 跳过按钮
              TextButton(
                onPressed: () => _skip(context),
                child: Text(
                  '暂时跳过',
                  style: AppTypography.body.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              AppSpacing.vMd,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestPermission(BuildContext context) async {
    final status = await Permission.notification.request();

    // 标记已请求过通知权限
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_permission_asked', true);

    if (status.isGranted) {
      // 权限已授予
    } else if (status.isPermanentlyDenied) {
      // 永久拒绝，提示去设置
      if (context.mounted) {
        _showSettingsDialog(context);
        return;
      }
    }

    onComplete();
  }

  void _skip(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_permission_asked', true);
    onComplete();
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要通知权限'),
        content: const Text('您已拒绝通知权限，请在系统设置中手动开启。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onComplete();
            },
            child: const Text('稍后再说'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
              onComplete();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
}

/// 检查是否需要显示通知权限引导
Future<bool> shouldShowNotificationPermission() async {
  final prefs = await SharedPreferences.getInstance();
  final hasAsked = prefs.getBool('notification_permission_asked') ?? false;
  if (hasAsked) return false;

  final status = await Permission.notification.status;
  return !status.isGranted;
}
