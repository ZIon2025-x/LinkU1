# 统一达人管理页面 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `features/task_expert/` 和 `features/expert_team/` 的达人管理功能合并到一个新的 `features/expert_dashboard/` 模块，提供统一入口、多团队切换、角色感知 UI。

**Architecture:** 新目录 `features/expert_dashboard/`，shell widget 解析 my-teams 并 provide `SelectedExpertCubit`，5 核心 tab 读 cubit 当前 expertId，管理中心作为独立嵌套路由。复用 `ExpertTeamRepository` 和 `TaskExpertRepository` 方法。整体切换团队时 shell 重建子树。

**Tech Stack:** Flutter 3.33+, BLoC (flutter_bloc), GoRouter, Dio, StorageService (SharedPreferences 封装)

**Spec:** `docs/superpowers/specs/2026-04-06-unified-expert-dashboard-design.md`

---

## File Structure

```
link2ur/lib/features/expert_dashboard/
├── bloc/
│   ├── selected_expert_cubit.dart           # 新：当前团队 + 所有团队列表
│   └── expert_dashboard_bloc.dart           # 迁移自 task_expert/bloc/
├── views/
│   ├── expert_dashboard_shell.dart          # 新：两阶段 widget + AppBar + TabBar
│   ├── team_switcher_sheet.dart             # 新：AppBar 标题点击打开
│   ├── tabs/
│   │   ├── stats_tab.dart                   # 迁移自 expert_dashboard_stats_tab.dart
│   │   ├── services_tab.dart                # 迁移自 expert_dashboard_services_tab.dart
│   │   ├── applications_tab.dart            # 迁移自 expert_applications_management_view.dart
│   │   ├── time_slots_tab.dart              # 迁移自 expert_dashboard_time_slots_tab.dart
│   │   └── schedule_tab.dart                # 迁移自 expert_dashboard_schedule_tab.dart
│   └── management/
│       ├── management_center_view.dart      # 新：⚙ 按钮打开的主页
│       ├── members_view.dart                # 迁移自 expert_team/views/expert_team_members_view.dart
│       ├── join_requests_view.dart          # 迁移自 expert_team/views/join_requests_view.dart
│       ├── edit_team_profile_view.dart      # 迁移自 expert_team/views/edit_team_profile_view.dart
│       ├── coupons_view.dart                # 迁移自 expert_team/views/expert_coupons_view.dart
│       ├── packages_view.dart               # 迁移自 expert_team/views/expert_packages_view.dart
│       └── review_replies_view.dart         # 新建

link2ur/lib/core/router/routes/
├── expert_dashboard_routes.dart             # 新：注册 /expert-dashboard + 嵌套
├── task_expert_routes.dart                  # 修改：删除 expertDashboard/expertProfileEdit/expertApplicationsManagement
└── expert_team_routes.dart                  # 修改：删除迁走的 members/coupons/... 路由

link2ur/lib/data/services/
└── storage_service.dart                     # 修改：加 getSelectedExpertId / setSelectedExpertId

link2ur/lib/core/router/
└── app_routes.dart                          # 修改：加新路由常量，删旧的
```

---

## Phase A: 基础骨架（SelectedExpertCubit + Shell + 5 tab 迁移）

### Task A1: 创建 SelectedExpertCubit

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/bloc/selected_expert_cubit.dart`

- [ ] **Step 1: 写 Cubit**

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/expert_team.dart';
import '../../../data/services/storage_service.dart';

class SelectedExpertState extends Equatable {
  const SelectedExpertState({
    required this.myTeams,
    required this.currentExpertId,
  });

  final List<ExpertTeam> myTeams;
  final String currentExpertId;

  ExpertTeam get currentTeam => myTeams.firstWhere(
        (t) => t.id == currentExpertId,
        orElse: () => myTeams.first,
      );

  String get currentRole => currentTeam.myRole ?? 'member';
  bool get isOwner => currentRole == 'owner';
  bool get isAdmin => currentRole == 'admin';
  bool get isMember => currentRole == 'member';
  bool get canManage => isOwner || isAdmin;

  @override
  List<Object?> get props => [myTeams, currentExpertId];
}

class SelectedExpertCubit extends Cubit<SelectedExpertState> {
  SelectedExpertCubit({
    required List<ExpertTeam> myTeams,
    required String initialExpertId,
  }) : super(SelectedExpertState(
          myTeams: myTeams,
          currentExpertId: initialExpertId,
        ));

  Future<void> switchTo(String expertId) async {
    if (state.currentExpertId == expertId) return;
    emit(SelectedExpertState(
      myTeams: state.myTeams,
      currentExpertId: expertId,
    ));
    await StorageService.instance.setSelectedExpertId(expertId);
  }

  void refreshTeams(List<ExpertTeam> teams) {
    // 保留当前选中（如果还存在），否则回退到第一个
    final keep = teams.any((t) => t.id == state.currentExpertId)
        ? state.currentExpertId
        : (teams.isNotEmpty ? teams.first.id : '');
    emit(SelectedExpertState(myTeams: teams, currentExpertId: keep));
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add link2ur/lib/features/expert_dashboard/bloc/selected_expert_cubit.dart
git commit -m "feat(expert_dashboard): add SelectedExpertCubit for team switching state"
```

---

### Task A2: StorageService 加 selected expert id 方法

**Files:**
- Modify: `link2ur/lib/data/services/storage_service.dart`

- [ ] **Step 1: 找到 StorageService 类定义位置并添加方法**

先读 `storage_service.dart` 找到类体内的合适位置（靠近其他 SharedPreferences getter/setter），添加：

```dart
// 达人 Dashboard 当前选中团队
static const String _keySelectedExpertId = 'selected_expert_id';

String? getSelectedExpertId() {
  return _prefs.getString(_keySelectedExpertId);
}

Future<void> setSelectedExpertId(String expertId) async {
  await _prefs.setString(_keySelectedExpertId, expertId);
}

Future<void> clearSelectedExpertId() async {
  await _prefs.remove(_keySelectedExpertId);
}
```

注意：如果文件里已经有缓存层（in-memory cache），要把 `_keySelectedExpertId` 纳入缓存模式（参考其他 getter 怎么做）。本方法的缓存可选（值变动不频繁，不加也行）。

- [ ] **Step 2: 确保 logout 清理**

搜索 StorageService 里的 `clear()` 或 `logout` 相关方法，确保会清理 `_keySelectedExpertId`（加入已有的清理逻辑）。

- [ ] **Step 3: 提交**

```bash
git add link2ur/lib/data/services/storage_service.dart
git commit -m "feat(storage): persist selected expert team id for dashboard"
```

---

### Task A3: 迁移 ExpertDashboardBloc 到新目录

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/bloc/expert_dashboard_bloc.dart`
- Create: `link2ur/lib/features/expert_dashboard/bloc/expert_dashboard_event.dart`
- Create: `link2ur/lib/features/expert_dashboard/bloc/expert_dashboard_state.dart`

- [ ] **Step 1: 复制 bloc 文件到新位置**

把 `link2ur/lib/features/task_expert/bloc/expert_dashboard_bloc.dart` 的**全部内容**复制到新位置 `link2ur/lib/features/expert_dashboard/bloc/expert_dashboard_bloc.dart`，同样复制 event 和 state 的 part 文件。

修改新文件顶部的 import 路径（`package:link2ur/data/repositories/task_expert_repository.dart` 保持不变，因为 repository 位置未变）。不需要改代码逻辑。

- [ ] **Step 2: 验证编译**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/features/expert_dashboard
```

Expected: 0 errors（如果有 error，多数是 import 路径问题，修正）

- [ ] **Step 3: 提交**

```bash
git add link2ur/lib/features/expert_dashboard/bloc/
git commit -m "refactor(expert_dashboard): copy ExpertDashboardBloc to new module"
```

---

### Task A4: 迁移 5 个 tab 到新位置

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/tabs/stats_tab.dart`
- Create: `link2ur/lib/features/expert_dashboard/views/tabs/services_tab.dart`
- Create: `link2ur/lib/features/expert_dashboard/views/tabs/applications_tab.dart`
- Create: `link2ur/lib/features/expert_dashboard/views/tabs/time_slots_tab.dart`
- Create: `link2ur/lib/features/expert_dashboard/views/tabs/schedule_tab.dart`

- [ ] **Step 1: 复制 stats_tab**

复制 `link2ur/lib/features/task_expert/views/expert_dashboard_stats_tab.dart` 到 `expert_dashboard/views/tabs/stats_tab.dart`。

改 class 名：`ExpertDashboardStatsTab` → `StatsTab`。

修改 import 路径：
- `'../bloc/expert_dashboard_bloc.dart'` → `'../../bloc/expert_dashboard_bloc.dart'`
- 其他相对路径加一层 `../`

- [ ] **Step 2: 复制 services_tab**

复制 `link2ur/lib/features/task_expert/views/expert_dashboard_services_tab.dart` 到 `expert_dashboard/views/tabs/services_tab.dart`。

改 class 名：`ExpertDashboardServicesTab` → `ServicesTab`。

修改 import 路径（同上）。

- [ ] **Step 3: 复制 applications_tab**

复制 `link2ur/lib/features/task_expert/views/expert_dashboard_applications_tab.dart` 和 `expert_applications_management_view.dart` 的**内容合并**到 `expert_dashboard/views/tabs/applications_tab.dart`。

思路：`ExpertDashboardApplicationsTab` 原本只是 `ExpertApplicationsManagementView(showAppBar: false, expertId: expertId)` 的包装。新的 `ApplicationsTab`：
- 从 `context.read<SelectedExpertCubit>().state.currentExpertId` 读 expertId
- 直接 copy `ExpertApplicationsManagementView` 的 body 逻辑（去掉 showAppBar 分支）
- BlocProvider 创建 `TaskExpertBloc(expertId: expertId)` 并 dispatch `TaskExpertLoadExpertApplications`

完整代码：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/question_repository.dart';
import '../../../../data/repositories/task_expert_repository.dart';
import '../../../task_expert/bloc/task_expert_bloc.dart';
import '../../../task_expert/views/expert_applications_management_view.dart';
import '../../bloc/selected_expert_cubit.dart';

/// Applications tab — 复用 ExpertApplicationsManagementView 的内容，
/// 从 SelectedExpertCubit 读当前 expertId。
class ApplicationsTab extends StatelessWidget {
  const ApplicationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final expertId = context.select<SelectedExpertCubit, String>(
      (c) => c.state.currentExpertId,
    );
    return BlocProvider(
      key: ValueKey('apps_$expertId'),
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
        questionRepository: context.read<QuestionRepository>(),
        expertId: expertId,
      )..add(const TaskExpertLoadExpertApplications()),
      child: const ExpertApplicationsManagementView(
        // 这里复用旧 view 的内容，但不显示 AppBar（在 shell 的 TabBarView 中）
        // expertId 传入是为了满足 required 参数；真正的 BLoC 已由外层 BlocProvider 提供
        showAppBar: false,
      ),
    );
  }
}
```

注意：`ExpertApplicationsManagementView` 当前的构造已经有 `showAppBar` 参数。如果它内部的 `BlocProvider` 会和外层冲突，直接 import 它的 `_ExpertApplicationsManagementContent`（如果是 private 的，则从 view 里抽出一个 public 的 body widget，或把该 view 的 content 复制到新 tab）。

**简化决策**：本步骤不再复用 `ExpertApplicationsManagementView`，而是将其**整个 body 代码**复制到新 tab。避免 BlocProvider 嵌套和 `expertId` 重复解析的问题。执行时打开原文件，复制 `_ExpertApplicationsManagementContent` + `_ApplicationCard` + `_ActionButton` 全部 class 到新 tab 文件，移除 `showAppBar` 分支，从 `context.select<SelectedExpertCubit>` 读 `expertId`。

- [ ] **Step 4: 复制 time_slots_tab**

复制 `link2ur/lib/features/task_expert/views/expert_dashboard_time_slots_tab.dart` 到 `expert_dashboard/views/tabs/time_slots_tab.dart`。改 class 名 `ExpertDashboardTimeSlotsTab` → `TimeSlotsTab`，修改 import 路径。

- [ ] **Step 5: 复制 schedule_tab**

复制 `link2ur/lib/features/task_expert/views/expert_dashboard_schedule_tab.dart` 到 `expert_dashboard/views/tabs/schedule_tab.dart`。改 class 名 `ExpertDashboardScheduleTab` → `ScheduleTab`，修改 import 路径。

- [ ] **Step 6: 验证编译**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard
```

Expected: 0 errors

- [ ] **Step 7: 提交**

```bash
git add link2ur/lib/features/expert_dashboard/views/tabs/
git commit -m "refactor(expert_dashboard): migrate 5 tabs to new module"
```

---

### Task A5: 创建 ExpertDashboardShell

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/expert_dashboard_shell.dart`

- [ ] **Step 1: 写 shell**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/expert_team.dart';
import '../../../data/repositories/expert_team_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/services/storage_service.dart';
import '../bloc/expert_dashboard_bloc.dart';
import '../bloc/selected_expert_cubit.dart';
import 'tabs/applications_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/services_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/time_slots_tab.dart';

/// 统一达人管理页面 shell
/// 两阶段：1. fetch my-teams 解析 expertId；2. 显示 5 tab dashboard
class ExpertDashboardShell extends StatefulWidget {
  const ExpertDashboardShell({super.key});

  @override
  State<ExpertDashboardShell> createState() => _ExpertDashboardShellState();
}

class _ExpertDashboardShellState extends State<ExpertDashboardShell> {
  List<ExpertTeam>? _myTeams;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMyTeams();
  }

  Future<void> _fetchMyTeams() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final teams = await context.read<ExpertTeamRepository>().getMyTeams();
      if (!mounted) return;
      if (teams.isEmpty) {
        // 无团队 → 重定向到 intro 页
        context.go(AppRoutes.taskExpertsIntro);
        return;
      }
      setState(() {
        _myTeams = teams;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertDashboardTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _myTeams == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertDashboardTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(context.localizeError(_error ?? 'expert_dashboard_no_team')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _fetchMyTeams,
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    // 初始 expertId：存储的优先，否则第一个
    final storedId = StorageService.instance.getSelectedExpertId();
    final initialId = (storedId != null && _myTeams!.any((t) => t.id == storedId))
        ? storedId
        : _myTeams!.first.id;

    return BlocProvider(
      create: (_) => SelectedExpertCubit(
        myTeams: _myTeams!,
        initialExpertId: initialId,
      ),
      child: BlocBuilder<SelectedExpertCubit, SelectedExpertState>(
        buildWhen: (prev, curr) => prev.currentExpertId != curr.currentExpertId,
        builder: (context, state) {
          return _DashboardTabs(key: ValueKey(state.currentExpertId));
        },
      ),
    );
  }
}

class _DashboardTabs extends StatelessWidget {
  const _DashboardTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final cubitState = context.watch<SelectedExpertCubit>().state;
    final canManage = cubitState.canManage;
    final expertId = cubitState.currentExpertId;

    // Member 角色不显示 applications tab
    final tabs = <Widget>[
      Tab(icon: const Icon(Icons.dashboard), text: context.l10n.expertDashboardTabStats),
      Tab(icon: const Icon(Icons.design_services), text: context.l10n.expertDashboardTabServices),
      if (canManage)
        Tab(icon: const Icon(Icons.assignment), text: context.l10n.expertDashboardTabApplications),
      Tab(icon: const Icon(Icons.schedule), text: context.l10n.expertDashboardTabTimeSlots),
      Tab(icon: const Icon(Icons.calendar_month), text: context.l10n.expertDashboardTabSchedule),
    ];

    final views = <Widget>[
      const StatsTab(),
      const ServicesTab(),
      if (canManage) const ApplicationsTab(),
      const TimeSlotsTab(),
      const ScheduleTab(),
    ];

    return BlocProvider(
      create: (context) => ExpertDashboardBloc(
        repository: context.read<TaskExpertRepository>(),
        expertId: expertId,
      )
        ..add(const ExpertDashboardLoadStats())
        ..add(const ExpertDashboardLoadMyServices())
        ..add(const ExpertDashboardLoadClosedDates()),
      child: BlocListener<ExpertDashboardBloc, ExpertDashboardState>(
        listenWhen: (prev, curr) =>
            (curr.errorMessage != null && prev.errorMessage != curr.errorMessage) ||
            (curr.actionMessage != null && prev.actionMessage != curr.actionMessage),
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.localizeError(state.errorMessage!))),
            );
          }
          if (state.actionMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.localizeError(state.actionMessage!))),
            );
          }
        },
        child: DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: _TeamTitle(state: cubitState),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: context.l10n.expertDashboardManagement,
                  onPressed: () {
                    context.push(
                      '/expert-dashboard/$expertId/management',
                    );
                  },
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: tabs,
              ),
            ),
            body: TabBarView(children: views),
          ),
        ),
      ),
    );
  }
}

class _TeamTitle extends StatelessWidget {
  const _TeamTitle({required this.state});
  final SelectedExpertState state;

  @override
  Widget build(BuildContext context) {
    // 导入在文件顶部：import 'team_switcher_sheet.dart';
    // （下一个 task 创建）
    return Text(state.currentTeam.name);
  }
}
```

注意：此处 `_TeamTitle` 先简化为显示名称，team switcher 在 Phase B 完成后替换。

- [ ] **Step 2: 加 l10n key `expertDashboardManagement`**

在 `link2ur/lib/l10n/app_en.arb`、`app_zh.arb`、`app_zh_Hant.arb` 加：

`app_en.arb`:
```json
"expertDashboardManagement": "Management",
```

`app_zh.arb`:
```json
"expertDashboardManagement": "管理中心",
```

`app_zh_Hant.arb`:
```json
"expertDashboardManagement": "管理中心",
```

然后运行 l10n 生成：

```bash
cd link2ur && /f/flutter/bin/flutter gen-l10n
```

- [ ] **Step 3: 加 error code `expert_dashboard_no_team` 到 error_localizer**

搜索 `link2ur/lib/core/utils/error_localizer.dart`，在 switch 里添加：

```dart
case 'expert_dashboard_no_team':
  return l10n.expertDashboardNoTeam;
```

对应 arb 加：

```json
"expertDashboardNoTeam": "You are not part of any expert team."
"expertDashboardNoTeam": "你还不在任何达人团队中"
"expertDashboardNoTeam": "你還不在任何達人團隊中"
```

重新运行 `flutter gen-l10n`。

- [ ] **Step 4: 验证编译**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard
```

Expected: 0 errors（可能有 warning：`_TeamTitle` 未使用 switcher，Phase B 会补上）

- [ ] **Step 5: 提交**

```bash
git add link2ur/lib/features/expert_dashboard/views/expert_dashboard_shell.dart
git add link2ur/lib/l10n/
git add link2ur/lib/core/utils/error_localizer.dart
git commit -m "feat(expert_dashboard): add dashboard shell with my-teams resolution"
```

---

### Task A6: 注册新路由 + 切换入口

**Files:**
- Create: `link2ur/lib/core/router/routes/expert_dashboard_routes.dart`
- Modify: `link2ur/lib/core/router/routes/task_expert_routes.dart`
- Modify: `link2ur/lib/core/router/app_routes.dart`
- Modify: `link2ur/lib/core/router/app_router.dart`（routes 注册处）

- [ ] **Step 1: 在 app_routes.dart 加新常量**

找到 `expertDashboard = '/expert-dashboard'` 附近，加上：

```dart
static const String expertDashboardWithId = '/expert-dashboard/:expertId';
static const String expertDashboardManagement =
    '/expert-dashboard/:expertId/management';
```

保留 `expertDashboard = '/expert-dashboard'` 作为入口（无 id 时自动解析）。

- [ ] **Step 2: 创建新路由文件**

```dart
// link2ur/lib/core/router/routes/expert_dashboard_routes.dart
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../../../features/expert_dashboard/views/expert_dashboard_shell.dart';

List<RouteBase> get expertDashboardRoutes => [
      // 入口：无 expertId，shell 解析并重定向到 /:expertId
      GoRoute(
        path: AppRoutes.expertDashboard,
        name: 'expertDashboard',
        builder: (context, state) => const ExpertDashboardShell(),
      ),
      // 显式 expertId 版本（Phase B 之后启用，暂时也指向 shell）
      GoRoute(
        path: AppRoutes.expertDashboardWithId,
        name: 'expertDashboardWithId',
        builder: (context, state) => const ExpertDashboardShell(),
      ),
    ];
```

注意：当前 shell 并不从路由读 expertId（它自己通过 my-teams 解析），所以两个路由都指向同一个 widget。Phase B 之后可以扩展 shell 接受 route param 直接跳过 my-teams fetch。

- [ ] **Step 3: 从 task_expert_routes.dart 删除 dashboard 相关路由**

打开 `link2ur/lib/core/router/routes/task_expert_routes.dart`，删除这三段：

```dart
GoRoute(
  path: AppRoutes.expertApplicationsManagement,
  ...
),
GoRoute(
  path: AppRoutes.expertDashboard,
  ...
),
GoRoute(
  path: AppRoutes.expertProfileEdit,
  ...
),
```

对应删除 import：
- `expert_applications_management_view.dart`
- `expert_dashboard_view.dart`
- `expert_profile_edit_view.dart`

- [ ] **Step 4: 在主 router 注册新路由**

找到 `link2ur/lib/core/router/app_router.dart`，找到 `taskExpertRoutes` 的 spread 位置（如 `...taskExpertRoutes,`），在其旁边加：

```dart
...expertDashboardRoutes,
```

加 import：

```dart
import 'routes/expert_dashboard_routes.dart';
```

- [ ] **Step 5: 验证编译**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib
```

Expected: 0 errors（可能有 warning：`expertApplicationsManagement` / `expertProfileEdit` 常量未使用——如果是，可以先保留留着后续清理；或者直接删这两个常量，但注意 `push_notification_service.dart` 和 `notification_list_view.dart` 还引用 `/expert-applications-management`，保留常量避免这两处出错）

**决策**：保留 `expertApplicationsManagement` 常量不删除。Phase F 清理时再处理。

- [ ] **Step 6: 提交**

```bash
git add link2ur/lib/core/router/
git commit -m "feat(router): wire up /expert-dashboard to new shell"
```

---

### Task A7: 手动验证 Phase A

- [ ] **Step 1: 运行 app 并点击达人中心入口**

```bash
cd link2ur && /f/flutter/bin/flutter run
```

检查点：
- 从 home drawer 的"达人中心"按钮进入
- 看到 5 个 tab（或 4 个如果是 member）
- Stats/Services/TimeSlots/Schedule tab 内容正常加载
- 无团队用户被重定向到 intro 页

- [ ] **Step 2: 如有问题，记录并修复**

如果 tab 内容为空，检查 `SelectedExpertCubit` 的 `currentExpertId` 是否正确传到 `ExpertDashboardBloc`，以及 bloc 是否 dispatch 了 load 事件。

**Phase A 完成后**：dashboard 可以正常工作，老路由已废弃。但仍**没有**团队切换器和管理中心。单团队用户体验无变化。

---

## Phase B: 团队切换器

### Task B1: 创建 TeamSwitcherSheet

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/team_switcher_sheet.dart`

- [ ] **Step 1: 写 sheet**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/expert_team.dart';
import '../bloc/selected_expert_cubit.dart';

class TeamSwitcherSheet extends StatelessWidget {
  const TeamSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: context.read<SelectedExpertCubit>(),
        child: const TeamSwitcherSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectedExpertCubit, SelectedExpertState>(
      builder: (context, state) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    context.l10n.expertDashboardSwitchTeam,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...state.myTeams.map((team) => _TeamTile(
                      team: team,
                      isSelected: team.id == state.currentExpertId,
                    )),
                const Divider(height: 24),
                _ActionTile(
                  icon: Icons.add_circle_outline,
                  iconColor: AppColors.primary,
                  label: context.l10n.expertDashboardApplyNewTeam,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push(AppRoutes.expertTeamCreate);
                  },
                ),
                _ActionTile(
                  icon: Icons.mail_outline,
                  label: context.l10n.expertDashboardMyInvitations,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push(AppRoutes.expertTeamInvitations);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({required this.team, required this.isSelected});
  final ExpertTeam team;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await context.read<SelectedExpertCubit>().switchTo(team.id);
        if (context.mounted) Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: team.avatar != null ? NetworkImage(team.avatar!) : null,
              child: team.avatar == null ? Text(team.name.characters.first) : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.name, style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '${(team.myRole ?? 'member').toUpperCase()} · ${team.totalServices} ${context.l10n.expertDashboardServiceCount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.iconColor});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      dense: true,
    );
  }
}
```

- [ ] **Step 2: 加 l10n keys**

`app_en.arb`:
```json
"expertDashboardSwitchTeam": "Switch Team",
"expertDashboardApplyNewTeam": "Apply for New Team",
"expertDashboardMyInvitations": "My Invitations",
"expertDashboardServiceCount": "services"
```

`app_zh.arb`:
```json
"expertDashboardSwitchTeam": "切换达人团队",
"expertDashboardApplyNewTeam": "申请新团队",
"expertDashboardMyInvitations": "我的邀请",
"expertDashboardServiceCount": "服务"
```

`app_zh_Hant.arb`:
```json
"expertDashboardSwitchTeam": "切換達人團隊",
"expertDashboardApplyNewTeam": "申請新團隊",
"expertDashboardMyInvitations": "我的邀請",
"expertDashboardServiceCount": "服務"
```

运行 `flutter gen-l10n`。

- [ ] **Step 3: 提交**

```bash
git add link2ur/lib/features/expert_dashboard/views/team_switcher_sheet.dart
git add link2ur/lib/l10n/
git commit -m "feat(expert_dashboard): add team switcher bottom sheet"
```

---

### Task B2: Shell AppBar 标题接入 switcher

**Files:**
- Modify: `link2ur/lib/features/expert_dashboard/views/expert_dashboard_shell.dart`

- [ ] **Step 1: 替换 `_TeamTitle`**

找到 Task A5 写的 `_TeamTitle` 类，替换为：

```dart
class _TeamTitle extends StatelessWidget {
  const _TeamTitle({required this.state});
  final SelectedExpertState state;

  Widget _roleBadge(BuildContext context, String role) {
    final (bg, fg, label) = switch (role) {
      'owner' => (const Color(0xFFE0F7E5), const Color(0xFF2E7D32), 'OWNER'),
      'admin' => (const Color(0xFFFFF4E0), const Color(0xFFF57C00), 'ADMIN'),
      _ => (const Color(0xFFF0F0F0), const Color(0xFF666666), 'MEMBER'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final team = state.currentTeam;
    return InkWell(
      onTap: () => TeamSwitcherSheet.show(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundImage: team.avatar != null ? NetworkImage(team.avatar!) : null,
              child: team.avatar == null
                  ? Text(team.name.characters.first, style: const TextStyle(fontSize: 12))
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                team.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _roleBadge(context, state.currentRole),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 加 import**

文件顶部添加：

```dart
import 'team_switcher_sheet.dart';
```

- [ ] **Step 3: 验证编译**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard
```

Expected: 0 errors

- [ ] **Step 4: 提交**

```bash
git add link2ur/lib/features/expert_dashboard/views/expert_dashboard_shell.dart
git commit -m "feat(expert_dashboard): wire up team switcher to AppBar title"
```

---

### Task B3: 手动验证 Phase B

- [ ] **Step 1: 单团队用户**

运行 app，点击 AppBar 标题，应该看到 sheet 显示 1 个团队 + 当前选中 ✓ + "申请新团队" + "我的邀请"。

- [ ] **Step 2: 多团队用户（如果账号有）**

切换到另一个团队，内容应该更新（Stats 数字刷新、服务列表重新加载）。刷新页面或重启 app 后，上次选中的团队应被恢复。

**Phase B 完成后**：多团队切换能用，持久化正确。管理中心和管理子页还没做。

---

## Phase C: 管理中心主页 + 4 个子页迁移

### Task C1: 管理中心主页

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/management/management_center_view.dart`

- [ ] **Step 1: 写主页**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/repositories/expert_team_repository.dart';
import '../../bloc/selected_expert_cubit.dart';

/// 管理中心主页
///
/// 根据角色显示可用的管理项。注意：本页面从路由参数接收 expertId，
/// 但角色需要从 SelectedExpertCubit 获取（cubit 提供在上层 shell）。
/// 由于 push 到这里时 cubit 仍在 context 中（GoRouter 保留 provider 链），
/// 可以直接读取。
class ManagementCenterView extends StatelessWidget {
  const ManagementCenterView({super.key, required this.expertId});
  final String expertId;

  @override
  Widget build(BuildContext context) {
    // 从 cubit 读当前团队和角色（如果不在 provider 链中，降级：重新 fetch）
    final cubit = context.read<SelectedExpertCubit?>();
    final state = cubit?.state;
    final role = state?.currentRole ?? 'member';
    final isOwner = role == 'owner';
    final canManage = isOwner || role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.expertDashboardManagement),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          _SectionHeader(title: context.l10n.expertManagementSectionTeam),
          _MenuCard(children: [
            _MenuTile(
              icon: Icons.people_outline,
              label: context.l10n.expertTeamMembers,
              onTap: () => context.push('/expert-dashboard/$expertId/management/members'),
            ),
            if (canManage)
              _MenuTile(
                icon: Icons.mail_outline,
                label: context.l10n.expertTeamJoinRequests,
                onTap: () => context.push('/expert-dashboard/$expertId/management/join-requests'),
              ),
            if (isOwner)
              _MenuTile(
                icon: Icons.edit_outlined,
                label: context.l10n.expertDashboardEditTeamProfile,
                onTap: () => context.push('/expert-dashboard/$expertId/management/edit-profile'),
              ),
          ]),

          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionHeader(title: context.l10n.expertManagementSectionMarketing),
            _MenuCard(children: [
              _MenuTile(
                icon: Icons.local_activity_outlined,
                label: context.l10n.expertTeamCoupons,
                onTap: () => context.push('/expert-dashboard/$expertId/management/coupons'),
              ),
              _MenuTile(
                icon: Icons.inventory_2_outlined,
                label: context.l10n.expertManagementPackages,
                onTap: () => context.push('/expert-dashboard/$expertId/management/packages'),
              ),
              _MenuTile(
                icon: Icons.reviews_outlined,
                label: context.l10n.expertManagementReviewReplies,
                onTap: () => context.push('/expert-dashboard/$expertId/management/review-replies'),
              ),
            ]),
          ],

          if (isOwner) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionHeader(title: context.l10n.expertManagementSectionFinance),
            _MenuCard(children: [
              _MenuTile(
                icon: Icons.credit_card,
                label: 'Stripe Connect',
                onTap: () => context.push('/expert-dashboard/$expertId/management/stripe'),
              ),
            ]),
          ],

          const SizedBox(height: AppSpacing.md),
          _SectionHeader(title: context.l10n.expertManagementSectionOther),
          _MenuCard(children: [
            _MenuTile(
              icon: Icons.public,
              label: context.l10n.expertManagementViewPublicPage,
              onTap: () => context.push('/expert-teams/$expertId'),
            ),
            if (!isOwner)
              _MenuTile(
                icon: Icons.exit_to_app,
                label: context.l10n.expertManagementLeaveTeam,
                color: Colors.red,
                onTap: () => _confirmLeave(context, expertId),
              ),
          ]),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context, String expertId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.expertManagementLeaveTeam),
        content: Text(context.l10n.expertManagementLeaveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              context.l10n.expertManagementLeaveTeam,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<ExpertTeamRepository>().leaveTeam(expertId);
        if (!context.mounted) return;
        // 离开后返回 dashboard 入口，shell 会重新解析（可能重定向到 intro）
        context.go('/expert-dashboard');
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final filtered = children.whereType<_MenuTile>().toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          for (int i = 0; i < filtered.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            filtered[i],
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: color != null ? TextStyle(color: color) : null),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 2: 加 l10n keys**

`app_en.arb`:
```json
"expertManagementSectionTeam": "Team",
"expertManagementSectionMarketing": "Marketing",
"expertManagementSectionFinance": "Finance",
"expertManagementSectionOther": "Other",
"expertManagementPackages": "Service Packages",
"expertManagementReviewReplies": "Review Replies",
"expertManagementViewPublicPage": "View Public Page",
"expertManagementLeaveTeam": "Leave Team",
"expertManagementLeaveConfirm": "Are you sure you want to leave this team? You will lose access to the team's services and chat.",
"expertDashboardEditTeamProfile": "Edit Team Profile"
```

`app_zh.arb`:
```json
"expertManagementSectionTeam": "团队",
"expertManagementSectionMarketing": "营销",
"expertManagementSectionFinance": "财务",
"expertManagementSectionOther": "其他",
"expertManagementPackages": "服务套餐",
"expertManagementReviewReplies": "评价回复",
"expertManagementViewPublicPage": "查看公开主页",
"expertManagementLeaveTeam": "离开团队",
"expertManagementLeaveConfirm": "确定要离开这个团队吗？你将失去对团队服务和聊天的访问权限。",
"expertDashboardEditTeamProfile": "编辑团队资料"
```

`app_zh_Hant.arb`:
```json
"expertManagementSectionTeam": "團隊",
"expertManagementSectionMarketing": "營銷",
"expertManagementSectionFinance": "財務",
"expertManagementSectionOther": "其他",
"expertManagementPackages": "服務套餐",
"expertManagementReviewReplies": "評價回覆",
"expertManagementViewPublicPage": "查看公開主頁",
"expertManagementLeaveTeam": "離開團隊",
"expertManagementLeaveConfirm": "確定要離開這個團隊嗎？你將失去對團隊服務和聊天的訪問權限。",
"expertDashboardEditTeamProfile": "編輯團隊資料"
```

运行 `flutter gen-l10n`。

- [ ] **Step 3: 注册路由**

在 `expert_dashboard_routes.dart` 的列表里添加：

```dart
GoRoute(
  path: '/expert-dashboard/:expertId/management',
  name: 'expertDashboardManagement',
  builder: (context, state) {
    final id = state.pathParameters['expertId']!;
    return ManagementCenterView(expertId: id);
  },
),
```

加 import：

```dart
import '../../../features/expert_dashboard/views/management/management_center_view.dart';
```

**重要注意**：`ManagementCenterView` 读取 `SelectedExpertCubit` 是通过 `context.read<SelectedExpertCubit?>()`（nullable）。这是因为 GoRouter 的新页面**不一定**保留 BlocProvider 链。如果拿不到 cubit，角色信息无法判断——降级方案：直接 fetch team 信息。

**Phase C 实施决策**：在 shell 的 `BlocProvider<SelectedExpertCubit>` 外面再包一层 `RepositoryProvider<SelectedExpertCubit>` 行不通（cubit 不是 repository）。正确做法是**每个管理子页自己从 my-teams 获取角色**，或者**管理中心页面自己 fetch 团队详情**。

**最终决策**：管理中心和所有子页都**自己 fetch**（调用 `ExpertTeamRepository.getExpertById(expertId)` 获取团队 + 角色信息），不依赖 cubit。这样每个管理子页独立可用，路由参数 expertId 是唯一的上下文。

修改 ManagementCenterView 为 StatefulWidget，在 initState fetch 团队信息：

```dart
import '../../../../data/models/expert_team.dart';
import '../../../../core/utils/error_localizer.dart';

class ManagementCenterView extends StatefulWidget {
  const ManagementCenterView({super.key, required this.expertId});
  final String expertId;

  @override
  State<ManagementCenterView> createState() => _ManagementCenterViewState();
}

class _ManagementCenterViewState extends State<ManagementCenterView> {
  ExpertTeam? _team;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    try {
      final team = await context.read<ExpertTeamRepository>().getExpertById(widget.expertId);
      if (!mounted) return;
      setState(() { _team = team; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertDashboardManagement)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _team == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertDashboardManagement)),
        body: Center(child: Text(context.localizeError(_error ?? 'load_failed'))),
      );
    }

    final role = _team!.myRole ?? 'member';
    final isOwner = role == 'owner';
    final canManage = isOwner || role == 'admin';
    final expertId = widget.expertId;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.expertDashboardManagement)),
      body: ListView(
        // ... (same body as before — _SectionHeader, _MenuCard, _MenuTile)
      ),
    );
  }

  // ... _confirmLeave helper
}
```

将 Step 1 写的 stateless 版本替换为这个 Stateful 版本。body 里的 ListView 和 section 保持一致，只是从 `widget.expertId` 取 expertId，从 `_team!.myRole` 取 role。

- [ ] **Step 4: 验证编译**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard lib/core/router
```

Expected: 0 errors

- [ ] **Step 5: 提交**

```bash
git add link2ur/lib/features/expert_dashboard/views/management/management_center_view.dart
git add link2ur/lib/core/router/routes/expert_dashboard_routes.dart
git add link2ur/lib/l10n/
git commit -m "feat(expert_dashboard): add management center view with role-based sections"
```

---

### Task C2: 迁移成员管理页

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/management/members_view.dart`
- Modify: `link2ur/lib/core/router/routes/expert_dashboard_routes.dart`

- [ ] **Step 1: 复制并改路径**

复制 `link2ur/lib/features/expert_team/views/expert_team_members_view.dart` 到 `expert_dashboard/views/management/members_view.dart`。

改动：
1. 类名 `ExpertTeamMembersView` → `MembersView`
2. `_ExpertTeamMembersBody` → `_MembersBody`
3. Import 路径：相对路径加一层 `../`
4. Body 中 `context.push('/expert-teams/$expertId/join-requests')` 改为 `context.push('/expert-dashboard/$expertId/management/join-requests')`

- [ ] **Step 2: 注册路由**

在 `expert_dashboard_routes.dart` 加：

```dart
GoRoute(
  path: '/expert-dashboard/:expertId/management/members',
  name: 'expertDashboardManagementMembers',
  builder: (context, state) {
    final id = state.pathParameters['expertId']!;
    return MembersView(expertId: id);
  },
),
```

加 import：
```dart
import '../../../features/expert_dashboard/views/management/members_view.dart';
```

- [ ] **Step 3: 验证编译 + 提交**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard
git add link2ur/lib/features/expert_dashboard/views/management/members_view.dart
git add link2ur/lib/core/router/routes/expert_dashboard_routes.dart
git commit -m "feat(expert_dashboard): migrate members view to management center"
```

---

### Task C3: 迁移入队申请审核页

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/management/join_requests_view.dart`
- Modify: `link2ur/lib/core/router/routes/expert_dashboard_routes.dart`

- [ ] **Step 1: 复制并改路径**

复制 `link2ur/lib/features/expert_team/views/join_requests_view.dart` 到 `expert_dashboard/views/management/join_requests_view.dart`。

改动：
1. 保留原类名 `JoinRequestsView`
2. Import 路径加一层 `../`

- [ ] **Step 2: 注册路由**

```dart
GoRoute(
  path: '/expert-dashboard/:expertId/management/join-requests',
  name: 'expertDashboardManagementJoinRequests',
  builder: (context, state) {
    final id = state.pathParameters['expertId']!;
    return JoinRequestsView(expertId: id);
  },
),
```

- [ ] **Step 3: 验证 + 提交**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard
git add link2ur/lib/features/expert_dashboard/views/management/join_requests_view.dart
git add link2ur/lib/core/router/routes/expert_dashboard_routes.dart
git commit -m "feat(expert_dashboard): migrate join requests view"
```

---

### Task C4: 迁移编辑团队资料页

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/management/edit_team_profile_view.dart`
- Modify: `link2ur/lib/core/router/routes/expert_dashboard_routes.dart`

- [ ] **Step 1: 复制并改路径**

复制 `link2ur/lib/features/expert_team/views/edit_team_profile_view.dart` 到 `expert_dashboard/views/management/edit_team_profile_view.dart`。

保留原类名 `EditTeamProfileView`。修 import 相对路径加一层 `../`。

- [ ] **Step 2: 注册路由**

```dart
GoRoute(
  path: '/expert-dashboard/:expertId/management/edit-profile',
  name: 'expertDashboardManagementEditProfile',
  builder: (context, state) {
    final id = state.pathParameters['expertId']!;
    return EditTeamProfileView(expertId: id);
  },
),
```

- [ ] **Step 3: 验证 + 提交**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard
git add link2ur/lib/features/expert_dashboard/views/management/edit_team_profile_view.dart
git add link2ur/lib/core/router/routes/expert_dashboard_routes.dart
git commit -m "feat(expert_dashboard): migrate edit team profile view"
```

---

### Task C5: 迁移优惠券管理页

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/management/coupons_view.dart`
- Modify: `link2ur/lib/core/router/routes/expert_dashboard_routes.dart`

- [ ] **Step 1: 复制并改路径**

复制 `link2ur/lib/features/expert_team/views/expert_coupons_view.dart` 到 `expert_dashboard/views/management/coupons_view.dart`。

改动：
1. 类名 `ExpertCouponsView` → `CouponsView`
2. Import 相对路径加一层 `../`

- [ ] **Step 2: 注册路由**

```dart
GoRoute(
  path: '/expert-dashboard/:expertId/management/coupons',
  name: 'expertDashboardManagementCoupons',
  builder: (context, state) {
    final id = state.pathParameters['expertId']!;
    return CouponsView(expertId: id);
  },
),
```

- [ ] **Step 3: 验证 + 提交**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard
git add link2ur/lib/features/expert_dashboard/views/management/coupons_view.dart
git add link2ur/lib/core/router/routes/expert_dashboard_routes.dart
git commit -m "feat(expert_dashboard): migrate coupons view"
```

---

### Task C6: 迁移套餐管理页

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/management/packages_view.dart`
- Modify: `link2ur/lib/core/router/routes/expert_dashboard_routes.dart`

- [ ] **Step 1: 复制并改路径**

复制 `link2ur/lib/features/expert_team/views/expert_packages_view.dart` 到 `expert_dashboard/views/management/packages_view.dart`。

注意：原 view 读的是"我的套餐"(`getMyPackages`)，是**买家侧**的视图（我买了哪些套餐）。达人侧的套餐管理在**服务创建**时设置（`package_type`, `total_sessions`），并不是独立页面。

**实施决策**：这个 migration **可能**不对应实际的"套餐管理"需求。先做一个简化版本：显示该团队**创建的**套餐类服务列表（`package_type != 'single'` 的 service），允许编辑/删除。

但这也可能超出简单 migration 范围。**采取保守方案**：先只复制现有 `ExpertPackagesView`（买家视角，用户已购套餐），class 名改为 `PackagesView`，路由命名为 `packages`。**备注：可能需要二次设计真正的"达人侧套餐管理"**，不在本 plan 范围。

- [ ] **Step 2: 注册路由**

```dart
GoRoute(
  path: '/expert-dashboard/:expertId/management/packages',
  name: 'expertDashboardManagementPackages',
  builder: (context, state) {
    final id = state.pathParameters['expertId']!;
    return const PackagesView();  // 注意：此 view 不需要 expertId
  },
),
```

**但是**：如果 `PackagesView` 是买家视角的"我的套餐"，它不属于"管理中心"。**更合理的决策**：从管理中心的菜单里**暂时移除 packages 项**，Phase D 用新建的 "达人侧套餐管理" 替代。

**最终决策**：Task C6 改为"**从管理中心暂时移除 packages 入口**"。

打开 `management_center_view.dart`，注释掉或删除 packages 的 `_MenuTile`：

```dart
// _MenuTile(
//   icon: Icons.inventory_2_outlined,
//   label: context.l10n.expertManagementPackages,
//   onTap: () => context.push('/expert-dashboard/$expertId/management/packages'),
// ),
```

添加注释：`// Packages management deferred — needs expert-side management view design`

- [ ] **Step 3: 验证 + 提交**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard
git add link2ur/lib/features/expert_dashboard/views/management/management_center_view.dart
git commit -m "chore(expert_dashboard): defer packages management (needs dedicated design)"
```

---

### Task C7: 手动验证 Phase C

- [ ] **Step 1: 进入管理中心**

从 dashboard AppBar 点 ⚙，应该看到按角色分组的菜单。

- [ ] **Step 2: 逐项点击**

- 成员管理 → 显示成员列表，Owner/Admin 可邀请、踢人、改角色
- 入队申请 → 显示申请列表，可 approve/reject
- 编辑团队资料（仅 Owner 可见）→ 正常提交
- 优惠券（仅 Owner/Admin 可见）→ 正常 CRUD
- 查看公开主页 → 跳到 `/expert-teams/:id` 正常显示

- [ ] **Step 3: 离开团队**

以 Admin 或 Member 角色点"离开团队"，确认对话框，确认后跳回 dashboard 入口，shell 重新解析。

- [ ] **Step 4: Member 角色验证**

以 Member 角色进入管理中心，应该只看到"成员管理"（只读）、"查看公开主页"、"离开团队"三项。

**Phase C 完成后**：主要管理功能全部可用。剩下评价回复和 Stripe。

---

## Phase D: 评价回复 + Stripe Connect 链接

### Task D1: 创建评价回复 view

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/management/review_replies_view.dart`
- Modify: `link2ur/lib/core/router/routes/expert_dashboard_routes.dart`

- [ ] **Step 1: 写 view**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/repositories/expert_team_repository.dart';
import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_endpoints.dart';

/// 评价回复页面
/// 后端：
/// - GET /api/experts/{id}/reviews  — 评价列表
/// - POST /api/reviews/{review_id}/reply  — 回复
class ReviewRepliesView extends StatefulWidget {
  const ReviewRepliesView({super.key, required this.expertId});
  final String expertId;

  @override
  State<ReviewRepliesView> createState() => _ReviewRepliesViewState();
}

class _ReviewRepliesViewState extends State<ReviewRepliesView> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() { _loading = true; _error = null; });
    try {
      // 直接调用 ApiService 而不扩展 repository，避免改动接口
      final response = await context.read<ApiService>().get<List<dynamic>>(
        ApiEndpoints.taskExpertReviews(widget.expertId),
        queryParameters: {'limit': 50, 'offset': 0},
      );
      if (!response.isSuccess || response.data == null) {
        throw Exception(response.message ?? 'load_failed');
      }
      if (!mounted) return;
      setState(() {
        _reviews = response.data!.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _reply(int reviewId, String content) async {
    try {
      await context.read<ExpertTeamRepository>().replyToReview(reviewId, content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.expertReviewReplySent)),
      );
      _loadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.expertManagementReviewReplies)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(context.localizeError(_error!)))
              : _reviews.isEmpty
                  ? Center(child: Text(context.l10n.expertReviewNoReviews))
                  : RefreshIndicator(
                      onRefresh: _loadReviews,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _reviews.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final review = _reviews[index];
                          return _ReviewCard(
                            review: review,
                            onReply: (content) => _reply(review['id'] as int, content),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onReply});
  final Map<String, dynamic> review;
  final Future<void> Function(String content) onReply;

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final replyContent = review['reply_content'] as String?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: List.generate(5, (i) => Icon(
              i < rating ? Icons.star : Icons.star_border,
              size: 18,
              color: Colors.amber,
            ))),
            const SizedBox(height: 8),
            Text(comment),
            const SizedBox(height: 8),
            if (replyContent != null && replyContent.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${context.l10n.expertReviewReplyLabel}: $replyContent'),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showReplyDialog(context),
                  child: Text(context.l10n.expertReviewReplyButton),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReplyDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.expertReviewReplyButton),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: context.l10n.expertReviewReplyHint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(ctx).pop(text);
            },
            child: Text(context.l10n.commonSubmit),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      await onReply(result);
    }
  }
}
```

- [ ] **Step 2: 加 l10n keys**

`app_en.arb`:
```json
"expertReviewReplySent": "Reply sent",
"expertReviewNoReviews": "No reviews yet",
"expertReviewReplyLabel": "Reply",
"expertReviewReplyButton": "Reply",
"expertReviewReplyHint": "Write your reply..."
```

`app_zh.arb`:
```json
"expertReviewReplySent": "回复已发送",
"expertReviewNoReviews": "暂无评价",
"expertReviewReplyLabel": "回复",
"expertReviewReplyButton": "回复",
"expertReviewReplyHint": "输入你的回复..."
```

`app_zh_Hant.arb`:
```json
"expertReviewReplySent": "回覆已發送",
"expertReviewNoReviews": "暫無評價",
"expertReviewReplyLabel": "回覆",
"expertReviewReplyButton": "回覆",
"expertReviewReplyHint": "輸入你的回覆..."
```

运行 `flutter gen-l10n`。

- [ ] **Step 3: 注册路由**

```dart
GoRoute(
  path: '/expert-dashboard/:expertId/management/review-replies',
  name: 'expertDashboardManagementReviewReplies',
  builder: (context, state) {
    final id = state.pathParameters['expertId']!;
    return ReviewRepliesView(expertId: id);
  },
),
```

加 import。

- [ ] **Step 4: 验证 + 提交**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard
git add link2ur/lib/features/expert_dashboard/views/management/review_replies_view.dart
git add link2ur/lib/core/router/routes/expert_dashboard_routes.dart
git add link2ur/lib/l10n/
git commit -m "feat(expert_dashboard): add review replies management view"
```

---

### Task D2: Stripe Connect 链接

**Files:**
- Modify: `link2ur/lib/features/expert_dashboard/views/management/management_center_view.dart`
- Modify: `link2ur/lib/core/router/routes/expert_dashboard_routes.dart`

- [ ] **Step 1: 决定跳转目标**

检查 `features/payment/views/stripe_connect_onboarding_view.dart` 的构造函数，看它需要什么参数。

```bash
cd F:/python_work/LinkU && grep -n "class StripeConnectOnboardingView" link2ur/lib/features/payment/views/stripe_connect_onboarding_view.dart
```

**如果** 它接受 `expertId` 参数，直接在 management center 的 Stripe tile onTap 里 push：

```dart
onTap: () => context.push('/stripe-connect/onboarding?expertId=$expertId'),
```

**如果** 它是通用的（无参数），需要在目标 view 内部先 fetch `ExpertTeamRepository.getStripeConnectStatus(expertId)` 决定显示什么。

**Phase D 实施决策**：**不扩展 `stripe_connect_onboarding_view.dart`**（避免修改 payment 模块）。而是在 management center 的 Stripe tile onTap 里做一个**简单的 dialog** 显示状态（"已认证 / 未认证，点击前往设置"），然后再 push 到 onboarding view。

修改 management_center_view.dart 的 Stripe tile onTap：

```dart
_MenuTile(
  icon: Icons.credit_card,
  label: 'Stripe Connect',
  onTap: () => _handleStripeConnect(context, expertId),
),
```

在同文件加方法：

```dart
Future<void> _handleStripeConnect(BuildContext context, String expertId) async {
  try {
    final status = await context.read<ExpertTeamRepository>().getStripeConnectStatus(expertId);
    if (!context.mounted) return;
    final isActive = status['onboarding_complete'] == true;

    final goToOnboarding = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stripe Connect'),
        content: Text(isActive
            ? context.l10n.expertStripeAlreadyActive
            : context.l10n.expertStripeNotActive),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isActive
                ? context.l10n.expertStripeViewDashboard
                : context.l10n.expertStripeStartOnboarding),
          ),
        ],
      ),
    );

    if (goToOnboarding == true && context.mounted) {
      // 导向现有的 Stripe Connect onboarding 路由（不改 payment 模块）
      context.push('/stripe-connect/onboarding');
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}
```

- [ ] **Step 2: 加 l10n keys**

`app_en.arb`:
```json
"expertStripeAlreadyActive": "Your Stripe Connect account is active. You can manage it in the Stripe dashboard.",
"expertStripeNotActive": "You haven't completed Stripe Connect setup. Set it up to receive payments.",
"expertStripeStartOnboarding": "Start Setup",
"expertStripeViewDashboard": "View Dashboard"
```

`app_zh.arb`:
```json
"expertStripeAlreadyActive": "你的 Stripe Connect 账户已激活，可以在 Stripe 面板管理。",
"expertStripeNotActive": "你还没有完成 Stripe Connect 设置。设置后即可接收付款。",
"expertStripeStartOnboarding": "开始设置",
"expertStripeViewDashboard": "查看面板"
```

`app_zh_Hant.arb`:
```json
"expertStripeAlreadyActive": "你的 Stripe Connect 帳戶已激活，可以在 Stripe 面板管理。",
"expertStripeNotActive": "你還沒有完成 Stripe Connect 設置。設置後即可接收付款。",
"expertStripeStartOnboarding": "開始設置",
"expertStripeViewDashboard": "查看面板"
```

运行 `flutter gen-l10n`。

- [ ] **Step 3: 验证 Stripe onboarding 路由存在**

```bash
grep -n "stripe-connect/onboarding" link2ur/lib/core/router/routes/payment_routes.dart
```

如果不存在该 path，则用它实际的路由常量（从 payment_routes.dart 查）。

- [ ] **Step 4: 验证 + 提交**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib/features/expert_dashboard
git add link2ur/lib/features/expert_dashboard/views/management/management_center_view.dart
git add link2ur/lib/l10n/
git commit -m "feat(expert_dashboard): link Stripe Connect management from center"
```

---

### Task D3: 手动验证 Phase D

- [ ] **Step 1: 评价回复**

以 Owner 身份点"评价回复"，应看到达人团队收到的所有评价。有评论的回复不可再回，无回复的可点"回复"输入回复。

- [ ] **Step 2: Stripe Connect（仅 Owner 可见）**

点"Stripe Connect"，应弹出状态对话框。点"开始设置"或"查看面板"跳到 Stripe onboarding view。

**Phase D 完成后**：管理中心所有可用项都能用。

---

## Phase E: 清理旧代码

### Task E1: 删除旧的 dashboard 相关文件

**Files:**
- Delete: 多个旧文件

- [ ] **Step 1: 删除旧 dashboard views**

```bash
cd F:/python_work/LinkU && rm link2ur/lib/features/task_expert/views/expert_dashboard_view.dart \
  link2ur/lib/features/task_expert/views/expert_dashboard_stats_tab.dart \
  link2ur/lib/features/task_expert/views/expert_dashboard_services_tab.dart \
  link2ur/lib/features/task_expert/views/expert_dashboard_applications_tab.dart \
  link2ur/lib/features/task_expert/views/expert_dashboard_time_slots_tab.dart \
  link2ur/lib/features/task_expert/views/expert_dashboard_schedule_tab.dart \
  link2ur/lib/features/task_expert/views/expert_profile_edit_view.dart \
  link2ur/lib/features/task_expert/views/expert_applications_management_view.dart \
  link2ur/lib/features/task_expert/bloc/expert_dashboard_bloc.dart \
  link2ur/lib/features/task_expert/bloc/expert_dashboard_event.dart \
  link2ur/lib/features/task_expert/bloc/expert_dashboard_state.dart
```

- [ ] **Step 2: 删除旧的 expert_team 管理 views（已迁移的）**

```bash
rm link2ur/lib/features/expert_team/views/expert_team_members_view.dart \
  link2ur/lib/features/expert_team/views/join_requests_view.dart \
  link2ur/lib/features/expert_team/views/edit_team_profile_view.dart \
  link2ur/lib/features/expert_team/views/expert_coupons_view.dart \
  link2ur/lib/features/expert_team/views/expert_services_manage_view.dart
```

注意：**不要**删 `my_teams_view.dart`、`create_team_view.dart`、`my_invitations_view.dart`、`expert_team_detail_view.dart`、`group_buy_view.dart`、`expert_packages_view.dart`（买家视角）。

- [ ] **Step 3: 更新 expert_team_routes.dart 删除迁走的路由**

打开 `link2ur/lib/core/router/routes/expert_team_routes.dart`，删除下面 5 段 GoRoute：
- `expertTeamMembers`
- `expertTeamJoinRequests`
- `expertTeamCoupons`
- `expertTeamServices`
- `expertTeamEditProfile`

对应删除 import：
- `expert_team_members_view.dart`
- `join_requests_view.dart`
- `expert_coupons_view.dart`
- `expert_services_manage_view.dart`
- `edit_team_profile_view.dart`

保留：`my_teams_view.dart`, `create_team_view.dart`, `expert_team_detail_view.dart`, `my_invitations_view.dart`, `expert_packages_view.dart`, `group_buy_view.dart` 对应的路由。

- [ ] **Step 4: 删除 app_routes.dart 中的对应常量**

打开 `link2ur/lib/core/router/app_routes.dart`，删除：
- `expertTeamMembers`
- `expertTeamJoinRequests`
- `expertTeamCoupons`
- `expertTeamServices`
- `expertTeamEditProfile`
- `expertProfileEdit`

**保留** `expertApplicationsManagement`（通知跳转仍用）和 `expertDashboard`（shell 入口）。

但 `expertApplicationsManagement` 指向的路由已经被删除（在 Task A6 中删了），所以要么：
- A. 保留路由常量，在 `expert_dashboard_routes.dart` 里重新注册一条 `/expert-applications-management` 路由指向新 shell（以 applications tab 初始选中）
- B. 更新 `push_notification_service.dart` 和 `notification_list_view.dart`，把推送的跳转目标改为 `/expert-dashboard`

**采取方案 B**：简单，不保留历史 URL。

修改 `link2ur/lib/data/services/push_notification_service.dart:604`：
```dart
_router!.push('/expert-dashboard');
```
改为：
```dart
_router!.push('/expert-dashboard');  // 保持不变，push 到 shell 即可
```
（已经是这样，无需改）

修改 `link2ur/lib/features/notification/views/notification_list_view.dart:270`：
```dart
context.push('/expert-applications-management');
```
改为：
```dart
context.push('/expert-dashboard');
```

然后删除 `AppRoutes.expertApplicationsManagement` 常量。

- [ ] **Step 5: 验证编译**

```bash
cd link2ur && /f/flutter/bin/flutter analyze lib
```

Expected: 0 errors, 可能还是那 6 个 pre-existing warnings。如果有新的 errors，是因为还有地方引用被删除的类，需要修。

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "chore(expert_dashboard): delete legacy views and routes after migration"
```

---

### Task E2: 手动验证 Phase E

- [ ] **Step 1: 全量功能测试**

运行 app：
- 达人中心入口正常
- 5 tab 全部工作
- 团队切换器可用
- 管理中心所有项可用
- 通知跳转到 applications 正常

- [ ] **Step 2: 冷启动持久化**

关闭 app 重开，上次选中的团队应该恢复。

- [ ] **Step 3: 0 团队 / 1 团队 / 多团队场景**

- 0 teams：重定向到 intro
- 1 team：team switcher 只有一项，切换无效果
- 多 teams：切换正常

---

## 手动验证清单（全部 Phase 完成后）

- [ ] Owner 能看到全部 5 tab（含 applications）
- [ ] Admin 能看到全部 5 tab
- [ ] Member 只看到 4 tab（无 applications）
- [ ] Owner 管理中心：成员/入队申请/编辑资料/优惠券/评价回复/Stripe/公开主页（无离开、无解散）
- [ ] Admin 管理中心：成员/入队申请/优惠券/评价回复/公开主页/离开
- [ ] Member 管理中心：成员（只读）/公开主页/离开
- [ ] 多团队用户切换后 Stats/Services/Applications 内容正确更新
- [ ] 切换后重启 app，恢复上次选中
- [ ] 0 teams 用户被重定向到 intro
- [ ] 离开团队后跳回 dashboard 入口重新解析
- [ ] 通知跳转到 applications 正常（新路径 `/expert-dashboard`）
- [ ] 时间段创建/列表/删除正常
- [ ] 评价回复能提交
- [ ] Stripe 状态对话框正常显示

---

## 未包含在本 plan（defer）

- 内部群聊 tab（等群聊 Phase 1）
- 达人侧的"套餐管理"（需要单独设计——当前的 ExpertPackagesView 是买家视角）
- 转让所有权（Owner → 某个 Admin）—— 原 members view 里有，保留迁移但不作为 plan 重点
- `features/task_expert/` 改名（保留用于公开浏览相关 view，无需改名）
