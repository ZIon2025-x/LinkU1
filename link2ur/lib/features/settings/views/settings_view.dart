import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/settings_bloc.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/cards.dart';
import '../../auth/bloc/auth_bloc.dart';

/// 设置页面
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
          _appVersion = '未知';
        });
      }
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认登出'),
        content: const Text('确定要登出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(AuthLogoutRequested());
              context.go('/login');
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('登出'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
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
                    const Text(
                      '请先登录',
                      style: TextStyle(color: AppColors.textSecondaryLight),
                    ),
                    AppSpacing.vLg,
                    ElevatedButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('去登录'),
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
                      // 账户信息
                      GroupedCard(
                        header: Padding(
                          padding: AppSpacing.horizontalMd,
                          child: const Text(
                            '账户信息',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        children: [
                          ListTile(
                            contentPadding: AppSpacing.horizontalMd,
                            leading: const Icon(Icons.email_outlined),
                            title: const Text('邮箱'),
                            subtitle: Text(user.email ?? '未绑定'),
                          ),
                          ListTile(
                            contentPadding: AppSpacing.horizontalMd,
                            leading: const Icon(Icons.phone_outlined),
                            title: const Text('手机号'),
                            subtitle: Text(user.phone ?? '未绑定'),
                          ),
                        ],
                      ),
                      AppSpacing.vMd,

                      // 外观
                      GroupedCard(
                        header: Padding(
                          padding: AppSpacing.horizontalMd,
                          child: const Text(
                            '外观',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: AppSpacing.horizontalMd,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '主题',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                AppSpacing.vSm,
                                SegmentedButton<ThemeMode>(
                                  segments: const [
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.system,
                                      label: Text('跟随系统'),
                                      icon: Icon(Icons.brightness_auto),
                                    ),
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.light,
                                      label: Text('浅色'),
                                      icon: Icon(Icons.light_mode),
                                    ),
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.dark,
                                      label: Text('深色'),
                                      icon: Icon(Icons.dark_mode),
                                    ),
                                  ],
                                  selected: {settingsState.themeMode},
                                  onSelectionChanged: (Set<ThemeMode> selected) {
                                    context.read<SettingsBloc>().add(
                                          SettingsThemeChanged(selected.first),
                                        );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.vMd,

                      // 偏好设置
                      GroupedCard(
                        header: Padding(
                          padding: AppSpacing.horizontalMd,
                          child: const Text(
                            '偏好设置',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        children: [
                          ListTile(
                            contentPadding: AppSpacing.horizontalMd,
                            leading: const Icon(Icons.language),
                            title: const Text('语言'),
                            subtitle: Text(
                              settingsState.locale == 'zh' ||
                                      settingsState.locale == 'zh-CN'
                                  ? '中文'
                                  : 'English',
                            ),
                            trailing: Switch(
                              value: settingsState.locale == 'zh' ||
                                  settingsState.locale == 'zh-CN',
                              onChanged: (value) {
                                context.read<SettingsBloc>().add(
                                      SettingsLanguageChanged(
                                        value ? 'zh-CN' : 'en',
                                      ),
                                    );
                              },
                            ),
                          ),
                          ListTile(
                            contentPadding: AppSpacing.horizontalMd,
                            leading: const Icon(Icons.notifications_outlined),
                            title: const Text('通知'),
                            subtitle: const Text('接收推送通知'),
                            trailing: Switch(
                              value: settingsState.notificationsEnabled,
                              onChanged: (value) {
                                context.read<SettingsBloc>().add(
                                      SettingsNotificationToggled(value),
                                    );
                              },
                            ),
                          ),
                          ListTile(
                            contentPadding: AppSpacing.horizontalMd,
                            leading: const Icon(Icons.delete_outline),
                            title: const Text('清除缓存'),
                            subtitle: Text(settingsState.cacheSize),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              context
                                  .read<SettingsBloc>()
                                  .add(const SettingsClearCache());
                            },
                          ),
                        ],
                      ),
                      AppSpacing.vMd,

                      // 账户管理
                      GroupedCard(
                        header: Padding(
                          padding: AppSpacing.horizontalMd,
                          child: const Text(
                            '账户管理',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        children: [
                          ListTile(
                            contentPadding: AppSpacing.horizontalMd,
                            leading: const Icon(Icons.school_outlined),
                            title: const Text('学生认证'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              context.push('/student-verification');
                            },
                          ),
                        ],
                      ),
                      AppSpacing.vMd,

                      // 隐私与法律
                      GroupedCard(
                        header: Padding(
                          padding: AppSpacing.horizontalMd,
                          child: const Text(
                            '隐私与法律',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        children: [
                          ListTile(
                            contentPadding: AppSpacing.horizontalMd,
                            leading: const Icon(Icons.privacy_tip_outlined),
                            title: const Text('隐私政策'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _launchUrl(
                              'https://link2ur.com/privacy',
                            ),
                          ),
                          ListTile(
                            contentPadding: AppSpacing.horizontalMd,
                            leading: const Icon(Icons.description_outlined),
                            title: const Text('服务条款'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _launchUrl(
                              'https://link2ur.com/terms',
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.vMd,

                      // 关于
                      GroupedCard(
                        header: Padding(
                          padding: AppSpacing.horizontalMd,
                          child: const Text(
                            '关于',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        children: [
                          ListTile(
                            contentPadding: AppSpacing.horizontalMd,
                            leading: const Icon(Icons.info_outlined),
                            title: const Text('版本'),
                            subtitle: Text(
                              _appVersion ??
                                  (settingsState.appVersion.isNotEmpty
                                      ? settingsState.appVersion
                                      : '加载中...'),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.vLg,

                      // 登出按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _handleLogout(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.button,
                            ),
                          ),
                          child: const Text('登出'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
    );
  }
}
