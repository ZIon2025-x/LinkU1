import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/haptic_feedback.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/review_bottom_sheet.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/utils/native_share.dart';
import '../../../core/widgets/user_identity_badges.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/page_transitions.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/task_type_helper.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/task_status_helper.dart';
import '../../../data/models/task.dart';
import '../../../data/models/review.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/task_detail_bloc.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/bouncing_widget.dart';
import '../../../core/design/app_shadows.dart';
import 'approval_payment_page.dart';
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
      child: _TaskDetailContent(taskId: taskId),
    );
  }
}

class _TaskDetailContent extends StatelessWidget {
  const _TaskDetailContent({required this.taskId});
  final int taskId;

  @override
  Widget build(BuildContext context) {
    // 获取当前用户 ID (响应式)
    final currentUserId = context.select<AuthBloc, String?>(
      (bloc) => bloc.state.user?.id,
    );

    return BlocConsumer<TaskDetailBloc, TaskDetailState>(
      listenWhen: (prev, curr) =>
          // 操作消息提示
          (curr.actionMessage != null &&
              prev.actionMessage != curr.actionMessage) ||
          // 首次加载完成时触发关联数据加载
          (!prev.isLoaded && curr.isLoaded && curr.task != null),
      listener: (context, state) {
        // 批准申请后需支付：用全屏路由打开支付页，否则在 Modal 内调 Stripe PaymentSheet 时原生银行卡/支付宝表单无法弹出
        if (state.actionMessage == 'open_payment' &&
            state.acceptPaymentData != null) {
          final data = state.acceptPaymentData!;
          final taskId = state.task?.id;
          final bloc = context.read<TaskDetailBloc>();
          bloc.add(const TaskDetailClearAcceptPaymentData());
          pushWithSwipeBack<bool>(
                context,
                ApprovalPaymentPage(paymentData: data),
                fullscreenDialog: true,
              )
              .then((result) {
            if (!context.mounted) return;
            if (result == true) {
              if (taskId != null) {
                context.read<TaskDetailBloc>().add(TaskDetailLoadRequested(taskId));
                context.read<TaskDetailBloc>().add(TaskDetailLoadApplications(
                    currentUserId: currentUserId));
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.paymentSuccessMessage),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          });
          return;
        }

        if (state.actionMessage == 'stripe_setup_required') {
          showDialog<void>(
            context: context,
            builder: (d) => AlertDialog(
              icon: const Icon(Icons.account_balance_wallet_outlined,
                  size: 40, color: AppColors.primary),
              title: Text(context.l10n.stripeSetupRequired),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(d);
                    context.push('/wallet');
                  },
                  child: Text(context.l10n.stripeSetupAction),
                ),
              ],
            ),
          );
          return;
        }

        if (state.actionMessage != null) {
          final l10n = context.l10n;
          final message = switch (state.actionMessage) {
            'application_submitted' => l10n.actionApplicationSubmitted,
            'application_failed' => l10n.actionApplicationFailed,
            'application_cancelled' => l10n.actionApplicationCancelled,
            'cancel_failed' => l10n.actionCancelFailed,
            'application_accepted' => l10n.actionApplicationAccepted,
            'application_rejected' => l10n.actionApplicationRejected,
            'operation_failed' => l10n.actionOperationFailed,
            'task_completed' => l10n.actionTaskCompleted,
            'submit_failed' => l10n.actionSubmitFailed,
            'completion_confirmed' => l10n.actionCompletionConfirmed,
            'confirm_failed' => l10n.actionConfirmFailed,
            'task_cancelled' => l10n.actionTaskCancelled,
            'review_submitted' => l10n.actionReviewSubmitted,
            'review_failed' => l10n.actionReviewFailed,
            'refund_submitted' => l10n.actionRefundSubmitted,
            'refund_failed' => l10n.actionRefundFailed,
            'refund_revoked' => l10n.actionRefundRevoked,
            'revoke_failed' => l10n.actionRevokeFailed,
            'dispute_submitted' => l10n.actionDisputeSubmitted,
            'dispute_failed' => l10n.actionDisputeFailed,
            _ => state.actionMessage ?? '',
          };
          final isError = state.actionMessage!.contains('failed') ||
              state.actionMessage == 'cancel_failed' ||
              state.actionMessage == 'operation_failed';
          final displayMessage = isError && state.errorMessage != null
              ? '$message: ${state.errorMessage}'
              : message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(displayMessage),
              backgroundColor: isError ? AppColors.error : null,
            ),
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
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveUtils.detailMaxWidth(context)),
              child: _buildBody(context, state, isPoster, isTaker, currentUserId),
            ),
          ),
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

    // 发布者或接单者 + pendingConfirmation 时加载退款状态
    final isPoster = currentUserId == task.posterId;
    final isTaker = currentUserId == task.takerId;
    if ((isPoster || isTaker) &&
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
        padding: const EdgeInsets.all(8),
        child: GlassButton(
          onTap: () {
            AppHaptics.selection();
            Navigator.of(context).pop();
          },
          child: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Colors.white),
        ),
      ),
      actions: [
        if (state.task != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GlassButton(
              onTap: () {
                AppHaptics.selection();
                _showMoreMenu(context, state);
              },
              child: const Icon(Icons.more_horiz, size: 20, color: Colors.white),
            ),
          ),
      ],
    );
  }

  /// 更多菜单 - 对标iOS ellipsis.circle Menu（分享 + 争议详情 + 取消任务）
  void _showMoreMenu(BuildContext context, TaskDetailState state) {
    final task = state.task;
    if (task == null) return;
    final l10n = context.l10n;
    final hasDisputeOrRefund = state.refundRequest != null ||
        task.status == AppConstants.taskStatusPendingConfirmation;
    final currentUserId = context.read<AuthBloc>().state.user?.id;
    final isPoster = currentUserId != null && task.posterId == currentUserId;
    final isTaker = currentUserId != null &&
        task.takerId != null &&
        task.takerId == currentUserId;
    final canCancel = (isPoster || isTaker) &&
        (task.status == AppConstants.taskStatusOpen ||
            task.status == AppConstants.taskStatusInProgress);

    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.cardBackgroundDark
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 不画自定义拖拽条：主题 showDragHandle: true 已提供
              // 争议详情（条件显示） - 对标iOS disputeDetail
              if (hasDisputeOrRefund)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(l10n.taskDetailDisputeDetail),
                  onTap: () {
                    Navigator.pop(context);
                    _showDisputeTimeline(context, task);
                  },
                ),
              // 取消任务（条件显示）- 发布者/接单者 + open/in_progress
              if (canCancel)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
                  title: Text(
                    l10n.actionsCancelTask,
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCancelTaskConfirm(context, task.id);
                  },
                ),
              // 分享 - 对标 iOS 直接调起系统分享（标题+描述+链接）
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(l10n.taskDetailShare),
                onTap: () async {
                  Navigator.pop(context);
                  final locale = Localizations.localeOf(context);
                  final imageUrl = task.images.isNotEmpty ? task.images.first : null;
                  final shareFiles = await NativeShare.fileFromFirstImageUrl(imageUrl);
                  if (!context.mounted) return;
                  await NativeShare.share(
                    title: task.displayTitle(locale),
                    description: task.displayDescription(locale) ?? '',
                    url: 'https://link2ur.com/tasks/${task.id}',
                    files: shareFiles,
                    context: context,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 取消任务确认弹窗
  void _showCancelTaskConfirm(BuildContext context, int taskId) {
    final l10n = context.l10n;
    SheetAdaptation.showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.taskDetailCancelTask),
        content: Text(l10n.taskDetailCancelTaskConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.taskDetailCancelTask),
          ),
        ],
      ),
    ).then((confirmed) {
      if (!context.mounted || confirmed != true) return;
      context.read<TaskDetailBloc>().add(const TaskDetailCancelRequested());
    });
  }

  /// 显示争议时间线 - 对标iOS showDisputeTimeline
  void _showDisputeTimeline(BuildContext context, Task task) {
    final locale = Localizations.localeOf(context);
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _DisputeTimelineSheet(
        taskId: task.id,
        taskTitle: task.displayTitle(locale),
        repository: context.read<TaskRepository>(),
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
          context.read<TaskDetailBloc>().add(TaskDetailLoadRequested(taskId));
        },
      );
    }

    final task = state.task;
    if (task == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<TaskDetailBloc>();
        bloc.add(TaskDetailLoadRequested(task.id));
        await bloc.stream.firstWhere((s) => s.isLoaded || s.status == TaskDetailStatus.error);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                AnimatedListItem(
                  index: 0,
                  child: _TaskHeaderCard(task: task, isDark: isDark, currentUserId: currentUserId),
                ),
                const SizedBox(height: AppSpacing.md),

                // 任务信息卡片
                AnimatedListItem(
                  index: 1,
                  child: _TaskInfoCard(task: task, isDark: isDark),
                ),
                const SizedBox(height: AppSpacing.md),

                // ========== 条件卡片区域 ==========

                // 发布者提示 (isPoster && open)
                if (isPoster && task.status == AppConstants.taskStatusOpen) ...[
                  AnimatedListItem(
                    index: 2,
                    child: PosterInfoCard(isDark: isDark),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 确认截止提醒 (pendingConfirmation && isPoster)
                if (task.status ==
                        AppConstants.taskStatusPendingConfirmation &&
                    isPoster &&
                    task.confirmationDeadline != null) ...[
                  AnimatedListItem(
                    index: 2,
                    child: ConfirmationReminderCard(
                      deadline: task.confirmationDeadline!,
                      isDark: isDark,
                      onConfirm: () {
                        context.read<TaskDetailBloc>().add(
                          const TaskDetailConfirmCompletionRequested());
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 等待确认卡片 (pendingConfirmation && isTaker)
                if (task.status ==
                        AppConstants.taskStatusPendingConfirmation &&
                    isTaker) ...[
                  AnimatedListItem(
                    index: 2,
                    child: WaitingConfirmationCard(isDark: isDark),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 完成证据 (pendingConfirmation || completed + evidence)
                if ((task.status ==
                            AppConstants.taskStatusPendingConfirmation ||
                        task.status ==
                            AppConstants.taskStatusCompleted) &&
                    task.completionEvidence != null &&
                    task.completionEvidence!.isNotEmpty) ...[
                  AnimatedListItem(
                    index: 3,
                    child: CompletionEvidenceCard(
                      evidenceList: task.completionEvidence!,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 申请状态卡片 (非发布者 + 已申请)
                if (!isPoster &&
                    (task.hasApplied || state.userApplication != null) &&
                    (state.userApplication?.status != 'pending' ||
                        task.userApplicationStatus != 'pending')) ...[
                  AnimatedListItem(
                    index: 3,
                    child: ApplicationStatusCard(
                      task: task,
                      application: state.userApplication,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 申请列表 (isPoster && open)
                if (isPoster &&
                    task.status == AppConstants.taskStatusOpen) ...[
                  AnimatedListItem(
                    index: 3,
                    child: ApplicationsListView(
                      applications: state.applications,
                      isLoading: state.isLoadingApplications,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 操作按钮已移至 bottomNavigationBar，避免重复显示

                // 评价区域 (已完成 + 有评价)
                if (task.status == AppConstants.taskStatusCompleted &&
                    state.reviews.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  AnimatedListItem(
                    index: 4,
                    child: TaskReviewsSection(
                      reviews: state.reviews,
                      isDark: isDark,
                    ),
                  ),
                ],

                // 对方信息卡片 — 仅与任务相关的用户可见
                if (isPoster || isTaker) ...[
                  const SizedBox(height: AppSpacing.md),
                  AnimatedListItem(
                    index: 5,
                    child: _CounterpartyCard(
                      task: task,
                      isPoster: isPoster,
                      isTaker: isTaker,
                      isDark: isDark,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
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

    // 聊天按钮仅在用户与任务相关，且任务在进行中/待确认/待支付状态时显示
    final isRelated = isPoster || isTaker;
    final showChat = isRelated &&
        (task.status == AppConstants.taskStatusInProgress ||
            task.status == AppConstants.taskStatusPendingConfirmation ||
            task.status == AppConstants.taskStatusPendingPayment);

    // 底部按钮：快速操作栏 (高性能半透明背景，替代 BackdropFilter)
    return Container(
      decoration: BoxDecoration(
        color: (isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight)
            .withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              // 聊天按钮 — 任务聊天（非私聊）
              if (showChat)
                IconActionButton(
                  icon: Icons.chat_bubble_outline,
                  onPressed: () {
                    context.goToTaskChat(task.id);
                  },
                  backgroundColor: AppColors.skeletonBase,
                ),
              if (showChat) AppSpacing.hMd,
              Expanded(
                child: _buildBottomActionButton(
                    context, state, isPoster, isTaker),
              ),
            ],
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
        isLoading: true,
      );
    }

    // 发布者 + 待支付 → 支付按钮
    if (isPoster && task.status == AppConstants.taskStatusPendingPayment) {
      return PrimaryButton(
        text: context.l10n.taskDetailPlatformServiceFee,
        icon: Icons.credit_card,
        onPressed: task.isPaymentExpired
            ? null
            : () => _openPaymentPageForPendingTask(context, task.id),
      );
    }

    // 非发布者 + 可申请 → 弹出申请框（留言 + 议价 + 金额）
    if (!isPoster && task.canApply) {
      return PrimaryButton(
        text: context.l10n.actionsApplyForTask,
        onPressed: () {
          final bloc = context.read<TaskDetailBloc>();
          SheetAdaptation.showAdaptiveModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => BlocProvider.value(
              value: bloc,
              child: BlocListener<TaskDetailBloc, TaskDetailState>(
                listenWhen: (prev, cur) =>
                    cur.actionMessage == 'application_submitted',
                listener: (c, _) => Navigator.of(c).pop(),
                child: ApplyTaskSheet(task: task),
              ),
            ),
          );
        },
      );
    }

    // 非发布者 + 已申请 (pending)
    if (!isPoster && task.hasApplied && task.userApplicationStatus == 'pending') {
      return PrimaryButton(
        text: context.l10n.taskDetailWaitingPosterConfirm,
      );
    }

    // 接单者 + 进行中 → 标记完成（打开证据收集对话框）
    if (isTaker && task.status == AppConstants.taskStatusInProgress) {
      return PrimaryButton(
        text: context.l10n.actionsMarkComplete,
        onPressed: () => _showCompleteTaskSheet(context),
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
        onPressed: () => _showReviewDialog(context),
        gradient: LinearGradient(
          colors: [AppColors.warning, AppColors.warning.withValues(alpha: 0.8)],
        ),
      );
    }

    // 默认：显示状态文本
    return PrimaryButton(
      text: TaskStatusHelper.getLocalizedLabel(task.status, context.l10n),
    );
  }

  void _showCompleteTaskSheet(BuildContext context) {
    final bloc = context.read<TaskDetailBloc>();
    final taskRepo = context.read<TaskRepository>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _CompleteTaskSheetContent(
        bloc: bloc,
        taskRepo: taskRepo,
      ),
    );
  }

  /// 待支付任务：拉取支付数据并打开支付页
  Future<void> _openPaymentPageForPendingTask(
      BuildContext context, int taskId) async {
    final currentUserId =
        context.read<AuthBloc>().state.user?.id;
    try {
      final resp = await context.read<PaymentRepository>().createTaskPayment(
        taskId: taskId,
      );
      if (!context.mounted) return;
      if (resp.clientSecret == null || resp.clientSecret!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.paymentLoadFailed),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      final data = AcceptPaymentData(
        taskId: taskId,
        clientSecret: resp.clientSecret!,
        customerId: resp.customerId ?? '',
        ephemeralKeySecret: resp.ephemeralKeySecret ?? '',
        amountDisplay: resp.finalAmountDisplay,
      );
      final result = await pushWithSwipeBack<bool>(
        context,
        ApprovalPaymentPage(paymentData: data),
        fullscreenDialog: true,
      );
      if (!context.mounted) return;
      if (result == true) {
        context.read<TaskDetailBloc>().add(TaskDetailLoadRequested(taskId));
        context
            .read<TaskDetailBloc>()
            .add(TaskDetailLoadApplications(currentUserId: currentUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.paymentSuccessMessage),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorLocalizer.localizeFromException(context, e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 显示评价弹窗
  void _showReviewDialog(BuildContext context) {
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReviewBottomSheet(
        onSubmit: (rating, comment, isAnonymous) async {
          final bloc = context.read<TaskDetailBloc>();
          bloc.add(
            TaskDetailReviewRequested(
              CreateReviewRequest(
                rating: rating,
                comment: comment,
                isAnonymous: isAnonymous,
              ),
            ),
          );
          await for (final s in bloc.stream) {
            if (s.actionMessage == 'review_submitted' ||
                s.actionMessage == 'review_failed') {
              return (
                success: s.actionMessage == 'review_submitted',
                error: s.errorMessage,
              );
            }
          }
          return (success: false, error: null);
        },
      ),
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
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.task.images;

    if (images.isEmpty) {
      return _buildPlaceholder();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 占位背景（避免闪烁）
          Container(
            height: 300,
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
          ),

          // 图片PageView
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              _currentPage.value = index;
            },
            itemBuilder: (context, index) {
              final imageWidget = AsyncImageView(
                imageUrl: images[index],
                width: double.infinity,
                height: 300,
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
                    theme.scaffoldBackgroundColor
                        .withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),

          // 自定义页面指示器 — 仅在 _currentPage 变化时重建（不触发整个轮播重建）
          if (images.length > 1)
            Positioned(
              bottom: 24,
              child: ValueListenableBuilder<int>(
                valueListenable: _currentPage,
                builder: (context, currentPage, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
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
                          width: currentPage == index ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: AppRadius.allPill,
                          ),
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
              TaskTypeHelper.getIcon(widget.task.taskType),
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
  const _TaskHeaderCard({required this.task, required this.isDark, this.currentUserId});
  final Task task;
  final bool isDark;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        // 极淡的渐变背景
        gradient: isDark
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  AppColors.primary.withValues(alpha: 0.03),
                ],
              ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xlarge),
          topRight: Radius.circular(AppRadius.xlarge),
          bottomLeft: Radius.circular(AppRadius.large),
          bottomRight: Radius.circular(AppRadius.large),
        ),
        boxShadow: AppShadows.card(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态 + 等级 + 来源 标签行
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _buildStatusBadge(context),
              TaskLevelBadge(task: task),
              TaskSourceBadge(task: task),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 标题
          Text(
            task.displayTitle(locale),
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
          if (task.platformFeeRate != null && task.platformFeeAmount != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildServiceFeeRow(context),
          ],
          const SizedBox(height: AppSpacing.md),

          // 分类和位置标签
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildTag(
                text: (task.isFleaMarketTask && task.fleaMarketCategory != null)
                    ? task.fleaMarketCategory!
                    : TaskTypeHelper.getLocalizedLabel(task.taskType, context.l10n),
                icon: task.isFleaMarketTask
                    ? Icons.shopping_bag
                    : Icons.local_offer,
                isPrimary: true,
              ),
              _buildTag(
                text: task.displayLocation(currentUserId) ?? 'Online',
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

  Widget _buildStatusBadge(BuildContext context) {
    final color = AppColors.taskStatusColor(task.status);
    final isPulse = task.status == AppConstants.taskStatusInProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.allPill, // 胶囊样式
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 脉冲动画点
          if (isPulse) ...[
             _PulseDot(color: color),
             const SizedBox(width: 6),
          ] else ...[
             Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            TaskStatusHelper.getLocalizedLabel(task.status, context.l10n),
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

    final priceText = Helpers.formatAmountNumber(amount);

    const goldColor = Color(0xFFD4A017); // 金色

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '£',
          style: AppTypography.title3.copyWith(
            color: goldColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          priceText,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.1,
            color: goldColor,
          ),
        ),
      ],
    );
  }

  /// 服务费比例 + 服务费金额（任务详情展示）
  Widget _buildServiceFeeRow(BuildContext context) {
    final l10n = context.l10n;
    final rate = task.platformFeeRate!;
    final amount = task.platformFeeAmount!;
    final ratePercent = (rate * 100).round();
    final amountStr = Helpers.formatAmountNumber(amount);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Row(
      children: [
        Text(
          '${l10n.taskDetailServiceFeeRate} $ratePercent%',
          style: AppTypography.caption.copyWith(color: secondaryColor),
        ),
        const SizedBox(width: AppSpacing.lg),
        Text(
          '${l10n.taskDetailServiceFeeAmount} £$amountStr',
          style: AppTypography.caption.copyWith(color: secondaryColor),
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
            ? AppColors.primaryLight.withValues(alpha: 0.1)
            : (isDark
                ? AppColors.backgroundDark
                : AppColors.backgroundLight),
        borderRadius: AppRadius.allPill,
        border: isPrimary
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
            : null,
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

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
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
    final locale = Localizations.localeOf(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
        boxShadow: AppShadows.card(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 描述
          if (task.displayDescription(locale)?.isNotEmpty ?? false) ...[
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
              task.displayDescription(locale)!,
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

          // 2x2 网格布局展示信息
          LayoutBuilder(
            builder: (context, constraints) {
              // 简单网格：每行2个
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  if (task.deadline != null)
                    _buildGridItem(
                      icon: Icons.access_time,
                      title: context.l10n.taskDetailDeadline,
                      value: _formatDate(task.deadline!),
                      iconColor: _isDeadlineUrgent(task.deadline!)
                          ? AppColors.error
                          : AppColors.primary,
                      width: (constraints.maxWidth - AppSpacing.md) / 2,
                    ),
                  if (task.createdAt != null)
                    _buildGridItem(
                      icon: Icons.calendar_today,
                      title: context.l10n.taskDetailPublishTime,
                      value: DateFormatter.formatRelative(task.createdAt!, l10n: context.l10n),
                      iconColor: AppColors.primary,
                      width: (constraints.maxWidth - AppSpacing.md) / 2,
                    ),
                  if (task.isMultiParticipant)
                    _buildGridItem(
                      icon: Icons.people_outline,
                      title: context.l10n.taskDetailParticipantCount,
                      value: '${task.currentParticipants}/${task.maxParticipants}',
                      iconColor: AppColors.primary,
                      width: (constraints.maxWidth - AppSpacing.md) / 2,
                    ),
                  // 可以在这里添加更多信息，如浏览量等
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem({
    required IconData icon,
    required String title,
    required String value,
    required double width,
    Color? iconColor,
  }) {
    final effectiveIconColor = iconColor ?? AppColors.primary;
    
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: effectiveIconColor.withValues(alpha: 0.05),
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: effectiveIconColor.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: effectiveIconColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodyBold.copyWith(
              fontSize: 14,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
// 对方信息卡片 — 基于用户身份和任务类型显示对应的人
// ============================================================

class _CounterpartyCard extends StatelessWidget {
  const _CounterpartyCard({
    required this.task,
    required this.isPoster,
    required this.isTaker,
    required this.isDark,
  });
  final Task task;
  final bool isPoster;
  final bool isTaker;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // 计算要显示的对方信息
    final info = _resolveCounterpartyInfo(context);
    if (info == null) return const SizedBox.shrink();

    return BouncingWidget(
      onTap: info.onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
          boxShadow: AppShadows.card(isDark),
        ),
        child: Row(
          children: [
            // 头像
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: info.isExpert
                      ? AppColors.gradientGold
                      : AppColors.gradientDeepBlue,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (info.isExpert
                            ? AppColors.gradientGold[1]
                            : AppColors.primary)
                        .withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AvatarView(
                  imageUrl: info.avatar,
                  name: info.name,
                  size: 48,
                ),
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
                          info.name,
                          style: AppTypography.bodyBold.copyWith(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (info.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 16, color: Colors.blue),
                      ],
                      if (info.isExpert) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.workspace_premium,
                            size: 16, color: AppColors.gradientGold[1]),
                      ],
                    ],
                  ),
                  if (info.isVerified) ...[
                    const SizedBox(height: 4),
                    UserIdentityBadges(
                      isStudentVerified: info.isVerified,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),

            // 角色标签 + 箭头
            Text(
              info.roleLabel,
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

  /// 根据身份和任务类型解析要显示的对方信息
  _CounterpartyInfo? _resolveCounterpartyInfo(BuildContext context) {
    final isExpertTask = task.isExpertServiceTask || task.isExpertActivityTask;

    // ===== 达人服务/活动任务 =====
    if (isExpertTask) {
      final expertId = task.expertCreatorId;
      // 当前用户是达人创建者 → 显示接单者/参与者（即 poster 是申请人）
      if (isPoster && expertId != null && task.posterId == expertId) {
        // 达人自己看任务，显示接单者（对方）
        if (task.taker != null) {
          return _CounterpartyInfo(
            name: task.taker!.name,
            avatar: task.taker!.avatar,
            isVerified: task.taker!.isVerified,
            roleLabel: task.isExpertActivityTask
                ? context.l10n.taskDetailParticipant
                : context.l10n.taskDetailApplicant,
            onTap: () {
              AppHaptics.selection();
              context.goToUserProfile(task.takerId!);
            },
          );
        }
        return null; // 达人视角但还没有接单者
      }
      // 当前用户不是达人 → 显示达人信息
      if (expertId != null) {
        // 尝试从 taker 或 poster 中推断达人身份
        final UserBrief? expertBrief;
        if (task.taker?.id == expertId) {
          expertBrief = task.taker;
        } else if (task.poster?.id == expertId) {
          expertBrief = task.poster;
        } else {
          expertBrief = null;
        }
        return _CounterpartyInfo(
          name: expertBrief?.name ?? context.l10n.taskSourceExpertService,
          avatar: expertBrief?.avatar,
          isVerified: expertBrief?.isVerified ?? false,
          isExpert: true,
          roleLabel: context.l10n.taskSourceExpertService,
          onTap: () {
            AppHaptics.selection();
            // 跳转到达人详情页
            context.safePush('/task-experts/$expertId');
          },
        );
      }
    }

    // ===== 跳蚤市场 =====
    if (task.isFleaMarketTask) {
      if (isPoster && task.taker != null) {
        // 买家 → 看卖家
        return _CounterpartyInfo(
          name: task.taker!.name,
          avatar: task.taker!.avatar,
          isVerified: task.taker!.isVerified,
          roleLabel: context.l10n.taskDetailSeller,
          onTap: () {
            AppHaptics.selection();
            context.goToUserProfile(task.takerId!);
          },
        );
      }
      if (isTaker && task.poster != null) {
        // 卖家 → 看买家
        return _CounterpartyInfo(
          name: task.poster!.name,
          avatar: task.poster!.avatar,
          isVerified: task.poster!.isVerified,
          roleLabel: context.l10n.taskDetailBuyer,
          onTap: () {
            AppHaptics.selection();
            context.goToUserProfile(task.posterId);
          },
        );
      }
      return null;
    }

    // ===== 普通任务 =====
    if (isPoster && task.taker != null) {
      // 发布者 → 看接单者
      return _CounterpartyInfo(
        name: task.taker!.name,
        avatar: task.taker!.avatar,
        isVerified: task.taker!.isVerified,
        roleLabel: context.l10n.taskDetailRecipient,
        onTap: () {
          AppHaptics.selection();
          context.goToUserProfile(task.takerId!);
        },
      );
    }
    if (isTaker && task.poster != null) {
      // 接单者 → 看发布者
      return _CounterpartyInfo(
        name: task.poster!.name,
        avatar: task.poster!.avatar,
        isVerified: task.poster!.isVerified,
        roleLabel: context.l10n.taskDetailPublisher,
        onTap: () {
          AppHaptics.selection();
          context.goToUserProfile(task.posterId);
        },
      );
    }

    return null; // 没有对方信息可展示
  }
}

/// 对方信息数据
class _CounterpartyInfo {
  const _CounterpartyInfo({
    required this.name,
    this.avatar,
    this.isVerified = false,
    this.isExpert = false,
    required this.roleLabel,
    this.onTap,
  });
  final String name;
  final String? avatar;
  final bool isVerified;
  final bool isExpert;
  final String roleLabel;
  final VoidCallback? onTap;
}

// ============================================================
// 争议时间线弹窗 - 对标iOS DisputeTimelineView
// ============================================================

class _DisputeTimelineSheet extends StatefulWidget {
  const _DisputeTimelineSheet({
    required this.taskId,
    required this.taskTitle,
    required this.repository,
  });

  final int taskId;
  final String taskTitle;
  final TaskRepository repository;

  @override
  State<_DisputeTimelineSheet> createState() => _DisputeTimelineSheetState();
}

class _DisputeTimelineSheetState extends State<_DisputeTimelineSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _timelineItems = [];

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await widget.repository.getDisputeTimeline(widget.taskId);
      final items = (data['timeline'] as List<dynamic>?) ?? [];
      setState(() {
        _timelineItems =
            items.map((e) => e as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.taskDetailDisputeDetail,
                      style: AppTypography.title3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 任务标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.taskTitle,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            // 内容
            Expanded(
              child: _isLoading
                  ? const LoadingView()
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_errorMessage!,
                                  style: AppTypography.body),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _loadTimeline,
                                child: Text(l10n.commonRetry),
                              ),
                            ],
                          ),
                        )
                      : _timelineItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time,
                                      size: 50,
                                      color: AppColors.textTertiaryLight),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.disputeNoRecords,
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _timelineItems.length,
                              itemBuilder: (context, index) {
                                // 交错入场动画
                                return AnimatedListItem(
                                  index: index,
                                  maxAnimatedIndex: 11,
                                  direction: AnimatedListDirection.left,
                                  staggerDelay: const Duration(milliseconds: 80),
                                  child: _TimelineItemTile(
                                    item: _timelineItems[index],
                                    isLast:
                                        index == _timelineItems.length - 1,
                                  ),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}

/// 时间线单项 - 对标iOS TimelineItemView
class _TimelineItemTile extends StatelessWidget {
  const _TimelineItemTile({
    required this.item,
    required this.isLast,
  });

  final Map<String, dynamic> item;
  final bool isLast;

  Color get _actorColor {
    switch (item['actor'] as String? ?? '') {
      case 'poster':
        return AppColors.primary;
      case 'taker':
        return AppColors.success;
      case 'admin':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _actorName(BuildContext context) {
    final l10n = context.l10n;
    switch (item['actor'] as String? ?? '') {
      case 'poster':
        return l10n.disputeActorPoster;
      case 'taker':
        return l10n.disputeActorTaker;
      case 'admin':
        return (item['reviewer_name'] as String?) ??
            (item['resolver_name'] as String?) ??
            l10n.disputeActorAdmin;
      default:
        return l10n.commonUnknown;
    }
  }

  IconData get _icon {
    switch (item['type'] as String? ?? '') {
      case 'task_completed':
        return Icons.check_circle;
      case 'task_confirmed':
        return Icons.verified;
      case 'refund_request':
        return Icons.replay_circle_filled;
      case 'rebuttal':
        return Icons.chat_bubble;
      case 'admin_review':
        return Icons.admin_panel_settings;
      case 'dispute':
        return Icons.warning_amber_rounded;
      case 'dispute_resolution':
        return Icons.gavel;
      default:
        return Icons.circle;
    }
  }

  String _formatTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return '';
    try {
      final date = DateTime.parse(ts);
      return DateFormat('MM/dd HH:mm').format(date.toLocal());
    } catch (_) {
      return ts;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'processing':
        return AppColors.primary;
      case 'approved':
      case 'completed':
      case 'resolved':
        return AppColors.success;
      case 'rejected':
      case 'cancelled':
      case 'dismissed':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusText(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'pending':
        return l10n.disputeStatusPending;
      case 'processing':
        return l10n.disputeStatusProcessing;
      case 'approved':
        return l10n.disputeStatusApproved;
      case 'rejected':
        return l10n.disputeStatusRejected;
      case 'completed':
        return l10n.disputeStatusCompleted;
      case 'cancelled':
        return l10n.disputeStatusCancelled;
      case 'resolved':
        return l10n.disputeStatusResolved;
      case 'dismissed':
        return l10n.disputeStatusDismissed;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? '';
    final description = item['description'] as String? ?? '';
    final timestamp = item['timestamp'] as String?;
    final status = item['status'] as String?;
    final evidence = item['evidence'] as List<dynamic>?;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间线指示器
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _actorColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, size: 16, color: Colors.white),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.dividerLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 内容卡片
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.dividerLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题 + 时间
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: AppTypography.body
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                      if (timestamp != null)
                        Text(
                          _formatTimestamp(timestamp),
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textTertiaryLight),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 操作人
                  Text(
                    _actorName(context),
                    style: AppTypography.caption.copyWith(color: _actorColor),
                  ),
                  const SizedBox(height: 6),
                  // 描述
                  Text(
                    description,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  // 状态标签
                  if (status != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _statusText(context, status),
                        style: AppTypography.caption
                            .copyWith(color: _statusColor(status)),
                      ),
                    ),
                  ],
                  // 证据
                  if (evidence != null && evidence.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: evidence.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final e = evidence[i] as Map<String, dynamic>;
                          final type = e['type'] as String? ?? '';
                          if (type == 'text') {
                            return Container(
                              width: 120,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryBackgroundLight,
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: Text(
                                e['content'] as String? ?? '',
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          final url = e['url'] as String?;
                          if (url != null && url.isNotEmpty) {
                            return GestureDetector(
                              onTap: () {
                                FullScreenImageView.show(
                                  context,
                                  images: [url],
                                );
                              },
                              child: AsyncImageView(
                                imageUrl: url,
                                width: 80,
                                height: 80,
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 完成任务证据收集 Sheet（支持图片+文字）
class _CompleteTaskSheetContent extends StatefulWidget {
  const _CompleteTaskSheetContent({
    required this.bloc,
    required this.taskRepo,
  });

  final TaskDetailBloc bloc;
  final TaskRepository taskRepo;

  @override
  State<_CompleteTaskSheetContent> createState() => _CompleteTaskSheetContentState();
}

class _CompleteTaskSheetContentState extends State<_CompleteTaskSheetContent> {
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 5 - _selectedImages.length;
    if (remaining <= 0) return;
    final picked = await _imagePicker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked.isNotEmpty && mounted) {
      setState(() {
        _selectedImages.addAll(picked.take(remaining));
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      List<String>? imageUrls;
      if (_selectedImages.isNotEmpty) {
        imageUrls = [];
        for (final img in _selectedImages) {
          final url = await widget.taskRepo.uploadTaskImage(img.path);
          imageUrls.add(url);
        }
      }

      final text = _textController.text.trim();
      widget.bloc.add(TaskDetailCompleteRequested(
        evidenceImages: imageUrls,
        evidenceText: text.isEmpty ? null : text,
      ));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.taskEvidenceTitle, style: AppTypography.title3),
          const SizedBox(height: 8),
          Text(l10n.taskEvidenceHint,
              style: AppTypography.footnote.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 16),
          Text(l10n.taskEvidenceTextLabel, style: AppTypography.subheadlineBold),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: l10n.taskEvidenceTextHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.taskEvidenceImagesLabel, style: AppTypography.subheadlineBold),
          const SizedBox(height: 4),
          Text(l10n.taskEvidenceImageLimit,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._selectedImages.asMap().entries.map((entry) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(entry.value.path),
                        width: 72, height: 72, fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2, right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImages.removeAt(entry.key)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_selectedImages.length < 5)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.dividerLight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSecondaryLight),
                        Text('${_selectedImages.length}/5',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle),
              label: Text(l10n.taskEvidenceSubmit),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
