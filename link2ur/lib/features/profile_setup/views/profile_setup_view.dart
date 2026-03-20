import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../bloc/profile_setup_bloc.dart';

// ---------------------------------------------------------------------------
// Skill data — fetched from backend, with hardcoded fallback
// ---------------------------------------------------------------------------

class _Category {
  const _Category({required this.id, required this.label, required this.skills});
  final int id;
  final String label;
  final List<String> skills;
}

/// Fallback categories if backend fetch fails
const List<_Category> _fallbackCategories = [
  _Category(id: 1, label: '语言', skills: ['英语沟通', '中文翻译', '粤语']),
  _Category(id: 2, label: '出行', skills: ['开车', '接机', '陪同出行']),
  _Category(id: 3, label: '生活服务', skills: ['搬家', '组装家具', '代买代取']),
  _Category(id: 4, label: '专业服务', skills: ['写简历', '改论文', '拍照剪视频']),
  _Category(id: 5, label: '本地经验', skills: ['银行开户', '租房流程', '签证办理', '学校注册']),
];

// ---------------------------------------------------------------------------
// Task mode data
// ---------------------------------------------------------------------------

class _ModeOption {
  const _ModeOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });
  final String value;
  final String label;
  final String description;
  final IconData icon;
}

const List<_ModeOption> _modeOptions = [
  _ModeOption(
    value: 'online',
    label: '线上任务',
    description: '通过视频、文字或远程方式完成任务',
    icon: Icons.laptop_mac,
  ),
  _ModeOption(
    value: 'offline',
    label: '线下任务',
    description: '面对面、实地协助完成任务',
    icon: Icons.location_on,
  ),
  _ModeOption(
    value: 'both',
    label: '都可以',
    description: '线上线下均可，灵活接单',
    icon: Icons.swap_horiz,
  ),
];

// ---------------------------------------------------------------------------
// ProfileSetupView
// ---------------------------------------------------------------------------

class ProfileSetupView extends StatelessWidget {
  const ProfileSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProfileSetupBloc(repository: context.read<UserProfileRepository>()),
      child: const _ProfileSetupScaffold(),
    );
  }
}

class _ProfileSetupScaffold extends StatefulWidget {
  const _ProfileSetupScaffold();

  @override
  State<_ProfileSetupScaffold> createState() => _ProfileSetupScaffoldState();
}

class _ProfileSetupScaffoldState extends State<_ProfileSetupScaffold> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<_Category> _categories = _fallbackCategories;

  static const int _totalPages = 2;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  // Map from category id to suggested sub-skills (used as hints)
  static const _skillSuggestions = <int, List<String>>{
    1: ['英语沟通', '中文翻译', '粤语'],
    2: ['开车', '接机', '陪同出行'],
    3: ['搬家', '组装家具', '代买代取'],
    4: ['写简历', '改论文', '拍照剪视频'],
    5: ['银行开户', '租房流程', '签证办理', '学校注册'],
  };

  Future<void> _loadCategories() async {
    try {
      final repo = context.read<UserProfileRepository>();
      final data = await repo.getSkillCategories();
      if (mounted && data.isNotEmpty) {
        setState(() {
          _categories = data.map((c) {
            final id = c['id'] as int;
            return _Category(
              id: id,
              label: c['name_zh'] as String? ?? c['name_en'] as String? ?? '',
              skills: _skillSuggestions[id] ?? const [],
            );
          }).toList();
        });
      }
    } catch (_) {
      // Keep fallback categories
    }
  }

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
      context.read<ProfileSetupBloc>().add(const ProfileSetupSubmit());
    }
  }

  void _skip() {
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<ProfileSetupBloc, ProfileSetupState>(
      listenWhen: (prev, curr) => curr.status != prev.status,
      listener: (context, state) {
        if (state.status == ProfileSetupStatus.success) {
          context.go('/');
        } else if (state.status == ProfileSetupStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? '提交失败，请重试'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
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
                // Top bar: step indicator + skip
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      // Page dots
                      Row(
                        children: List.generate(_totalPages, (index) {
                          return Container(
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
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
                      const Spacer(),
                      // Skip button
                      TextButton(
                        onPressed: _skip,
                        child: Text(
                          '跳过',
                          style: AppTypography.body.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    children: [
                      _SkillsPage(categories: _categories),
                      const _ModePage(),
                    ],
                  ),
                ),

                // Bottom action button
                BlocBuilder<ProfileSetupBloc, ProfileSetupState>(
                  buildWhen: (prev, curr) => curr.status != prev.status,
                  builder: (context, state) {
                    final isSubmitting =
                        state.status == ProfileSetupStatus.submitting;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.xl,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.gradientPrimary,
                            ),
                            borderRadius: AppRadius.button,
                          ),
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : _goToNextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: AppSpacing.button,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.button,
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _currentPage < _totalPages - 1
                                        ? '下一步'
                                        : '完成',
                                    style: AppTypography.button.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1: Skills
// ---------------------------------------------------------------------------

class _SkillsPage extends StatelessWidget {
  const _SkillsPage({required this.categories});
  final List<_Category> categories;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.vXl,

          // Title
          Text(
            '你擅长什么？',
            style: AppTypography.largeTitle.copyWith(
              color:
                  isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vSm,
          Text(
            '选择你的技能领域',
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),

          AppSpacing.vXl,

          // Category chips + sub-skill chips
          BlocBuilder<ProfileSetupBloc, ProfileSetupState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categories.map((cat) {
                  final isSelected =
                      state.selectedCategories.contains(cat.id);
                  return _CategorySection(
                    category: cat,
                    isSelected: isSelected,
                    selectedSkills: state.selectedSkills,
                    isDark: isDark,
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.isSelected,
    required this.selectedSkills,
    required this.isDark,
  });

  final _Category category;
  final bool isSelected;
  final List<Map<String, dynamic>> selectedSkills;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category chip
        GestureDetector(
          onTap: () => context
              .read<ProfileSetupBloc>()
              .add(ProfileSetupSelectCategory(categoryId: category.id)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(colors: AppColors.gradientPrimary)
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
              category.label,
              style: AppTypography.body.copyWith(
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Sub-skill chips when category selected
        if (isSelected) ...[
          AppSpacing.vSm,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: category.skills.map((skill) {
              final skillSelected = selectedSkills
                  .any((s) => s['skill_name'] == skill);
              return GestureDetector(
                onTap: () {
                  final bloc = context.read<ProfileSetupBloc>();
                  if (skillSelected) {
                    bloc.add(ProfileSetupRemoveSkill(skillName: skill));
                  } else {
                    bloc.add(ProfileSetupAddSkill(
                      categoryId: category.id,
                      skillName: skill,
                    ));
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: skillSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : null,
                    border: Border.all(
                      color: skillSelected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.dividerDark
                              : AppColors.separatorLight),
                    ),
                    borderRadius: AppRadius.allSmall,
                  ),
                  child: Text(
                    skill,
                    style: AppTypography.caption.copyWith(
                      color: skillSelected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                      fontWeight:
                          skillSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        AppSpacing.vMd,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: Mode
// ---------------------------------------------------------------------------

class _ModePage extends StatelessWidget {
  const _ModePage();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.vXl,

          // Title
          Text(
            '你更喜欢什么类型的任务？',
            style: AppTypography.title.copyWith(
              color:
                  isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),

          AppSpacing.vXl,

          BlocBuilder<ProfileSetupBloc, ProfileSetupState>(
            buildWhen: (prev, curr) => curr.mode != prev.mode,
            builder: (context, state) {
              return Column(
                children: _modeOptions.map((option) {
                  final isSelected = state.mode == option.value;
                  return _ModeCard(
                    option: option,
                    isSelected: isSelected,
                    isDark: isDark,
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.option,
    required this.isSelected,
    required this.isDark,
  });

  final _ModeOption option;
  final bool isSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context
          .read<ProfileSetupBloc>()
          .add(ProfileSetupSetMode(mode: option.value)),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primaryLight.withValues(alpha: 0.08),
                  ],
                )
              : null,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.dividerDark : AppColors.separatorLight),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: AppRadius.allMedium,
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isDark
                        ? AppColors.cardBackgroundDark
                        : AppColors.cardBackgroundLight),
                borderRadius: AppRadius.allSmall,
              ),
              child: Icon(
                option.icon,
                size: 26,
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            ),

            AppSpacing.hMd,

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: AppTypography.title3.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                  AppSpacing.vXs,
                  Text(
                    option.description,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),

            // Check mark
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
