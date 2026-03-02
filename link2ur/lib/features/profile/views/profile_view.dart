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
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/user_identity_badges.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/router/page_transitions.dart';
import '../../../core/widgets/content_constraint.dart';
import '../../../core/widgets/decorative_background.dart';
import '../../../core/widgets/credit_score_gauge.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import 'avatar_picker_view.dart';
import '../bloc/profile_bloc.dart';

part 'profile_desktop_widgets.dart';
part 'profile_mobile_widgets.dart';
part 'profile_menu_widgets.dart';

/// 个人中心页
/// 参考iOS ProfileView.swift
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) =>
          prev.isAuthenticated != curr.isAuthenticated ||
          prev.user != curr.user,
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
    final isDesktopShell = ResponsiveUtils.isDesktopShell(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const RepaintBoundary(child: DecorativeBackground()),
          BlocListener<ProfileBloc, ProfileState>(
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
              buildWhen: (prev, curr) =>
                  prev.status != curr.status ||
                  prev.user != curr.user ||
                  prev.myTasks != curr.myTasks ||
                  prev.postedTasks != curr.postedTasks ||
                  prev.myForumPosts != curr.myForumPosts ||
                  prev.favoritedPosts != curr.favoritedPosts ||
                  prev.likedPosts != curr.likedPosts ||
                  prev.preferences != curr.preferences ||
                  prev.errorMessage != curr.errorMessage ||
                  prev.isUpdating != curr.isUpdating,
              builder: (context, profileState) {
                final user = authState.user!;
                return RefreshIndicator(
                  onRefresh: () async {
                    final bloc = context.read<ProfileBloc>();
                    bloc
                      ..add(const ProfileLoadRequested())
                      ..add(const ProfileLoadMyTasks())
                      ..add(const ProfileLoadMyTasks(isPosted: true));
                    await bloc.stream
                        .where((s) => s.status != ProfileStatus.loading)
                        .first
                        .timeout(
                          const Duration(seconds: 10),
                          onTimeout: () => bloc.state,
                        );
                  },
                  child: isDesktopShell
                      ? ContentConstraint(
                          child: _buildDesktopProfile(context, profileState, user, isDark),
                        )
                      : SafeArea(
                          bottom: false,
                          child: Column(
                            children: [
                              _buildProfileMobileAppBar(context, isDark),
                              Expanded(
                                child: _buildMobileProfile(context, profileState, user, isDark),
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

  /// 移动端顶部栏：与首页、社区一致，SafeArea 内自定义透明栏（无 AppBar）
  Widget _buildProfileMobileAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        children: [
          const SizedBox(width: 44, height: 44),
          const Spacer(),
          Text(
            context.l10n.tabsProfile,
            style: AppTypography.title3.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              AppHaptics.selection();
              await context.push('/profile/edit');
              if (context.mounted) {
                context.read<ProfileBloc>().add(const ProfileLoadRequested());
              }
            },
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(child: Icon(Icons.edit_outlined, size: 22)),
            ),
          ),
        ],
      ),
    );
  }
}
