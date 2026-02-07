import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';

/// 引导教程页面
/// 参考iOS OnboardingView.swift
class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    this.onComplete,
  });

  final VoidCallback? onComplete;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 个性化数据
  String _selectedCity = 'London';
  final Set<String> _selectedTaskTypes = {};
  bool _notificationEnabled = false;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      title: '欢迎使用 Link²Ur',
      subtitle: '校园互助平台',
      description: '发布任务、接受任务、连接校园生活的每一面',
      icon: Icons.home_filled,
      color: AppColors.primary,
    ),
    _OnboardingPage(
      title: '发布任务',
      subtitle: '轻松找人帮忙',
      description: '描述你的需求，设定酬劳，等待有能力的同学接单',
      icon: Icons.add_circle,
      color: AppColors.success,
    ),
    _OnboardingPage(
      title: '接受任务',
      subtitle: '赚取额外收入',
      description: '浏览附近任务，选择你擅长的领域，利用闲暇时间获得报酬',
      icon: Icons.check_circle,
      color: AppColors.warning,
    ),
    _OnboardingPage(
      title: '安全支付',
      subtitle: '资金有保障',
      description: '平台托管资金，任务完成后自动结算，安全可靠',
      icon: Icons.shield,
      color: AppColors.error,
    ),
    _OnboardingPage(
      title: '社区互动',
      subtitle: '连接你的世界',
      description: '论坛交流、排行榜挑战、跳蚤市场…丰富的校园社交体验',
      icon: Icons.people,
      color: AppColors.primary,
    ),
  ];

  final List<String> _popularCities = const [
    'London',
    'Birmingham',
    'Manchester',
    'Edinburgh',
    'Glasgow',
    'Liverpool',
    'Bristol',
    'Leeds',
  ];

  final List<String> _taskTypes = const [
    '跑腿代办',
    '技能服务',
    '家政保洁',
    '交通出行',
    '社交帮助',
    '校园生活',
    '二手租赁',
    '宠物看护',
    '生活便利',
    '其他',
  ];

  int get _totalPages => _pages.length + 1; // +1 for personalization page

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    widget.onComplete?.call();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_city', _selectedCity);
    await prefs.setStringList(
      'preferred_task_types',
      _selectedTaskTypes.toList(),
    );
    await prefs.setBool('has_seen_onboarding', true);
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
              (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
                  .withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 跳过按钮
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                  ),
                  child: TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      '跳过',
                      style: AppTypography.body.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
              ),

              // 主要内容区域
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _totalPages,
                  itemBuilder: (context, index) {
                    if (index < _pages.length) {
                      return _OnboardingPageWidget(page: _pages[index]);
                    } else {
                      return _PersonalizationPage(
                        selectedCity: _selectedCity,
                        selectedTaskTypes: _selectedTaskTypes,
                        notificationEnabled: _notificationEnabled,
                        popularCities: _popularCities,
                        taskTypes: _taskTypes,
                        onCityChanged: (city) =>
                            setState(() => _selectedCity = city),
                        onTaskTypeToggled: (type) {
                          setState(() {
                            if (_selectedTaskTypes.contains(type)) {
                              _selectedTaskTypes.remove(type);
                            } else {
                              _selectedTaskTypes.add(type);
                            }
                          });
                        },
                        onNotificationChanged: (enabled) =>
                            setState(() => _notificationEnabled = enabled),
                      );
                    }
                  },
                ),
              ),

              // 页面指示器
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalPages, (index) {
                    return Container(
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

              // 底部按钮
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _goToPreviousPage,
                          icon: const Icon(Icons.chevron_left, size: 20),
                          label: const Text('上一步'),
                          style: OutlinedButton.styleFrom(
                            padding: AppSpacing.button,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.button,
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.dividerDark
                                  : AppColors.separatorLight,
                            ),
                          ),
                        ),
                      ),
                    if (_currentPage > 0) AppSpacing.hMd,
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.gradientPrimary,
                          ),
                          borderRadius: AppRadius.button,
                        ),
                        child: ElevatedButton(
                          onPressed: _goToNextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: AppSpacing.button,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.button,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage < _totalPages - 1
                                    ? '下一步'
                                    : '开始使用',
                                style: AppTypography.button.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              if (_currentPage < _totalPages - 1) ...[
                                AppSpacing.hXs,
                                const Icon(Icons.chevron_right,
                                    size: 20, color: Colors.white),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 引导页面数据模型
class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
}

/// 引导页面视图
class _OnboardingPageWidget extends StatelessWidget {
  const _OnboardingPageWidget({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // 图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: page.color,
            ),
          ),

          AppSpacing.vXl,

          // 标题
          Text(
            page.title,
            style: AppTypography.largeTitle.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),

          AppSpacing.vSm,

          Text(
            page.subtitle,
            style: AppTypography.title2.copyWith(
              color: page.color,
            ),
            textAlign: TextAlign.center,
          ),

          AppSpacing.vLg,

          // 描述
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              page.description,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

/// 个性化设置页面
class _PersonalizationPage extends StatelessWidget {
  const _PersonalizationPage({
    required this.selectedCity,
    required this.selectedTaskTypes,
    required this.notificationEnabled,
    required this.popularCities,
    required this.taskTypes,
    required this.onCityChanged,
    required this.onTaskTypeToggled,
    required this.onNotificationChanged,
  });

  final String selectedCity;
  final Set<String> selectedTaskTypes;
  final bool notificationEnabled;
  final List<String> popularCities;
  final List<String> taskTypes;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onTaskTypeToggled;
  final ValueChanged<bool> onNotificationChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.vXl,

          // 标题
          Center(
            child: Column(
              children: [
                Text(
                  '个性化设置',
                  style: AppTypography.largeTitle.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                AppSpacing.vSm,
                Text(
                  '帮助我们为你推荐更合适的内容',
                  style: AppTypography.body.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          AppSpacing.vXl,

          // 选择常用城市
          Text(
            '常用城市',
            style: AppTypography.title3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: popularCities.map((city) {
              final isSelected = selectedCity == city;
              return GestureDetector(
                onTap: () => onCityChanged(city),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: AppColors.gradientPrimary,
                          )
                        : null,
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDark
                                ? AppColors.dividerDark
                                : AppColors.separatorLight,
                          ),
                    borderRadius: AppRadius.allSmall,
                  ),
                  child: Text(
                    city,
                    style: AppTypography.body.copyWith(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          AppSpacing.vXl,

          // 选择感兴趣的任务类型
          Text(
            '感兴趣的任务类型（可选）',
            style: AppTypography.title3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: taskTypes.map((type) {
              final isSelected = selectedTaskTypes.contains(type);
              return GestureDetector(
                onTap: () => onTaskTypeToggled(type),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: AppColors.gradientPrimary,
                          )
                        : null,
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDark
                                ? AppColors.dividerDark
                                : AppColors.separatorLight,
                          ),
                    borderRadius: AppRadius.allSmall,
                  ),
                  child: Text(
                    type,
                    style: AppTypography.body.copyWith(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          AppSpacing.vXl,

          // 通知权限
          Container(
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark
                    ? AppColors.dividerDark
                    : AppColors.separatorLight,
              ),
              borderRadius: AppRadius.allMedium,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '开启通知提醒',
                        style: AppTypography.title3.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      AppSpacing.vXs,
                      Text(
                        '接收任务更新、消息提醒等重要通知',
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: notificationEnabled,
                  onChanged: onNotificationChanged,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),

          // 底部留白
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
