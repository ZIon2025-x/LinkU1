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
import '../../../core/widgets/animated_star_rating.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user.dart' show User, UserProfileDetail, UserProfileReview, UserProfileForumPost;
import '../../../data/models/task.dart' show CreateTaskRequest;
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/follow_repository.dart';
import '../../../core/router/app_router.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/profile_bloc.dart';
import 'widgets/personal_services_section.dart';
import 'widgets/user_profile_hero_card.dart';

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
                                        BlocBuilder<AuthBloc, AuthState>(
                                          buildWhen: (prev, curr) =>
                                              prev.user?.id != curr.user?.id ||
                                              prev.status != curr.status,
                                          builder: (context, authState) {
                                            final currentUserId = authState.status == AuthStatus.authenticated
                                                ? authState.user?.id
                                                : null;
                                            final isSelf = currentUserId == state.publicUser!.id;
                                            return UserProfileHeroCard(
                                              user: state.publicUser!,
                                              followersCount: state.followersCount,
                                              followingCount: state.followingCount,
                                              totalReviews: state.publicProfileDetail?.stats.totalReviews ?? 0,
                                              isSelf: isSelf,
                                              isFollowing: state.isFollowing,
                                              isFollowLoading: state.isFollowLoading,
                                              onFollow: () {
                                                if (state.isFollowing) {
                                                  context.read<ProfileBloc>().add(ProfileUnfollowUser(state.publicUser!.id));
                                                } else {
                                                  context.read<ProfileBloc>().add(ProfileFollowUser(state.publicUser!.id));
                                                }
                                              },
                                            );
                                          },
                                        ),
                                        const SizedBox(height: AppSpacing.lg),
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
                                        // 个人服务（widget 内部判空，无服务时折叠）
                                        PersonalServicesSection(
                                          services: state.publicProfileDetail?.personalServices ?? const [],
                                        ),
                                        // 收到的评价
                                        if (state.publicProfileDetail?.reviews.isNotEmpty == true)
                                          _buildReviewsSection(context, state.publicProfileDetail!.reviews),
                                        // 近期任务（后端 recent_tasks，该用户近期发布或参与的任务，最多 5 条）
                                        _buildRecentTasksSection(context, state.publicProfileDetail),
                                        // 近期论坛帖子
                                        if (state.publicProfileDetail?.recentForumPosts.isNotEmpty == true)
                                          _buildRecentForumPostsSection(context, state.publicProfileDetail!.recentForumPosts),
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
                        '${t.status} · ${Helpers.formatPrice(t.reward, currency: t.currency)}',
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
