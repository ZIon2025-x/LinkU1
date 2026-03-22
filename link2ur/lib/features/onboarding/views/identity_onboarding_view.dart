import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/bloc/auth_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../bloc/identity_onboarding_bloc.dart';

class IdentityOnboardingView extends StatelessWidget {
  const IdentityOnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => IdentityOnboardingBloc(
        repository: context.read<UserProfileRepository>(),
      ),
      child: const _OnboardingContent(),
    );
  }
}

class _OnboardingContent extends StatefulWidget {
  const _OnboardingContent();

  @override
  State<_OnboardingContent> createState() => _OnboardingContentState();
}

class _OnboardingContentState extends State<_OnboardingContent> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IdentityOnboardingBloc, IdentityOnboardingState>(
      listenWhen: (prev, curr) =>
          prev.currentStep != curr.currentStep ||
          curr.isComplete ||
          (prev.errorMessage == null && curr.errorMessage != null),
      listener: (context, state) {
        if (state.isComplete) {
          // Refresh auth state so router redirect knows onboarding is done
          context.read<AuthBloc>().add(AuthCheckRequested());
          context.go('/');
          return;
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          return;
        }
        _goToPage(state.currentStep);
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      _IdentityStep(),
                      _CityStep(),
                      _SkillsStep(),
                    ],
                  ),
                ),
                _PageIndicator(currentStep: state.currentStep),
                AppSpacing.vMd,
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== Step 1: Identity Selection ====================

class _IdentityStep extends StatelessWidget {
  const _IdentityStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: AppSpacing.horizontalLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.vXl,
          Text(
            l10n.onboardingIdentityTitle,
            style: AppTypography.title.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          AppSpacing.vXl,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _IdentityCard(
                  icon: Icons.flight_takeoff_rounded,
                  label: l10n.onboardingIdentityPreArrival,
                  value: 'pre_arrival',
                  isDark: isDark,
                ),
                AppSpacing.vMd,
                _IdentityCard(
                  icon: Icons.school_rounded,
                  label: l10n.onboardingIdentityInUk,
                  value: 'in_uk',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _IdentityCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context
            .read<IdentityOnboardingBloc>()
            .add(OnboardingSetIdentity(value));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withAlpha(15)
              : AppColors.primary.withAlpha(15),
          borderRadius: AppRadius.allLarge,
          border: Border.all(
            color: AppColors.primary.withAlpha(60),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.gradientPrimary,
                ),
                borderRadius: AppRadius.allMedium,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyBold.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Step 2: City Selection ====================

class _CityStep extends StatefulWidget {
  const _CityStep();

  @override
  State<_CityStep> createState() => _CityStepState();
}

class _CityStepState extends State<_CityStep> {
  final TextEditingController _customCityController = TextEditingController();
  String? _selectedCity;

  static const List<String> _cities = [
    'London',
    'Manchester',
    'Birmingham',
    'Edinburgh',
    'Glasgow',
    'Leeds',
    'Bristol',
    'Sheffield',
    'Liverpool',
    'Nottingham',
    'Cambridge',
    'Oxford',
  ];

  @override
  void dispose() {
    _customCityController.dispose();
    super.dispose();
  }

  void _onCitySelected(String city) {
    setState(() {
      _selectedCity = city;
      _customCityController.clear();
    });
  }

  void _onNext() {
    final city = _customCityController.text.trim().isNotEmpty
        ? _customCityController.text.trim()
        : _selectedCity;
    if (city != null && city.isNotEmpty) {
      context.read<IdentityOnboardingBloc>().add(OnboardingSetCity(city));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: AppSpacing.horizontalLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.vXl,
          Text(
            l10n.onboardingCityTitle,
            style: AppTypography.title.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          AppSpacing.vLg,
          TextField(
            controller: _customCityController,
            decoration: InputDecoration(
              hintText: l10n.onboardingCityHint,
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: AppRadius.allMedium,
              ),
            ),
            onChanged: (_) {
              setState(() {
                _selectedCity = null;
              });
            },
          ),
          AppSpacing.vMd,
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _cities.map((city) {
                  final isSelected = _selectedCity == city;
                  return ChoiceChip(
                    label: Text(city),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withAlpha(30),
                    labelStyle: AppTypography.callout.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? Colors.white.withAlpha(30)
                              : Colors.black.withAlpha(20)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.allSmall,
                    ),
                    onSelected: (_) => _onCitySelected(city),
                  );
                }).toList(),
              ),
            ),
          ),
          AppSpacing.vMd,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_selectedCity != null ||
                      _customCityController.text.trim().isNotEmpty)
                  ? _onNext
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: AppSpacing.button,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.allMedium,
                ),
              ),
              child: Text(
                l10n.onboardingNext,
                style: AppTypography.bodyBold.copyWith(color: Colors.white),
              ),
            ),
          ),
          AppSpacing.vMd,
        ],
      ),
    );
  }
}

// ==================== Step 3: Skills Selection ====================

class _SkillsStep extends StatefulWidget {
  const _SkillsStep();

  @override
  State<_SkillsStep> createState() => _SkillsStepState();
}

class _SkillsStepState extends State<_SkillsStep> {
  List<Map<String, dynamic>> _categories = [];
  final Set<int> _selectedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final repo = context.read<UserProfileRepository>();
      final data = await repo.getSkillCategories();
      if (mounted) {
        setState(() {
          _categories = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSubmit({bool skip = false}) {
    final bloc = context.read<IdentityOnboardingBloc>();
    if (!skip && _selectedIds.isNotEmpty) {
      final locale = Localizations.localeOf(context).languageCode;
      final selectedSkills = _categories
          .where((c) => _selectedIds.contains(c['id']))
          .map((c) => {
                'category_id': c['id'],
                'skill_name': locale == 'zh'
                    ? (c['name_zh'] ?? c['name_en'] ?? '')
                    : (c['name_en'] ?? c['name_zh'] ?? ''),
                'proficiency': 'beginner',
              })
          .toList();
      bloc.add(OnboardingSetSkills(selectedSkills));
    }
    bloc.add(const OnboardingSubmit());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<IdentityOnboardingBloc, IdentityOnboardingState>(
      buildWhen: (prev, curr) => prev.isSubmitting != curr.isSubmitting,
      builder: (context, state) {
        return Padding(
          padding: AppSpacing.horizontalLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSpacing.vXl,
              Text(
                l10n.onboardingSkillsTitle,
                style: AppTypography.title.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              AppSpacing.vLg,
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _categories.map((cat) {
                            final id = cat['id'] as int;
                            // Backend returns name_zh and name_en
                            final locale = Localizations.localeOf(context).languageCode;
                            final name = locale == 'zh'
                                ? (cat['name_zh'] as String? ?? cat['name_en'] as String? ?? '')
                                : (cat['name_en'] as String? ?? cat['name_zh'] as String? ?? '');
                            final isSelected = _selectedIds.contains(id);
                            return FilterChip(
                              label: Text(name),
                              selected: isSelected,
                              selectedColor: AppColors.primary.withAlpha(30),
                              labelStyle: AppTypography.callout.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : theme.colorScheme.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                        ? Colors.white.withAlpha(30)
                                        : Colors.black.withAlpha(20)),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.allSmall,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedIds.add(id);
                                  } else {
                                    _selectedIds.remove(id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
              ),
              AppSpacing.vMd,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          state.isSubmitting ? null : () => _onSubmit(skip: true),
                      style: OutlinedButton.styleFrom(
                        padding: AppSpacing.button,
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withAlpha(50)
                              : Colors.black.withAlpha(30),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.allMedium,
                        ),
                      ),
                      child: Text(
                        l10n.onboardingSkillsSkip,
                        style: AppTypography.bodyBold.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: FilledButton(
                      onPressed: state.isSubmitting ? null : () => _onSubmit(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: AppSpacing.button,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.allMedium,
                        ),
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n.onboardingComplete,
                              style: AppTypography.bodyBold
                                  .copyWith(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
              AppSpacing.vMd,
            ],
          ),
        );
      },
    );
  }
}

// ==================== Page Indicator ====================

class _PageIndicator extends StatelessWidget {
  final int currentStep;

  const _PageIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withAlpha(50),
            borderRadius: AppRadius.allPill,
          ),
        );
      }),
    );
  }
}
