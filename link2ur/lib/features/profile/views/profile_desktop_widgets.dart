part of 'profile_view.dart';

/// Desktop profile layout — title bar + user card + two-column menus + logout
Widget _buildDesktopProfile(
    BuildContext context, ProfileState profileState, User user, bool isDark) {
  return SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
              onTap: () async {
                await context.push('/profile/edit');
                if (context.mounted) {
                  context.read<ProfileBloc>().add(const ProfileLoadRequested());
                }
              },
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

/// Desktop user card — avatar, name, badges, stats in a horizontal row
Widget _buildDesktopUserCard(
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
                      user.displayNameWith(context.l10n),
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
