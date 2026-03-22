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
                // Skip button at top-right
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () {
                            context
                                .read<IdentityOnboardingBloc>()
                                .add(const OnboardingSubmit());
                          },
                    child: Text(
                      context.l10n.onboardingSkillsSkip,
                      style: AppTypography.callout.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      _ProfileStep(),
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

// ==================== Step 1: Profile Setup ====================

class _ProfileStep extends StatefulWidget {
  const _ProfileStep();

  @override
  State<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<_ProfileStep> {
  late final TextEditingController _nameController;
  String? _selectedIdentity;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;
    _nameController = TextEditingController(text: user?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _isRandomEmail(String? email) {
    if (email == null || email.isEmpty) return true;
    return email.contains('@link2ur.com') && email.startsWith('phone_');
  }

  void _onNext() {
    final name = _nameController.text.trim();
    final bloc = context.read<IdentityOnboardingBloc>();
    if (name.isNotEmpty) {
      bloc.add(OnboardingSetProfile(name: name));
    }
    bloc.add(OnboardingSetIdentity(_selectedIdentity!));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    return Padding(
      padding: AppSpacing.horizontalLg,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
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

                  // Avatar section
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primary.withAlpha(30),
                          backgroundImage: user?.avatar != null &&
                                  user!.avatar!.isNotEmpty
                              ? NetworkImage(user.avatar!)
                              : null,
                          child: user?.avatar == null || user!.avatar!.isEmpty
                              ? const Icon(Icons.person_rounded,
                                  size: 40, color: AppColors.primary)
                              : null,
                        ),
                        AppSpacing.vSm,
                        Text(
                          l10n.onboardingProfileAvatar,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.vLg,

                  // Name field
                  Text(
                    l10n.onboardingProfileName,
                    style: AppTypography.callout.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vSm,
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: l10n.onboardingProfileName,
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allMedium,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  AppSpacing.vMd,

                  // Email field (only if random/invalid)
                  if (_isRandomEmail(user?.email)) ...[
                    Text(
                      l10n.onboardingProfileEmail,
                      style: AppTypography.callout.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.vSm,
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: l10n.onboardingProfileEmail,
                        prefixIcon:
                            const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.allMedium,
                        ),
                        suffixIcon: const Tooltip(
                          message: 'Can be updated in profile settings',
                          child: Icon(Icons.info_outline_rounded,
                              size: 20,
                              color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ),
                    AppSpacing.vMd,
                  ],

                  // Phone field (only if empty)
                  if (user?.phone == null || user!.phone!.isEmpty) ...[
                    Text(
                      l10n.onboardingProfilePhone,
                      style: AppTypography.callout.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.vSm,
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: l10n.onboardingProfilePhone,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.allMedium,
                        ),
                        suffixIcon: const Tooltip(
                          message: 'Can be updated in profile settings',
                          child: Icon(Icons.info_outline_rounded,
                              size: 20,
                              color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ),
                    AppSpacing.vMd,
                  ],

                  AppSpacing.vSm,

                  // Identity selection
                  Text(
                    l10n.onboardingProfileIdentityLabel,
                    style: AppTypography.callout.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vSm,
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.luggage_rounded,
                            size: 18,
                            color: _selectedIdentity == 'pre_arrival'
                                ? AppColors.primary
                                : theme.colorScheme.onSurface,
                          ),
                          label: Text(l10n.onboardingIdentityPreArrival),
                          selected: _selectedIdentity == 'pre_arrival',
                          selectedColor: AppColors.primary.withAlpha(30),
                          labelStyle: AppTypography.callout.copyWith(
                            color: _selectedIdentity == 'pre_arrival'
                                ? AppColors.primary
                                : theme.colorScheme.onSurface,
                            fontWeight: _selectedIdentity == 'pre_arrival'
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: _selectedIdentity == 'pre_arrival'
                                ? AppColors.primary
                                : (isDark
                                    ? Colors.white.withAlpha(30)
                                    : Colors.black.withAlpha(20)),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.allSmall,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedIdentity = 'pre_arrival');
                          },
                        ),
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: _selectedIdentity == 'in_uk'
                                ? AppColors.primary
                                : theme.colorScheme.onSurface,
                          ),
                          label: Text(l10n.onboardingIdentityInUk),
                          selected: _selectedIdentity == 'in_uk',
                          selectedColor: AppColors.primary.withAlpha(30),
                          labelStyle: AppTypography.callout.copyWith(
                            color: _selectedIdentity == 'in_uk'
                                ? AppColors.primary
                                : theme.colorScheme.onSurface,
                            fontWeight: _selectedIdentity == 'in_uk'
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: _selectedIdentity == 'in_uk'
                                ? AppColors.primary
                                : (isDark
                                    ? Colors.white.withAlpha(30)
                                    : Colors.black.withAlpha(20)),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.allSmall,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedIdentity = 'in_uk');
                          },
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vLg,
                ],
              ),
            ),
          ),

          // Next button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedIdentity != null ? _onNext : null,
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
