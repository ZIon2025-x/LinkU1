import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
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
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/task_detail_bloc.dart';
import 'task_detail_components.dart';

/// 任务详情页
/// 三维条件显示：任务状态 x 用户身份 x 任务来源
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
    // 获取当前用户 ID (响应式)
    final currentUserId = context.select<AuthBloc, String?>(
      (bloc) => bloc.state.user?.id,
    );

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

        // 任务加载完成后，自动加载关联数据
        if (state.isLoaded && state.task != null) {
          _loadAssociatedData(context, state, currentUserId);
        }
      },
      builder: (context, state) {
        final task = state.task;
        final isPoster = task != null && currentUserId == task.posterId;
        final isTaker =
            task != null && task.takerId != null && currentUserId == task.takerId;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(context, state),
          body: _buildBody(context, state, isPoster, isTaker, currentUserId),
          bottomNavigationBar:
              state.isLoaded && task != null
                  ? _buildBottomBar(context, state, isPoster, isTaker)
                  : null,
        );
      },
    );
  }

  /// 加载关联数据 (申请列表、退款状态、评价)
  void _loadAssociatedData(
    BuildContext context,
    TaskDetailState state,
    String? currentUserId,
  ) {
    final bloc = context.read<TaskDetailBloc>();
    final task = state.task!;

    // 加载申请列表 (发布者 + open 状态，或者所有已登录用户用于获取自己的申请状态)
    if (currentUserId != null && !state.isLoadingApplications && state.applications.isEmpty) {
      bloc.add(TaskDetailLoadApplications(currentUserId: currentUserId));
    }

    // 发布者 + pendingConfirmation 时加载退款状态
    final isPoster = currentUserId == task.posterId;
    if (isPoster &&
        task.status == AppConstants.taskStatusPendingConfirmation &&
        !state.isLoadingRefundStatus &&
        state.refundRequest == null) {
      bloc.add(const TaskDetailLoadRefundStatus());
    }

    // 已完成时加载评价
    if (task.status == AppConstants.taskStatusCompleted &&
        !state.isLoadingReviews &&
        state.reviews.isEmpty) {
      bloc.add(const TaskDetailLoadReviews());
    }
  }

  /// 透明AppBar
  PreferredSizeWidget _buildAppBar(
      BuildContext context, TaskDetailState state) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: true,
      leading: Padding(
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
      ),
      actions: [
        if (state.task != null) ...[
          _buildAppBarButton(
            icon: Icons.share_outlined,
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
            onPressed: () {},
          ),
        ],
      ],
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
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

  Widget _buildBody(
    BuildContext context,
    TaskDetailState state,
    bool isPoster,
    bool isTaker,
    String? currentUserId,
  ) {
    if (state.isLoading) {
      return const SkeletonDetail();
    }

    if (state.status == TaskDetailStatus.error) {
      return ErrorStateView(
        message: state.errorMessage ?? context.l10n.homeLoadFailed,
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
          // 图片轮播区域
          _TaskImageCarousel(task: task),

          // 内容区域 - 上移重叠图片
          Transform.translate(
            offset: const Offset(0, -20),
            child: Column(
              children: [
                // 标题和状态卡片
                _TaskHeaderCard(task: task, isDark: isDark),
                const SizedBox(height: AppSpacing.md),

                // 任务信息卡片
                _TaskInfoCard(task: task, isDark: isDark),
                const SizedBox(height: AppSpacing.md),

                // ========== 条件卡片区域 ==========

                // 发布者提示 (isPoster && open)
                if (isPoster && task.status == AppConstants.taskStatusOpen) ...[
                  PosterInfoCard(isDark: isDark),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 确认截止提醒 (pendingConfirmation && isPoster)
                if (task.status ==
                        AppConstants.taskStatusPendingConfirmation &&
                    isPoster &&
                    task.confirmationDeadline != null) ...[
                  ConfirmationReminderCard(
                    deadline: task.confirmationDeadline!,
                    isDark: isDark,
                    onConfirm: () {
                      context.read<TaskDetailBloc>().add(
                          const TaskDetailConfirmCompletionRequested());
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 等待确认卡片 (pendingConfirmation && isTaker)
                if (task.status ==
                        AppConstants.taskStatusPendingConfirmation &&
                    isTaker) ...[
                  WaitingConfirmationCard(isDark: isDark),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 完成证据 (pendingConfirmation || completed + evidence)
                if ((task.status ==
                            AppConstants.taskStatusPendingConfirmation ||
                        task.status ==
                            AppConstants.taskStatusCompleted) &&
                    task.completionEvidence != null &&
                    task.completionEvidence!.isNotEmpty) ...[
                  CompletionEvidenceCard(
                    evidence: task.completionEvidence!,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 申请状态卡片 (非发布者 + 已申请)
                if (!isPoster &&
                    (task.hasApplied || state.userApplication != null) &&
                    (state.userApplication?.status != 'pending' ||
                        task.userApplicationStatus != 'pending')) ...[
                  ApplicationStatusCard(
                    task: task,
                    application: state.userApplication,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 申请列表 (isPoster && open)
                if (isPoster &&
                    task.status == AppConstants.taskStatusOpen) ...[
                  ApplicationsListView(
                    applications: state.applications,
                    isLoading: state.isLoadingApplications,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ========== 操作按钮区域 ==========
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: TaskActionButtonsView(
                    task: task,
                    isPoster: isPoster,
                    isTaker: isTaker,
                    isDark: isDark,
                    state: state,
                  ),
                ),

                // 评价区域 (已完成 + 有评价)
                if (task.status == AppConstants.taskStatusCompleted &&
                    state.reviews.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  TaskReviewsSection(
                    reviews: state.reviews,
                    isDark: isDark,
                  ),
                ],

                // 发布者信息卡片
                const SizedBox(height: AppSpacing.md),
                _TaskPosterCard(
                  task: task,
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    TaskDetailState state,
    bool isPoster,
    bool isTaker,
  ) {
    final task = state.task!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 确定聊天目标
    final chatTargetId = isPoster ? task.takerId : task.posterId;

    // 底部按钮：快速操作栏 (简洁版)
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark
                    ? AppColors.cardBackgroundDark
                    : AppColors.cardBackgroundLight)
                .withValues(alpha: 0.85),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // 聊天按钮 — 有目标时才显示
                  if (chatTargetId != null)
                    IconActionButton(
                      icon: Icons.chat_bubble_outline,
                      onPressed: () {
                        context.push('/chat/$chatTargetId');
                      },
                      backgroundColor: AppColors.skeletonBase,
                    ),
                  if (chatTargetId != null) AppSpacing.hMd,
                  Expanded(
                    child: _buildBottomActionButton(
                        context, state, isPoster, isTaker),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 底部主操作按钮 — 根据状态 + 角色显示最重要的操作
  Widget _buildBottomActionButton(
    BuildContext context,
    TaskDetailState state,
    bool isPoster,
    bool isTaker,
  ) {
    final task = state.task!;

    if (state.isSubmitting) {
      return PrimaryButton(
        text: context.l10n.taskDetailProcessing,
        onPressed: null,
        isLoading: true,
      );
    }

    // 发布者 + 待支付 → 支付按钮
    if (isPoster && task.status == AppConstants.taskStatusPendingPayment) {
      return PrimaryButton(
        text: context.l10n.taskDetailPlatformServiceFee,
        icon: Icons.credit_card,
        onPressed: task.isPaymentExpired ? null : () {},
      );
    }

    // 非发布者 + 可申请
    if (!isPoster && task.canApply) {
      return PrimaryButton(
        text: context.l10n.actionsApplyForTask,
        onPressed: () {
          context
              .read<TaskDetailBloc>()
              .add(const TaskDetailApplyRequested());
        },
      );
    }

    // 非发布者 + 已申请 (pending)
    if (!isPoster && task.hasApplied && task.userApplicationStatus == 'pending') {
      return PrimaryButton(
        text: context.l10n.taskDetailWaitingPosterConfirm,
        onPressed: null,
      );
    }

    // 接单者 + 进行中 → 标记完成
    if (isTaker && task.status == AppConstants.taskStatusInProgress) {
      return PrimaryButton(
        text: context.l10n.actionsMarkComplete,
        onPressed: () {
          context
              .read<TaskDetailBloc>()
              .add(const TaskDetailCompleteRequested());
        },
        gradient: LinearGradient(
          colors: [AppColors.success, AppColors.success.withValues(alpha: 0.8)],
        ),
      );
    }

    // 发布者 + 待确认 → 确认完成
    if (isPoster &&
        task.status == AppConstants.taskStatusPendingConfirmation) {
      return PrimaryButton(
        text: context.l10n.actionsConfirmComplete,
        onPressed: () {
          context.read<TaskDetailBloc>().add(
              const TaskDetailConfirmCompletionRequested());
        },
        gradient: LinearGradient(
          colors: [AppColors.success, AppColors.success.withValues(alpha: 0.8)],
        ),
      );
    }

    // 已完成 + 可评价
    if (task.status == AppConstants.taskStatusCompleted &&
        (isPoster || isTaker) &&
        !task.hasReviewed) {
      return PrimaryButton(
        text: context.l10n.actionsRateTask,
        onPressed: () {
          // TODO: 打开评价弹窗
        },
        gradient: LinearGradient(
          colors: [AppColors.warning, AppColors.warning.withValues(alpha: 0.8)],
        ),
      );
    }

    // 默认：显示状态文本
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
              final imageWidget = AsyncImageView(
                imageUrl: images[index],
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
              );
              return GestureDetector(
                onTap: () {
                  FullScreenImageView.show(
                    context,
                    images: images,
                    initialIndex: index,
                  );
                },
                child: index == 0
                    ? Hero(
                        tag: 'task_image_${widget.task.id}',
                        child: imageWidget,
                      )
                    : imageWidget,
              );
            },
          ),

          // 底部渐变过渡
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Theme.of(context)
                        .scaffoldBackgroundColor
                        .withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),

          // 自定义页面指示器
          if (images.length > 1)
            Positioned(
              bottom: 24,
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
              context.l10n.taskDetailNoImages,
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
// 标题卡片 — 增强版: 来源标签 + 等级标签
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
          // 状态 + 等级 + 来源 标签行
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _buildStatusBadge(),
              TaskLevelBadge(task: task),
              TaskSourceBadge(task: task),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 标题
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

          // 价格
          _buildAmountView(),
          const SizedBox(height: AppSpacing.md),

          // 分类和位置标签
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildTag(
                text: task.displayCategoryText,
                icon: task.isFleaMarketTask
                    ? Icons.shopping_bag
                    : Icons.local_offer,
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

  Widget _buildAmountView() {
    final amount = task.displayReward;
    if (amount <= 0) return const SizedBox.shrink();

    final currencySymbol = task.currency == 'GBP' ? '£' : '\$';
    final priceText = amount.truncateToDouble() == amount
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);

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
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            height: 1.1,
          ),
        ),
      ],
    );
  }

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
// 任务信息卡片
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
          // 描述
          if (task.displayDescription != null &&
              task.displayDescription!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.text_snippet_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.taskDetailTaskDescription,
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

          // 时间信息
          if (task.deadline != null)
            _buildInfoRow(
              icon: Icons.access_time,
              title: context.l10n.taskDetailDeadline,
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
              title: context.l10n.taskDetailPublishTime,
              value: _formatDate(task.createdAt!),
              iconColor: AppColors.primary,
            ),

          // 参与人数 (多人任务)
          if (task.isMultiParticipant) ...[
            const SizedBox(height: AppSpacing.md),
            _buildInfoRow(
              icon: Icons.people_outline,
              title: context.l10n.taskDetailParticipantCount,
              value:
                  '${task.currentParticipants}/${task.maxParticipants}',
              iconColor: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

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
// 发布者信息卡片 — 增强版: 来源感知角色称谓
// ============================================================

class _TaskPosterCard extends StatelessWidget {
  const _TaskPosterCard({required this.task, required this.isDark});
  final Task task;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final roleTitle = getPosterRoleText(task, context);

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
            // 头像
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF0059B3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: task.poster?.avatar != null
                    ? CircleAvatar(
                        backgroundImage:
                            NetworkImage(task.poster!.avatar!),
                        backgroundColor: Colors.transparent,
                      )
                    : const Icon(Icons.person,
                        size: 22, color: Colors.white),
              ),
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
                          task.poster?.name ?? roleTitle,
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
              roleTitle,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.backgroundDark
                    : AppColors.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right,
                size: 14,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
