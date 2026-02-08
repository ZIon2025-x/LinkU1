import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/custom_share_panel.dart';
import '../../../core/widgets/user_identity_badges.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../bloc/task_detail_bloc.dart';

/// 任务详情页
/// 参考iOS TaskDetailView.swift + TaskDetailContentView
class TaskDetailView extends StatelessWidget {
  const TaskDetailView({super.key, required this.taskId});

  final int taskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskDetailBloc(
        taskRepository: context.read<TaskRepository>(),
      )..add(TaskDetailLoadRequested(taskId)),
      child: const _TaskDetailContent(),
    );
  }
}

class _TaskDetailContent extends StatelessWidget {
  const _TaskDetailContent();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskDetailBloc, TaskDetailState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != null &&
          prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(context, state),
          body: _buildBody(context, state),
          bottomNavigationBar:
              state.isLoaded && state.task != null
                  ? _buildBottomBar(context, state)
                  : null,
        );
      },
    );
  }

  /// 透明AppBar (对齐iOS - 图片延伸到状态栏下方)
  PreferredSizeWidget _buildAppBar(
      BuildContext context, TaskDetailState state) {
    final hasImages =
        state.task != null && state.task!.images.isNotEmpty;

    return AppBar(
      backgroundColor:
          hasImages ? Colors.transparent : null,
      elevation: 0,
      leading: _buildBackButton(context, hasImages),
      actions: [
        if (state.task != null) ...[
          _buildAppBarButton(
            icon: Icons.share_outlined,
            hasImages: hasImages,
            onPressed: () {
              HapticFeedback.selectionClick();
              CustomSharePanel.show(
                context,
                title: state.task!.displayTitle,
                description: state.task!.displayDescription ?? '',
                url: 'https://link2ur.com/tasks/${state.task!.id}',
              );
            },
          ),
          _buildAppBarButton(
            icon: Icons.more_horiz,
            hasImages: hasImages,
            onPressed: () {},
          ),
        ],
      ],
    );
  }

  /// 返回按钮 (对齐iOS - 图片上方用白色圆底)
  Widget _buildBackButton(BuildContext context, bool hasImages) {
    if (!hasImages) {
      return const BackButton();
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Colors.white),
        ),
      ),
    );
  }

  /// AppBar上的圆形按钮
  Widget _buildAppBarButton({
    required IconData icon,
    required bool hasImages,
    required VoidCallback onPressed,
  }) {
    if (!hasImages) {
      return IconButton(icon: Icon(icon), onPressed: onPressed);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TaskDetailState state) {
    if (state.isLoading) {
      return const SkeletonDetail();
    }

    if (state.status == TaskDetailStatus.error) {
      return ErrorStateView(
        message: state.errorMessage ?? '加载失败',
        onRetry: () {
          final bloc = context.read<TaskDetailBloc>();
          if (state.task != null) {
            bloc.add(TaskDetailLoadRequested(state.task!.id));
          }
        },
      );
    }

    final task = state.task;
    if (task == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片轮播区域 (对齐iOS TaskImageCarouselView - 300pt)
          _TaskImageCarousel(task: task),

          // 内容区域 - 上移重叠图片 (对齐iOS padding .top -20)
          Transform.translate(
            offset: const Offset(0, -20),
            child: Column(
              children: [
                // 标题和状态卡片 (对齐iOS TaskHeaderCard)
                _TaskHeaderCard(task: task, isDark: isDark),
                const SizedBox(height: AppSpacing.md),

                // 任务信息卡片 (对齐iOS TaskInfoCard)
                _TaskInfoCard(task: task, isDark: isDark),
                const SizedBox(height: AppSpacing.md),

                // 发布者信息卡片
                _TaskPosterCard(task: task, isDark: isDark),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, TaskDetailState state) {
    final task = state.task!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconActionButton(
              icon: Icons.chat_bubble_outline,
              onPressed: () {
                context.push('/chat/${task.posterId}');
              },
              backgroundColor: AppColors.skeletonBase,
            ),
            AppSpacing.hMd,
            Expanded(
              child: _buildActionButton(context, state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, TaskDetailState state) {
    final task = state.task!;

    if (state.isSubmitting) {
      return const PrimaryButton(
        text: '处理中...',
        onPressed: null,
        isLoading: true,
      );
    }

    if (task.canApply) {
      return PrimaryButton(
        text: '申请接单',
        onPressed: () {
          context
              .read<TaskDetailBloc>()
              .add(const TaskDetailApplyRequested());
        },
      );
    }

    if (task.hasApplied) {
      return PrimaryButton(
        text: '取消申请',
        onPressed: () {
          context.read<TaskDetailBloc>().add(
              const TaskDetailCancelApplicationRequested());
        },
      );
    }

    if (task.status == 'in_progress') {
      return PrimaryButton(
        text: '完成任务',
        onPressed: () {
          context
              .read<TaskDetailBloc>()
              .add(const TaskDetailCompleteRequested());
        },
      );
    }

    if (task.status == 'pending_confirmation') {
      return PrimaryButton(
        text: '确认完成',
        onPressed: () {
          context.read<TaskDetailBloc>().add(
              const TaskDetailConfirmCompletionRequested());
        },
      );
    }

    return PrimaryButton(
      text: task.statusText,
      onPressed: null,
    );
  }
}

// ============================================================
// 图片轮播 (对齐iOS TaskImageCarouselView)
// ============================================================

class _TaskImageCarousel extends StatefulWidget {
  const _TaskImageCarousel({required this.task});
  final Task task;

  @override
  State<_TaskImageCarousel> createState() => _TaskImageCarouselState();
}

class _TaskImageCarouselState extends State<_TaskImageCarousel> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.task.images;

    if (images.isEmpty) {
      return _buildPlaceholder();
    }

    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 占位背景（避免闪烁）
          Container(
            height: 300,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
          ),

          // 图片PageView
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  FullScreenImageView.show(
                    context,
                    images: images,
                    initialIndex: index,
                  );
                },
                child: AsyncImageView(
                  imageUrl: images[index],
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),

          // 自定义页面指示器 (对齐iOS - Capsule dots + 毛玻璃背景)
          if (images.length > 1)
            Positioned(
              bottom: 24, // 避开下方卡片的圆角
              child: ClipRRect(
                borderRadius: AppRadius.allPill,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: AppRadius.allPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        images.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPage == index ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: AppRadius.allPill,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 无图片占位 (对齐iOS - gradient + icon + text)
  Widget _buildPlaceholder() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 60,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '暂无图片',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 标题卡片 (对齐iOS TaskHeaderCard)
// ============================================================

class _TaskHeaderCard extends StatelessWidget {
  const _TaskHeaderCard({required this.task, required this.isDark});
  final Task task;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xlarge),
          topRight: Radius.circular(AppRadius.xlarge),
          bottomLeft: Radius.circular(AppRadius.large),
          bottomRight: Radius.circular(AppRadius.large),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态标签行 (对齐iOS HStack: taskLevel + StatusBadge)
          Row(
            children: [
              _buildStatusBadge(),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 标题 (对齐iOS AppTypography.title)
          Text(
            task.displayTitle,
            style: AppTypography.title2.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.sm),

          // 价格 (对齐iOS TaskAmountView - 大号)
          _buildAmountView(),
          const SizedBox(height: AppSpacing.md),

          // 分类和位置标签 (对齐iOS HStack: TaskTagView)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildTag(
                text: task.taskTypeText,
                icon: Icons.local_offer,
                isPrimary: true,
              ),
              _buildTag(
                text: task.location ?? 'Online',
                icon: task.isOnline
                    ? Icons.language
                    : Icons.location_on,
                isPrimary: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 状态徽章 (对齐iOS StatusBadge)
  Widget _buildStatusBadge() {
    final color = AppColors.taskStatusColor(task.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.allSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            task.statusText,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 金额视图 (对齐iOS TaskAmountView)
  Widget _buildAmountView() {
    if (task.reward <= 0) return const SizedBox.shrink();

    final currencySymbol = task.currency == 'GBP' ? '£' : '\$';
    final priceText = task.reward.truncateToDouble() == task.reward
        ? task.reward.toStringAsFixed(0)
        : task.reward.toStringAsFixed(2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          currencySymbol,
          style: AppTypography.title3.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          priceText,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  /// 标签组件 (对齐iOS TaskTagView)
  Widget _buildTag({
    required String text,
    required IconData icon,
    required bool isPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.primaryLight.withValues(alpha: 0.3)
            : (isDark
                ? AppColors.backgroundDark
                : AppColors.backgroundLight),
        borderRadius: AppRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isPrimary
                ? AppColors.primary
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: isPrimary
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 任务信息卡片 (对齐iOS TaskInfoCard)
// ============================================================

class _TaskInfoCard extends StatelessWidget {
  const _TaskInfoCard({required this.task, required this.isDark});
  final Task task;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 描述 (对齐iOS TaskInfoCard - 描述区域)
          if (task.displayDescription != null &&
              task.displayDescription!.isNotEmpty) ...[
            // 描述标题 (对齐iOS: icon + "任务描述")
            Row(
              children: [
                Icon(
                  Icons.text_snippet_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '任务描述',
                  style: AppTypography.title3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              task.displayDescription!,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(
              color: isDark
                  ? AppColors.dividerDark
                  : AppColors.dividerLight,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 时间信息 (对齐iOS TaskTimeInfoView)
          if (task.deadline != null)
            _buildInfoRow(
              icon: Icons.access_time,
              title: '截止时间',
              value: _formatDate(task.deadline!),
              iconColor: _isDeadlineUrgent(task.deadline!)
                  ? AppColors.error
                  : AppColors.primary,
            ),
          if (task.deadline != null)
            const SizedBox(height: AppSpacing.md),

          if (task.createdAt != null)
            _buildInfoRow(
              icon: Icons.calendar_today,
              title: '发布时间',
              value: _formatDate(task.createdAt!),
              iconColor: AppColors.primary,
            ),

          // 参与人数 (多人任务)
          if (task.isMultiParticipant) ...[
            const SizedBox(height: AppSpacing.md),
            _buildInfoRow(
              icon: Icons.people_outline,
              title: '参与人数',
              value:
                  '${task.currentParticipants}/${task.maxParticipants}',
              iconColor: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  /// 信息行 (对齐iOS TaskInfoRow: circle icon + title/value)
  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color:
                (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor ?? AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  bool _isDeadlineUrgent(DateTime deadline) {
    return deadline.difference(DateTime.now()).inHours < 24;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// 发布者信息卡片 (对齐iOS TaskPosterInfoView)
// ============================================================

class _TaskPosterCard extends StatelessWidget {
  const _TaskPosterCard({required this.task, required this.isDark});
  final Task task;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: task.poster != null
            ? () {
                HapticFeedback.selectionClick();
                context.push('/chat/${task.posterId}');
              }
            : null,
        child: Row(
          children: [
            // 头像 (对齐iOS AsyncImageView 50x50 circle)
            AvatarView(
              imageUrl: task.poster?.avatar,
              name: task.poster?.name ?? '发布者',
              size: 50,
            ),
            const SizedBox(width: AppSpacing.md),

            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          task.poster?.name ?? '发布者',
                          style: AppTypography.bodyBold.copyWith(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.poster?.isVerified == true) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 16, color: Colors.blue),
                      ],
                    ],
                  ),
                  if (task.poster?.isVerified == true) ...[
                    const SizedBox(height: 4),
                    UserIdentityBadges(
                      isStudentVerified: task.poster?.isVerified,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),

            // 角色标签 + 箭头
            Text(
              '发布者',
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}
