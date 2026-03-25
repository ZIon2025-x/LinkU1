import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/content_constraint.dart';
import '../../../data/models/flea_market.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/task_repository.dart';

/// 统一发布页面 — 纯类型选择器
/// 从底部滑入，选择类型后跳转到对应的独立创建页面。
class PublishView extends StatefulWidget {
  const PublishView({super.key});

  @override
  State<PublishView> createState() => _PublishViewState();
}

class _PublishViewState extends State<PublishView> {
  // ── 折叠区块（最近发布 + 发布小贴士）──
  bool _recentSectionExpanded = false;
  bool _tipsSectionExpanded = false;
  List<_RecentPublishItem>? _recentItems; // null = loading, [] = empty

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentItems();
    });
  }

  Future<void> _loadRecentItems() async {
    try {
      final taskRepo = context.read<TaskRepository>();
      final forumRepo = context.read<ForumRepository>();
      final fleaRepo = context.read<FleaMarketRepository>();
      final locale = Localizations.localeOf(context);

      final results = await Future.wait([
        taskRepo.getMyTasks(role: 'poster', pageSize: 2),
        forumRepo.getMyPosts(pageSize: 2),
        fleaRepo.getMyItems(pageSize: 2),
      ]);

      final items = <_RecentPublishItem>[];
      for (final task in (results[0] as TaskListResponse).tasks) {
        items.add(_RecentPublishItem(
          type: _RecentItemType.task,
          id: task.id.toString(),
          title: task.displayTitle(locale),
          createdAt: task.createdAt ?? DateTime(1970),
        ));
      }
      for (final post in (results[1] as ForumPostListResponse).posts) {
        items.add(_RecentPublishItem(
          type: _RecentItemType.post,
          id: post.id.toString(),
          title: post.displayTitle(locale),
          createdAt: post.createdAt ?? DateTime(1970),
        ));
      }
      for (final fleaItem in (results[2] as FleaMarketListResponse).items) {
        items.add(_RecentPublishItem(
          type: _RecentItemType.fleaMarket,
          id: fleaItem.id,
          title: fleaItem.title,
          createdAt: fleaItem.createdAt ?? DateTime(1970),
        ));
      }
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final top3 = items.take(3).toList();
      if (mounted) setState(() => _recentItems = top3);
    } catch (e) {
      AppLogger.warning('Failed to load recent items: $e');
      if (mounted) setState(() => _recentItems = []);
    }
  }

  void _dismiss() {
    AppHaptics.light();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDesktop = ResponsiveUtils.isDesktop(context);

    final body = Column(
      children: [
        _buildPickerHeader(isDark),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSpacing.vSm,
                  // 2x2 Grid
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.15,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _PublishOptionTile(
                        isDark: isDark,
                        icon: Icons.task_alt_rounded,
                        iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                        iconColor: AppColors.primary,
                        title: context.l10n.publishTaskCardLabel,
                        subtitle: context.l10n.publishTaskCardDescription,
                        onTap: () {
                          AppHaptics.selection();
                          context.push(AppRoutes.createTask);
                        },
                      ),
                      _PublishOptionTile(
                        isDark: isDark,
                        icon: Icons.home_repair_service_rounded,
                        iconBgColor: AppColors.accent.withValues(alpha: 0.1),
                        iconColor: AppColors.accent,
                        title: context.l10n.publishService,
                        subtitle: context.l10n.publishServiceDesc,
                        onTap: () {
                          AppHaptics.selection();
                          context.push(AppRoutes.createService);
                        },
                      ),
                      _PublishOptionTile(
                        isDark: isDark,
                        icon: Icons.storefront_rounded,
                        iconBgColor: AppColors.success.withValues(alpha: 0.1),
                        iconColor: AppColors.success,
                        title: context.l10n.publishFleaCardLabel,
                        subtitle: context.l10n.publishFleaCardDescription,
                        onTap: () {
                          AppHaptics.selection();
                          context.push(AppRoutes.createFleaMarketItem);
                        },
                      ),
                      _PublishOptionTile(
                        isDark: isDark,
                        icon: Icons.article_rounded,
                        iconBgColor: AppColors.purple.withValues(alpha: 0.1),
                        iconColor: AppColors.purple,
                        title: context.l10n.publishPostCardLabel,
                        subtitle: context.l10n.publishPostCardDescription,
                        onTap: () {
                          AppHaptics.selection();
                          context.push(AppRoutes.createPost);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // AI 辅助入口
                  _buildAiAssistEntry(isDark),
                  const SizedBox(height: 14),
                  _buildRecentSection(isDark),
                  AppSpacing.vSm,
                  _buildTipsSection(isDark),
                  SizedBox(height: bottomPadding + 24),
                ],
              ),
            ),
          ),
        ),
        _buildCloseButton(isDark, bottomPadding),
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: isDesktop ? ContentConstraint(child: body) : body,
      ),
    );
  }

  // ==================== Header ====================
  Widget _buildPickerHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.publishTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vXs,
          Text(
            context.l10n.publishTypeSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  // ==================== AI 辅助入口 ====================
  Widget _buildAiAssistEntry(bool isDark) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push(AppRoutes.aiChatList);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.gradientPrimary,
          ),
          borderRadius: AppRadius.allMedium,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome, size: 22, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.publishAiAssistTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.publishAiAssistSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 最近发布 ====================
  Widget _buildRecentSection(bool isDark) {
    return _buildCollapsibleSection(
      isDark: isDark,
      title: context.l10n.publishRecentSectionTitle,
      expanded: _recentSectionExpanded,
      onTap: () {
        AppHaptics.selection();
        setState(() => _recentSectionExpanded = !_recentSectionExpanded);
      },
      child: _recentItems == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ),
            )
          : _recentItems!.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    context.l10n.publishRecentEmpty,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _recentItems!
                      .map((item) => _RecentPublishListItem(
                            isDark: isDark,
                            item: item,
                            onTap: () {
                              AppHaptics.selection();
                              switch (item.type) {
                                case _RecentItemType.task:
                                  context.push('/tasks/${item.id}');
                                  break;
                                case _RecentItemType.fleaMarket:
                                  context.push('/flea-market/${item.id}');
                                  break;
                                case _RecentItemType.post:
                                  context.push('/forum/posts/${item.id}');
                                  break;
                              }
                            },
                          ))
                      .toList(),
                ),
    );
  }

  // ==================== 发布小贴士 ====================
  Widget _buildTipsSection(bool isDark) {
    final List<String> tips = [
      context.l10n.publishTip1,
      context.l10n.publishTip2,
      context.l10n.publishTip3,
      context.l10n.publishTip4,
    ];
    return _buildCollapsibleSection(
      isDark: isDark,
      title: context.l10n.publishTipsSectionTitle,
      expanded: _tipsSectionExpanded,
      onTap: () {
        AppHaptics.selection();
        setState(() => _tipsSectionExpanded = !_tipsSectionExpanded);
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tips
              .map<Widget>(
                (String t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ==================== 可折叠区块 ====================
  Widget _buildCollapsibleSection({
    required bool isDark,
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.allMedium,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: child,
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  // ==================== 关闭按钮 ====================
  Widget _buildCloseButton(bool isDark, double bottomPadding) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: bottomPadding + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Center(
        child: Semantics(
          button: true,
          label: 'Close',
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 22,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 最近发布数据与列表项 ──
enum _RecentItemType { task, fleaMarket, post }

class _RecentPublishItem {
  const _RecentPublishItem({
    required this.type,
    required this.id,
    required this.title,
    required this.createdAt,
  });
  final _RecentItemType type;
  final String id;
  final String title;
  final DateTime createdAt;
}

class _RecentPublishListItem extends StatelessWidget {
  const _RecentPublishListItem({
    required this.isDark,
    required this.item,
    required this.onTap,
  });
  final bool isDark;
  final _RecentPublishItem item;
  final VoidCallback onTap;

  IconData get _icon {
    switch (item.type) {
      case _RecentItemType.task:
        return Icons.task_alt_rounded;
      case _RecentItemType.fleaMarket:
        return Icons.storefront_rounded;
      case _RecentItemType.post:
        return Icons.article_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              _icon,
              size: 20,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 发布类型卡片 ====================
class _PublishOptionTile extends StatelessWidget {
  const _PublishOptionTile({
    required this.isDark,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool isDark;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMedium,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allMedium,
            border: Border.all(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
