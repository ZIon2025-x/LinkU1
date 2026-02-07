import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/user_identity_badges.dart';
import '../../../core/widgets/stat_item.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../coupon_points/views/coupon_points_view.dart';
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
          )
            ..add(const ProfileLoadRequested())
            ..add(const ProfileLoadMyTasks())
            ..add(const ProfileLoadMyTasks(isPosted: true)),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tabsProfile),
        actions: [
          // 编辑按钮 (对齐iOS: pencil SF Symbol)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, profileState) {
          final user = authState.user!;

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ProfileBloc>()
                ..add(const ProfileLoadRequested())
                ..add(const ProfileLoadMyTasks())
                ..add(const ProfileLoadMyTasks(isPosted: true));
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: Stack(
              children: [
                // 顶部渐变背景 (对齐iOS)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      // 用户信息区域 (居中布局，对齐iOS)
                      _buildUserInfoSection(context, user, isDark),
                      const SizedBox(height: 24),

                      // 统计数据 (3项: 进行中/已完成/信用分)
                      _buildStatsSection(context, profileState, user, isDark),
                      const SizedBox(height: 24),

                      // 我的内容
                      _buildMyContentSection(context, isDark),
                      const SizedBox(height: 24),

                      // 系统与认证
                      _buildSystemSection(context, isDark),
                      const SizedBox(height: 24),

                      // 登出按钮
                      _buildLogoutButton(context, isDark),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 用户信息区域 - 居中布局，对齐iOS
  Widget _buildUserInfoSection(
      BuildContext context, User user, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 40, AppSpacing.md, 0),
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
                      // 刷新页面
                    },
                  ),
                ),
              );
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                // 白色外圈 + 阴影
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AvatarView(
                      imageUrl: user.avatar,
                      name: user.name,
                      size: 96,
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
            t.status == 'in_progress' ||
            t.status == 'accepted')
        .length;
    final completedCount = state.myTasks
        .where((t) => t.status == 'completed')
        .length;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                HapticFeedback.selectionClick();
                context.push('/profile/my-tasks');
              },
              behavior: HitTestBehavior.opaque,
              child: StatItem(
                value: '$inProgressCount',
                label: context.l10n.profileInProgress,
                color: AppColors.primary,
              ),
            ),
          ),
          Container(width: 1, height: 30, color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/profile/my-tasks');
              },
              behavior: HitTestBehavior.opaque,
              child: StatItem(
                value: '$completedCount',
                label: context.l10n.profileCompleted,
                color: AppColors.success,
              ),
            ),
          ),
          Container(width: 1, height: 30, color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
          Expanded(
            child: StatItem(
              value: user.creditScoreDisplay,
              label: context.l10n.profileCreditScore,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  /// 我的内容 (对齐iOS myContentSection)
  Widget _buildMyContentSection(BuildContext context, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
                  color: AppColors.primary,
                  onTap: () => context.push('/profile/my-tasks'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.inventory_2,           // shippingbox.fill
                  title: context.l10n.profileMyPosts,
                  color: Colors.orange,
                  onTap: () => context.push('/profile/my-posts'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.description,           // doc.text.fill
                  title: context.l10n.profileMyForumPosts,
                  color: Colors.blue,
                  onTap: () => context.push('/forum/my-posts'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.credit_card,           // creditcard.fill
                  title: context.l10n.profileMyWallet,
                  color: AppColors.success,
                  onTap: () => context.push('/wallet'),
                ),
                _divider(isDark),
                _ProfileRow(
                  icon: Icons.admin_panel_settings,  // bolt.shield.fill
                  title: context.l10n.profileMyApplications,
                  color: Colors.purple,
                  onTap: () => context.push('/profile/my-tasks'),
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
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
                  onTap: () => context.push('/wallet'),
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CouponPointsView()),
                  ),
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
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 40),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
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
              Icon(Icons.power_settings_new,       // power
                  color: AppColors.error, size: 18),
              SizedBox(width: 8),
              Text(
                context.l10n.profileLogout,
                style: TextStyle(
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

/// 个人中心行组件 - 对齐iOS ProfileRow
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 图标背景 (对齐iOS: 38x38 rounded rect)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
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
