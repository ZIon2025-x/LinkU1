import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/stat_item.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/animated_circular_progress.dart';
import '../../../core/widgets/animated_star_rating.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/skill_radar_chart.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user.dart' show User, UserProfileDetail, UserProfileReview, UserProfileForumPost, UserProfileFleaItem;
import '../../../data/models/task.dart' show CreateTaskRequest;
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../core/router/app_router.dart';
import '../bloc/profile_bloc.dart';

/// 公开用户资料页
/// 参考iOS UserProfileView.swift
class UserProfileView extends StatefulWidget {
  const UserProfileView({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
      )..add(ProfileLoadPublicProfile(widget.userId)),
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.profileUserProfile),
            ),
            body: state.isLoading
                ? const LoadingView()
                : state.errorMessage != null
                    ? ErrorStateView(
                        message: state.errorMessage!,
                        onRetry: () {
                          context.read<ProfileBloc>().add(
                                ProfileLoadPublicProfile(widget.userId),
                              );
                        },
                      )
                    : state.publicUser == null
                        ? const SizedBox.shrink()
                        : RefreshIndicator(
                            onRefresh: () async {
                              context.read<ProfileBloc>().add(
                                    ProfileLoadPublicProfile(widget.userId),
                                  );
                            },
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  // 用户信息卡片
                                  _buildUserInfoCard(context, state.publicUser!),
                                  // 指定任务请求按钮
                                  _buildDirectRequestButton(context, state.publicUser!),
                                  // 统计数据
                                  _buildStatsRow(context, state.publicUser!),
                                  const SizedBox(height: AppSpacing.md),
                                  // 技能雷达图
                                  _buildSkillRadar(context, state.publicUser!),
                                  // 近期任务
                                  _buildRecentTasksSection(context, state.publicProfileDetail),
                                  // 近期论坛帖子
                                  if (state.publicProfileDetail?.recentForumPosts.isNotEmpty == true)
                                    _buildRecentForumPostsSection(context, state.publicProfileDetail!.recentForumPosts),
                                  // 已售闲置物品
                                  if (state.publicProfileDetail?.soldFleaItems.isNotEmpty == true)
                                    _buildSoldFleaItemsSection(context, state.publicProfileDetail!.soldFleaItems),
                                  // 收到的评价
                                  if (state.publicProfileDetail?.reviews.isNotEmpty == true)
                                    _buildReviewsSection(context, state.publicProfileDetail!.reviews),
                                  const SizedBox(height: AppSpacing.xl),
                                ],
                              ),
                            ),
                          ),
          );
        },
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, User user) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
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
          // 头像（使用 AvatarView 正确处理相对路径）
          AvatarView(
            imageUrl: user.avatar,
            name: user.displayNameWith(context.l10n),
            size: 88,
          ),
          const SizedBox(height: AppSpacing.md),

          // 名称 + 徽章
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.displayNameWith(context.l10n),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: AppColors.primary, size: 20),
              ],
              if (user.isStudentVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.school, color: Colors.blue, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // 简介
          if (user.bio != null && user.bio!.isNotEmpty)
            Text(
              user.bio!,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

          // 居住城市
          if (user.residenceCity != null &&
              user.residenceCity!.isNotEmpty) ...[
            const SizedBox(height: 8),
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

          // 评分
          if (user.avgRating != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  user.ratingDisplay,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, User user) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
          // 总任务数 — 保持 StatItem
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
      padding: const EdgeInsets.all(AppSpacing.md),
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
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(l10n.profileRecentTasks,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
            ...tasks.take(5).map((t) => Padding(
                  key: ValueKey('task_${t.id}'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    title: Text(t.displayTitle(Localizations.localeOf(context)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${t.status} · £${t.reward.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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

  /// 指定任务请求按钮
  Widget _buildDirectRequestButton(BuildContext context, User user) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showDirectRequestSheet(context, user),
          icon: const Icon(Icons.send, size: 18),
          label: Text(l10n.profileDirectRequest),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
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
                    // 拖拽手柄
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
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

                    // 价格 + 地点（一行两列）
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.profileDirectRequestHintPrice,
                              prefixText: '£ ',
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
                    const SizedBox(height: AppSpacing.md),

                    // 任务类型
                    DropdownButtonFormField<String>(
                      value: selectedTaskType,
                      decoration: InputDecoration(
                        labelText: l10n.profileDirectRequestHintTaskType,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                      ),
                      items: _getLocalizedTaskTypes(ctx)
                          .map((entry) => DropdownMenuItem(
                                value: entry['key'],
                                child: Text(entry['label']!),
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
                    GestureDetector(
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
                              ? GestureDetector(
                                  onTap: () => setSheetState(
                                      () => selectedDeadline = null),
                                  child: const Icon(Icons.close, size: 18),
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
                                    priceController.text.trim());
                                if (title.isEmpty ||
                                    price == null ||
                                    price < 1) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                        content: Text(l10n
                                            .profileDirectRequestValidation)),
                                  );
                                  return;
                                }

                                final taskRepo =
                                    context.read<TaskRepository>();
                                setSheetState(() => isSubmitting = true);
                                try {
                                  final loc =
                                      locationController.text.trim();
                                  await taskRepo.createTask(
                                    CreateTaskRequest(
                                      title: title,
                                      description: descriptionController
                                              .text
                                              .trim()
                                              .isNotEmpty
                                          ? descriptionController.text
                                              .trim()
                                          : null,
                                      taskType: selectedTaskType,
                                      location:
                                          loc.isNotEmpty ? loc : 'Online',
                                      reward: price,
                                      deadline: selectedDeadline,
                                      isPublic: 0,
                                      taskSource: 'user_profile',
                                      designatedTakerId: user.id,
                                    ),
                                  );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text(l10n
                                              .profileDirectRequestSuccess)),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(
                                      () => isSubmitting = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text(e.toString())),
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
    ).then((_) {
      titleController.dispose();
      descriptionController.dispose();
      priceController.dispose();
      locationController.dispose();
    });
  }

  List<Map<String, String>> _getLocalizedTaskTypes(BuildContext context) {
    final l10n = context.l10n;
    return [
      {'key': 'delivery', 'label': l10n.createTaskCategoryDelivery},
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(l10n.profileRecentPosts,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...posts.take(5).map((p) => Padding(
                key: ValueKey('post_${p.id}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(l10n.profileSoldItems,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
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
                                '£${item.price.toStringAsFixed(2)}',
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(
    BuildContext context,
    List<UserProfileReview> reviews,
  ) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(l10n.profileUserReviews,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...reviews.take(5).map((r) => _ReviewItem(review: r)),
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
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
            const SizedBox(height: 6),
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
