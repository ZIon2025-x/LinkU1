part of 'profile_view.dart';

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
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.home_repair_service,
                title: context.l10n.profileMyServices,
                subtitle: context.l10n.profileMyServicesSubtitle,
                color: AppColors.accent,
                onTap: () => context.push('/services/my'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.assignment_outlined,
                title: context.l10n.profileMyServiceApplications,
                subtitle: context.l10n.profileMyServiceApplicationsSubtitle,
                color: AppColors.info,
                onTap: () => context.push('/services/my/sent-applications'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.inventory_2,           // shippingbox.fill
                title: context.l10n.profileMyPosts,
                subtitle: context.l10n.profileMyPostsSubtitle,
                color: AppColors.warning,
                onTap: () => context.push('/profile/my-posts'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.key,
                title: context.l10n.fleaMarketMyRentals,
                subtitle: context.l10n.fleaMarketRentalDetail,
                color: AppColors.info,
                onTap: () => context.push('/flea-market/my-rentals'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.description,           // doc.text.fill
                title: context.l10n.profileMyForumPosts,
                subtitle: context.l10n.profileMyForumPostsSubtitle,
                color: AppColors.primary,
                onTap: () => context.push('/forum/my-posts'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.credit_card,           // creditcard.fill
                title: context.l10n.profileMyWallet,
                subtitle: context.l10n.profileMyWalletSubtitle,
                color: AppColors.success,
                onTap: () => context.push('/wallet'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.admin_panel_settings,  // bolt.shield.fill
                title: context.l10n.profileMyApplications,
                subtitle: context.l10n.profileMyApplicationsSubtitle,
                color: AppColors.purple,
                onTap: () => context.push('/my-service-applications'),
              ),
              _ExpertEntryRow(isDark: isDark),
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
              Builder(builder: (context) {
                final isStudentVerified = context
                    .read<AuthBloc>()
                    .state
                    .user
                    ?.isStudentVerified ?? false;
                return _ProfileRow(
                  icon: Icons.school,
                  title: context.l10n.profileStudentVerification,
                  color: AppColors.indigo,
                  trailing: Text(
                    isStudentVerified
                        ? context.l10n.studentVerificationVerified
                        : context.l10n.studentVerificationUnverified,
                    style: TextStyle(
                      fontSize: 13,
                      color: isStudentVerified
                          ? AppColors.success
                          : (isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight),
                    ),
                  ),
                  onTap: () => context.push('/student-verification'),
                );
              }),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.credit_card,           // creditcard.fill
                title: context.l10n.profilePaymentAccount,
                color: AppColors.primary,
                onTap: () => context.push('/payment/stripe-connect/onboarding'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.schedule,              // calendar.badge.clock
                title: context.l10n.profileActivity,
                color: AppColors.warning,
                onTap: () => context.push('/activities'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.tune_rounded,
                title: context.l10n.myProfileTitle,
                color: AppColors.primary,
                onTap: () => context.push('/my-profile'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.local_activity,        // ticket.fill
                title: context.l10n.profilePointsCoupons,
                color: AppColors.accentPink,
                onTap: () => context.push('/coupon-points'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.settings,              // gearshape.fill
                title: context.l10n.profileSettings,
                color: AppColors.textSecondaryLight,
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
    child: Semantics(
      button: true,
      label: 'Log out',
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
    ),
  );
}

void _showLogoutDialog(BuildContext context) async {
  final confirmed = await AdaptiveDialogs.showConfirmDialog<bool>(
    context: context,
    title: context.l10n.profileConfirmLogout,
    content: context.l10n.profileLogoutMessage,
    confirmText: context.l10n.profileLogout,
    cancelText: context.l10n.commonCancel,
    isDestructive: true,
  );
  if (confirmed == true && context.mounted) {
    context.read<AuthBloc>().add(AuthLogoutRequested());
  }
}

/// 达人中心入口行：
/// - 如果 user.is_expert == true，立即显示
/// - 否则尝试拉一次 my-teams，命中则显示（覆盖历史 is_expert 未回填的账号）
/// - 结果缓存到 session 静态变量，避免每次进 profile 都请求
class _ExpertEntryRow extends StatefulWidget {
  const _ExpertEntryRow({required this.isDark});
  final bool isDark;

  // Session-level cache: null = unknown, true/false = result of my-teams probe
  static bool? _cachedHasTeams;

  @override
  State<_ExpertEntryRow> createState() => _ExpertEntryRowState();
}

class _ExpertEntryRowState extends State<_ExpertEntryRow> {
  bool? _hasTeams = _ExpertEntryRow._cachedHasTeams;

  @override
  void initState() {
    super.initState();
    final isExpertFlag =
        context.read<AuthBloc>().state.user?.isExpert ?? false;
    if (!isExpertFlag && _hasTeams == null) {
      _probeTeams();
    }
  }

  Future<void> _probeTeams() async {
    try {
      final teams =
          await context.read<ExpertTeamRepository>().getMyTeams();
      if (!mounted) return;
      setState(() => _hasTeams = teams.isNotEmpty);
      _ExpertEntryRow._cachedHasTeams = teams.isNotEmpty;
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasTeams = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpertFlag =
        context.watch<AuthBloc>().state.user?.isExpert ?? false;
    final show = isExpertFlag || (_hasTeams ?? false);
    if (!show) return const SizedBox.shrink();

    return Column(
      children: [
        _profileDivider(widget.isDark),
        _ProfileRow(
          icon: Icons.assignment_ind,
          title: context.l10n.profileExpertManagement,
          subtitle: context.l10n.profileExpertManagementSubtitle,
          color: AppColors.indigo,
          onTap: () => context.push('/expert-dashboard'),
        ),
      ],
    );
  }
}

Widget _profileDivider(bool isDark) {
  return Divider(
    height: 1,
    indent: 56,
    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
  );
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

    return Semantics(
      button: true,
      label: 'Open menu item',
      child: GestureDetector(
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
              const SizedBox(width: 4),
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
      ),
    );
  }
}
