import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/stat_item.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/animated_circular_progress.dart';
import '../../../core/widgets/animated_star_rating.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/skill_radar_chart.dart';
import '../../../core/widgets/user_identity_badges.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user.dart' show User, UserProfileDetail, UserProfileReview, UserProfileForumPost, UserProfileFleaItem;
import '../../../data/models/task.dart' show CreateTaskRequest;
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/follow_repository.dart';
import '../../../core/router/app_router.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/profile_bloc.dart';

/// 公开用户资料页
/// 参考iOS UserProfileView.swift
class UserProfileView extends StatelessWidget {
  const UserProfileView({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
        followRepository: context.read<FollowRepository>(),
      )..add(ProfileLoadPublicProfile(userId))
        ..add(ProfileLoadSharedTasks(userId)),
      child: BlocListener<ProfileBloc, ProfileState>(
        listenWhen: (prev, curr) =>
            curr.errorMessage != null && prev.errorMessage != curr.errorMessage &&
            (curr.errorMessage == 'follow_failed' || curr.errorMessage == 'unfollow_failed'),
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.errorMessage!))),
          );
        },
        child: BlocBuilder<ProfileBloc, ProfileState>(
          buildWhen: (prev, curr) =>
              prev.isLoading != curr.isLoading ||
              prev.errorMessage != curr.errorMessage ||
              prev.publicUser != curr.publicUser ||
              prev.isFollowing != curr.isFollowing ||
              prev.isFollowLoading != curr.isFollowLoading ||
              prev.followersCount != curr.followersCount ||
              prev.followingCount != curr.followingCount,
          builder: (context, state) {
            // 关注错误不应替换整个页面，已通过 BlocListener 以 SnackBar 显示
            final isPageError = state.errorMessage != null &&
                state.errorMessage != 'follow_failed' &&
                state.errorMessage != 'unfollow_failed';
            return Scaffold(
              appBar: AppBar(
                title: Text(l10n.profileUserProfile),
              ),
              body: state.isLoading
                  ? const LoadingView()
                  : isPageError
                      ? ErrorStateView(
                          message: state.errorMessage!,
                          onRetry: () {
                            context.read<ProfileBloc>().add(
                                  ProfileLoadPublicProfile(userId),
                                );
                          },
                        )
                      : state.publicUser == null
                        ? EmptyStateView.noData(
                            context,
                            title: context.l10n.userNotFound,
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: () async {
                                    context.read<ProfileBloc>()
                                      ..add(ProfileLoadPublicProfile(userId))
                                      ..add(ProfileLoadSharedTasks(userId));
                                  },
                                  child: SingleChildScrollView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    child: Column(
                                      children: [
                                        // 用户信息卡片（头像、名字、徽章、简介、城市 + 三项统计）
                                        _buildUserInfoCard(context, state.publicUser!, state),
                                        const SizedBox(height: AppSpacing.xl),
                                        // 技能雷达图
                                        _buildSkillRadar(context, state.publicUser!),
                                        const SizedBox(height: AppSpacing.section),
                                        // 合作记录
                                        BlocBuilder<ProfileBloc, ProfileState>(
                                          buildWhen: (prev, curr) =>
                                              prev.sharedTasks != curr.sharedTasks ||
                                              prev.isLoadingSharedTasks != curr.isLoadingSharedTasks,
                                          builder: (context, state) {
                                            if (state.sharedTasks.isEmpty && !state.isLoadingSharedTasks) {
                                              return const SizedBox.shrink();
                                            }
                                            return _buildSharedTasksSection(context, state.sharedTasks);
                                          },
                                        ),
                                        // 收到的评价
                                        if (state.publicProfileDetail?.reviews.isNotEmpty == true)
                                          _buildReviewsSection(context, state.publicProfileDetail!.reviews),
                                        // 近期任务（后端 recent_tasks，该用户近期发布或参与的任务，最多 5 条）
                                        _buildRecentTasksSection(context, state.publicProfileDetail),
                                        // 近期论坛帖子
                                        if (state.publicProfileDetail?.recentForumPosts.isNotEmpty == true)
                                          _buildRecentForumPostsSection(context, state.publicProfileDetail!.recentForumPosts),
                                        // 已售闲置物品
                                        if (state.publicProfileDetail?.soldFleaItems.isNotEmpty == true)
                                          _buildSoldFleaItemsSection(context, state.publicProfileDetail!.soldFleaItems),
                                        const SizedBox(height: AppSpacing.xxl),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // 底部：发布任务请求
                              _buildBottomRequestButton(context, state.publicUser!),
                            ],
                          ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, User user, ProfileState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头像 + 会员/超级会员角标（右下角皇冠/徽章）
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomRight,
            children: [
              AvatarView(
                imageUrl: user.avatar,
                name: user.displayNameWith(context.l10n),
                size: 88,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: MemberBadgeAvatarOverlay(
                  userLevel: user.userLevel,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 名称 + 徽章（达人蓝标、学生、会员、超级会员）
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                user.displayNameWith(context.l10n),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (user.isExpert) ...[
                const Icon(Icons.verified, color: AppColors.primary, size: 20),
              ],
              if (user.isStudentVerified) ...[
                const Icon(Icons.school, color: Colors.blue, size: 20),
              ],
              if (user.userLevel == 'vip') ...[
                IdentityBadge(
                  text: context.l10n.badgeVip,
                  icon: Icons.workspace_premium,
                  gradientColors: AppColors.gradientGold,
                  compact: true,
                ),
              ],
              if (user.userLevel == 'super') ...[
                IdentityBadge(
                  text: context.l10n.badgeSuper,
                  icon: Icons.local_fire_department,
                  gradientColors: AppColors.gradientPinkPurple,
                  compact: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 关注按钮 + 粉丝/关注数
          _buildFollowSection(context, user, state),
          const SizedBox(height: AppSpacing.sm),

          // 简介
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            Text(
              user.bio!,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 居住城市
          if (user.residenceCity != null &&
              user.residenceCity!.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  user.residenceCity!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textTertiary),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // 三项统计数据（完成数、总任务、评分）
          _buildStatsRow(context, user),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, User user) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          // 任务完成率 — 环形进度条
          Expanded(
            child: AnimatedCircularProgress(
              progress: user.completionRate,
              size: 56,
              strokeWidth: 5,
              gradientColors: const [AppColors.primary, AppColors.primaryLight],
              label: l10n.profileCompletedTasks,
              centerWidget: Text(
                '${user.completedTaskCount}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // 总任务数
          Expanded(
            child: StatItem(
              label: l10n.profileTaskCount,
              value: '${user.taskCount}',
              icon: Icons.assignment,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // 评分 — 星星动画
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedStarRating(
                  rating: user.avgRating ?? 0,
                  size: 14,
                  spacing: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  user.ratingDisplay,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.profileRating,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowSection(BuildContext context, User user, ProfileState state) {
    final l10n = context.l10n;

    // 不显示关注按钮：自己 或 未登录
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState.status == AuthStatus.authenticated;
    final currentUserId = isAuthenticated ? authState.user?.id : null;
    final isSelf = currentUserId == user.id;

    return Column(
      children: [
        // 粉丝 / 关注数
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${state.followersCount}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.profileFollowers,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.lg),
            Text(
              '${state.followingCount}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.profileFollowing,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        if (isAuthenticated && !isSelf) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: 140,
            height: 36,
            child: state.isFollowing
                ? OutlinedButton(
                    onPressed: state.isFollowLoading
                        ? null
                        : () => context.read<ProfileBloc>().add(ProfileUnfollowUser(user.id)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.textTertiary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: state.isFollowLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            l10n.profileFollowingAction,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                  )
                : ElevatedButton.icon(
                    onPressed: state.isFollowLoading
                        ? null
                        : () => context.read<ProfileBloc>().add(ProfileFollowUser(user.id)),
                    icon: state.isFollowLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add, size: 18),
                    label: Text(l10n.profileFollow, style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  /// 技能雷达图 — 展示用户多维能力
  Widget _buildSkillRadar(BuildContext context, User user) {
    final l10n = context.l10n;
    // 根据用户数据构建雷达图维度
    final rating = (user.avgRating ?? 0) / 5.0; // 归一化到 0-1
    final completionRate = user.completionRate;
    final taskVolume =
        (user.taskCount / 50).clamp(0.0, 1.0); // 50个任务为满
    final experience = user.completedTaskCount > 0
        ? (user.completedTaskCount / 30).clamp(0.0, 1.0)
        : 0.0;
    // 如果数据太少，不显示雷达图
    if (user.taskCount == 0 && (user.avgRating ?? 0) == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(l10n.profileRating,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: SkillRadarChart(
              data: {
                '⭐': rating,
                '✅': completionRate,
                '📦': taskVolume,
                '🏆': experience,
              },
              size: 160,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTasksSection(
    BuildContext context,
    UserProfileDetail? profileDetail,
  ) {
    final l10n = context.l10n;
    final tasks = profileDetail?.recentTasks ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(l10n.profileRecentTasks,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Center(
                child: Text(
                  l10n.profileNoRecentTasks,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...tasks
                .where((t) => t.status == 'completed')
                .take(3)
                .map((t) => Padding(
                  key: ValueKey('task_${t.id}'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    title: Text(t.displayTitle(Localizations.localeOf(context)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${t.status} · ${Helpers.formatPrice(t.reward)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    onTap: () => context.goToTaskDetail(t.id),
                  ),
                )),
        ],
      ),
    );
  }

  /// 底部固定：发布任务请求按钮
  Widget _buildBottomRequestButton(BuildContext context, User user) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showDirectRequestSheet(context, user),
            icon: const Icon(Icons.send, size: 20),
            label: Text(l10n.profileDirectRequest),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDirectRequestSheet(BuildContext context, User user) {
    final l10n = context.l10n;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final locationController = TextEditingController(
      text: user.residenceCity ?? 'Online',
    );
    String selectedTaskType = AppConstants.taskTypes.first;
    DateTime? selectedDeadline;
    bool rewardToBeQuoted = false; // 待报价：由指定用户同意后报价/议价
    bool isSubmitting = false;

    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 不画自定义拖拽条：主题 showDragHandle: true 已提供
                    Center(
                      child: Text(
                        l10n.profileDirectRequestTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 任务标题
                    TextField(
                      controller: titleController,
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: l10n.profileDirectRequestHintTitle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 描述
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: l10n.profileDirectRequestHintDescription,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 价格 + 地点（一行两列）；待报价时不填金额
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            enabled: !rewardToBeQuoted,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.profileDirectRequestHintPrice,
                              prefixText: rewardToBeQuoted ? null : '${Helpers.currencySymbol} ',
                              hintText: rewardToBeQuoted ? l10n.taskRewardToBeQuoted : null,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.medium),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: locationController,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.profileDirectRequestHintLocation,
                              prefixIcon:
                                  const Icon(Icons.location_on_outlined, size: 20),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.medium),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 待报价：指定用户同意后再报价/议价
                    CheckboxListTile(
                      value: rewardToBeQuoted,
                      onChanged: (v) => setSheetState(() => rewardToBeQuoted = v ?? false),
                      title: Text(
                        l10n.createTaskRewardToBeQuoted,
                        style: const TextStyle(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 任务类型
                    AppSelectField<String>(
                      value: selectedTaskType,
                      hint: l10n.profileDirectRequestHintTaskType,
                      sheetTitle: l10n.profileDirectRequestHintTaskType,
                      prefixIcon: Icons.category_outlined,
                      options: _getLocalizedTaskTypes(ctx)
                          .map((entry) => SelectOption(
                                value: entry['key']!,
                                label: entry['label']!,
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedTaskType = value);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 截止日期
                    Semantics(
                      button: true,
                      label: 'Select deadline',
                      child: GestureDetector(
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDeadline ??
                                now.add(const Duration(days: 7)),
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDeadline = picked);
                          }
                        },
                        child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.profileDirectRequestHintDeadline,
                          prefixIcon:
                              const Icon(Icons.event_outlined, size: 20),
                          suffixIcon: selectedDeadline != null
                              ? Semantics(
                                  button: true,
                                  label: 'Clear deadline',
                                  child: GestureDetector(
                                    onTap: () => setSheetState(
                                        () => selectedDeadline = null),
                                    child: const Icon(Icons.close, size: 18),
                                  ),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.medium),
                          ),
                        ),
                        child: Text(
                          selectedDeadline != null
                              ? '${selectedDeadline!.year}-${selectedDeadline!.month.toString().padLeft(2, '0')}-${selectedDeadline!.day.toString().padLeft(2, '0')}'
                              : '',
                          style: TextStyle(
                            color: selectedDeadline != null
                                ? null
                                : (isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight),
                          ),
                        ),
                      ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 提交按钮
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                final price = double.tryParse(
                                    priceController.text.trim().replaceAll(',', ''));
                                final bool needPrice = !rewardToBeQuoted;
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                        content: Text(l10n
                                            .profileDirectRequestValidation(Helpers.currencySymbolFor(AppConstants.defaultCurrency)))),
                                  );
                                  return;
                                }
                                if (needPrice && (price == null || price < 1)) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                        content: Text(l10n
                                            .profileDirectRequestValidation(Helpers.currencySymbolFor(AppConstants.defaultCurrency)))),
                                  );
                                  return;
                                }

                                final taskRepo =
                                    context.read<TaskRepository>();
                                // 保存外部 ScaffoldMessenger 引用，pop 之后 ctx 已失效
                                final messenger = ScaffoldMessenger.of(context);
                                setSheetState(() => isSubmitting = true);
                                try {
                                  final loc =
                                      locationController.text.trim();
                                  await taskRepo.createTask(
                                    CreateTaskRequest(
                                      title: title,
                                      description:
                                          descriptionController.text.trim(),
                                      taskType: selectedTaskType,
                                      location:
                                          loc.isNotEmpty ? loc : 'Online',
                                      reward: rewardToBeQuoted ? null : price,
                                      deadline: selectedDeadline,
                                      isPublic: 0,
                                      taskSource: 'user_profile',
                                      designatedTakerId: user.id,
                                    ),
                                  );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(
                                        content: Text(l10n
                                            .profileDirectRequestSuccess)),
                                  );
                                } catch (e) {
                                  setSheetState(
                                      () => isSubmitting = false);
                                  if (ctx.mounted) {
                                    final errorText = ctx.localizeError(e.toString());
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text(errorText)),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.medium),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(l10n.profileDirectRequestSubmit),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Delay dispose to allow dismiss animation to finish;
      // controllers may still be referenced by fading TextFields.
      Future.delayed(const Duration(milliseconds: 300), () {
        titleController.dispose();
        descriptionController.dispose();
        priceController.dispose();
        locationController.dispose();
      });
    });
  }

  List<Map<String, String>> _getLocalizedTaskTypes(BuildContext context) {
    final l10n = context.l10n;
    return [
      {'key': 'shopping', 'label': l10n.createTaskCategoryShopping},
      {'key': 'tutoring', 'label': l10n.createTaskCategoryTutoring},
      {'key': 'translation', 'label': l10n.createTaskCategoryTranslation},
      {'key': 'design', 'label': l10n.createTaskCategoryDesign},
      {'key': 'programming', 'label': l10n.createTaskCategoryProgramming},
      {'key': 'writing', 'label': l10n.createTaskCategoryWriting},
      {'key': 'photography', 'label': l10n.createTaskCategoryPhotography},
      {'key': 'moving', 'label': l10n.createTaskCategoryMoving},
      {'key': 'cleaning', 'label': l10n.createTaskCategoryCleaning},
      {'key': 'repair', 'label': l10n.createTaskCategoryRepair},
      {'key': 'pickup_dropoff', 'label': l10n.createTaskCategoryPickupDropoff},
      {'key': 'cooking', 'label': l10n.createTaskCategoryCooking},
      {'key': 'language_help', 'label': l10n.createTaskCategoryLanguageHelp},
      {'key': 'government', 'label': l10n.createTaskCategoryGovernment},
      {'key': 'pet_care', 'label': l10n.createTaskCategoryPetCare},
      {'key': 'errand', 'label': l10n.createTaskCategoryErrand},
      {'key': 'accompany', 'label': l10n.createTaskCategoryAccompany},
      {'key': 'digital', 'label': l10n.createTaskCategoryDigital},
      {'key': 'rental_housing', 'label': l10n.createTaskCategoryRentalHousing},
      {'key': 'campus_life', 'label': l10n.createTaskCategoryCampusLife},
      {'key': 'second_hand', 'label': l10n.createTaskCategorySecondHand},
      {'key': 'other', 'label': l10n.createTaskCategoryOther},
    ];
  }

  /// 近期论坛帖子
  Widget _buildRecentForumPostsSection(
    BuildContext context,
    List<UserProfileForumPost> posts,
  ) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(l10n.profileRecentPosts,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...posts.take(5).map((p) => Padding(
                key: ValueKey('post_${p.id}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  title: Text(p.displayTitle(Localizations.localeOf(context)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.contentPreview != null && p.contentPreview!.isNotEmpty)
                        Text(
                          p.contentPreview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.thumb_up_outlined, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text('${p.likeCount}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                          const SizedBox(width: 12),
                          const Icon(Icons.comment_outlined, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text('${p.replyCount}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  onTap: () => context.goToForumPostDetail(p.id),
                ),
              )),
        ],
      ),
    );
  }

  /// 已售闲置物品
  Widget _buildSoldFleaItemsSection(
    BuildContext context,
    List<UserProfileFleaItem> items,
  ) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(l10n.profileSoldItems,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = items[index];
                return Semantics(
                  button: true,
                  label: 'View details',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => context.goToFleaMarketDetail('${item.id}'),
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thumbnail
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadius.medium),
                          ),
                          child: item.images.isNotEmpty
                              ? AsyncImageView(
                                  imageUrl: item.images.first,
                                  width: 120,
                                  height: 80,
                                )
                              : Container(
                                  width: 120,
                                  height: 80,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image, color: AppColors.textTertiary),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Helpers.formatPrice(item.price),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedTasksSection(
      BuildContext context, List<Map<String, dynamic>> tasks) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(l10n.sharedTasksTitle, style: AppTypography.title3),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...tasks.map((task) => _buildSharedTaskItem(context, task, isDark)),
          const SizedBox(height: AppSpacing.section),
        ],
      ),
    );
  }

  Widget _buildSharedTaskItem(
      BuildContext context, Map<String, dynamic> task, bool isDark) {
    final l10n = context.l10n;
    final title = task['title'] as String? ?? '';
    final status = task['status'] as String? ?? '';
    final reward = task['reward'] as num? ?? 0;
    final isPoster = task['is_poster'] as bool? ?? false;
    final taskId = task['id'];

    return GestureDetector(
      onTap: () {
        if (taskId != null) {
          final id = taskId is int ? taskId : int.tryParse(taskId.toString());
          if (id != null) context.goToTaskDetail(id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPoster
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPoster ? l10n.sharedTasksRolePoster : l10n.sharedTasksRoleTaker,
                          style: AppTypography.caption2.copyWith(
                            color: isPoster ? AppColors.primary : AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: AppTypography.caption.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (reward > 0)
              Text(
                '${Helpers.currencySymbolFor(task['currency'] as String? ?? 'GBP')}${(reward / 100).toStringAsFixed(2)}',
                style: AppTypography.body.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection(
    BuildContext context,
    List<UserProfileReview> reviews,
  ) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(l10n.profileUserReviews,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...reviews.take(10).map((r) => Padding(
                key: ValueKey('review_${r.createdAt}_${r.rating}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ReviewItem(review: r),
              )),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review});
  final UserProfileReview review;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedStarRating(
                rating: review.rating,
                size: 14,
                spacing: 2,
              ),
              if (review.createdAt.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  _formatReviewTime(context, review.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.comment!,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatReviewTime(BuildContext context, String createdAt) {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return createdAt;
    return DateFormatter.formatRelative(dt, l10n: context.l10n);
  }
}
