import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/l10n_extension.dart';

/// 工具调用指示卡片（展示名称随系统语言切换）
class ToolCallCard extends StatelessWidget {
  const ToolCallCard({
    super.key,
    required this.toolName,
    this.isLoading = true,
  });

  final String toolName;
  final bool isLoading;

  String _displayName(BuildContext context) {
    final l10n = context.l10n;
    switch (toolName) {
      case 'query_my_tasks':
        return l10n.toolCallQueryMyTasks;
      case 'get_task_detail':
        return l10n.toolCallGetTaskDetail;
      case 'search_tasks':
        return l10n.toolCallSearchTasks;
      case 'get_my_profile':
        return l10n.toolCallGetMyProfile;
      case 'get_platform_faq':
        return l10n.toolCallGetPlatformFaq;
      case 'check_cs_availability':
        return l10n.toolCallCheckCsAvailability;
      case 'get_my_points_and_coupons':
        return l10n.toolCallGetMyPointsAndCoupons;
      case 'list_activities':
        return l10n.toolCallListActivities;
      case 'get_my_notifications_summary':
        return l10n.toolCallGetMyNotificationsSummary;
      case 'list_my_forum_posts':
        return l10n.toolCallListMyForumPosts;
      case 'search_flea_market':
        return l10n.toolCallSearchFleaMarket;
      case 'get_leaderboard_summary':
        return l10n.toolCallGetLeaderboardSummary;
      case 'list_task_experts':
        return l10n.toolCallListTaskExperts;
      case 'get_my_wallet_summary':
        return l10n.toolCallGetMyWalletSummary;
      case 'get_my_messages_summary':
        return l10n.toolCallGetMyMessagesSummary;
      case 'get_my_vip_status':
        return l10n.toolCallGetMyVipStatus;
      case 'get_my_student_verification':
        return l10n.toolCallGetMyStudentVerification;
      case 'get_my_checkin_status':
        return l10n.toolCallGetMyCheckinStatus;
      case 'get_my_flea_market_items':
        return l10n.toolCallGetMyFleaMarketItems;
      case 'search_forum_posts':
        return l10n.toolCallSearchForumPosts;
      default:
        return toolName;
    }
  }

  /// 工具执行中时显示的「正在…」提示，分步感更明显
  String _loadingHint(BuildContext context) {
    final l10n = context.l10n;
    switch (toolName) {
      case 'query_my_tasks':
        return l10n.toolCallLoadingQueryMyTasks;
      case 'get_task_detail':
        return l10n.toolCallLoadingGetTaskDetail;
      case 'search_tasks':
        return l10n.toolCallLoadingSearchTasks;
      case 'get_my_profile':
        return l10n.toolCallLoadingGetMyProfile;
      case 'get_platform_faq':
        return l10n.toolCallLoadingGetPlatformFaq;
      case 'check_cs_availability':
        return l10n.toolCallLoadingCheckCsAvailability;
      case 'get_my_points_and_coupons':
        return l10n.toolCallLoadingGetMyPointsAndCoupons;
      case 'list_activities':
        return l10n.toolCallLoadingListActivities;
      case 'get_my_notifications_summary':
        return l10n.toolCallLoadingGetMyNotificationsSummary;
      case 'list_my_forum_posts':
        return l10n.toolCallLoadingListMyForumPosts;
      case 'search_flea_market':
        return l10n.toolCallLoadingSearchFleaMarket;
      case 'get_leaderboard_summary':
        return l10n.toolCallLoadingGetLeaderboardSummary;
      case 'list_task_experts':
        return l10n.toolCallLoadingListTaskExperts;
      case 'get_my_wallet_summary':
        return l10n.toolCallLoadingGetMyWalletSummary;
      case 'get_my_messages_summary':
        return l10n.toolCallLoadingGetMyMessagesSummary;
      case 'get_my_vip_status':
        return l10n.toolCallLoadingGetMyVipStatus;
      case 'get_my_student_verification':
        return l10n.toolCallLoadingGetMyStudentVerification;
      case 'get_my_checkin_status':
        return l10n.toolCallLoadingGetMyCheckinStatus;
      case 'get_my_flea_market_items':
        return l10n.toolCallLoadingGetMyFleaMarketItems;
      case 'search_forum_posts':
        return l10n.toolCallLoadingSearchForumPosts;
      default:
        return _displayName(context);
    }
  }

  IconData get _icon {
    switch (toolName) {
      case 'query_my_tasks':
        return Icons.task_alt;
      case 'get_task_detail':
        return Icons.description;
      case 'search_tasks':
        return Icons.search;
      case 'get_my_profile':
        return Icons.person;
      case 'get_platform_faq':
        return Icons.help_outline;
      case 'check_cs_availability':
        return Icons.support_agent;
      case 'get_my_points_and_coupons':
        return Icons.monetization_on;
      case 'list_activities':
        return Icons.event;
      case 'get_my_notifications_summary':
        return Icons.notifications;
      case 'list_my_forum_posts':
        return Icons.forum;
      case 'search_flea_market':
        return Icons.storefront;
      case 'get_leaderboard_summary':
        return Icons.leaderboard;
      case 'list_task_experts':
        return Icons.star;
      case 'get_my_wallet_summary':
        return Icons.account_balance_wallet;
      case 'get_my_messages_summary':
        return Icons.chat;
      case 'get_my_vip_status':
        return Icons.workspace_premium;
      case 'get_my_student_verification':
        return Icons.school;
      case 'get_my_checkin_status':
        return Icons.calendar_today;
      case 'get_my_flea_market_items':
        return Icons.inventory_2;
      case 'search_forum_posts':
        return Icons.manage_search;
      default:
        return Icons.build;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 40, // AI avatar + spacing
        vertical: AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 4,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isDark
                ? Colors.white12
                : Colors.black.withAlpha(15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isLoading ? _loadingHint(context) : _displayName(context),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: AppSpacing.sm),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.primary,
                ),
              ),
            ] else ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.check_circle,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
