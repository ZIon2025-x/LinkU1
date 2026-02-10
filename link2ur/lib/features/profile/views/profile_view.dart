import 'package:flutter/material.dart';
import '../../../core/utils/haptic_feedback.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/user_identity_badges.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/content_constraint.dart';
import '../../../core/widgets/credit_score_gauge.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import 'avatar_picker_view.dart';
import '../bloc/profile_bloc.dart';

/// 个人中心页
/// 参考iOS ProfileView.swift
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (!authState.isAuthenticated) {
          return _buildNotLoggedIn(context);
        }

        return BlocProvider(
          create: (context) => ProfileBloc(
            userRepository: context.read<UserRepository>(),
            taskRepository: context.read<TaskRepository>(),
            forumRepository: context.read<ForumRepository>(),
          )
            ..add(const ProfileLoadRequested())
            ..add(const ProfileLoadMyTasks(pageSize: 20))
            ..add(const ProfileLoadMyTasks(isPosted: true, pageSize: 20)),
          child: _ProfileContent(authState: authState),
        );
      },
    );
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tabsProfile),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.vLg,
            Text(
              context.l10n.profileWelcome,
              style: AppTypography.title2.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            AppSpacing.vSm,
            Text(
              context.l10n.profileLoginPrompt,
              style: AppTypography.subheadline.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.gradientPrimary,
                    ),
                    borderRadius: AppRadius.allLarge,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.allLarge,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.l10n.loginLoginNow,
                          style: AppTypography.bodyBold.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        AppSpacing.hSm,
                        const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: isDesktop
          ? (isDark ? AppColors.backgroundDark : Colors.white)
          : null,
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(context.l10n.tabsProfile),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.push('/profile/edit'),
                ),
              ],
            ),
      body: BlocListener<ProfileBloc, ProfileState>(
        listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage && curr.actionMessage != null,
        listener: (context, state) {
          final actionType = state.actionMessage;
          if (actionType == null) return;
          final l10n = context.l10n;
          final message = switch (actionType) {
            'profile_updated' => l10n.profileUpdated,
            'update_failed' => l10n.profileUpdateFailed,
            'avatar_updated' => l10n.profileAvatarUpdated,
            'upload_failed' => l10n.profileUploadFailed,
            'preferences_updated' => l10n.profilePreferencesUpdated,
            _ => actionType,
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
        child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, profileState) {
          final user = authState.user!;

          return RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<ProfileBloc>();
              bloc
                ..add(const ProfileLoadRequested())
                ..add(const ProfileLoadMyTasks(pageSize: 20))
                ..add(const ProfileLoadMyTasks(isPosted: true, pageSize: 20));
              // 等待 BLoC 状态变为非 loading（使用 where + first 避免 orElse 缺陷）
              await bloc.stream
                  .where((s) => s.status != ProfileStatus.loading)
                  .first
                  .timeout(
                    const Duration(seconds: 10),
                    onTimeout: () => bloc.state,
                  );
            },
            child: isDesktop
                ? ContentConstraint(
                    child: _buildDesktopProfile(context, profileState, user, isDark),
                  )
                : _buildMobileProfile(context, profileState, user, isDark),
          );
        },
      ),
      ),
    );
  }

  Widget _buildDesktopProfile(
      BuildContext context, ProfileState profileState, User user, bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题 + 编辑按钮
          Row(
            children: [
              Text(
                context.l10n.tabsProfile,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.desktopTextLight,
                ),
              ),
              const Spacer(),
              _DesktopEditButton(
                onTap: () => context.push('/profile/edit'),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 横向用户信息 + 统计
          _buildDesktopUserCard(context, profileState, user, isDark),
          const SizedBox(height: 32),

          // 两列菜单
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMyContentSection(context, isDark),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildSystemSection(context, isDark),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 登出按钮
          _buildLogoutButton(context, isDark),
        ],
      ),
    );
  }

  Widget _buildDesktopUserCard(
      BuildContext context, ProfileState state, User user, bool isDark) {
    final inProgressCount = state.myTasks
        .where((t) =>
            t.status == 'assigned' ||
            t.status == AppConstants.taskStatusInProgress ||
            t.status == 'accepted')
        .length;
    final completedCount = state.myTasks
        .where((t) => t.status == AppConstants.taskStatusCompleted)
        .length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.desktopBorderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 头像
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AvatarPickerView(
                    currentAvatar: user.avatar,
                    onSelected: (newAvatar) {
                      // 头像更新后刷新 Profile
                      context.read<ProfileBloc>().add(const ProfileLoadRequested());
                    },
                  ),
                ),
              );
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.gradientPrimary,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? AppColors.cardBackgroundDark
                          : AppColors.cardBackgroundLight,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Center(
                      child: AvatarView(
                        imageUrl: user.avatar,
                        name: user.name,
                        size: 72,
                      ),
                    ),
                  ),
                ),
                MemberBadgeAvatarOverlay(
                  userLevel: user.userLevel,
                  size: 24,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.desktopTextLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: Colors.blue, size: 18),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                UserIdentityBadges(
                  userLevel: user.userLevel,
                  isExpert: user.isExpert,
                  isStudentVerified: user.isStudentVerified,
                  compact: false,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? user.phone ?? 'ID: ${user.id}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.desktopPlaceholderLight,
                  ),
                ),
              ],
            ),
          ),

          // 统计数据
          Row(
            children: [
              _DesktopStatItem(
                value: '$inProgressCount',
                label: context.l10n.profileInProgress,
                color: AppColors.primary,
              ),
              const SizedBox(width: 24),
              _DesktopStatItem(
                value: '$completedCount',
                label: context.l10n.profileCompleted,
                color: AppColors.success,
              ),
              const SizedBox(width: 24),
              _DesktopStatItem(
                value: user.creditScoreDisplay,
                label: context.l10n.profileCreditScore,
                color: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileProfile(
      BuildContext context, ProfileState profileState, User user, bool isDark) {
    return Stack(
      children: [
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.primary.withValues(alpha: 0.20),
                        AppColors.purple.withValues(alpha: 0.15),
                        AppColors.teal.withValues(alpha: 0.12),
                        AppColors.primary.withValues(alpha: 0.10),
                      ]
                    : [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.purple.withValues(alpha: 0.12),
                        AppColors.teal.withValues(alpha: 0.10),
                        AppColors.primary.withValues(alpha: 0.08),
                      ],
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              _buildUserInfoSection(context, user, isDark),
              const SizedBox(height: 24),
              _buildStatsSection(context, profileState, user, isDark),
              const SizedBox(height: 24),
              _buildMyContentSection(context, isDark),
              const SizedBox(height: 24),
              _buildSystemSection(context, isDark),
              const SizedBox(height: 24),
              _buildLogoutButton(context, isDark),
            ],
          ),
        ),
      ],
    );
  }

  /// 用户信息区域 - 居中布局，对齐iOS
  Widget _buildUserInfoSection(
      BuildContext context, User user, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 40, AppSpacing.md, 0),
      child: Column(
        children: [
          // 头像 + 角标（点击可更换头像）
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AvatarPickerView(
                    currentAvatar: user.avatar,
                    onSelected: (newAvatar) {
                      // 头像更新后刷新 Profile
                      context.read<ProfileBloc>().add(const ProfileLoadRequested());
                    },
                  ),
                ),
              );
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                // 渐变环 + 头像
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.gradientPrimary,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? AppColors.cardBackgroundDark
                          : AppColors.cardBackgroundLight,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Center(
                      child: AvatarView(
                        imageUrl: user.avatar,
                        name: user.name,
                        size: 96,
                      ),
                    ),
                  ),
                ),
                MemberBadgeAvatarOverlay(
                  userLevel: user.userLevel,
                  size: 28,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 用户名 + 认证标识
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (user.isVerified) ...[
                AppSpacing.hSm,
                const Icon(Icons.verified, color: Colors.blue, size: 18),   // checkmark.seal.fill
              ],
            ],
          ),
          const SizedBox(height: 6),

          // 身份标识（VIP/Super）
          UserIdentityBadges(
            userLevel: user.userLevel,
            isExpert: user.isExpert,
            isStudentVerified: user.isStudentVerified,
            compact: false,
          ),
          const SizedBox(height: 6),

          // 邮箱/手机号（带圆角背景）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.email ?? user.phone ?? 'ID: ${user.id}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 统计区域 - 3项: 进行中/已完成/信用分 (对齐iOS)
  Widget _buildStatsSection(
      BuildContext context, ProfileState state, User user, bool isDark) {
    // 计算进行中和已完成的任务数量
    final inProgressCount = state.myTasks
        .where((t) =>
            t.status == 'assigned' ||
            t.status == AppConstants.taskStatusInProgress ||
            t.status == 'accepted')
        .length;
    final completedCount = state.myTasks
        .where((t) => t.status == AppConstants.taskStatusCompleted)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                AppHaptics.selection();
                context.push('/profile/my-tasks');
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCounter(
                    value: inProgressCount,
                    style: AppTypography.title2.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppSpacing.vXs,
                  Text(
                    context.l10n.profileInProgress,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 30, color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
          Expanded(
            child: GestureDetector(
              onTap: () {
                AppHaptics.selection();
                context.push('/profile/my-tasks');
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCounter(
                    value: completedCount,
                    style: AppTypography.title2.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppSpacing.vXs,
                  Text(
                    context.l10n.profileCompleted,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 30, color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
          Expanded(
            child: CreditScoreGauge(
              score: (user.avgRating ?? 0) * 20, // 0-5 → 0-100
              size: 72,
              strokeWidth: 7,
              label: context.l10n.profileCreditScore,
            ),
          ),
        ],
      ),
    );
  }

  /// 我的内容 (对齐iOS myContentSection)
  Widget _buildMyContentSection(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              context.l10n.profileMyContent,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.cardBackgroundDark
                  : AppColors.cardBackgroundLight,
              borderRadius: AppRadius.allLarge,
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
                _ProfileRow(
                  icon: Icons.format_list_bulleted,  // list.bullet.rectangle.fill
                  title: context.l10n.profileMyTasks,
                  subtitle: context.l10n.profileMyTasksSubtitle,
                  color: AppColors.primary,
                  onTap: () => context.push('/profile/my-tasks'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.inventory_2,           // shippingbox.fill
                  title: context.l10n.profileMyPosts,
                  subtitle: context.l10n.profileMyPostsSubtitle,
                  color: Colors.orange,
                  onTap: () => context.push('/profile/my-posts'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.description,           // doc.text.fill
                  title: context.l10n.profileMyForumPosts,
                  subtitle: context.l10n.profileMyForumPostsSubtitle,
                  color: Colors.blue,
                  onTap: () => context.push('/forum/my-posts'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.credit_card,           // creditcard.fill
                  title: context.l10n.profileMyWallet,
                  subtitle: context.l10n.profileMyWalletSubtitle,
                  color: AppColors.success,
                  onTap: () => context.push('/wallet'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.admin_panel_settings,  // bolt.shield.fill
                  title: context.l10n.profileMyApplications,
                  subtitle: context.l10n.profileMyApplicationsSubtitle,
                  color: Colors.purple,
                  onTap: () => context.push('/my-service-applications'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 系统与认证 (对齐iOS systemSection)
  Widget _buildSystemSection(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              context.l10n.profileSystemAndVerification,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.cardBackgroundDark
                  : AppColors.cardBackgroundLight,
              borderRadius: AppRadius.allLarge,
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
                _ProfileRow(
                  icon: Icons.school,                // graduationcap.fill
                  title: context.l10n.profileStudentVerification,
                  color: Colors.indigo,
                  onTap: () => context.push('/student-verification'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.credit_card,           // creditcard.fill
                  title: context.l10n.profilePaymentAccount,
                  color: AppColors.primary,
                  onTap: () => context.push('/payment/stripe-connect/payments'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.schedule,              // calendar.badge.clock
                  title: context.l10n.profileActivity,
                  color: Colors.orange,
                  onTap: () => context.push('/activities'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.favorite,              // heart.text.square.fill
                  title: context.l10n.profileTaskPreferences,
                  color: Colors.red,
                  onTap: () => context.push('/profile/task-preferences'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.local_activity,        // ticket.fill
                  title: context.l10n.profilePointsCoupons,
                  color: Colors.pink,
                  onTap: () => context.push('/coupon-points'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.settings,              // gearshape.fill
                  title: context.l10n.profileSettings,
                  color: Colors.grey,
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 登出按钮 - 对齐iOS样式（红色边框 + 红色半透明背景）
  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 40),
      child: GestureDetector(
        onTap: () {
          AppHaptics.heavy();
          _showLogoutDialog(context);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: AppRadius.allLarge,
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.power_settings_new,       // power
                  color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Text(
                context.l10n.profileLogout,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.profileConfirmLogout),
        content: Text(context.l10n.profileLogoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(AuthLogoutRequested());
              context.go('/login');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(context.l10n.profileLogout),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 56,
      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
    );
  }
}

/// 桌面端统计项
class _DesktopStatItem extends StatelessWidget {
  const _DesktopStatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.desktopPlaceholderLight,
          ),
        ),
      ],
    );
  }
}

/// 桌面端编辑按钮
class _DesktopEditButton extends StatefulWidget {
  const _DesktopEditButton({
    required this.onTap,
    required this.isDark,
  });

  final VoidCallback onTap;
  final bool isDark;

  @override
  State<_DesktopEditButton> createState() => _DesktopEditButtonState();
}

class _DesktopEditButtonState extends State<_DesktopEditButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.desktopHoverLight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.desktopBorderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: widget.isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.desktopTextLight,
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.profileEditProfile,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: widget.isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.desktopTextLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 个人中心行组件 - 对齐iOS ProfileRow (含副标题支持)
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 图标背景 (对齐iOS: 38x38 rounded rect with gradient)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  // 副标题 (对齐iOS ProfileRow subtitle)
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right,
              size: 16,
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
