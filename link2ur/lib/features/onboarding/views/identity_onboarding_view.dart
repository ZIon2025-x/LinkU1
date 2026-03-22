import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/constants/interest_categories.dart';
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
          (prev.isComplete != curr.isComplete && curr.isComplete) ||
          (prev.errorMessage != curr.errorMessage && curr.errorMessage != null),
      listener: (context, state) {
        if (state.isComplete) {
          // Update auth user with onboardingCompleted=true directly.
          // AuthCheckRequested would return stale cached user (fire-and-forget refresh),
          // so we use AuthUserUpdated to set the flag immediately.
          // GoRouterBlocRefreshStream then re-evaluates redirect and navigates to home.
          final currentUser = context.read<AuthBloc>().state.user;
          if (currentUser != null) {
            context.read<AuthBloc>().add(
              AuthUserUpdated(user: currentUser.copyWith(onboardingCompleted: true)),
            );
          }
          return;
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.errorMessage))),
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
                      _InterestsStep(),
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
                        suffixIcon: Tooltip(
                          message: l10n.onboardingProfileUpdateInSettings,
                          child: const Icon(Icons.info_outline_rounded,
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
                        suffixIcon: Tooltip(
                          message: l10n.onboardingProfileUpdateInSettings,
                          child: const Icon(Icons.info_outline_rounded,
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
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCity;
  String _searchQuery = '';

  static const List<String> _allCities = [
    'London', 'Manchester', 'Birmingham', 'Edinburgh', 'Glasgow',
    'Leeds', 'Bristol', 'Sheffield', 'Liverpool', 'Nottingham',
    'Cambridge', 'Oxford', 'Cardiff', 'Belfast', 'Southampton',
    'Newcastle', 'Leicester', 'Coventry', 'Reading', 'Aberdeen',
    'Dundee', 'Bath', 'York', 'Brighton', 'Exeter',
    'Norwich', 'Plymouth', 'Swansea', 'Derby', 'Wolverhampton',
    'Bournemouth', 'Warwick', 'Lancaster', 'Canterbury', 'Chester',
    'Durham', 'St Andrews', 'Loughborough', 'Surrey', 'Hatfield',
  ];

  List<String> get _filteredCities {
    if (_searchQuery.isEmpty) return _allCities;
    final query = _searchQuery.toLowerCase();
    return _allCities
        .where((c) => c.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCitySelected(String city) {
    setState(() {
      _selectedCity = city;
      _searchController.text = city;
      _searchQuery = city;
    });
  }

  void _onNext() {
    final city = _selectedCity ?? _searchController.text.trim();
    if (city.isNotEmpty) {
      context.read<IdentityOnboardingBloc>().add(OnboardingSetCity(city));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cities = _filteredCities;

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
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.onboardingCityHint,
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: AppRadius.allMedium,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
                // If typed text doesn't match selected city, clear selection
                if (_selectedCity != null &&
                    _selectedCity!.toLowerCase() != value.trim().toLowerCase()) {
                  _selectedCity = null;
                }
              });
            },
          ),
          AppSpacing.vMd,
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: cities.map((city) {
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
                      _searchController.text.trim().isNotEmpty)
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

// ==================== Step 3: Interests Selection ====================

class _InterestsStep extends StatefulWidget {
  const _InterestsStep();

  @override
  State<_InterestsStep> createState() => _InterestsStepState();
}

class _InterestsStepState extends State<_InterestsStep> {
  final Set<String> _selectedKeys = {};

  static const List<InterestCategory> _interests = InterestCategories.all;

  void _onSubmit({bool skip = false}) {
    final bloc = context.read<IdentityOnboardingBloc>();
    if (!skip && _selectedKeys.isNotEmpty) {
      bloc.add(OnboardingSetInterests(_selectedKeys.toList()));
    }
    bloc.add(const OnboardingSubmit());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

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
                l10n.onboardingInterestsTitle,
                style: AppTypography.title.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.onboardingInterestsSubtitle,
                style: AppTypography.callout.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              AppSpacing.vLg,
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _interests.map((item) {
                      final isSelected = _selectedKeys.contains(item.key);
                      final label = isZh ? item.zh : item.en;
                      return FilterChip(
                        avatar: Icon(
                          item.icon,
                          size: 18,
                          color: isSelected
                              ? AppColors.primary
                              : theme.colorScheme.onSurface,
                        ),
                        label: Text(label),
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
                              _selectedKeys.add(item.key);
                            } else {
                              _selectedKeys.remove(item.key);
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
