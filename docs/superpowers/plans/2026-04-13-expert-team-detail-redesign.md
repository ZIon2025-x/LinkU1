# Expert Team Detail Page Redesign

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current plain `expert_team_detail_view.dart` (420 lines, basic ListTile layout) with a polished, iOS-style design matching the HTML preview at `link2ur/docs/expert_detail_preview.html` — hero banner, floating stats card, horizontal-scroll services/activities, reviews, forum entry, and sticky bottom action bar.

**Architecture:** The existing `ExpertTeamBloc` already handles team detail, follow, services, reviews (via `TaskExpertRepository`). We add two new events/handlers: `ExpertTeamLoadActivities` (calls `ActivityRepository.getActivities(expertId:)`) and `ExpertTeamLoadReviews` (calls `TaskExpertRepository.getExpertReviews()`). The view is a single file rewrite of `expert_team_detail_view.dart` with private widget classes. No new files created — the redesign replaces the existing view in-place.

**Tech Stack:** Flutter BLoC, AppColors/AppSpacing/AppRadius design system, ActivityRepository, TaskExpertRepository, ExpertTeamRepository, GoRouter navigation.

**Reference:** `task_expert_detail_view.dart` is the mature reference for the iOS-style hero + floating card + activities + reviews pattern. The new expert team detail should follow the same structural approach but adapted for team data (members section, team forum, etc.).

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| **Modify** | `lib/features/expert_team/bloc/expert_team_bloc.dart` | Add `ExpertTeamLoadActivities`, `ExpertTeamLoadReviews` events + state fields + handlers |
| **Rewrite** | `lib/features/expert_team/views/expert_team_detail_view.dart` | Full UI rewrite: hero, stats, bio, members, services, activities, reviews, forum, bottom bar |
| **Modify** | `lib/core/router/routes/expert_team_routes.dart` | Inject `ActivityRepository` + `TaskExpertRepository` into the detail route's BlocProvider |

No new files. The `ExpertRoleBadge` widget (`lib/features/expert_team/widgets/role_badge.dart`) is reused as-is. The `ActivityPriceWidget` from `lib/features/task_expert/views/activity_price_widget.dart` is reused for activity cards.

---

### Task 1: Add Activities & Reviews to ExpertTeamBloc

**Files:**
- Modify: `lib/features/expert_team/bloc/expert_team_bloc.dart`

This task adds two new events, corresponding state fields, and handlers so the detail page can load activities and reviews for the team.

- [ ] **Step 1: Add new state fields**

In `ExpertTeamState`, add these fields after `coupons`:

```dart
final List<Activity> activities;
final bool isLoadingActivities;
final List<Map<String, dynamic>> reviews;
final bool isLoadingReviews;
final bool hasMoreReviews;
```

Add to constructor with defaults:
```dart
this.activities = const [],
this.isLoadingActivities = false,
this.reviews = const [],
this.isLoadingReviews = false,
this.hasMoreReviews = false,
```

Add to `copyWith`:
```dart
List<Activity>? activities,
bool? isLoadingActivities,
List<Map<String, dynamic>>? reviews,
bool? isLoadingReviews,
bool? hasMoreReviews,
```

And in the return body:
```dart
activities: activities ?? this.activities,
isLoadingActivities: isLoadingActivities ?? this.isLoadingActivities,
reviews: reviews ?? this.reviews,
isLoadingReviews: isLoadingReviews ?? this.isLoadingReviews,
hasMoreReviews: hasMoreReviews ?? this.hasMoreReviews,
```

Add to `props` list:
```dart
activities, isLoadingActivities, reviews, isLoadingReviews, hasMoreReviews,
```

Add import at top of file:
```dart
import 'package:link2ur/data/models/activity.dart';
import 'package:link2ur/data/repositories/activity_repository.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';
```

- [ ] **Step 2: Add new events**

After `ExpertTeamReplyReview`, add:

```dart
class ExpertTeamLoadActivities extends ExpertTeamEvent {
  final String expertId;
  ExpertTeamLoadActivities(this.expertId);
  @override
  List<Object?> get props => [expertId];
}

class ExpertTeamLoadReviews extends ExpertTeamEvent {
  final String expertId;
  final bool loadMore;
  ExpertTeamLoadReviews(this.expertId, {this.loadMore = false});
  @override
  List<Object?> get props => [expertId, loadMore];
}
```

- [ ] **Step 3: Add repository fields and constructor parameters to BLoC**

Change the `ExpertTeamBloc` constructor to accept optional repositories:

```dart
class ExpertTeamBloc extends Bloc<ExpertTeamEvent, ExpertTeamState> {
  final ExpertTeamRepository _repository;
  final ActivityRepository? _activityRepository;
  final TaskExpertRepository? _taskExpertRepository;

  ExpertTeamBloc({
    required ExpertTeamRepository repository,
    ActivityRepository? activityRepository,
    TaskExpertRepository? taskExpertRepository,
  })  : _repository = repository,
        _activityRepository = activityRepository,
        _taskExpertRepository = taskExpertRepository,
        super(const ExpertTeamState()) {
    // ... existing on<> registrations ...
    on<ExpertTeamLoadActivities>(_onLoadActivities);
    on<ExpertTeamLoadReviews>(_onLoadReviews);
  }
```

The repositories are optional to avoid breaking all other BlocProvider sites (e.g. my teams, invitations pages) that don't need activities/reviews.

- [ ] **Step 4: Implement `_onLoadActivities` handler**

```dart
Future<void> _onLoadActivities(ExpertTeamLoadActivities event, Emitter<ExpertTeamState> emit) async {
  if (_activityRepository == null) return;
  emit(state.copyWith(isLoadingActivities: true));
  try {
    final result = await _activityRepository!.getActivities(
      expertId: event.expertId,
      status: 'open',
      pageSize: 10,
    );
    emit(state.copyWith(
      activities: result.activities,
      isLoadingActivities: false,
    ));
  } catch (e) {
    emit(state.copyWith(isLoadingActivities: false));
  }
}
```

- [ ] **Step 5: Implement `_onLoadReviews` handler**

```dart
Future<void> _onLoadReviews(ExpertTeamLoadReviews event, Emitter<ExpertTeamState> emit) async {
  if (_taskExpertRepository == null) return;
  emit(state.copyWith(isLoadingReviews: true));
  try {
    final offset = event.loadMore ? state.reviews.length : 0;
    final data = await _taskExpertRepository!.getExpertReviews(
      event.expertId,
      limit: 10,
      offset: offset,
    );
    final items = data['items'] as List<Map<String, dynamic>>;
    final total = data['total'] as int;
    final allReviews = event.loadMore ? [...state.reviews, ...items] : items;
    emit(state.copyWith(
      reviews: allReviews,
      isLoadingReviews: false,
      hasMoreReviews: allReviews.length < total,
    ));
  } catch (e) {
    emit(state.copyWith(isLoadingReviews: false));
  }
}
```

- [ ] **Step 6: Verify compilation**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/features/expert_team/bloc/expert_team_bloc.dart`

Expected: No errors (warnings acceptable).

- [ ] **Step 7: Commit**

```bash
git add lib/features/expert_team/bloc/expert_team_bloc.dart
git commit -m "feat(expert-team): add activities & reviews loading to ExpertTeamBloc"
```

---

### Task 2: Update Route to Inject Repositories

**Files:**
- Modify: `lib/core/router/routes/expert_team_routes.dart`

The detail route's `BlocProvider` needs `ActivityRepository` and `TaskExpertRepository` so the new events work.

- [ ] **Step 1: Read current file**

Read `lib/core/router/routes/expert_team_routes.dart` to see the current BlocProvider setup.

- [ ] **Step 2: Update the ExpertTeamDetailView route**

Find the route that creates `ExpertTeamBloc` for the detail page and add the two optional repositories:

```dart
ExpertTeamBloc(
  repository: context.read<ExpertTeamRepository>(),
  activityRepository: context.read<ActivityRepository>(),
  taskExpertRepository: context.read<TaskExpertRepository>(),
)
```

Add the necessary imports:
```dart
import 'package:link2ur/data/repositories/activity_repository.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';
```

**Note:** If the route file doesn't create its own `BlocProvider` (because `ExpertTeamDetailView` creates it internally), then this step applies to the view file itself in Task 3. Check the route file first.

- [ ] **Step 3: Verify compilation**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/core/router/routes/expert_team_routes.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/core/router/routes/expert_team_routes.dart
git commit -m "feat(expert-team): inject ActivityRepository + TaskExpertRepository into detail route"
```

---

### Task 3: Rewrite ExpertTeamDetailView — Hero + Stats + Bio

**Files:**
- Rewrite: `lib/features/expert_team/views/expert_team_detail_view.dart`

This is the main rewrite. Task 3 covers the top portion: hero banner, stats card, and bio section. Task 4 covers the remaining sections. Split for manageability.

**Design reference:** `link2ur/docs/expert_detail_preview.html` hero, stats-card, and bio section. Code reference: `task_expert_detail_view.dart` lines 234-400 (`_TopHeaderBackground`, `_ProfileCard`).

- [ ] **Step 1: Replace the file scaffold**

Rewrite `expert_team_detail_view.dart` with the new structure. The top-level widget stays the same (takes `expertId`, creates BlocProvider), but now dispatches 3 events on creation:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/expert_team.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/expert_team_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/services/storage_service.dart';
import '../../task_expert/views/activity_price_widget.dart';
import '../bloc/expert_team_bloc.dart';
import '../widgets/role_badge.dart';

class ExpertTeamDetailView extends StatelessWidget {
  final String expertId;
  const ExpertTeamDetailView({super.key, required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
        activityRepository: context.read<ActivityRepository>(),
        taskExpertRepository: context.read<TaskExpertRepository>(),
      )
        ..add(ExpertTeamLoadDetail(expertId))
        ..add(ExpertTeamLoadServices(expertId))
        ..add(ExpertTeamLoadActivities(expertId))
        ..add(ExpertTeamLoadReviews(expertId)),
      child: _ExpertTeamDetailBody(expertId: expertId),
    );
  }
}
```

- [ ] **Step 2: Build `_ExpertTeamDetailBody` with Scaffold**

This widget handles loading/error states and the overall Scaffold with `extendBodyBehindAppBar` + transparent AppBar + bottom action bar:

```dart
class _ExpertTeamDetailBody extends StatelessWidget {
  final String expertId;
  const _ExpertTeamDetailBody({required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != prev.actionMessage ||
          curr.errorMessage != prev.errorMessage,
      listener: (context, state) {
        final msg = state.actionMessage ?? state.errorMessage;
        if (msg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(msg))),
          );
        }
      },
      child: BlocBuilder<ExpertTeamBloc, ExpertTeamState>(
        builder: (context, state) {
          if (state.status == ExpertTeamStatus.loading && state.currentTeam == null) {
            return const Scaffold(body: LoadingView());
          }
          if (state.status == ExpertTeamStatus.error && state.currentTeam == null) {
            return Scaffold(
              appBar: AppBar(),
              body: ErrorStateView.loadFailed(
                message: state.errorMessage != null
                    ? context.localizeError(state.errorMessage!)
                    : context.l10n.taskExpertLoadFailed,
                onRetry: () => context.read<ExpertTeamBloc>().add(ExpertTeamLoadDetail(expertId)),
              ),
            );
          }
          final team = state.currentTeam;
          if (team == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(context.l10n.taskExpertLoadFailed)),
            );
          }
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {
                    // TODO: share when ShareUtil supports expert teams
                  },
                ),
              ],
            ),
            body: _DetailContent(
              team: team,
              expertId: expertId,
              state: state,
            ),
            bottomNavigationBar: _BottomActionBar(
              team: team,
              expertId: expertId,
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: Build `_DetailContent` — scrollable body**

```dart
class _DetailContent extends StatelessWidget {
  final ExpertTeam team;
  final String expertId;
  final ExpertTeamState state;

  const _DetailContent({
    required this.team,
    required this.expertId,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final members = team.members ?? [];
    final previewMembers = members.take(5).toList();
    final locale = Localizations.localeOf(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero banner with avatar + name + badges
          _HeroBanner(team: team),

          // 2. Stats card (overlapping hero bottom)
          Transform.translate(
            offset: const Offset(0, -28),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(), // placeholder, replaced next step
            ),
          ),
          // ... more sections added in subsequent steps
        ],
      ),
    );
  }
}
```

(This is scaffolding — full content assembled across Steps 3-7.)

- [ ] **Step 4: Build `_HeroBanner`**

Hero banner with gradient background, decorative circles, avatar ring, name, badges (official/verified), follower count, location:

```dart
class _HeroBanner extends StatelessWidget {
  final ExpertTeam team;
  const _HeroBanner({required this.team});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return SizedBox(
      height: 210 + MediaQuery.paddingOf(context).top,
      child: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF007AFF),
                    Color(0xFF5856D6),
                    Color(0xFFAF52DE),
                  ],
                ),
              ),
            ),
          ),
          // Dark overlay at bottom
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            right: -30,
            top: -50 + MediaQuery.paddingOf(context).top,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: 20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Content: avatar + info
          Positioned(
            left: 20,
            right: 20,
            bottom: 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar ring
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                  child: AvatarView(
                    imageUrl: team.avatar,
                    name: team.name,
                    size: 76,
                  ),
                ),
                const SizedBox(width: 16),
                // Name + badges + meta
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name + badges
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              team.displayName(locale.languageCode),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            if (team.isOfficial)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: AppColors.gradientGold,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  context.l10n.expertTeamOfficialBadge,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (team.status == 'active')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '✓',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Sub row: follower count + category placeholder
                        Text(
                          '${team.memberCount} ${context.l10n.expertTeamStatMembers}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        // Location
                        if (team.location != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  [
                                    team.location!,
                                    if (team.serviceRadiusKm != null && team.serviceRadiusKm! > 0)
                                      '${context.l10n.expertTeamStatServices} ${team.serviceRadiusKm}km',
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Build `_StatsCard`**

Floating white card with 4 stats (members, services, completed, rating), overlapping the hero:

```dart
class _StatsCard extends StatelessWidget {
  final ExpertTeam team;
  const _StatsCard({required this.team});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatCell(value: team.memberCount.toString(), label: l10n.expertTeamStatMembers),
            _StatCell(value: team.totalServices.toString(), label: l10n.expertTeamStatServices),
            _StatCell(value: team.completedTasks.toString(), label: l10n.expertTeamStatCompleted),
            _StatCell(
              value: team.rating.toStringAsFixed(1),
              label: l10n.expertTeamStatRating,
              valueColor: const Color(0xFFFF9500),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _StatCell({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: value != '' // first cell has no border handled by parent
                ? BorderSide.none
                : BorderSide.none,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: valueColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: Use `IntrinsicHeight` + Row with vertical dividers between stat cells. Each stat cell separated by a 1px vertical divider (use `VerticalDivider` or a `Container` with border).

- [ ] **Step 6: Build `_BioSection`**

White card with expandable bio text, info pills (response time, service radius, completion rate), and nothing else for now (tags can be added later when the backend supports expertise/skill tags on teams):

```dart
class _BioSection extends StatefulWidget {
  final ExpertTeam team;
  const _BioSection({required this.team});

  @override
  State<_BioSection> createState() => _BioSectionState();
}

class _BioSectionState extends State<_BioSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final bio = widget.team.displayBio(locale.languageCode);
    if (bio == null || bio.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.info_outline,
            iconGradient: const [Color(0xFF007AFF), Color(0xFF5856D6)],
            title: context.l10n.expertTeamBio,
          ),
          const SizedBox(height: 12),
          Text(
            bio,
            style: TextStyle(
              fontSize: 14,
              height: 1.65,
              color: isDark ? const Color(0xCCEBEBF5) : const Color(0xFF3C3C43),
            ),
            maxLines: _expanded ? null : 2,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          if (bio.length > 80)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _expanded ? context.l10n.commonCollapse : context.l10n.commonExpand,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.team.serviceRadiusKm != null && widget.team.serviceRadiusKm! > 0)
                  _InfoPill(
                    icon: Icons.location_on_outlined,
                    label: context.l10n.expertTeamStatServices,
                    value: '${widget.team.serviceRadiusKm}km',
                  ),
                _InfoPill(
                  icon: Icons.check_circle_outline,
                  label: context.l10n.expertTeamStatCompleted,
                  value: '${(widget.team.completionRate * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Build shared helper widgets**

`_SectionCard` — consistent card wrapper:
```dart
class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _SectionCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: child,
    );
  }
}
```

`_SectionHeader` — icon + title + optional trailing:
```dart
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final int? count;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const _SectionHeader({
    required this.icon,
    required this.iconGradient,
    required this.title,
    this.count,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: iconGradient),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
        const Spacer(),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing!,
                  style: const TextStyle(fontSize: 13, color: AppColors.primary),
                ),
                const SizedBox(width: 2),
                const Text('›', style: TextStyle(fontSize: 13, color: AppColors.primary)),
              ],
            ),
          ),
      ],
    );
  }
}
```

`_InfoPill` — small tag:
```dart
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? AppColors.textSecondaryDark : const Color(0xFF636366)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : const Color(0xFF636366)),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Verify compilation**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/features/expert_team/views/expert_team_detail_view.dart`

Fix any errors before proceeding.

- [ ] **Step 9: Commit**

```bash
git add lib/features/expert_team/views/expert_team_detail_view.dart
git commit -m "feat(expert-team): rewrite detail view - hero banner, stats card, bio section"
```

---

### Task 4: Add Members, Services, Activities, Reviews, Forum, Bottom Bar

**Files:**
- Modify: `lib/features/expert_team/views/expert_team_detail_view.dart` (continue)

- [ ] **Step 1: Build `_MembersSection`**

Horizontal scrolling member avatars with role dots, matching the HTML members-scroll:

```dart
class _MembersSection extends StatelessWidget {
  final List<ExpertMember> members;
  final int totalCount;
  final String expertId;
  final bool canManage;

  const _MembersSection({
    required this.members,
    required this.totalCount,
    required this.expertId,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      child: Column(
        children: [
          _SectionHeader(
            icon: Icons.people_outline,
            iconGradient: const [Color(0xFF007AFF), Color(0xFF5856D6)],
            title: context.l10n.expertTeamStatMembers,
            count: totalCount,
            trailing: totalCount > 5 && canManage ? context.l10n.expertTeamSeeAll : null,
            onTrailingTap: totalCount > 5 && canManage
                ? () => context.push('/expert-dashboard/$expertId/management/members')
                : null,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _MemberAvatar(member: members[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final ExpertMember member;
  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color roleColor;
    final String roleLabel;
    switch (member.role) {
      case 'owner':
        roleColor = const Color(0xFFFF8C00);
        roleLabel = '★';
      case 'admin':
        roleColor = const Color(0xFF007AFF);
        roleLabel = 'A';
      default:
        roleColor = const Color(0xFF8E8E93);
        roleLabel = 'M';
    }

    return SizedBox(
      width: 64,
      child: Column(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              children: [
                AvatarView(
                  imageUrl: member.userAvatar,
                  name: member.userName ?? '?',
                  size: 52,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: roleColor,
                      border: Border.all(
                        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        roleLabel,
                        style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            member.userName ?? member.userId,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xCCEBEBF5) : const Color(0xFF3C3C43),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Build `_ServicesSection`**

Horizontal scrolling service cards, matching the HTML services-scroll. Data comes from `state.services` (already loaded by `ExpertTeamLoadServices`):

```dart
class _ServicesSection extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final String expertId;

  const _ServicesSection({required this.services, required this.expertId});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      padding: const EdgeInsets.only(top: 18, left: 18, right: 18, bottom: 14),
      child: Column(
        children: [
          _SectionHeader(
            icon: Icons.star_outline,
            iconGradient: const [Color(0xFFFF6B6B), Color(0xFFE64D4D)],
            title: context.l10n.expertTeamStatServices,
            count: services.length,
            trailing: services.length > 3 ? context.l10n.expertTeamSeeAll : null,
            onTrailingTap: services.length > 3
                ? () {
                    // Navigate to full services list for this expert
                    // Reuse task_expert service browse with expert_id filter
                  }
                : null,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: services.length > 6 ? 6 : services.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final svc = services[index];
                return _ServiceCard(service: svc, expertId: expertId);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final String expertId;

  const _ServiceCard({required this.service, required this.expertId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final name = (locale.languageCode.startsWith('zh')
            ? service['name_zh']
            : service['name_en']) as String? ??
        service['name'] as String? ??
        '';
    final price = service['price'];
    final priceStr = price != null ? '£${Helpers.formatAmountNumber(price)}' : '';
    final images = service['images'] as List<dynamic>?;
    final firstImage = images != null && images.isNotEmpty ? images[0] as String : null;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        final serviceId = service['id'];
        if (serviceId != null) {
          context.push('/task-experts/$expertId/services/$serviceId');
        }
      },
      child: Container(
        width: 220,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: isDark ? AppColors.secondaryBackgroundDark : const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 120,
              width: double.infinity,
              child: firstImage != null
                  ? AsyncImageView(
                      imageUrl: Helpers.getThumbnailUrl(firstImage),
                      fallbackUrl: Helpers.getImageUrl(firstImage),
                      width: 220,
                      height: 120,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.08),
                            AppColors.purple.withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.design_services_outlined, size: 28, color: AppColors.textSecondary),
                      ),
                    ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    priceStr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.priceRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Build `_ActivitiesSection`**

Horizontal scrolling activity cards. Similar pattern to services, but shows status badge, date, participants, price:

```dart
class _ActivitiesSection extends StatelessWidget {
  final List<Activity> activities;
  final bool isLoading;

  const _ActivitiesSection({required this.activities, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty && !isLoading) return const SizedBox.shrink();
    return _SectionCard(
      padding: const EdgeInsets.only(top: 18, left: 18, right: 18, bottom: 14),
      child: Column(
        children: [
          _SectionHeader(
            icon: Icons.event_outlined,
            iconGradient: AppColors.gradientGreen,
            title: context.l10n.activityActivities,
            count: activities.length > 0 ? activities.length : null,
          ),
          const SizedBox(height: 12),
          if (isLoading && activities.isEmpty)
            const SizedBox(
              height: 100,
              child: Center(child: LoadingView()),
            )
          else
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: activities.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _ActivityCard(activity: activities[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Activity activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        context.push('/activities/${activity.id}');
      },
      child: Container(
        width: 260,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: isDark ? AppColors.secondaryBackgroundDark : const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + status badge + date badge
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: activity.firstImage != null
                        ? AsyncImageView(
                            imageUrl: Helpers.getThumbnailUrl(activity.firstImage!),
                            fallbackUrl: Helpers.getImageUrl(activity.firstImage!),
                            width: 260,
                            height: 130,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.success.withValues(alpha: 0.1),
                                  AppColors.success.withValues(alpha: 0.05),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.event,
                              size: 28,
                              color: AppColors.success.withValues(alpha: 0.5),
                            ),
                          ),
                  ),
                  // Status badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppColors.gradientGreen),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.l10n.expertTeamStatusActive,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Date badge
                  if (activity.deadline != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          DateFormat('MM/dd\nHH:mm').format(activity.deadline!.toLocal()),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.displayTitle(locale),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    activity.displayDescription(locale),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 14,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF636366),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF636366),
                        ),
                      ),
                      const Spacer(),
                      ActivityPriceWidget(activity: activity, fontSize: 13),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Build `_ReviewsSection`**

Vertical review cards with summary (big score + stars + count), matching the HTML reviews section. Reuse the same pattern as `task_expert_detail_view.dart` `_ReviewsSection`:

```dart
class _ReviewsSection extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  final bool isLoading;
  final bool hasMore;
  final String expertId;
  final double rating;
  final int totalCompleted;

  const _ReviewsSection({
    required this.reviews,
    required this.isLoading,
    required this.hasMore,
    required this.expertId,
    required this.rating,
    required this.totalCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.star,
            iconGradient: AppColors.gradientOrange,
            title: context.l10n.taskExpertReviews,
            trailing: reviews.length > 3 ? context.l10n.expertTeamSeeAll : null,
          ),
          const SizedBox(height: 14),
          // Summary row
          if (reviews.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9500),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '★' * rating.round() + '☆' * (5 - rating.round()),
                      style: const TextStyle(fontSize: 16, color: Color(0xFFFF9500), letterSpacing: 1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.taskExpertReviewsCount(totalCompleted),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (isLoading && reviews.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: LoadingView(),
              ),
            )
          else if (reviews.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  context.l10n.taskExpertNoReviews,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ),
            )
          else ...[
            // Show first 3 reviews
            ...reviews.take(3).map((r) => _ReviewCard(review: r)),
            if (hasMore)
              Center(
                child: TextButton(
                  onPressed: () {
                    context.read<ExpertTeamBloc>().add(ExpertTeamLoadReviews(expertId, loadMore: true));
                  },
                  child: Text(
                    context.l10n.commonLoadMore,
                    style: const TextStyle(color: AppColors.primary, fontSize: 14),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = review['user_name'] as String? ?? '';
    final userAvatar = review['user_avatar'] as String?;
    final rating = (review['rating'] as num?)?.toInt() ?? 5;
    final content = review['content'] as String? ?? '';
    final serviceName = review['service_name'] as String? ?? '';
    final createdAt = review['created_at'] as String?;
    final date = createdAt != null ? DateTime.tryParse(createdAt) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryBackgroundDark : const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarView(imageUrl: userAvatar, name: userName, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '★' * rating,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFFF9500)),
                        ),
                        if (serviceName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              serviceName,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (date != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            Helpers.timeAgo(date),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              content,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: isDark ? const Color(0xCCEBEBF5) : const Color(0xFF3C3C43),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Build `_ForumEntry`**

Simple row with icon, text, and arrow — only shown if `team.forumCategoryId != null`:

```dart
class _ForumEntry extends StatelessWidget {
  final int forumCategoryId;
  const _ForumEntry({required this.forumCategoryId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          context.push('/forum/category/$forumCategoryId');
        },
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.gradientBlueTeal),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.forum, size: 18, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.expertTeamForumSection,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    context.l10n.expertTeamForumSection, // reuse; or add a new l10n key for subtitle
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark ? AppColors.textTertiaryDark : const Color(0xFFC7C7CC),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Build `_BottomActionBar`**

Sticky bottom bar with follow button + chat button (matching HTML bottom-bar):

```dart
class _BottomActionBar extends StatelessWidget {
  final ExpertTeam team;
  final String expertId;

  const _BottomActionBar({required this.team, required this.expertId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = StorageService.instance.getUserId();
    final members = team.members ?? [];
    final isInTeam = members.any((m) => m.userId == currentUserId);
    final canManage = members.any((m) => m.userId == currentUserId && m.canManage);

    // If user is team admin/owner, show management button instead
    if (canManage) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xEB1C1C1E)
              : const Color(0xEBFFFFFF),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/expert-dashboard/$expertId/management'),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: Text(context.l10n.expertDashboardManagement),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      );
    }

    return BlocBuilder<ExpertTeamBloc, ExpertTeamState>(
      buildWhen: (prev, curr) =>
          prev.currentTeam?.isFollowing != curr.currentTeam?.isFollowing,
      builder: (context, state) {
        final isFollowing = state.currentTeam?.isFollowing ?? team.isFollowing;

        return Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xEB1C1C1E)
                : const Color(0xEBFFFFFF),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Follow button
                SizedBox(
                  width: 52,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      AppHaptics.selection();
                      context.read<ExpertTeamBloc>().add(ExpertTeamToggleFollow(expertId));
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(
                        color: isFollowing ? AppColors.primary : AppColors.primary,
                        width: 1.5,
                      ),
                      backgroundColor: isFollowing ? AppColors.primary : Colors.transparent,
                      foregroundColor: isFollowing ? Colors.white : AppColors.primary,
                    ),
                    child: Icon(
                      isFollowing ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Chat button
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Chat with the team owner
                        final owner = members.firstWhere(
                          (m) => m.role == 'owner',
                          orElse: () => members.first,
                        );
                        context.push('/messages/${owner.userId}');
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text(context.l10n.taskExpertContactExpert),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 7: Assemble everything in `_DetailContent.build()`**

Complete the `_DetailContent` widget's `build()` method to compose all sections:

```dart
@override
Widget build(BuildContext context) {
  final members = team.members ?? [];
  final previewMembers = members.take(5).toList();
  final currentUserId = StorageService.instance.getUserId();
  final currentMember = members.firstWhere(
    (m) => m.userId == currentUserId,
    orElse: () => const ExpertMember(id: -1, userId: '', role: ''),
  );
  final canManage = currentMember.id != -1 && currentMember.canManage;

  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroBanner(team: team),

        // Stats card (overlapping hero)
        Transform.translate(
          offset: const Offset(0, -28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _StatsCard(team: team),
          ),
        ),

        // Content sections
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              _BioSection(team: team),
              const SizedBox(height: 12),

              if (previewMembers.isNotEmpty) ...[
                _MembersSection(
                  members: previewMembers,
                  totalCount: team.memberCount,
                  expertId: expertId,
                  canManage: canManage,
                ),
                const SizedBox(height: 12),
              ],

              _ServicesSection(services: state.services, expertId: expertId),
              const SizedBox(height: 12),

              _ActivitiesSection(
                activities: state.activities,
                isLoading: state.isLoadingActivities,
              ),
              if (state.activities.isNotEmpty) const SizedBox(height: 12),

              _ReviewsSection(
                reviews: state.reviews,
                isLoading: state.isLoadingReviews,
                hasMore: state.hasMoreReviews,
                expertId: expertId,
                rating: team.rating,
                totalCompleted: team.completedTasks,
              ),
              const SizedBox(height: 12),

              if (team.forumCategoryId != null)
                _ForumEntry(forumCategoryId: team.forumCategoryId!),

              SizedBox(height: MediaQuery.paddingOf(context).bottom + 100),
            ],
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 8: Verify compilation**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/features/expert_team/views/expert_team_detail_view.dart`

Fix all errors. Common issues: missing imports, `AvatarView` name (it's `AsyncImageView` for network images or check the actual widget name used in the codebase), `Helpers.timeAgo` existence, `displayDescription` method on Activity.

- [ ] **Step 9: Commit**

```bash
git add lib/features/expert_team/views/expert_team_detail_view.dart
git commit -m "feat(expert-team): complete detail view rewrite - members, services, activities, reviews, forum, bottom bar"
```

---

### Task 5: Fix Compilation & Visual Testing

**Files:**
- Potentially all files from Tasks 1-4

This task is for fixing any compilation errors found in Task 4 Step 8, and verifying the UI looks correct.

- [ ] **Step 1: Run full analyze**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze`

Fix any errors. Pay special attention to:
- `AvatarView` — check the actual class name used in the codebase (may be `AsyncImageView` with a circle clip, or a custom avatar widget)
- `Helpers.timeAgo` — check if this method exists; if not, use `DateFormat` or add it
- `Activity.displayDescription` — check if this method exists on the model
- `Activity.firstImage` — check if this getter exists
- `context.l10n.activityActivities` — check if this l10n key exists; if not, use a different existing key or add it
- `context.l10n.commonCollapse` / `context.l10n.commonExpand` — check existence
- `context.l10n.taskExpertContactExpert` — check existence
- `context.l10n.expertDashboardManagement` — check existence

- [ ] **Step 2: Fix all found issues**

Address each compilation error. For missing l10n keys, check if a similar key exists and use that, or add the key to all 3 ARB files.

- [ ] **Step 3: Run the app on web**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter run -d web-server`

Navigate to an expert team detail page and verify the visual layout matches the HTML preview.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix(expert-team): compilation fixes and visual adjustments for detail page"
```

---

### Summary of Sections

| Section | Widget | Data Source | Matching HTML |
|---------|--------|-------------|---------------|
| Hero banner | `_HeroBanner` | `ExpertTeam` | hero + hero-content |
| Stats card | `_StatsCard` | `ExpertTeam` | stats-card |
| Bio | `_BioSection` | `ExpertTeam.bio` | bio section + info-pills |
| Members | `_MembersSection` | `ExpertTeam.members` | members-scroll |
| Services | `_ServicesSection` | `state.services` (ExpertTeamLoadServices) | services-scroll |
| Activities | `_ActivitiesSection` | `state.activities` (ExpertTeamLoadActivities) | activities-scroll (**new**) |
| Reviews | `_ReviewsSection` | `state.reviews` (ExpertTeamLoadReviews) | review cards |
| Forum | `_ForumEntry` | `ExpertTeam.forumCategoryId` | forum-entry |
| Bottom bar | `_BottomActionBar` | `ExpertTeam` | bottom-bar |
