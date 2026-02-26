part of 'profile_view.dart';

/// Mobile profile layout — 与首页同款装饰背景，由 ProfileView 层 Stack 提供
Widget _buildMobileProfile(
    BuildContext context, ProfileState profileState, User user, bool isDark) {
  return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          // MediaQuery.padding.bottom 已包含底部导航栏+系统安全区高度（extendBody: true）
          bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
        ),
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
  );
}

/// 用户信息区域 - 居中布局，对齐iOS
Widget _buildUserInfoSection(
    BuildContext context, User user, bool isDark) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 0),
    child: Column(
      children: [
        // 头像 + 角标（点击可更换头像）
        GestureDetector(
          onTap: () {
            pushWithSwipeBack(
              context,
              AvatarPickerView(
                currentAvatar: user.avatar,
                onSelected: (newAvatar) {
                  // 头像更新后刷新 Profile
                  context.read<ProfileBloc>().add(const ProfileLoadRequested());
                },
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
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
                user.displayNameWith(context.l10n),
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
  // 单次遍历计算进行中和已完成的任务数量（避免双重 .where()）
  var inProgressCount = 0;
  var completedCount = 0;
  for (final t in state.myTasks) {
    if (t.status == 'assigned' ||
        t.status == AppConstants.taskStatusInProgress ||
        t.status == 'accepted') {
      inProgressCount++;
    } else if (t.status == AppConstants.taskStatusCompleted) {
      completedCount++;
    }
  }

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
