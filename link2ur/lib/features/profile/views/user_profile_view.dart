import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/native_share.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user.dart' show User, UserProfileReview, UserProfileForumPost;
import '../../../data/models/task.dart' show CreateTaskRequest;
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/follow_repository.dart';
import '../../../core/router/app_router.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/profile_bloc.dart';
import 'widgets/b_section_card.dart';
import 'widgets/forum_post_row.dart';
import 'widgets/personal_services_section.dart';
import 'widgets/review_mini.dart';
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
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final fg = isDark ? Colors.white : const Color(0xFF1A1D1F);
            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                title: const SizedBox.shrink(),
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                foregroundColor: fg,
                actions: state.publicUser == null
                    ? null
                    : [
                        IconButton(
                          icon: const Icon(Icons.ios_share_rounded),
                          tooltip: l10n.commonShare,
                          onPressed: () =>
                              _shareUserProfile(context, state.publicUser!),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz_rounded),
                          tooltip: l10n.commonMore,
                          onSelected: (value) =>
                              _onMoreSelected(context, value, state.publicUser!),
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'copy_link',
                              child: Row(
                                children: [
                                  const Icon(Icons.link, size: 18),
                                  const SizedBox(width: 8),
                                  Text(l10n.commonCopyLink),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                      ],
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
                                        const SizedBox(height: AppSpacing.md),
                                        // 你和 TA 的合作（老用户决策核心，置顶）
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
                                          userId: userId,
                                          services: state.publicProfileDetail?.personalServices ?? const [],
                                          totalServices: state.publicProfileDetail?.stats.totalPersonalServices ?? 0,
                                        ),
                                        // 收到的评价
                                        if (state.publicProfileDetail?.reviews.isNotEmpty == true)
                                          _ReviewsBlock(
                                            userId: userId,
                                            reviews:
                                                state.publicProfileDetail!.reviews,
                                            avgRating: state.publicUser?.avgRating,
                                            totalReviews:
                                                state.publicProfileDetail?.stats.totalReviews ?? 0,
                                          ),
                                        // TA 的论坛动态
                                        if (state.publicProfileDetail?.recentForumPosts.isNotEmpty == true)
                                          _buildRecentForumPostsSection(
                                            context,
                                            posts: state.publicProfileDetail!.recentForumPosts,
                                            totalPosts: state.publicProfileDetail?.stats.totalForumPosts ?? 0,
                                          ),
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

  static String _profileUrl(String userId) =>
      'https://link2ur.com/user/$userId';

  Future<void> _shareUserProfile(BuildContext context, User user) async {
    final url = _profileUrl(user.id);
    final name = user.displayNameWith(context.l10n);
    await NativeShare.share(
      title: name,
      description: user.bio ?? '',
      url: url,
    );
  }

  void _onMoreSelected(BuildContext context, String value, User user) {
    final l10n = context.l10n;
    switch (value) {
      case 'copy_link':
        Clipboard.setData(ClipboardData(text: _profileUrl(user.id)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonLinkCopied)),
        );
        break;
    }
  }

  /// 底部固定：发布任务请求按钮（紫蓝渐变 CTA · 对齐 Plan B）
  Widget _buildBottomRequestButton(BuildContext context, User user) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showDirectRequestSheet(context, user),
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5B6CFF), Color(0xFF8B5BFF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B6CFF).withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded,
                      size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    l10n.profileDirectRequest,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
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

  /// TA 的论坛动态（Plan B section）
  /// 后端只返回前 3 条最热帖子;[totalPosts] 是真实总数,用于副标题 + 决定 "全部 >"。
  Widget _buildRecentForumPostsSection(
    BuildContext context, {
    required List<UserProfileForumPost> posts,
    required int totalPosts,
  }) {
    final l10n = context.l10n;
    final visiblePosts = posts.take(3).toList();
    final shownCount = totalPosts > 0 ? totalPosts : posts.length;
    final hasMore = shownCount > visiblePosts.length;
    return BSectionCard(
      title: l10n.profileRecentPosts,
      subtitle: l10n.profileForumPostsCount(shownCount),
      moreLabel: hasMore ? l10n.commonViewAll : null,
      onTapMore: hasMore
          ? () => context.goToUserForumPosts(
                userId,
                totalPosts: shownCount,
              )
          : null,
      children: [
        for (var i = 0; i < visiblePosts.length; i++)
          ForumPostRow(
            post: visiblePosts[i],
            colorIndex: i,
            showDivider: i > 0,
          ),
      ],
    );
  }

  /// 你和 TA 的合作（Plan B 置顶 section）
  Widget _buildSharedTasksSection(
      BuildContext context, List<Map<String, dynamic>> tasks) {
    final l10n = context.l10n;
    return BSectionCard(
      title: l10n.profileSharedWithYou,
      subtitle: l10n.profileSharedTasksCount(tasks.length),
      children: [
        for (var i = 0; i < tasks.length; i++)
          _SharedTaskRow(task: tasks[i], showDivider: i > 0),
      ],
    );
  }

}

/// 收到的评价（Plan B section · 头像 + 姓名 + 星级 + 时间 + 评论）。
/// 默认展示 3 条；点击底部按钮展开至最多 10 条，再次点击折叠。
class _ReviewsBlock extends StatelessWidget {
  const _ReviewsBlock({
    required this.userId,
    required this.reviews,
    required this.avgRating,
    required this.totalReviews,
  });

  final String userId;
  final List<UserProfileReview> reviews;
  final double? avgRating;
  final int totalReviews;

  static const _previewCount = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ratingText =
        avgRating != null ? avgRating!.toStringAsFixed(1) : '-';
    final shownCount = totalReviews > 0 ? totalReviews : reviews.length;
    final visible = reviews.take(_previewCount).toList();
    final hasMore = shownCount > visible.length;

    return BSectionCard(
      title: l10n.profileUserReviews,
      subtitle: l10n.profileReviewsSubtitle(ratingText, shownCount),
      moreLabel: hasMore ? l10n.commonViewAll : null,
      onTapMore: hasMore
          ? () => context.goToUserReviews(
                userId,
                totalReviews: shownCount,
                avgRating: avgRating,
              )
          : null,
      children: [
        for (var i = 0; i < visible.length; i++)
          ReviewMini(review: visible[i], showDivider: i > 0),
        if (hasMore) ...[
          const SizedBox(height: 12),
          _ViewAllReviewsButton(
            label: l10n.profileViewAllReviewsCount(shownCount),
            onTap: () => context.goToUserReviews(
              userId,
              totalReviews: shownCount,
              avgRating: avgRating,
            ),
          ),
        ],
      ],
    );
  }
}

/// 单条合作记录行（b-task-row）：彩色图标块 + 标题 + 角色 tag + 价格右贴。
class _SharedTaskRow extends StatelessWidget {
  const _SharedTaskRow({required this.task, required this.showDivider});

  final Map<String, dynamic> task;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = task['title'] as String? ?? '';
    final status = task['status'] as String? ?? '';
    final reward = task['reward'] as num? ?? 0;
    final isPoster = task['is_poster'] as bool? ?? false;
    final taskId = task['id'];

    return InkWell(
      onTap: () {
        if (taskId == null) return;
        final id = taskId is int ? taskId : int.tryParse(taskId.toString());
        if (id != null) context.goToTaskDetail(id);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  top: BorderSide(color: Color(0xFFF0F1F4)),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.description_outlined,
                  color: Color(0xFF4F46E5), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _RoleTag(
                        label: isPoster
                            ? l10n.sharedTasksRolePoster
                            : l10n.sharedTasksRoleTaker,
                        isPoster: isPoster,
                      ),
                      if (status.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· $status',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9A9FA5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (reward > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${Helpers.currencySymbolFor(task['currency'] as String? ?? 'GBP')}${(reward / 100).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.label, required this.isPoster});
  final String label;
  final bool isPoster;

  @override
  Widget build(BuildContext context) {
    final bg = isPoster ? const Color(0xFFEEF0FF) : const Color(0xFFD1FAE5);
    final fg = isPoster ? const Color(0xFF4338CA) : const Color(0xFF047857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }
}

// _ReviewMini 已迁移到 widgets/review_mini.dart 作为公共组件 ReviewMini，
// 供他人主页 section 内联预览与「全部评价」独立页共用。

/// "查看全部 X 条评价" 按钮（b-review-all-btn）。
class _ViewAllReviewsButton extends StatelessWidget {
  const _ViewAllReviewsButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4D5560),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Color(0xFF4D5560),
            ),
          ],
        ),
      ),
    );
  }
}

// _ForumPostRow 已迁移到 widgets/forum_post_row.dart 作为公共组件 ForumPostRow，
// 供他人主页 section 内联预览与「TA 的论坛动态」独立页共用。
