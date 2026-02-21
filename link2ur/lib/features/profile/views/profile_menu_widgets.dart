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
                icon: Icons.inventory_2,           // shippingbox.fill
                title: context.l10n.profileMyPosts,
                subtitle: context.l10n.profileMyPostsSubtitle,
                color: Colors.orange,
                onTap: () => context.push('/profile/my-posts'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.description,           // doc.text.fill
                title: context.l10n.profileMyForumPosts,
                subtitle: context.l10n.profileMyForumPostsSubtitle,
                color: Colors.blue,
                onTap: () => context.push('/forum/my-posts'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.storefront,            // sold items
                title: context.l10n.profileMySoldItems,
                subtitle: context.l10n.profileMySoldItemsSubtitle,
                color: Colors.teal,
                onTap: () => context.push('/flea-market'),
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
                color: Colors.orange,
                onTap: () => context.push('/activities'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.favorite,              // heart.text.square.fill
                title: context.l10n.profileTaskPreferences,
                color: Colors.red,
                onTap: () => context.push('/profile/task-preferences'),
              ),
              _profileDivider(isDark),
              _ProfileRow(
                icon: Icons.local_activity,        // ticket.fill
                title: context.l10n.profilePointsCoupons,
                color: Colors.pink,
                onTap: () => context.push('/coupon-points'),
              ),
              _profileDivider(isDark),
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
  SheetAdaptation.showAdaptiveDialog(
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
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

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
