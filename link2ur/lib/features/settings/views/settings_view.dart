import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/widgets/external_web_view.dart';
import '../bloc/settings_bloc.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../auth/bloc/auth_bloc.dart';

/// 设置页面
/// 参考iOS SettingsView.swift
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = null; // Will use l10n fallback in build method
        });
      }
    }
  }

  /// 在应用内 WebView 打开链接（条款/隐私等）
  void _openInAppWebView(String url, String title) {
    ExternalWebView.openInApp(context, url: url, title: title);
  }

  void _showDeleteAccountDialog(BuildContext context) {
    SheetAdaptation.showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsDeleteAccount),
        content: Text(
          context.l10n.settingsDeleteAccountMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 发送删除账户事件
              context.read<SettingsBloc>().add(const SettingsDeleteAccount());
              // 监听状态 —— 成功后退出登录
              context.read<AuthBloc>().add(AuthLogoutRequested());
              context.go('/login');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(context.l10n.settingsDeleteAccount),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profileSettings),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (!authState.isAuthenticated) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: AppColors.textTertiaryLight,
                  ),
                  AppSpacing.vMd,
                  Text(
                    context.l10n.settingsPleaseLoginFirst,
                    style: const TextStyle(color: AppColors.textSecondaryLight),
                  ),
                  AppSpacing.vLg,
                  ElevatedButton(
                    onPressed: () => context.push('/login'),
                    child: Text(context.l10n.settingsGoLogin),
                  ),
                ],
              ),
            );
          }

          final user = authState.user!;

          return BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, settingsState) {
              return SingleChildScrollView(
                padding: AppSpacing.allMd,
                child: Column(
                  children: [
                    // 通知偏好
                    _SettingsSection(
                      title: context.l10n.settingsNotifications,
                      children: [
                        _SettingsSwitchRow(
                          icon: Icons.notifications_outlined,
                          title: context.l10n.settingsAllowNotifications,
                          subtitle: context.l10n.settingsNotifications,
                          value: settingsState.notificationsEnabled,
                          onChanged: (value) {
                            context.read<SettingsBloc>().add(
                                  SettingsNotificationToggled(value),
                                );
                          },
                        ),
                        _settingsDivider(isDark),
                        _SettingsSwitchRow(
                          icon: Icons.volume_up_outlined,
                          title: context.l10n.settingsSuccessSound,
                          subtitle: context.l10n.settingsSuccessSoundDescription,
                          value: settingsState.soundEnabled,
                          onChanged: (value) {
                            context.read<SettingsBloc>().add(
                                  SettingsSoundToggled(value),
                                );
                          },
                        ),
                      ],
                    ),
                    AppSpacing.vMd,

                    // 外观
                    _SettingsSection(
                      title: context.l10n.settingsAppearance,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.settingsThemeMode,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              AppSpacing.vSm,
                              SegmentedButton<ThemeMode>(
                                segments: [
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.system,
                                    label: Text(context.l10n.settingsThemeSystem),
                                    icon: const Icon(Icons.brightness_auto, size: 18),
                                  ),
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.light,
                                    label: Text(context.l10n.settingsThemeLight),
                                    icon: const Icon(Icons.light_mode, size: 18),
                                  ),
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.dark,
                                    label: Text(context.l10n.settingsThemeDark),
                                    icon: const Icon(Icons.dark_mode, size: 18),
                                  ),
                                ],
                                selected: {settingsState.themeMode},
                                onSelectionChanged:
                                    (Set<ThemeMode> selected) {
                                  context.read<SettingsBloc>().add(
                                        SettingsThemeChanged(selected.first),
                                      );
                                },
                              ),
                            ],
                          ),
                        ),
                        _settingsDivider(isDark),
                        _SettingsNavRow(
                          icon: Icons.language,
                          title: context.l10n.settingsLanguage,
                          trailing: Text(
                            settingsState.locale == 'zh' ||
                                    settingsState.locale == 'zh-CN'
                                ? context.l10n.settingsChinese
                                : 'English',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () {
                            final isZh = settingsState.locale == 'zh' ||
                                settingsState.locale == 'zh-CN';
                            context.read<SettingsBloc>().add(
                                  SettingsLanguageChanged(
                                    isZh ? 'en' : 'zh-CN',
                                  ),
                                );
                          },
                        ),
                      ],
                    ),
                    AppSpacing.vMd,

                    // 收款与支付 (对齐iOS)
                    _SettingsSection(
                      title: context.l10n.settingsPaymentReceiving,
                      children: [
                        _SettingsNavRow(
                          icon: Icons.account_balance,
                          title: context.l10n.settingsPaymentAccount,
                          subtitle: 'Stripe Connect',
                          onTap: () => context.push('/payment/stripe-connect/onboarding'),
                        ),
                        _settingsDivider(isDark),
                        _SettingsNavRow(
                          icon: Icons.payments_outlined,
                          title: context.l10n.settingsExpenseManagement,
                          onTap: () => context.push('/payment/stripe-connect/payouts'),
                        ),
                        _settingsDivider(isDark),
                        _SettingsNavRow(
                          icon: Icons.receipt_long_outlined,
                          title: context.l10n.settingsPaymentHistory,
                          onTap: () => context.push('/payment/stripe-connect/payments'),
                        ),
                      ],
                    ),
                    AppSpacing.vMd,

                    // 会员
                    _SettingsSection(
                      title: context.l10n.settingsMembership,
                      children: [
                        _SettingsNavRow(
                          icon: Icons.workspace_premium,
                          title: context.l10n.settingsVipMembership,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.gradientGold,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () => context.push('/vip/purchase'),
                        ),
                      ],
                    ),
                    AppSpacing.vMd,

                    // 帮助与支持 (对齐iOS)
                    _SettingsSection(
                      title: context.l10n.settingsHelpSupport,
                      children: [
                        _SettingsNavRow(
                          icon: Icons.help_outline,
                          title: context.l10n.settingsFaq,
                          onTap: () => context.push('/faq'),
                        ),
                        _settingsDivider(isDark),
                        _SettingsNavRow(
                          icon: Icons.support_agent,
                          title: context.l10n.settingsContactSupport,
                          onTap: () => context.push('/support-chat'),
                        ),
                      ],
                    ),
                    AppSpacing.vMd,

                    // 法律条款 (对齐iOS)
                    _SettingsSection(
                      title: context.l10n.settingsLegal,
                      children: [
                        _SettingsNavRow(
                          icon: Icons.description_outlined,
                          title: context.l10n.appTermsOfService,
                          onTap: () => _openInAppWebView(
                            'https://link2ur.com/terms',
                            context.l10n.appTermsOfService,
                          ),
                        ),
                        _settingsDivider(isDark),
                        _SettingsNavRow(
                          icon: Icons.privacy_tip_outlined,
                          title: context.l10n.appPrivacyPolicy,
                          onTap: () => _openInAppWebView(
                            'https://link2ur.com/privacy',
                            context.l10n.appPrivacyPolicy,
                          ),
                        ),
                        _settingsDivider(isDark),
                        _SettingsNavRow(
                          icon: Icons.cookie_outlined,
                          title: context.l10n.settingsCookiePolicy,
                          onTap: () => _openInAppWebView(
                            'https://link2ur.com/cookies',
                            context.l10n.settingsCookiePolicy,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vMd,

                    // 关于
                    _SettingsSection(
                      title: context.l10n.settingsAbout,
                      children: [
                        _SettingsInfoRow(
                          icon: Icons.info_outline,
                          title: context.l10n.settingsAppName,
                          value: context.l10n.appName,
                        ),
                        _settingsDivider(isDark),
                        _SettingsInfoRow(
                          icon: Icons.numbers,
                          title: context.l10n.appVersion,
                          value: _appVersion ??
                              (settingsState.appVersion.isNotEmpty
                                  ? settingsState.appVersion
                                  : context.l10n.settingsUnknown),
                        ),
                      ],
                    ),
                    AppSpacing.vMd,

                    // 账户信息
                    _SettingsSection(
                      title: context.l10n.settingsAccount,
                      children: [
                        _SettingsInfoRow(
                          icon: Icons.badge_outlined,
                          title: context.l10n.settingsUserId,
                          value: user.id,
                        ),
                        _settingsDivider(isDark),
                        _SettingsInfoRow(
                          icon: Icons.email_outlined,
                          title: context.l10n.settingsEmail,
                          value: user.email ?? context.l10n.settingsNotBound,
                        ),
                      ],
                    ),
                    AppSpacing.vMd,

                    // 其他
                    _SettingsSection(
                      title: context.l10n.settingsOther,
                      children: [
                        _SettingsNavRow(
                          icon: Icons.delete_outline,
                          title: context.l10n.settingsClearCache,
                          trailing: Text(
                            settingsState.cacheSize == 'common_loading'
                                ? context.l10n.commonLoading
                                : settingsState.cacheSize,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () {
                            context
                                .read<SettingsBloc>()
                                .add(const SettingsClearCache());
                          },
                        ),
                      ],
                    ),
                    AppSpacing.vMd,

                    // 危险区域 (对齐iOS)
                    _SettingsSection(
                      title: context.l10n.settingsDangerZone,
                      titleColor: AppColors.error,
                      children: [
                        _SettingsNavRow(
                          icon: Icons.delete_forever_outlined,
                          title: context.l10n.settingsDeleteAccount,
                          titleColor: AppColors.error,
                          iconColor: AppColors.error,
                          onTap: () => _showDeleteAccountDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _settingsDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 52,
      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
    );
  }
}

/// 设置分组
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    this.titleColor,
  });

  final String title;
  final List<Widget> children;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: titleColor ??
                  (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allLarge,
            // 与iOS InsetGroupedListStyle对齐：微妙边框 + 轻阴影
            border: Border.all(
              color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                  .withValues(alpha: 0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// 导航行（带箭头）
class _SettingsNavRow extends StatelessWidget {
  const _SettingsNavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleColor,
    this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? titleColor;
  final Color? iconColor;
  final VoidCallback onTap;

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ??
                  (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: titleColor ??
                          (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
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
    );
  }
}

/// 开关行
class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 信息行（只读，无箭头）
class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
