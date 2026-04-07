# Expert Dashboard Views Rewrite — /me/* to /experts/{expertId}/*

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite all `task_expert/` dashboard/management views from old `/api/task-experts/me/*` endpoints to new `/api/experts/{expertId}/*` endpoints, where expertId comes from the `experts` table.

**Architecture:** The `ExpertDashboardBloc` gains a `required String expertId` constructor param. `TaskExpertRepository` methods that used `myExpert*` endpoints switch to `expertId`-parameterized new endpoints. `ExpertDashboardView` becomes a two-phase widget: first fetches `my-teams` to resolve expertId, then creates the bloc. Routes and navigation callers stay unchanged (`/expert-dashboard` with no path param).

**Tech Stack:** Flutter/Dart, BLoC, GoRouter, Dio-based ApiService

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/data/repositories/task_expert_repository.dart` | Add `expertId` param to 12 methods, switch to new endpoint URLs |
| Modify | `lib/features/task_expert/bloc/expert_dashboard_bloc.dart` | Add `expertId` field, pass to all repository calls |
| Modify | `lib/features/task_expert/views/expert_dashboard_view.dart` | Fetch my-teams to resolve expertId before creating bloc |
| Modify | `lib/features/task_expert/views/expert_profile_edit_view.dart` | Same: fetch expertId, pass to bloc |
| Modify | `lib/features/task_expert/views/expert_applications_management_view.dart` | Same: accept expertId or fetch it |
| Modify | `lib/features/task_expert/views/expert_dashboard_applications_tab.dart` | Pass expertId when embedding applications view |
| Modify | `lib/core/constants/api_endpoints.dart` | Delete old `myExpert*` constants after migration |

---

### Task 1: Update TaskExpertRepository — add expertId to dashboard methods

**Files:**
- Modify: `lib/data/repositories/task_expert_repository.dart:365-690`

All methods below currently use `ApiEndpoints.myExpert*` (no param). Each gains a `String expertId` parameter and switches to the corresponding new endpoint.

- [ ] **Step 1: Update `getMyExpertProfile` → `getExpertProfile(String expertId)`**

```dart
/// 获取达人资料
Future<Map<String, dynamic>?> getExpertProfile(String expertId) async {
  final response = await _apiService.get<Map<String, dynamic>>(
    ApiEndpoints.taskExpertById(expertId),
  );

  if (!response.isSuccess) {
    throw TaskExpertException(response.message ?? '获取达人资料失败');
  }

  return response.data;
}
```

Replace the old `getMyExpertProfile()` method entirely.

- [ ] **Step 2: Update `getMyExpertStats` → `getExpertStats(String expertId)`**

```dart
/// 获取达人统计数据
Future<Map<String, dynamic>> getExpertStats(String expertId) async {
  final response = await _apiService.get<Map<String, dynamic>>(
    ApiEndpoints.expertDashboardStats(expertId),
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '获取统计数据失败');
  }

  return response.data!;
}
```

Remove both `getMyExpertDashboardStats()` and `getMyExpertStats()` (duplicates), replace with this single method.

- [ ] **Step 3: Update `getMyServices` → `getExpertManagedServices(String expertId)`**

```dart
/// 获取达人服务列表（管理用）
Future<List<Map<String, dynamic>>> getExpertManagedServices(String expertId) async {
  final response = await _apiService.get<Map<String, dynamic>>(
    ApiEndpoints.taskExpertServices(expertId),
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '获取服务列表失败');
  }

  // 后端返回 {expert_id, expert_name, services: [...]}
  final List<dynamic> serviceItems;
  if (response.data is Map<String, dynamic>) {
    serviceItems =
        (response.data as Map<String, dynamic>)['services'] as List<dynamic>? ?? [];
  } else if (response.data is List) {
    serviceItems = response.data as List<dynamic>;
  } else {
    serviceItems = [];
  }

  return serviceItems.map((e) => e as Map<String, dynamic>).toList();
}
```

Remove `getMyServices()` and `getMyExpertServices()`.

- [ ] **Step 4: Update `createService` → takes `expertId`**

```dart
/// 创建服务
Future<Map<String, dynamic>> createService(String expertId, Map<String, dynamic> data) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.taskExpertServices(expertId),
    data: data,
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '创建服务失败');
  }

  return response.data!;
}
```

- [ ] **Step 5: Update `updateService` → takes `expertId`**

```dart
/// 更新服务
Future<Map<String, dynamic>> updateService(String expertId, int serviceId, Map<String, dynamic> data) async {
  final response = await _apiService.put<Map<String, dynamic>>(
    ApiEndpoints.expertServiceById(expertId, serviceId),
    data: data,
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '更新服务失败');
  }

  return response.data!;
}
```

Note: `serviceId` changes from `String` to `int` to match new endpoint signature `expertServiceById(String expertId, int serviceId)`.

- [ ] **Step 6: Update `deleteService` → takes `expertId`**

```dart
/// 删除服务
Future<void> deleteService(String expertId, int serviceId) async {
  final response = await _apiService.delete(
    ApiEndpoints.expertServiceById(expertId, serviceId),
  );

  if (!response.isSuccess) {
    throw TaskExpertException(response.message ?? '删除服务失败');
  }
}
```

- [ ] **Step 7: Update time slot methods → take `expertId`**

```dart
/// 获取服务时间段（达人管理）
Future<List<Map<String, dynamic>>> getExpertServiceTimeSlots(String expertId, int serviceId) async {
  final response = await _apiService.get<dynamic>(
    ApiEndpoints.expertServiceTimeSlots(expertId, serviceId),
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '获取时间段失败');
  }

  final List<dynamic> items;
  if (response.data is List) {
    items = response.data as List<dynamic>;
  } else if (response.data is Map<String, dynamic>) {
    items = (response.data as Map<String, dynamic>)['time_slots']
            as List<dynamic>? ?? [];
  } else {
    items = [];
  }
  return items.map((e) => e as Map<String, dynamic>).toList();
}

/// 创建服务时间段
Future<Map<String, dynamic>> createServiceTimeSlot(String expertId, int serviceId, Map<String, dynamic> data) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.expertServiceTimeSlots(expertId, serviceId),
    data: data,
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '创建时间段失败');
  }

  return response.data!;
}

/// 删除服务时间段
Future<void> deleteServiceTimeSlot(String expertId, int serviceId, int slotId) async {
  final response = await _apiService.delete(
    ApiEndpoints.expertServiceTimeSlotById(expertId, serviceId, slotId),
  );

  if (!response.isSuccess) {
    throw TaskExpertException(response.message ?? '删除时间段失败');
  }
}
```

Remove `getMyExpertServiceTimeSlots(String)`, `getMyServiceTimeSlots(int)`, and old `createServiceTimeSlot(String, Map)` / `deleteServiceTimeSlot(String, String)`.

- [ ] **Step 8: Update closed date methods → take `expertId`**

```dart
/// 获取休息日列表
Future<List<Map<String, dynamic>>> getClosedDates(String expertId) async {
  final response = await _apiService.get<List<dynamic>>(
    ApiEndpoints.expertClosedDates(expertId),
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '获取休息日失败');
  }

  return response.data!.map((e) => e as Map<String, dynamic>).toList();
}

/// 创建休息日
Future<Map<String, dynamic>> createClosedDate(String expertId, String date, {String? reason}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.expertClosedDates(expertId),
    data: {
      'date': date,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    },
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '创建休息日失败');
  }

  return response.data!;
}

/// 删除休息日
Future<void> deleteClosedDate(String expertId, int closedDateId) async {
  final response = await _apiService.delete(
    ApiEndpoints.expertClosedDateById(expertId, closedDateId),
  );

  if (!response.isSuccess) {
    throw TaskExpertException(response.message ?? '删除休息日失败');
  }
}
```

Remove `getMyClosedDates()`, `getMyExpertClosedDates()`, old `createClosedDate(String, {String?})`, old `deleteClosedDate(String)`.

- [ ] **Step 9: Update `submitProfileUpdateRequest` → takes `expertId`**

```dart
/// 提交达人资料更新请求
Future<void> submitProfileUpdateRequest(String expertId, {
  String? name,
  String? bio,
  String? avatarUrl,
}) async {
  final response = await _apiService.post(
    ApiEndpoints.expertTeamProfileUpdateRequest(expertId),
    data: {
      if (name != null && name.isNotEmpty) 'name': name,
      if (bio != null && bio.isNotEmpty) 'bio': bio,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
    },
  );

  if (!response.isSuccess) {
    throw TaskExpertException(response.message ?? '提交资料更新请求失败');
  }
}
```

Remove old `submitProfileUpdateRequest({String?, String?, String?})` and `requestExpertProfileUpdate(Map)`.

- [ ] **Step 10: Update `getMyExpertApplications` → takes `expertId`**

```dart
/// 获取达人收到的申请记录
Future<List<Map<String, dynamic>>> getExpertApplications(String expertId, {
  int page = 1,
  int pageSize = 20,
}) async {
  final response = await _apiService.get<Map<String, dynamic>>(
    ApiEndpoints.expertApplicationsList(expertId),
    queryParameters: {
      'page': page,
      'page_size': pageSize,
    },
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '获取申请记录失败');
  }

  final items = response.data!['items'] as List<dynamic>? ?? [];
  return items.map((e) => e as Map<String, dynamic>).toList();
}
```

Remove old `getMyExpertApplications()`.

- [ ] **Step 11: Remove deprecated and old `/me/` methods**

Delete these methods entirely:
- `getMyExpertProfile()`
- `getMyExpertServices()` (the @Deprecated one)
- `getMyExpertDashboardStats()`
- `getMyExpertStats()`
- `getMyServices()`
- `getMyExpertServiceTimeSlots(String)`
- `getMyServiceTimeSlots(int)`
- `getMyClosedDates()`
- `getMyExpertClosedDates()`
- `getMyExpertSchedule()`
- `requestExpertProfileUpdate(Map)`
- `getMyExpertApplications()`

Also remove `getMyExpertSchedule()` — the schedule tab uses the calendar + closed dates, not a separate schedule endpoint.

- [ ] **Step 12: Commit**

```bash
git add link2ur/lib/data/repositories/task_expert_repository.dart
git commit -m "refactor: update TaskExpertRepository to use expertId-based endpoints"
```

---

### Task 2: Update ExpertDashboardBloc — accept expertId

**Files:**
- Modify: `lib/features/task_expert/bloc/expert_dashboard_bloc.dart`

- [ ] **Step 1: Add expertId to constructor and pass to all repository calls**

Replace the entire bloc file content. The `expertId` is stored as a field and passed to every repository method:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';

part 'expert_dashboard_event.dart';
part 'expert_dashboard_state.dart';

class ExpertDashboardBloc
    extends Bloc<ExpertDashboardEvent, ExpertDashboardState> {
  ExpertDashboardBloc({
    required TaskExpertRepository repository,
    required this.expertId,
  })  : _repository = repository,
        super(const ExpertDashboardState()) {
    on<ExpertDashboardLoadStats>(_onLoadStats);
    on<ExpertDashboardLoadMyServices>(_onLoadMyServices);
    on<ExpertDashboardCreateService>(_onCreateService);
    on<ExpertDashboardUpdateService>(_onUpdateService);
    on<ExpertDashboardDeleteService>(_onDeleteService);
    on<ExpertDashboardLoadTimeSlots>(_onLoadTimeSlots);
    on<ExpertDashboardCreateTimeSlot>(_onCreateTimeSlot);
    on<ExpertDashboardDeleteTimeSlot>(_onDeleteTimeSlot);
    on<ExpertDashboardLoadClosedDates>(_onLoadClosedDates);
    on<ExpertDashboardCreateClosedDate>(_onCreateClosedDate);
    on<ExpertDashboardDeleteClosedDate>(_onDeleteClosedDate);
    on<ExpertDashboardSubmitProfileUpdate>(_onSubmitProfileUpdate);
  }

  final TaskExpertRepository _repository;
  final String expertId;

  Future<void> _onLoadStats(
    ExpertDashboardLoadStats event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.loading));
    try {
      final stats = await _repository.getExpertStats(expertId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        stats: stats,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_load_stats_failed',
      ));
    }
  }

  Future<void> _onLoadMyServices(
    ExpertDashboardLoadMyServices event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.loading));
    try {
      final services = await _repository.getExpertManagedServices(expertId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: services,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_load_services_failed',
      ));
    }
  }

  Future<void> _onCreateService(
    ExpertDashboardCreateService event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.createService(expertId, event.data);
      final services = await _repository.getExpertManagedServices(expertId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: services,
        actionMessage: 'expertServiceSubmitted',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_create_service_failed',
      ));
    }
  }

  Future<void> _onUpdateService(
    ExpertDashboardUpdateService event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      final serviceId = int.tryParse(event.id) ?? 0;
      await _repository.updateService(expertId, serviceId, event.data);
      final services = await _repository.getExpertManagedServices(expertId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: services,
        actionMessage: 'expertServiceUpdated',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_update_service_failed',
      ));
    }
  }

  Future<void> _onDeleteService(
    ExpertDashboardDeleteService event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      final serviceId = int.tryParse(event.id) ?? 0;
      await _repository.deleteService(expertId, serviceId);
      final services = await _repository.getExpertManagedServices(expertId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: services,
        actionMessage: 'expertServiceDeleted',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_delete_service_failed',
      ));
    }
  }

  Future<void> _onLoadTimeSlots(
    ExpertDashboardLoadTimeSlots event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(
      status: ExpertDashboardStatus.loading,
      selectedServiceId: event.serviceId,
    ));
    try {
      final serviceId = int.tryParse(event.serviceId) ?? 0;
      final timeSlots =
          await _repository.getExpertServiceTimeSlots(expertId, serviceId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        timeSlots: timeSlots,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_load_time_slots_failed',
      ));
    }
  }

  Future<void> _onCreateTimeSlot(
    ExpertDashboardCreateTimeSlot event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      final serviceId = int.tryParse(event.serviceId) ?? 0;
      await _repository.createServiceTimeSlot(expertId, serviceId, event.data);
      final timeSlots =
          await _repository.getExpertServiceTimeSlots(expertId, serviceId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        timeSlots: timeSlots,
        selectedServiceId: event.serviceId,
        actionMessage: 'expertTimeSlotCreated',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_create_time_slot_failed',
      ));
    }
  }

  Future<void> _onDeleteTimeSlot(
    ExpertDashboardDeleteTimeSlot event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      final serviceId = int.tryParse(event.serviceId) ?? 0;
      final slotId = int.tryParse(event.slotId) ?? 0;
      await _repository.deleteServiceTimeSlot(expertId, serviceId, slotId);
      final timeSlots =
          await _repository.getExpertServiceTimeSlots(expertId, serviceId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        timeSlots: timeSlots,
        selectedServiceId: event.serviceId,
        actionMessage: 'expertTimeSlotDeleted',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_delete_time_slot_failed',
      ));
    }
  }

  Future<void> _onLoadClosedDates(
    ExpertDashboardLoadClosedDates event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.loading));
    try {
      final closedDates = await _repository.getClosedDates(expertId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        closedDates: closedDates,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_load_closed_dates_failed',
      ));
    }
  }

  Future<void> _onCreateClosedDate(
    ExpertDashboardCreateClosedDate event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.createClosedDate(expertId, event.date, reason: event.reason);
      final closedDates = await _repository.getClosedDates(expertId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        closedDates: closedDates,
        actionMessage: 'expertScheduleMarkedRest',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_create_closed_date_failed',
      ));
    }
  }

  Future<void> _onDeleteClosedDate(
    ExpertDashboardDeleteClosedDate event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      final closedDateId = int.tryParse(event.id) ?? 0;
      await _repository.deleteClosedDate(expertId, closedDateId);
      final closedDates = await _repository.getClosedDates(expertId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        closedDates: closedDates,
        actionMessage: 'expertScheduleUnmarked',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_delete_closed_date_failed',
      ));
    }
  }

  Future<void> _onSubmitProfileUpdate(
    ExpertDashboardSubmitProfileUpdate event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.submitProfileUpdateRequest(
        expertId,
        name: event.name,
        bio: event.bio,
        avatarUrl: event.avatarUrl,
      );
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        actionMessage: 'expertProfileUpdateSubmitted',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_submit_profile_update_failed',
      ));
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/task_expert/bloc/expert_dashboard_bloc.dart
git commit -m "refactor: ExpertDashboardBloc accepts expertId, routes through new endpoints"
```

---

### Task 3: Update ExpertDashboardView — fetch expertId via my-teams

**Files:**
- Modify: `lib/features/task_expert/views/expert_dashboard_view.dart`

The view becomes a two-phase widget: first resolves expertId from the my-teams API, then creates the BLoC.

- [ ] **Step 1: Rewrite ExpertDashboardView to resolve expertId first**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/expert_team_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../bloc/expert_dashboard_bloc.dart';
import 'expert_dashboard_applications_tab.dart';
import 'expert_dashboard_services_tab.dart';
import 'expert_dashboard_stats_tab.dart';
import 'expert_dashboard_schedule_tab.dart';
import 'expert_dashboard_time_slots_tab.dart';

/// 达人工作台 — resolves expertId via my-teams, then shows 5-tab dashboard
class ExpertDashboardView extends StatefulWidget {
  const ExpertDashboardView({super.key});

  @override
  State<ExpertDashboardView> createState() => _ExpertDashboardViewState();
}

class _ExpertDashboardViewState extends State<ExpertDashboardView> {
  String? _expertId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExpertId();
  }

  Future<void> _loadExpertId() async {
    try {
      final teams = await context.read<ExpertTeamRepository>().getMyTeams();
      if (!mounted) return;
      if (teams.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'expert_no_team';
        });
        return;
      }
      setState(() {
        _expertId = teams.first.id;
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

    if (_error != null || _expertId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertDashboardTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.localizeError(_error ?? 'expert_no_team')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadExpertId();
                },
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => ExpertDashboardBloc(
        repository: context.read<TaskExpertRepository>(),
        expertId: _expertId!,
      )
        ..add(const ExpertDashboardLoadStats())
        ..add(const ExpertDashboardLoadMyServices())
        ..add(const ExpertDashboardLoadClosedDates()),
      child: _ExpertDashboardContent(expertId: _expertId!),
    );
  }
}

class _ExpertDashboardContent extends StatelessWidget {
  const _ExpertDashboardContent({required this.expertId});

  final String expertId;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertDashboardBloc, ExpertDashboardState>(
      listenWhen: (prev, curr) =>
          (curr.errorMessage != null &&
              prev.errorMessage != curr.errorMessage) ||
          (curr.actionMessage != null &&
              prev.actionMessage != curr.actionMessage),
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(context.localizeError(state.errorMessage!))),
          );
        }
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(context.localizeError(state.actionMessage!))),
          );
        }
      },
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.expertDashboardTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: context.l10n.expertProfileEditTitle,
                onPressed: () => context.push(AppRoutes.expertProfileEdit),
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                  icon: const Icon(Icons.dashboard),
                  text: context.l10n.expertDashboardTabStats,
                ),
                Tab(
                  icon: const Icon(Icons.design_services),
                  text: context.l10n.expertDashboardTabServices,
                ),
                Tab(
                  icon: const Icon(Icons.assignment),
                  text: context.l10n.expertDashboardTabApplications,
                ),
                Tab(
                  icon: const Icon(Icons.schedule),
                  text: context.l10n.expertDashboardTabTimeSlots,
                ),
                Tab(
                  icon: const Icon(Icons.calendar_month),
                  text: context.l10n.expertDashboardTabSchedule,
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              const ExpertDashboardStatsTab(),
              const ExpertDashboardServicesTab(),
              ExpertDashboardApplicationsTab(expertId: expertId),
              const ExpertDashboardTimeSlotsTab(),
              const ExpertDashboardScheduleTab(),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/task_expert/views/expert_dashboard_view.dart
git commit -m "refactor: ExpertDashboardView resolves expertId via my-teams before creating bloc"
```

---

### Task 4: Update ExpertDashboardApplicationsTab and ExpertApplicationsManagementView

**Files:**
- Modify: `lib/features/task_expert/views/expert_dashboard_applications_tab.dart`
- Modify: `lib/features/task_expert/views/expert_applications_management_view.dart`
- Modify: `lib/features/task_expert/bloc/task_expert_bloc.dart` (the `_onLoadExpertApplications` handler)

The `ExpertApplicationsManagementView` creates its own `TaskExpertBloc` and dispatches `TaskExpertLoadExpertApplications`. The bloc's handler calls `getMyExpertApplications()`. This needs to call `getExpertApplications(expertId)` instead.

- [ ] **Step 1: Add expertId to ExpertApplicationsManagementView**

In `expert_applications_management_view.dart`, change the constructor and builder:

```dart
class ExpertApplicationsManagementView extends StatelessWidget {
  const ExpertApplicationsManagementView({
    super.key,
    required this.expertId,
    this.showAppBar = true,
  });

  final String expertId;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
        questionRepository: context.read<QuestionRepository>(),
        expertId: expertId,
      )..add(const TaskExpertLoadExpertApplications()),
      child: _ExpertApplicationsManagementContent(showAppBar: showAppBar),
    );
  }
}
```

- [ ] **Step 2: Add optional expertId to TaskExpertBloc**

In `task_expert_bloc.dart`, add an optional `expertId` field to the constructor:

```dart
class TaskExpertBloc extends Bloc<TaskExpertEvent, TaskExpertState> {
  TaskExpertBloc({
    required TaskExpertRepository taskExpertRepository,
    required QuestionRepository questionRepository,
    ActivityRepository? activityRepository,
    this.expertId,
  }) : _taskExpertRepository = taskExpertRepository,
       _questionRepository = questionRepository,
       _activityRepository = activityRepository,
       super(const TaskExpertState()) {
```

Add the field:

```dart
  final String? expertId;
```

- [ ] **Step 3: Update `_onLoadExpertApplications` handler**

Change the handler to use `expertId`:

```dart
  Future<void> _onLoadExpertApplications(
    TaskExpertLoadExpertApplications event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(status: TaskExpertStatus.loading));

    try {
      final expertApplications = expertId != null
          ? await _taskExpertRepository.getExpertApplications(expertId!)
          : <Map<String, dynamic>>[];

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        expertApplications: expertApplications,
      ));
    } catch (e) {
      AppLogger.error('Failed to load expert applications', e);
      emit(state.copyWith(
        status: TaskExpertStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
```

Also update `_onApproveApplication`, `_onOwnerApproveApplication`, `_onRejectApplication`, `_onCounterOffer` — they all re-dispatch `TaskExpertLoadExpertApplications()` after success, which is fine (the handler above uses expertId).

- [ ] **Step 4: Update ExpertDashboardApplicationsTab to pass expertId**

```dart
import 'package:flutter/material.dart';

import 'expert_applications_management_view.dart';

class ExpertDashboardApplicationsTab extends StatelessWidget {
  const ExpertDashboardApplicationsTab({super.key, required this.expertId});

  final String expertId;

  @override
  Widget build(BuildContext context) {
    return ExpertApplicationsManagementView(
      expertId: expertId,
      showAppBar: false,
    );
  }
}
```

- [ ] **Step 5: Update the standalone route for expertApplicationsManagement**

In `lib/core/router/routes/task_expert_routes.dart`, update:

```dart
GoRoute(
  path: AppRoutes.expertApplicationsManagement,
  name: 'expertApplicationsManagement',
  builder: (context, state) {
    final expertId = state.uri.queryParameters['expertId'] ?? '';
    return ExpertApplicationsManagementView(expertId: expertId);
  },
),
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/task_expert/views/expert_dashboard_applications_tab.dart
git add link2ur/lib/features/task_expert/views/expert_applications_management_view.dart
git add link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart
git add link2ur/lib/core/router/routes/task_expert_routes.dart
git commit -m "refactor: ExpertApplicationsManagementView accepts expertId for new endpoints"
```

---

### Task 5: Update ExpertProfileEditView — fetch expertId

**Files:**
- Modify: `lib/features/task_expert/views/expert_profile_edit_view.dart`

Same pattern as ExpertDashboardView: resolve expertId, then create bloc.

- [ ] **Step 1: Rewrite ExpertProfileEditView**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/expert_team_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../bloc/expert_dashboard_bloc.dart';

/// 达人资料编辑页 — resolves expertId, then shows form
class ExpertProfileEditView extends StatefulWidget {
  const ExpertProfileEditView({super.key});

  @override
  State<ExpertProfileEditView> createState() => _ExpertProfileEditViewState();
}

class _ExpertProfileEditViewState extends State<ExpertProfileEditView> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  String? _expertId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _loadExpertId();
  }

  Future<void> _loadExpertId() async {
    try {
      final teams = await context.read<ExpertTeamRepository>().getMyTeams();
      if (!mounted) return;
      if (teams.isEmpty) {
        setState(() { _loading = false; _error = 'expert_no_team'; });
        return;
      }
      setState(() { _expertId = teams.first.id; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertProfileEditTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _expertId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertProfileEditTitle)),
        body: Center(child: Text(context.localizeError(_error ?? 'expert_no_team'))),
      );
    }

    return BlocProvider(
      create: (context) => ExpertDashboardBloc(
        repository: context.read<TaskExpertRepository>(),
        expertId: _expertId!,
      ),
      child: _ExpertProfileEditContent(
        nameController: _nameController,
        bioController: _bioController,
      ),
    );
  }
}

class _ExpertProfileEditContent extends StatelessWidget {
  const _ExpertProfileEditContent({
    required this.nameController,
    required this.bioController,
  });

  final TextEditingController nameController;
  final TextEditingController bioController;

  void _onSubmit(BuildContext context) {
    final name = nameController.text.trim();
    final bio = bioController.text.trim();
    context.read<ExpertDashboardBloc>().add(
          ExpertDashboardSubmitProfileUpdate(
            name: name.isEmpty ? null : name,
            bio: bio.isEmpty ? null : bio,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertDashboardBloc, ExpertDashboardState>(
      listenWhen: (prev, curr) =>
          (curr.errorMessage != null &&
              prev.errorMessage != curr.errorMessage) ||
          (curr.actionMessage != null &&
              prev.actionMessage != curr.actionMessage),
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.localizeError(state.errorMessage!)),
            ),
          );
        }
        if (state.actionMessage == 'expertProfileUpdateSubmitted') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(context.localizeError(state.actionMessage!)),
            ),
          );
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.expertProfileEditTitle),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertProfileEditName,
                  hintText: context.l10n.expertProfileEditNameHint,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: bioController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertProfileEditBio,
                  hintText: context.l10n.expertProfileEditBioHint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: AppSpacing.xl),
              BlocBuilder<ExpertDashboardBloc, ExpertDashboardState>(
                buildWhen: (prev, curr) => prev.status != curr.status,
                builder: (context, state) {
                  final isSubmitting =
                      state.status == ExpertDashboardStatus.submitting;
                  return FilledButton(
                    onPressed: isSubmitting ? null : () => _onSubmit(context),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.expertProfileEditSubmit),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/task_expert/views/expert_profile_edit_view.dart
git commit -m "refactor: ExpertProfileEditView resolves expertId before creating bloc"
```

---

### Task 6: Clean up old API endpoint constants

**Files:**
- Modify: `lib/core/constants/api_endpoints.dart:253-279`

- [ ] **Step 1: Delete old myExpert* constants**

Remove the entire "旧兼容" block (lines 253-279):

```dart
// DELETE these lines:
static const String myExpertProfile = '/api/task-experts/me';
static const String myExpertServices = '/api/task-experts/me/services';
static const String myExpertApplications = '/api/task-experts/me/applications';
static const String myExpertDashboardStats = '/api/task-experts/me/dashboard/stats';
static const String myExpertSchedule = '/api/task-experts/me/schedule';
static const String myExpertClosedDates = '/api/task-experts/me/closed-dates';
static const String myExpertStats = '/api/task-experts/me/dashboard/stats';
static String myExpertServiceById(String id) => '/api/task-experts/me/services/$id';
static String myExpertServiceTimeSlots(String serviceId) =>
    '/api/task-experts/me/services/$serviceId/time-slots';
static String myExpertServiceTimeSlotById(String serviceId, String slotId) =>
    '/api/task-experts/me/services/$serviceId/time-slots/$slotId';
static String myExpertClosedDateById(String id) =>
    '/api/task-experts/me/closed-dates/$id';
static const String myExpertProfileUpdateRequest =
    '/api/task-experts/me/profile-update-request';
static String serviceTimeSlots(int serviceId) =>
    '/api/task-experts/services/$serviceId/time-slots';
static String myServiceTimeSlots(int serviceId) =>
    '/api/task-experts/me/services/$serviceId/time-slots';
```

Also remove these two (they still reference old paths but are unused after migration):

```dart
static String taskExpertServiceDetail(int serviceId) =>
    '/api/task-experts/services/$serviceId';
static String respondServiceCounterOffer(int applicationId) =>
    '/api/users/me/service-applications/$applicationId/respond-counter-offer';
static String cancelServiceApplication(int applicationId) =>
    '/api/users/me/service-applications/$applicationId/cancel';
```

**Important:** Before deleting, verify no other file still references these constants. Run:
```bash
cd link2ur && grep -r "myExpertProfile\|myExpertServices\|myExpertApplications\|myExpertDashboardStats\|myExpertSchedule\|myExpertClosedDates\|myExpertStats\|myExpertServiceById\|myExpertServiceTimeSlots\|myExpertServiceTimeSlotById\|myExpertClosedDateById\|myExpertProfileUpdateRequest\|myServiceTimeSlots\|taskExpertServiceDetail\b" lib/ --include="*.dart" -l
```

Expected: only `api_endpoints.dart` itself (since we already updated the repository in Task 1).

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart
git commit -m "chore: remove deprecated myExpert* endpoint constants"
```

---

### Task 7: Verify compilation and fix any remaining references

**Files:**
- All modified files

- [ ] **Step 1: Run flutter analyze**

```bash
cd link2ur && flutter analyze
```

Fix any compilation errors from remaining references to old method names.

- [ ] **Step 2: Verify the app_providers.dart has ExpertTeamRepository available**

The `ExpertDashboardView` and `ExpertProfileEditView` now call `context.read<ExpertTeamRepository>()`. Verify that `ExpertTeamRepository` is registered in `app_providers.dart`:

```bash
grep -n "ExpertTeamRepository" link2ur/lib/app_providers.dart
```

If not registered, add it to the `MultiRepositoryProvider`.

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve remaining compilation issues from endpoint migration"
```
