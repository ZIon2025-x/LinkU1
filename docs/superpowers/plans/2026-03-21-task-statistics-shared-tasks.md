# Task Statistics & Shared Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add VIP-only task statistics detail page (accessible from profile stats section) and shared tasks section on other users' public profiles.

**Architecture:** Two independent features sharing the same ProfileBloc. Feature 1 adds a new event/handler for task statistics + a new detail page, with VIP gating on the stats section tap. Feature 2 adds a new event/handler for shared tasks + a new section in UserProfileView. Both use existing unused API endpoints already defined in `api_endpoints.dart`.

**Tech Stack:** Flutter, BLoC, Dio (via ApiService), GoRouter, ARB localization

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/data/repositories/user_repository.dart` | Add `getTaskStatistics(userId)` and `getSharedTasks(userId)` methods |
| Modify | `lib/features/profile/bloc/profile_bloc.dart` | Add events, state fields, handlers for both features |
| Modify | `lib/features/profile/views/profile_mobile_widgets.dart` | Add VIP upgrade hint row below stats + tap handler |
| Create | `lib/features/profile/views/task_statistics_view.dart` | Full task statistics detail page |
| Modify | `lib/features/profile/views/user_profile_view.dart` | Add shared tasks section |
| Modify | `lib/core/router/routes/profile_routes.dart` | Add `/profile/task-statistics` route |
| Modify | `lib/core/router/app_routes.dart` | Add `taskStatistics` constant |
| Modify | `lib/l10n/app_en.arb` | Add English l10n keys |
| Modify | `lib/l10n/app_zh.arb` | Add Chinese l10n keys |
| Modify | `lib/l10n/app_zh_Hant.arb` | Add Traditional Chinese l10n keys |
| Modify | `lib/l10n/app_localizations.dart` | Regenerated |
| Modify | `lib/l10n/app_localizations_en.dart` | Regenerated |
| Modify | `lib/l10n/app_localizations_zh.dart` | Regenerated |

---

### Task 1: Add Localization Keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add English l10n keys**

Add to `app_en.arb`:
```json
"taskStatisticsTitle": "Task Statistics",
"taskStatisticsPosted": "Posted",
"taskStatisticsAccepted": "Accepted",
"taskStatisticsCompleted": "Completed",
"taskStatisticsTotal": "Total",
"taskStatisticsCompletionRate": "Completion Rate",
"taskStatisticsUpgradeProgress": "Upgrade Progress",
"taskStatisticsCurrentLevel": "Current Level",
"taskStatisticsUpgradeDisabled": "Upgrade not available yet",
"taskStatisticsThreshold": "{current}/{target}",
"taskStatisticsViewDetails": "View Statistics",
"taskStatisticsLevelNormal": "Normal",
"taskStatisticsLevelVip": "VIP",
"taskStatisticsLevelSuper": "Super VIP",
"taskStatisticsTaskCount": "Task Count",
"taskStatisticsRating": "Rating",
"sharedTasksTitle": "Collaboration History",
"sharedTasksRolePoster": "Posted by you",
"sharedTasksRoleTaker": "Completed by you",
"sharedTasksEmpty": "No collaboration history yet"
```

- [ ] **Step 2: Add Chinese l10n keys**

Add to `app_zh.arb`:
```json
"taskStatisticsTitle": "任务统计",
"taskStatisticsPosted": "发布",
"taskStatisticsAccepted": "接单",
"taskStatisticsCompleted": "完成",
"taskStatisticsTotal": "总计",
"taskStatisticsCompletionRate": "完成率",
"taskStatisticsUpgradeProgress": "晋升进度",
"taskStatisticsCurrentLevel": "当前等级",
"taskStatisticsUpgradeDisabled": "暂未开放晋升",
"taskStatisticsThreshold": "{current}/{target}",
"taskStatisticsViewDetails": "查看统计",
"taskStatisticsLevelNormal": "普通",
"taskStatisticsLevelVip": "VIP",
"taskStatisticsLevelSuper": "超级VIP",
"taskStatisticsTaskCount": "任务数",
"taskStatisticsRating": "评分",
"sharedTasksTitle": "合作记录",
"sharedTasksRolePoster": "你发布的",
"sharedTasksRoleTaker": "你接单的",
"sharedTasksEmpty": "暂无合作记录"
```

- [ ] **Step 3: Add Traditional Chinese l10n keys**

Add to `app_zh_Hant.arb`:
```json
"taskStatisticsTitle": "任務統計",
"taskStatisticsPosted": "發佈",
"taskStatisticsAccepted": "接單",
"taskStatisticsCompleted": "完成",
"taskStatisticsTotal": "總計",
"taskStatisticsCompletionRate": "完成率",
"taskStatisticsUpgradeProgress": "晉升進度",
"taskStatisticsCurrentLevel": "當前等級",
"taskStatisticsUpgradeDisabled": "暫未開放晉升",
"taskStatisticsThreshold": "{current}/{target}",
"taskStatisticsViewDetails": "查看統計",
"taskStatisticsLevelNormal": "普通",
"taskStatisticsLevelVip": "VIP",
"taskStatisticsLevelSuper": "超級VIP",
"taskStatisticsTaskCount": "任務數",
"taskStatisticsRating": "評分",
"sharedTasksTitle": "合作記錄",
"sharedTasksRolePoster": "你發佈的",
"sharedTasksRoleTaker": "你接單的",
"sharedTasksEmpty": "暫無合作記錄"
```

- [ ] **Step 4: Regenerate l10n files**

Run from `link2ur/`:
```bash
flutter gen-l10n
```

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add l10n keys for task statistics and shared tasks"
```

---

### Task 2: Add Repository Methods

**Files:**
- Modify: `lib/data/repositories/user_repository.dart`

API endpoints already defined in `api_endpoints.dart:44-47`:
- `ApiEndpoints.userTaskStatistics(userId)` → `GET /api/users/$userId/task-statistics`
- `ApiEndpoints.sharedTasks(userId)` → `GET /api/users/shared-tasks/$userId`

- [ ] **Step 1: Add `getTaskStatistics` method to UserRepository**

Add after existing methods in `user_repository.dart`:
```dart
/// 获取用户任务统计（VIP功能）
/// Returns: { statistics: {...}, upgrade_conditions: {...}, current_level: String }
Future<Map<String, dynamic>> getTaskStatistics(String userId) async {
  final response = await _apiService.get(
    ApiEndpoints.userTaskStatistics(userId),
  );
  return Map<String, dynamic>.from(response.data as Map);
}

/// 获取与指定用户的共同任务
/// Returns: List<{ id, title, status, created_at, reward, task_type, is_poster }>
Future<List<Map<String, dynamic>>> getSharedTasks(String otherUserId) async {
  final response = await _apiService.get(
    ApiEndpoints.sharedTasks(otherUserId),
  );
  final list = response.data as List;
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/data/repositories/user_repository.dart
git commit -m "feat: add getTaskStatistics and getSharedTasks repository methods"
```

---

### Task 3: Add ProfileBloc Events, State Fields, and Handlers

**Files:**
- Modify: `lib/features/profile/bloc/profile_bloc.dart`

- [ ] **Step 1: Add new events**

Add after `ProfileUpdatePreferences` event (around line 143):
```dart
class ProfileLoadTaskStatistics extends ProfileEvent {
  const ProfileLoadTaskStatistics(this.userId);
  final String userId;
  @override
  List<Object?> get props => [userId];
}

class ProfileLoadSharedTasks extends ProfileEvent {
  const ProfileLoadSharedTasks(this.otherUserId);
  final String otherUserId;
  @override
  List<Object?> get props => [otherUserId];
}
```

- [ ] **Step 2: Add state fields**

Add to `ProfileState` constructor and field declarations (after `showPhoneCodeField`):
```dart
this.taskStatistics,
this.sharedTasks = const [],
this.isLoadingStatistics = false,
this.isLoadingSharedTasks = false,
```

Field declarations:
```dart
final Map<String, dynamic>? taskStatistics;
final List<Map<String, dynamic>> sharedTasks;
final bool isLoadingStatistics;
final bool isLoadingSharedTasks;
```

- [ ] **Step 3: Update `copyWith` method**

Add parameters:
```dart
Map<String, dynamic>? taskStatistics,
List<Map<String, dynamic>>? sharedTasks,
bool? isLoadingStatistics,
bool? isLoadingSharedTasks,
```

And in the return body:
```dart
taskStatistics: taskStatistics ?? this.taskStatistics,
sharedTasks: sharedTasks ?? this.sharedTasks,
isLoadingStatistics: isLoadingStatistics ?? this.isLoadingStatistics,
isLoadingSharedTasks: isLoadingSharedTasks ?? this.isLoadingSharedTasks,
```

- [ ] **Step 4: Update `props` list**

Add to the `props` list:
```dart
taskStatistics,
sharedTasks,
isLoadingStatistics,
isLoadingSharedTasks,
```

- [ ] **Step 5: Register event handlers in Bloc constructor**

Add in the constructor block (after existing `on<>` registrations):
```dart
on<ProfileLoadTaskStatistics>(_onLoadTaskStatistics);
on<ProfileLoadSharedTasks>(_onLoadSharedTasks);
```

- [ ] **Step 6: Implement `_onLoadTaskStatistics` handler**

```dart
Future<void> _onLoadTaskStatistics(
  ProfileLoadTaskStatistics event,
  Emitter<ProfileState> emit,
) async {
  emit(state.copyWith(isLoadingStatistics: true));
  try {
    final data = await _userRepository.getTaskStatistics(event.userId);
    emit(state.copyWith(
      taskStatistics: data,
      isLoadingStatistics: false,
    ));
  } catch (e) {
    AppLogger.error('Failed to load task statistics', e);
    emit(state.copyWith(
      isLoadingStatistics: false,
      errorMessage: 'task_statistics_load_failed',
    ));
  }
}
```

- [ ] **Step 7: Implement `_onLoadSharedTasks` handler**

```dart
Future<void> _onLoadSharedTasks(
  ProfileLoadSharedTasks event,
  Emitter<ProfileState> emit,
) async {
  emit(state.copyWith(isLoadingSharedTasks: true));
  try {
    final tasks = await _userRepository.getSharedTasks(event.otherUserId);
    emit(state.copyWith(
      sharedTasks: tasks,
      isLoadingSharedTasks: false,
    ));
  } catch (e) {
    AppLogger.error('Failed to load shared tasks', e);
    emit(state.copyWith(
      sharedTasks: const [],
      isLoadingSharedTasks: false,
    ));
  }
}
```

- [ ] **Step 8: Commit**

```bash
git add lib/features/profile/bloc/profile_bloc.dart
git commit -m "feat: add task statistics and shared tasks events/state to ProfileBloc"
```

---

### Task 4: Add Route for Task Statistics Page

**Files:**
- Modify: `lib/core/router/app_routes.dart`
- Modify: `lib/core/router/routes/profile_routes.dart`

- [ ] **Step 1: Add route constant**

In `app_routes.dart`, add after `taskPreferences` (line 73):
```dart
static const String taskStatistics = '/profile/task-statistics';
```

Add to `authRequiredRoutes` set:
```dart
AppRoutes.taskStatistics,
```

- [ ] **Step 2: Add route definition**

In `profile_routes.dart`, add import at top:
```dart
import '../../../features/profile/views/task_statistics_view.dart';
```

Add route entry in the list (after `taskPreferences` route):
```dart
GoRoute(
  path: AppRoutes.taskStatistics,
  name: 'taskStatistics',
  builder: (context, state) => const TaskStatisticsView(),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/router/app_routes.dart lib/core/router/routes/profile_routes.dart
git commit -m "feat: add task statistics route"
```

---

### Task 5: Create Task Statistics Detail Page

**Files:**
- Create: `lib/features/profile/views/task_statistics_view.dart`

- [ ] **Step 1: Create the task statistics view**

Create `lib/features/profile/views/task_statistics_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/radius.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/profile_bloc.dart';

/// VIP 任务统计详情页
class TaskStatisticsView extends StatelessWidget {
  const TaskStatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState.user?.id;
    if (userId == null) return const SizedBox.shrink();

    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read(),
        forumRepository: context.read(),
      )..add(ProfileLoadTaskStatistics(userId)),
      child: const _TaskStatisticsBody(),
    );
  }
}

class _TaskStatisticsBody extends StatelessWidget {
  const _TaskStatisticsBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.taskStatisticsTitle)),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        buildWhen: (prev, curr) =>
            prev.taskStatistics != curr.taskStatistics ||
            prev.isLoadingStatistics != curr.isLoadingStatistics,
        builder: (context, state) {
          if (state.isLoadingStatistics && state.taskStatistics == null) {
            return const Center(child: LoadingIndicator());
          }

          final data = state.taskStatistics;
          if (data == null) {
            return Center(child: Text(l10n.errorGeneric));
          }

          final stats = data['statistics'] as Map<String, dynamic>? ?? {};
          final upgrade = data['upgrade_conditions'] as Map<String, dynamic>? ?? {};
          final currentLevel = data['current_level'] as String? ?? 'normal';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsCard(context, stats, isDark),
                const SizedBox(height: AppSpacing.lg),
                _buildUpgradeCard(context, stats, upgrade, currentLevel, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(
      BuildContext context, Map<String, dynamic> stats, bool isDark) {
    final l10n = context.l10n;
    final posted = stats['posted_tasks'] as int? ?? 0;
    final accepted = stats['accepted_tasks'] as int? ?? 0;
    final completed = stats['completed_tasks'] as int? ?? 0;
    final total = stats['total_tasks'] as int? ?? 0;
    final rate = stats['completion_rate'] as num? ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.taskStatisticsTitle, style: AppTypography.title3),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _statItem(l10n.taskStatisticsPosted, '$posted', AppColors.primary),
              _statItem(l10n.taskStatisticsAccepted, '$accepted', AppColors.info),
              _statItem(l10n.taskStatisticsCompleted, '$completed', AppColors.success),
              _statItem(l10n.taskStatisticsTotal, '$total', isDark ? Colors.white70 : Colors.black87),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(l10n.taskStatisticsCompletionRate, style: AppTypography.body),
              const Spacer(),
              Text(
                '${(rate * 100).toStringAsFixed(0)}%',
                style: AppTypography.title3.copyWith(color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate.toDouble().clamp(0.0, 1.0),
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              color: AppColors.success,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.title2.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard(
    BuildContext context,
    Map<String, dynamic> stats,
    Map<String, dynamic> upgrade,
    String currentLevel,
    bool isDark,
  ) {
    final l10n = context.l10n;
    final enabled = upgrade['upgrade_enabled'] as bool? ?? false;

    final levelLabel = switch (currentLevel) {
      'vip' => l10n.taskStatisticsLevelVip,
      'super' => l10n.taskStatisticsLevelSuper,
      _ => l10n.taskStatisticsLevelNormal,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.taskStatisticsUpgradeProgress, style: AppTypography.title3),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${l10n.taskStatisticsCurrentLevel}: $levelLabel',
                  style: AppTypography.caption.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!enabled)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l10n.taskStatisticsUpgradeDisabled,
                  style: AppTypography.body.copyWith(color: Colors.grey),
                ),
              ),
            )
          else ...[
            _upgradeProgressRow(
              context,
              label: l10n.taskStatisticsTaskCount,
              current: (stats['completed_tasks'] as int? ?? 0).toDouble(),
              target: (upgrade['task_count_threshold'] as num? ?? 50).toDouble(),
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            _upgradeProgressRow(
              context,
              label: l10n.taskStatisticsRating,
              current: (stats['completion_rate'] as num? ?? 0).toDouble() * 5,
              target: (upgrade['rating_threshold'] as num? ?? 4.5).toDouble(),
              color: AppColors.warning,
              displayCurrent: '${((stats['completion_rate'] as num? ?? 0) * 5).toStringAsFixed(1)}',
              displayTarget: '${(upgrade['rating_threshold'] as num? ?? 4.5).toStringAsFixed(1)}',
            ),
            const SizedBox(height: AppSpacing.sm),
            _upgradeProgressRow(
              context,
              label: l10n.taskStatisticsCompletionRate,
              current: (stats['completion_rate'] as num? ?? 0).toDouble(),
              target: (upgrade['completion_rate_threshold'] as num? ?? 0.8).toDouble(),
              color: AppColors.success,
              displayCurrent: '${((stats['completion_rate'] as num? ?? 0) * 100).toStringAsFixed(0)}%',
              displayTarget: '${((upgrade['completion_rate_threshold'] as num? ?? 0.8) * 100).toStringAsFixed(0)}%',
            ),
          ],
        ],
      ),
    );
  }

  Widget _upgradeProgressRow(
    BuildContext context, {
    required String label,
    required double current,
    required double target,
    required Color color,
    String? displayCurrent,
    String? displayTarget,
  }) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final currentStr = displayCurrent ?? '${current.toInt()}';
    final targetStr = displayTarget ?? '${target.toInt()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppTypography.body),
            const Spacer(),
            Text(
              '$currentStr / $targetStr',
              style: AppTypography.caption.copyWith(
                color: progress >= 1.0 ? AppColors.success : null,
                fontWeight: progress >= 1.0 ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.1),
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/profile/views/task_statistics_view.dart
git commit -m "feat: create task statistics detail view for VIP users"
```

---

### Task 6: Enhance Profile Stats Section with VIP Row

**Files:**
- Modify: `lib/features/profile/views/profile_mobile_widgets.dart` (lines 161-264)

- [ ] **Step 1: Add VIP statistics row below existing stats**

In `_buildStatsSection()`, after the closing `]` of the `Row` children (around line 261) and before the closing `)` of the Container, add a VIP-only expandable row:

Replace the closing of the Container (lines 261-263):
```dart
      // existing: ],  <-- end of Row children
      // existing: ),  <-- end of Row
```

With:
```dart
      ],  // end of Row children
    ),   // end of Row
    // VIP 统计详情入口
    if (user.userLevel == 'vip' || user.userLevel == 'super') ...[
      Divider(
        height: 1,
        color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
      ),
      GestureDetector(
        onTap: () {
          AppHaptics.selection();
          context.push(AppRoutes.taskStatistics);
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.taskStatisticsViewDetails,
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    ],
```

Also add required imports at the call site. Since this is a `part of` file, the imports are in `profile_view.dart`. Ensure `app_routes.dart` is imported there:
```dart
import '../../../core/router/app_routes.dart';
```

- [ ] **Step 2: Verify the `buildWhen` in profile_view.dart includes user changes**

Check `profile_view.dart:207-217` — `buildWhen` already includes `prev.user != curr.user`, so VIP level changes will trigger rebuild. No change needed.

- [ ] **Step 3: Commit**

```bash
git add lib/features/profile/views/profile_mobile_widgets.dart lib/features/profile/views/profile_view.dart
git commit -m "feat: add VIP task statistics entry in profile stats section"
```

---

### Task 7: Add Shared Tasks Section to User Profile View

**Files:**
- Modify: `lib/features/profile/views/user_profile_view.dart`

- [ ] **Step 1: Dispatch `ProfileLoadSharedTasks` alongside existing load**

In `user_profile_view.dart`, find where `ProfileLoadPublicProfile(userId)` is dispatched (line 46 or in the BlocProvider create). Add shared tasks load right after:

```dart
..add(ProfileLoadSharedTasks(userId))
```

Also add it to the `onRefresh` callback (around line 78-80):
```dart
context.read<ProfileBloc>()
  ..add(ProfileLoadPublicProfile(userId))
  ..add(ProfileLoadSharedTasks(userId));
```

- [ ] **Step 2: Add shared tasks section in the Column**

In the `Column` children (around line 84-104), insert between `_buildSkillRadar` and `_buildReviewsSection`:

```dart
// 合作记录
BlocBuilder<ProfileBloc, ProfileState>(
  buildWhen: (prev, curr) =>
      prev.sharedTasks != curr.sharedTasks ||
      prev.isLoadingSharedTasks != curr.isLoadingSharedTasks,
  builder: (context, state) {
    if (state.sharedTasks.isEmpty && !state.isLoadingSharedTasks) {
      return const SizedBox.shrink();
    }
    return _buildSharedTasksSection(context, state.sharedTasks);
  },
),
```

- [ ] **Step 3: Implement `_buildSharedTasksSection` method**

Add to the view's widget class:

```dart
Widget _buildSharedTasksSection(
    BuildContext context, List<Map<String, dynamic>> tasks) {
  final l10n = context.l10n;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.handshake_outlined, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(l10n.sharedTasksTitle, style: AppTypography.title3),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...tasks.map((task) => _buildSharedTaskItem(context, task, isDark)),
        const SizedBox(height: AppSpacing.section),
      ],
    ),
  );
}

Widget _buildSharedTaskItem(
    BuildContext context, Map<String, dynamic> task, bool isDark) {
  final l10n = context.l10n;
  final title = task['title'] as String? ?? '';
  final status = task['status'] as String? ?? '';
  final reward = task['reward'] as num? ?? 0;
  final isPoster = task['is_poster'] as bool? ?? false;
  final taskId = task['id'];

  return GestureDetector(
    onTap: () {
      if (taskId != null) {
        final id = taskId is int ? taskId : int.tryParse(taskId.toString());
        if (id != null) context.goToTaskDetail(id);
      }
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPoster
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isPoster ? l10n.sharedTasksRolePoster : l10n.sharedTasksRoleTaker,
                        style: AppTypography.overline.copyWith(
                          color: isPoster ? AppColors.primary : AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: AppTypography.caption.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (reward > 0)
            Text(
              '£${(reward / 100).toStringAsFixed(2)}',
              style: AppTypography.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/profile/views/user_profile_view.dart
git commit -m "feat: add shared tasks section to user public profile"
```

---

### Task 8: Integration Verification

- [ ] **Step 1: Run flutter analyze**

```bash
cd link2ur && flutter analyze
```

Expected: No errors in modified files.

- [ ] **Step 2: Verify app builds**

```bash
flutter build apk --debug
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Final commit if any fixups needed**

```bash
git add -A && git commit -m "fix: resolve any analysis issues"
```
