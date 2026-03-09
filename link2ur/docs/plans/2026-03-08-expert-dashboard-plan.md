# Expert Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a full expert management centre (dashboard, services CRUD, time slots, schedule, profile edit) gated to `isExpert` users, plus fix small expert-related issues.

**Architecture:** New `ExpertDashboardBloc` (page-level) handles all write-heavy expert operations. New `/expert-dashboard` route with 5-tab layout. `TaskExpertRepository` extended with new methods. Existing `ExpertApplicationsManagementView` logic migrated into Tab 2.

**Tech Stack:** Flutter BLoC, GoRouter, Dio/ApiService, flutter_bloc, bloc_test, existing design system (AppColors, AppSpacing, AppRadius, SheetAdaptation, AdaptiveDialogs)

---

## Task 1: Expert category constants

**Files:**
- Create: `lib/core/constants/expert_constants.dart`
- Modify: `lib/features/task_expert/views/task_expert_list_view.dart`
- Modify: `lib/features/task_expert/views/task_expert_search_view.dart`

**Step 1: Create constants file**

```dart
// lib/core/constants/expert_constants.dart

/// Expert category keys — aligned with backend FeaturedTaskExpert.category
const List<String> kExpertCategoryKeys = [
  'all',
  'programming',
  'translation',
  'tutoring',
  'food',
  'beverage',
  'cake',
  'errand_transport',
  'social_entertainment',
  'beauty_skincare',
  'handicraft',
];

/// Expert service currencies
const List<String> kExpertServiceCurrencies = ['GBP', 'CNY', 'USD'];

/// Max images per service
const int kExpertServiceMaxImages = 4;
```

**Step 2: Replace in task_expert_list_view.dart**

Remove the local `const List<Map<String, String>> _expertCategories = [...]` block (lines ~24-36).

Add import at top:
```dart
import '../../../core/constants/expert_constants.dart';
```

Replace every reference to `_expertCategories` with a map over `kExpertCategoryKeys`:
```dart
// Wherever _expertCategories is iterated, replace with:
kExpertCategoryKeys.map((key) => {'key': key}).toList()
```

Or if the code uses `_expertCategories` as `List<Map<String,String>>`, keep the shape but derive from the constant:
```dart
final List<Map<String, String>> _expertCategories =
    kExpertCategoryKeys.map((k) => {'key': k}).toList();
```
Place this as a local variable inside the widget build method (not a top-level const).

**Step 3: Same change in task_expert_search_view.dart**

Same import + same replacement — remove the duplicate `const List<Map<String, String>> _expertCategories`.

**Step 4: Verify**

```bash
cd F:\python_work\LinkU\link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze lib/core/constants/expert_constants.dart lib/features/task_expert/views/task_expert_list_view.dart lib/features/task_expert/views/task_expert_search_view.dart
```
Expected: no issues.

**Step 5: Commit**
```bash
git add link2ur/lib/core/constants/expert_constants.dart link2ur/lib/features/task_expert/views/task_expert_list_view.dart link2ur/lib/features/task_expert/views/task_expert_search_view.dart
git commit -m "refactor(expert): extract category list to expert_constants.dart"
```

---

## Task 2: Fix officialBadge hardcode + add new l10n strings

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_zh_Hant.arb`
- Modify: `lib/features/task_expert/views/task_expert_list_view.dart` (officialBadge fix)

**Step 1: Add l10n keys to app_en.arb**

Find the expert section and append:
```json
"expertOfficialBadge": "Official",
"expertDashboardTitle": "Expert Centre",
"expertDashboardTabStats": "Dashboard",
"expertDashboardTabServices": "Services",
"expertDashboardTabApplications": "Applications",
"expertDashboardTabTimeSlots": "Time Slots",
"expertDashboardTabSchedule": "Schedule",
"expertDashboardEditProfile": "Edit Profile",
"expertDashboardTotalServices": "Total Services",
"expertDashboardActiveServices": "Active",
"expertDashboardTotalApplications": "Total Applications",
"expertDashboardPendingApplications": "Pending",
"expertDashboardUpcomingSlots": "Upcoming Slots",
"expertServicesEmpty": "No services yet",
"expertServicesEmptyMessage": "Tap + to create your first service",
"expertServiceCreate": "New Service",
"expertServiceEdit": "Edit Service",
"expertServiceDelete": "Delete Service",
"expertServiceConfirmDelete": "Delete this service?",
"expertServiceConfirmDeleteMessage": "This action cannot be undone.",
"expertServiceName": "Service Name",
"expertServiceNameHint": "e.g. English Tutoring",
"expertServiceNameEn": "Service Name (English)",
"expertServiceDescription": "Description",
"expertServiceDescriptionHint": "Describe what you offer...",
"expertServiceDescriptionEn": "Description (English)",
"expertServicePrice": "Price",
"expertServicePriceHint": "e.g. 30",
"expertServiceCurrency": "Currency",
"expertServiceImages": "Images (up to 4)",
"expertServiceSubmitted": "Service submitted for review",
"expertServiceDeleted": "Service deleted",
"expertServiceUpdated": "Service updated",
"expertServiceStatusActive": "Active",
"expertServiceStatusPending": "Pending Review",
"expertServiceStatusRejected": "Rejected",
"expertServiceStatusInactive": "Inactive",
"expertTimeSlotsEmpty": "No time slots",
"expertTimeSlotsEmptyMessage": "Select a service and add time slots",
"expertTimeSlotCreate": "Add Time Slot",
"expertTimeSlotDate": "Date",
"expertTimeSlotStartTime": "Start Time",
"expertTimeSlotEndTime": "End Time",
"expertTimeSlotPrice": "Price per Person",
"expertTimeSlotMaxParticipants": "Max Participants",
"expertTimeSlotCreated": "Time slot added",
"expertTimeSlotDeleted": "Time slot removed",
"expertTimeSlotConfirmDelete": "Remove this time slot?",
"expertScheduleTitle": "Schedule",
"expertScheduleSetClosed": "Mark as Unavailable",
"expertScheduleRemoveClosed": "Remove Unavailability",
"expertScheduleClosedReason": "Reason (optional)",
"expertScheduleClosedReasonHint": "e.g. Public holiday",
"expertScheduleClosedAdded": "Marked as unavailable",
"expertScheduleClosedRemoved": "Availability restored",
"expertProfileEditTitle": "Edit Profile",
"expertProfileEditName": "Display Name",
"expertProfileEditNameHint": "Your expert display name",
"expertProfileEditBio": "Bio",
"expertProfileEditBioHint": "Tell clients about yourself...",
"expertProfileEditAvatar": "Profile Photo",
"expertProfileEditSubmit": "Submit for Review",
"expertProfileEditSubmitted": "Submitted — pending admin review",
"expertProfileEditAlreadyPending": "You already have a pending update request",
"expertViewTask": "View Task",
"expertSearchSortLabel": "Sort by",
"expertSearchSortRating": "Rating",
"expertSearchSortCompleted": "Most Completed",
"expertSearchSortNewest": "Newest"
```

**Step 2: Add same keys to app_zh.arb**

```json
"expertOfficialBadge": "官方",
"expertDashboardTitle": "达人中心",
"expertDashboardTabStats": "看板",
"expertDashboardTabServices": "我的服务",
"expertDashboardTabApplications": "申请管理",
"expertDashboardTabTimeSlots": "时间段",
"expertDashboardTabSchedule": "日程",
"expertDashboardEditProfile": "编辑资料",
"expertDashboardTotalServices": "服务总数",
"expertDashboardActiveServices": "上架中",
"expertDashboardTotalApplications": "申请总数",
"expertDashboardPendingApplications": "待处理",
"expertDashboardUpcomingSlots": "即将到来的时间段",
"expertServicesEmpty": "暂无服务",
"expertServicesEmptyMessage": "点击 + 创建第一个服务",
"expertServiceCreate": "新建服务",
"expertServiceEdit": "编辑服务",
"expertServiceDelete": "删除服务",
"expertServiceConfirmDelete": "删除此服务？",
"expertServiceConfirmDeleteMessage": "此操作不可撤销。",
"expertServiceName": "服务名称",
"expertServiceNameHint": "例如：英语辅导",
"expertServiceNameEn": "服务名称（英文）",
"expertServiceDescription": "描述",
"expertServiceDescriptionHint": "描述你提供的服务内容...",
"expertServiceDescriptionEn": "描述（英文）",
"expertServicePrice": "价格",
"expertServicePriceHint": "例如：30",
"expertServiceCurrency": "货币",
"expertServiceImages": "图片（最多4张）",
"expertServiceSubmitted": "服务已提交审核",
"expertServiceDeleted": "服务已删除",
"expertServiceUpdated": "服务已更新",
"expertServiceStatusActive": "上架中",
"expertServiceStatusPending": "待审核",
"expertServiceStatusRejected": "已拒绝",
"expertServiceStatusInactive": "已下架",
"expertTimeSlotsEmpty": "暂无时间段",
"expertTimeSlotsEmptyMessage": "选择服务后添加时间段",
"expertTimeSlotCreate": "添加时间段",
"expertTimeSlotDate": "日期",
"expertTimeSlotStartTime": "开始时间",
"expertTimeSlotEndTime": "结束时间",
"expertTimeSlotPrice": "每人价格",
"expertTimeSlotMaxParticipants": "最大人数",
"expertTimeSlotCreated": "时间段已添加",
"expertTimeSlotDeleted": "时间段已移除",
"expertTimeSlotConfirmDelete": "移除此时间段？",
"expertScheduleTitle": "日程管理",
"expertScheduleSetClosed": "设为不可用",
"expertScheduleRemoveClosed": "取消不可用",
"expertScheduleClosedReason": "原因（可选）",
"expertScheduleClosedReasonHint": "例如：节假日",
"expertScheduleClosedAdded": "已标记为不可用",
"expertScheduleClosedRemoved": "可用状态已恢复",
"expertProfileEditTitle": "编辑资料",
"expertProfileEditName": "显示名称",
"expertProfileEditNameHint": "你的达人显示名称",
"expertProfileEditBio": "简介",
"expertProfileEditBioHint": "介绍一下自己...",
"expertProfileEditAvatar": "头像",
"expertProfileEditSubmit": "提交审核",
"expertProfileEditSubmitted": "已提交，等待管理员审核",
"expertProfileEditAlreadyPending": "你已有一条待审核的更新请求",
"expertViewTask": "查看任务",
"expertSearchSortLabel": "排序方式",
"expertSearchSortRating": "评分",
"expertSearchSortCompleted": "完成数最多",
"expertSearchSortNewest": "最新加入"
```

**Step 3: Add same keys to app_zh_Hant.arb**

Use Traditional Chinese equivalents (same as Simplified but with Traditional characters where they differ):
```json
"expertOfficialBadge": "官方",
"expertDashboardTitle": "達人中心",
"expertDashboardTabStats": "看板",
"expertDashboardTabServices": "我的服務",
"expertDashboardTabApplications": "申請管理",
"expertDashboardTabTimeSlots": "時間段",
"expertDashboardTabSchedule": "日程",
"expertDashboardEditProfile": "編輯資料",
"expertDashboardTotalServices": "服務總數",
"expertDashboardActiveServices": "上架中",
"expertDashboardTotalApplications": "申請總數",
"expertDashboardPendingApplications": "待處理",
"expertDashboardUpcomingSlots": "即將到來的時間段",
"expertServicesEmpty": "暫無服務",
"expertServicesEmptyMessage": "點擊 + 建立第一個服務",
"expertServiceCreate": "新建服務",
"expertServiceEdit": "編輯服務",
"expertServiceDelete": "刪除服務",
"expertServiceConfirmDelete": "刪除此服務？",
"expertServiceConfirmDeleteMessage": "此操作不可撤銷。",
"expertServiceName": "服務名稱",
"expertServiceNameHint": "例如：英語輔導",
"expertServiceNameEn": "服務名稱（英文）",
"expertServiceDescription": "描述",
"expertServiceDescriptionHint": "描述你提供的服務內容...",
"expertServiceDescriptionEn": "描述（英文）",
"expertServicePrice": "價格",
"expertServicePriceHint": "例如：30",
"expertServiceCurrency": "貨幣",
"expertServiceImages": "圖片（最多4張）",
"expertServiceSubmitted": "服務已提交審核",
"expertServiceDeleted": "服務已刪除",
"expertServiceUpdated": "服務已更新",
"expertServiceStatusActive": "上架中",
"expertServiceStatusPending": "待審核",
"expertServiceStatusRejected": "已拒絕",
"expertServiceStatusInactive": "已下架",
"expertTimeSlotsEmpty": "暫無時間段",
"expertTimeSlotsEmptyMessage": "選擇服務後新增時間段",
"expertTimeSlotCreate": "新增時間段",
"expertTimeSlotDate": "日期",
"expertTimeSlotStartTime": "開始時間",
"expertTimeSlotEndTime": "結束時間",
"expertTimeSlotPrice": "每人價格",
"expertTimeSlotMaxParticipants": "最大人數",
"expertTimeSlotCreated": "時間段已新增",
"expertTimeSlotDeleted": "時間段已移除",
"expertTimeSlotConfirmDelete": "移除此時間段？",
"expertScheduleTitle": "日程管理",
"expertScheduleSetClosed": "設為不可用",
"expertScheduleRemoveClosed": "取消不可用",
"expertScheduleClosedReason": "原因（可選）",
"expertScheduleClosedReasonHint": "例如：節假日",
"expertScheduleClosedAdded": "已標記為不可用",
"expertScheduleClosedRemoved": "可用狀態已恢復",
"expertProfileEditTitle": "編輯資料",
"expertProfileEditName": "顯示名稱",
"expertProfileEditNameHint": "你的達人顯示名稱",
"expertProfileEditBio": "簡介",
"expertProfileEditBioHint": "介紹一下自己...",
"expertProfileEditAvatar": "頭像",
"expertProfileEditSubmit": "提交審核",
"expertProfileEditSubmitted": "已提交，等待管理員審核",
"expertProfileEditAlreadyPending": "你已有一條待審核的更新請求",
"expertViewTask": "查看任務",
"expertSearchSortLabel": "排序方式",
"expertSearchSortRating": "評分",
"expertSearchSortCompleted": "完成數最多",
"expertSearchSortNewest": "最新加入"
```

**Step 4: Fix officialBadge in task_expert_list_view.dart**

Search for `expert.officialBadge ?? '官方'` and replace with:
```dart
expert.officialBadge ?? context.l10n.expertOfficialBadge
```

**Step 5: Regenerate l10n**

```bash
cd F:\python_work\LinkU\link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter gen-l10n
```
Expected: generates without errors.

**Step 6: Commit**
```bash
git add link2ur/lib/l10n/ link2ur/lib/features/task_expert/views/task_expert_list_view.dart
git commit -m "feat(expert): add l10n strings for expert dashboard features"
```

---

## Task 3: Add API endpoints + new repository methods

**Files:**
- Modify: `lib/core/constants/api_endpoints.dart`
- Modify: `lib/data/repositories/task_expert_repository.dart`

**Step 1: Add missing endpoints to api_endpoints.dart**

In the `// ==================== 任务达人 ====================` section, after the existing endpoints add:

```dart
// --- 达人服务 CRUD ---
static String myExpertServiceById(int serviceId) =>
    '/api/task-experts/me/services/$serviceId';

// --- 达人服务时间段管理 ---
static String myExpertServiceTimeSlotById(int serviceId, int slotId) =>
    '/api/task-experts/me/services/$serviceId/time-slots/$slotId';

// --- 达人休息日管理 ---
static String myExpertClosedDateById(int closedDateId) =>
    '/api/task-experts/me/closed-dates/$closedDateId';
static const String myExpertClosedDateByDate =
    '/api/task-experts/me/closed-dates/by-date';
```

**Step 2: Add repository methods to task_expert_repository.dart**

At the end of the class, before the closing `}`, add:

```dart
// ==================== 达人 Profile 更新请求 ====================

Future<Map<String, dynamic>> submitProfileUpdateRequest({
  String? name,
  String? bio,
  String? avatar,
}) async {
  final response = await _apiService.post(
    ApiEndpoints.myExpertProfileUpdateRequest,
    data: {
      if (name != null) 'new_expert_name': name,
      if (bio != null) 'new_bio': bio,
      if (avatar != null) 'new_avatar': avatar,
    },
  );
  if (!response.isSuccess) {
    throw Exception(response.message ?? '提交失败');
  }
  return response.data as Map<String, dynamic>? ?? {};
}

// ==================== 达人服务管理 ====================

Future<List<Map<String, dynamic>>> getMyServices() async {
  final response = await _apiService.get(ApiEndpoints.myExpertServices);
  if (!response.isSuccess) {
    throw Exception(response.message ?? '获取服务列表失败');
  }
  final data = response.data;
  if (data is List) return List<Map<String, dynamic>>.from(data);
  if (data is Map && data['services'] is List) {
    return List<Map<String, dynamic>>.from(data['services'] as List);
  }
  return [];
}

Future<Map<String, dynamic>> createService(Map<String, dynamic> data) async {
  final response = await _apiService.post(
    ApiEndpoints.myExpertServices,
    data: data,
  );
  if (!response.isSuccess) {
    throw Exception(response.message ?? '创建服务失败');
  }
  return response.data as Map<String, dynamic>? ?? {};
}

Future<Map<String, dynamic>> updateService(
    int serviceId, Map<String, dynamic> data) async {
  final response = await _apiService.put(
    ApiEndpoints.myExpertServiceById(serviceId),
    data: data,
  );
  if (!response.isSuccess) {
    throw Exception(response.message ?? '更新服务失败');
  }
  return response.data as Map<String, dynamic>? ?? {};
}

Future<void> deleteService(int serviceId) async {
  final response = await _apiService.delete(
    ApiEndpoints.myExpertServiceById(serviceId),
  );
  if (!response.isSuccess) {
    throw Exception(response.message ?? '删除服务失败');
  }
}

// ==================== 达人时间段管理 ====================

Future<List<Map<String, dynamic>>> getMyServiceTimeSlotsManage(
    int serviceId) async {
  final response =
      await _apiService.get(ApiEndpoints.myServiceTimeSlots(serviceId));
  if (!response.isSuccess) {
    throw Exception(response.message ?? '获取时间段失败');
  }
  final data = response.data;
  if (data is List) return List<Map<String, dynamic>>.from(data);
  if (data is Map && data['time_slots'] is List) {
    return List<Map<String, dynamic>>.from(data['time_slots'] as List);
  }
  return [];
}

Future<Map<String, dynamic>> createServiceTimeSlotManage(
    int serviceId, Map<String, dynamic> data) async {
  final response = await _apiService.post(
    ApiEndpoints.myServiceTimeSlots(serviceId),
    data: data,
  );
  if (!response.isSuccess) {
    throw Exception(response.message ?? '创建时间段失败');
  }
  return response.data as Map<String, dynamic>? ?? {};
}

Future<void> deleteServiceTimeSlotManage(
    int serviceId, int slotId) async {
  final response = await _apiService.delete(
    ApiEndpoints.myExpertServiceTimeSlotById(serviceId, slotId),
  );
  if (!response.isSuccess) {
    throw Exception(response.message ?? '删除时间段失败');
  }
}

// ==================== 达人休息日管理 ====================

Future<List<Map<String, dynamic>>> getMyClosedDates({
  String? startDate,
  String? endDate,
}) async {
  final response = await _apiService.get(
    ApiEndpoints.myExpertClosedDates,
    queryParameters: {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    },
  );
  if (!response.isSuccess) {
    throw Exception(response.message ?? '获取休息日失败');
  }
  final data = response.data;
  if (data is List) return List<Map<String, dynamic>>.from(data);
  if (data is Map && data['closed_dates'] is List) {
    return List<Map<String, dynamic>>.from(data['closed_dates'] as List);
  }
  return [];
}

Future<Map<String, dynamic>> createClosedDate({
  required String date,
  String? reason,
}) async {
  final response = await _apiService.post(
    ApiEndpoints.myExpertClosedDates,
    data: {
      'closed_date': date,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    },
  );
  if (!response.isSuccess) {
    throw Exception(response.message ?? '创建休息日失败');
  }
  return response.data as Map<String, dynamic>? ?? {};
}

Future<void> deleteClosedDate(int closedDateId) async {
  final response = await _apiService.delete(
    ApiEndpoints.myExpertClosedDateById(closedDateId),
  );
  if (!response.isSuccess) {
    throw Exception(response.message ?? '删除休息日失败');
  }
}

Future<void> deleteClosedDateByDate(String date) async {
  final response = await _apiService.delete(
    ApiEndpoints.myExpertClosedDateByDate,
    data: {'closed_date': date},
  );
  if (!response.isSuccess) {
    throw Exception(response.message ?? '删除休息日失败');
  }
}

// ==================== 达人看板统计 ====================

Future<Map<String, dynamic>> getMyExpertDashboardStatsData() async {
  final response =
      await _apiService.get(ApiEndpoints.myExpertDashboardStats);
  if (!response.isSuccess) {
    throw Exception(response.message ?? '获取统计失败');
  }
  return response.data as Map<String, dynamic>? ?? {};
}
```

**Step 3: Verify**
```bash
flutter analyze lib/core/constants/api_endpoints.dart lib/data/repositories/task_expert_repository.dart
```
Expected: no issues.

**Step 4: Commit**
```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/repositories/task_expert_repository.dart
git commit -m "feat(expert): add API endpoints and repository methods for dashboard features"
```

---

## Task 4: ExpertDashboardBloc

**Files:**
- Create: `lib/features/task_expert/bloc/expert_dashboard_bloc.dart`
- Create: `test/features/task_expert/expert_dashboard_bloc_test.dart`

**Step 1: Create the BLoC file**

```dart
// lib/features/task_expert/bloc/expert_dashboard_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/task_expert_repository.dart';

// ==================== Events ====================

abstract class ExpertDashboardEvent extends Equatable {
  const ExpertDashboardEvent();
  @override
  List<Object?> get props => [];
}

class ExpertDashboardLoadStats extends ExpertDashboardEvent {
  const ExpertDashboardLoadStats();
}

class ExpertDashboardLoadServices extends ExpertDashboardEvent {
  const ExpertDashboardLoadServices();
}

class ExpertDashboardCreateService extends ExpertDashboardEvent {
  const ExpertDashboardCreateService(this.data);
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [data];
}

class ExpertDashboardUpdateService extends ExpertDashboardEvent {
  const ExpertDashboardUpdateService(this.serviceId, this.data);
  final int serviceId;
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [serviceId, data];
}

class ExpertDashboardDeleteService extends ExpertDashboardEvent {
  const ExpertDashboardDeleteService(this.serviceId);
  final int serviceId;
  @override
  List<Object?> get props => [serviceId];
}

class ExpertDashboardLoadTimeSlots extends ExpertDashboardEvent {
  const ExpertDashboardLoadTimeSlots(this.serviceId);
  final int serviceId;
  @override
  List<Object?> get props => [serviceId];
}

class ExpertDashboardCreateTimeSlot extends ExpertDashboardEvent {
  const ExpertDashboardCreateTimeSlot(this.serviceId, this.data);
  final int serviceId;
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [serviceId, data];
}

class ExpertDashboardDeleteTimeSlot extends ExpertDashboardEvent {
  const ExpertDashboardDeleteTimeSlot(
      {required this.serviceId, required this.slotId});
  final int serviceId;
  final int slotId;
  @override
  List<Object?> get props => [serviceId, slotId];
}

class ExpertDashboardLoadClosedDates extends ExpertDashboardEvent {
  const ExpertDashboardLoadClosedDates();
}

class ExpertDashboardCreateClosedDate extends ExpertDashboardEvent {
  const ExpertDashboardCreateClosedDate(
      {required this.date, this.reason});
  final String date;
  final String? reason;
  @override
  List<Object?> get props => [date, reason];
}

class ExpertDashboardDeleteClosedDate extends ExpertDashboardEvent {
  const ExpertDashboardDeleteClosedDate(this.closedDateId);
  final int closedDateId;
  @override
  List<Object?> get props => [closedDateId];
}

class ExpertDashboardSubmitProfileUpdate extends ExpertDashboardEvent {
  const ExpertDashboardSubmitProfileUpdate(
      {this.name, this.bio, this.avatar});
  final String? name;
  final String? bio;
  final String? avatar;
  @override
  List<Object?> get props => [name, bio, avatar];
}

// ==================== State ====================

enum ExpertDashboardStatus { initial, loading, loaded, submitting, error }

class ExpertDashboardState extends Equatable {
  const ExpertDashboardState({
    this.status = ExpertDashboardStatus.initial,
    this.stats = const {},
    this.services = const [],
    this.timeSlots = const [],
    this.closedDates = const [],
    this.selectedServiceId,
    this.isLoadingTimeSlots = false,
    this.isLoadingClosedDates = false,
    this.errorMessage,
    this.actionMessage,
  });

  final ExpertDashboardStatus status;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> timeSlots;
  final List<Map<String, dynamic>> closedDates;
  final int? selectedServiceId;
  final bool isLoadingTimeSlots;
  final bool isLoadingClosedDates;
  final String? errorMessage;
  final String? actionMessage;

  bool get isLoading => status == ExpertDashboardStatus.loading;
  bool get isSubmitting => status == ExpertDashboardStatus.submitting;

  ExpertDashboardState copyWith({
    ExpertDashboardStatus? status,
    Map<String, dynamic>? stats,
    List<Map<String, dynamic>>? services,
    List<Map<String, dynamic>>? timeSlots,
    List<Map<String, dynamic>>? closedDates,
    int? selectedServiceId,
    bool? isLoadingTimeSlots,
    bool? isLoadingClosedDates,
    String? errorMessage,
    String? actionMessage,
    bool clearSelectedServiceId = false,
  }) {
    return ExpertDashboardState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      services: services ?? this.services,
      timeSlots: timeSlots ?? this.timeSlots,
      closedDates: closedDates ?? this.closedDates,
      selectedServiceId: clearSelectedServiceId
          ? null
          : (selectedServiceId ?? this.selectedServiceId),
      isLoadingTimeSlots: isLoadingTimeSlots ?? this.isLoadingTimeSlots,
      isLoadingClosedDates:
          isLoadingClosedDates ?? this.isLoadingClosedDates,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        stats,
        services,
        timeSlots,
        closedDates,
        selectedServiceId,
        isLoadingTimeSlots,
        isLoadingClosedDates,
        errorMessage,
        actionMessage,
      ];
}

// ==================== Bloc ====================

class ExpertDashboardBloc
    extends Bloc<ExpertDashboardEvent, ExpertDashboardState> {
  ExpertDashboardBloc({required TaskExpertRepository repository})
      : _repo = repository,
        super(const ExpertDashboardState()) {
    on<ExpertDashboardLoadStats>(_onLoadStats);
    on<ExpertDashboardLoadServices>(_onLoadServices);
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

  final TaskExpertRepository _repo;

  Future<void> _onLoadStats(
      ExpertDashboardLoadStats event, Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(status: ExpertDashboardStatus.loading));
    try {
      final stats = await _repo.getMyExpertDashboardStatsData();
      emit(state.copyWith(status: ExpertDashboardStatus.loaded, stats: stats));
    } catch (e) {
      emit(state.copyWith(
          status: ExpertDashboardStatus.error,
          errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadServices(ExpertDashboardLoadServices event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(status: ExpertDashboardStatus.loading));
    try {
      final services = await _repo.getMyServices();
      emit(state.copyWith(
          status: ExpertDashboardStatus.loaded, services: services));
    } catch (e) {
      emit(state.copyWith(
          status: ExpertDashboardStatus.error,
          errorMessage: e.toString()));
    }
  }

  Future<void> _onCreateService(ExpertDashboardCreateService event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repo.createService(event.data);
      final services = await _repo.getMyServices();
      emit(state.copyWith(
          status: ExpertDashboardStatus.loaded,
          services: services,
          actionMessage: 'service_created'));
    } catch (e) {
      emit(state.copyWith(
          status: ExpertDashboardStatus.error,
          errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateService(ExpertDashboardUpdateService event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repo.updateService(event.serviceId, event.data);
      final services = await _repo.getMyServices();
      emit(state.copyWith(
          status: ExpertDashboardStatus.loaded,
          services: services,
          actionMessage: 'service_updated'));
    } catch (e) {
      emit(state.copyWith(
          status: ExpertDashboardStatus.error,
          errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteService(ExpertDashboardDeleteService event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repo.deleteService(event.serviceId);
      final services = await _repo.getMyServices();
      emit(state.copyWith(
          status: ExpertDashboardStatus.loaded,
          services: services,
          actionMessage: 'service_deleted'));
    } catch (e) {
      emit(state.copyWith(
          status: ExpertDashboardStatus.error,
          errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadTimeSlots(ExpertDashboardLoadTimeSlots event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(
        isLoadingTimeSlots: true, selectedServiceId: event.serviceId));
    try {
      final slots =
          await _repo.getMyServiceTimeSlotsManage(event.serviceId);
      emit(state.copyWith(isLoadingTimeSlots: false, timeSlots: slots));
    } catch (e) {
      emit(state.copyWith(
          isLoadingTimeSlots: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onCreateTimeSlot(ExpertDashboardCreateTimeSlot event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repo.createServiceTimeSlotManage(event.serviceId, event.data);
      final slots =
          await _repo.getMyServiceTimeSlotsManage(event.serviceId);
      emit(state.copyWith(
          status: ExpertDashboardStatus.loaded,
          timeSlots: slots,
          actionMessage: 'time_slot_created'));
    } catch (e) {
      emit(state.copyWith(
          status: ExpertDashboardStatus.error,
          errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteTimeSlot(ExpertDashboardDeleteTimeSlot event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repo.deleteServiceTimeSlotManage(
          event.serviceId, event.slotId);
      final slots =
          await _repo.getMyServiceTimeSlotsManage(event.serviceId);
      emit(state.copyWith(
          status: ExpertDashboardStatus.loaded,
          timeSlots: slots,
          actionMessage: 'time_slot_deleted'));
    } catch (e) {
      emit(state.copyWith(
          status: ExpertDashboardStatus.error,
          errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadClosedDates(ExpertDashboardLoadClosedDates event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(isLoadingClosedDates: true));
    try {
      final dates = await _repo.getMyClosedDates();
      emit(state.copyWith(isLoadingClosedDates: false, closedDates: dates));
    } catch (e) {
      emit(state.copyWith(
          isLoadingClosedDates: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onCreateClosedDate(ExpertDashboardCreateClosedDate event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repo.createClosedDate(date: event.date, reason: event.reason);
      final dates = await _repo.getMyClosedDates();
      emit(state.copyWith(
          status: ExpertDashboardStatus.loaded,
          closedDates: dates,
          actionMessage: 'closed_date_created'));
    } catch (e) {
      emit(state.copyWith(
          status: ExpertDashboardStatus.error,
          errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteClosedDate(ExpertDashboardDeleteClosedDate event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repo.deleteClosedDate(event.closedDateId);
      final dates = await _repo.getMyClosedDates();
      emit(state.copyWith(
          status: ExpertDashboardStatus.loaded,
          closedDates: dates,
          actionMessage: 'closed_date_deleted'));
    } catch (e) {
      emit(state.copyWith(
          status: ExpertDashboardStatus.error,
          errorMessage: e.toString()));
    }
  }

  Future<void> _onSubmitProfileUpdate(ExpertDashboardSubmitProfileUpdate event,
      Emitter<ExpertDashboardState> emit) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repo.submitProfileUpdateRequest(
        name: event.name,
        bio: event.bio,
        avatar: event.avatar,
      );
      emit(state.copyWith(
          status: ExpertDashboardStatus.loaded,
          actionMessage: 'profile_update_submitted'));
    } catch (e) {
      emit(state.copyWith(
          status: ExpertDashboardStatus.error,
          errorMessage: e.toString()));
    }
  }
}
```

**Step 2: Write BLoC test**

```dart
// test/features/task_expert/expert_dashboard_bloc_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/data/repositories/task_expert_repository.dart';
import 'package:link2ur/features/task_expert/bloc/expert_dashboard_bloc.dart';

class MockTaskExpertRepository extends Mock implements TaskExpertRepository {}

void main() {
  late MockTaskExpertRepository repo;

  setUp(() {
    repo = MockTaskExpertRepository();
  });

  group('ExpertDashboardBloc', () {
    test('initial state is ExpertDashboardState()', () {
      final bloc = ExpertDashboardBloc(repository: repo);
      expect(bloc.state, const ExpertDashboardState());
      bloc.close();
    });

    blocTest<ExpertDashboardBloc, ExpertDashboardState>(
      'LoadStats emits loading then loaded with stats',
      build: () {
        when(() => repo.getMyExpertDashboardStatsData())
            .thenAnswer((_) async => {'total_services': 3});
        return ExpertDashboardBloc(repository: repo);
      },
      act: (bloc) => bloc.add(const ExpertDashboardLoadStats()),
      expect: () => [
        const ExpertDashboardState(status: ExpertDashboardStatus.loading),
        const ExpertDashboardState(
            status: ExpertDashboardStatus.loaded,
            stats: {'total_services': 3}),
      ],
    );

    blocTest<ExpertDashboardBloc, ExpertDashboardState>(
      'LoadStats emits error when repo throws',
      build: () {
        when(() => repo.getMyExpertDashboardStatsData())
            .thenThrow(Exception('network error'));
        return ExpertDashboardBloc(repository: repo);
      },
      act: (bloc) => bloc.add(const ExpertDashboardLoadStats()),
      expect: () => [
        const ExpertDashboardState(status: ExpertDashboardStatus.loading),
        isA<ExpertDashboardState>()
            .having((s) => s.status, 'status', ExpertDashboardStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );

    blocTest<ExpertDashboardBloc, ExpertDashboardState>(
      'DeleteService emits service_deleted actionMessage on success',
      build: () {
        when(() => repo.deleteService(1)).thenAnswer((_) async {});
        when(() => repo.getMyServices()).thenAnswer((_) async => []);
        return ExpertDashboardBloc(repository: repo);
      },
      act: (bloc) =>
          bloc.add(const ExpertDashboardDeleteService(1)),
      expect: () => [
        const ExpertDashboardState(status: ExpertDashboardStatus.submitting),
        const ExpertDashboardState(
            status: ExpertDashboardStatus.loaded,
            actionMessage: 'service_deleted'),
      ],
    );

    blocTest<ExpertDashboardBloc, ExpertDashboardState>(
      'SubmitProfileUpdate emits profile_update_submitted on success',
      build: () {
        when(() => repo.submitProfileUpdateRequest(
                name: any(named: 'name'),
                bio: any(named: 'bio'),
                avatar: any(named: 'avatar')))
            .thenAnswer((_) async => {});
        return ExpertDashboardBloc(repository: repo);
      },
      act: (bloc) => bloc.add(
          const ExpertDashboardSubmitProfileUpdate(name: 'Test', bio: 'Bio')),
      expect: () => [
        const ExpertDashboardState(status: ExpertDashboardStatus.submitting),
        const ExpertDashboardState(
            status: ExpertDashboardStatus.loaded,
            actionMessage: 'profile_update_submitted'),
      ],
    );
  });
}
```

**Step 3: Run tests**
```bash
cd F:\python_work\LinkU\link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter test test/features/task_expert/expert_dashboard_bloc_test.dart -v
```
Expected: all 5 tests PASS.

**Step 4: Commit**
```bash
git add link2ur/lib/features/task_expert/bloc/expert_dashboard_bloc.dart link2ur/test/features/task_expert/expert_dashboard_bloc_test.dart
git commit -m "feat(expert): add ExpertDashboardBloc with tests"
```

---

## Task 5: Routes + profile menu update

**Files:**
- Modify: `lib/core/router/routes/task_expert_routes.dart`
- Modify: `lib/core/router/app_routes.dart`
- Modify: `lib/features/profile/views/profile_menu_widgets.dart`

**Step 1: Add route constants to app_routes.dart**

Find the section with `expertApplicationsManagement` and add after it:
```dart
static const String expertDashboard = '/expert-dashboard';
static const String expertProfileEdit = '/expert-profile-edit';
```

Also add to `authRequiredRoutes` list:
```dart
AppRoutes.expertDashboard,
AppRoutes.expertProfileEdit,
```

**Step 2: Add routes to task_expert_routes.dart**

Add imports at the top:
```dart
import '../../../features/task_expert/views/expert_dashboard_view.dart';
import '../../../features/task_expert/views/expert_profile_edit_view.dart';
import '../../features/auth/bloc/auth_bloc.dart';
```

Add two new GoRoutes to the `taskExpertRoutes` list:
```dart
GoRoute(
  path: AppRoutes.expertDashboard,
  name: 'expertDashboard',
  redirect: (context, state) {
    final user = context.read<AuthBloc>().state.user;
    if (user == null || !user.isExpert) {
      return AppRoutes.taskExpertsIntro;
    }
    return null;
  },
  builder: (context, state) => const ExpertDashboardView(),
),
GoRoute(
  path: AppRoutes.expertProfileEdit,
  name: 'expertProfileEdit',
  redirect: (context, state) {
    final user = context.read<AuthBloc>().state.user;
    if (user == null || !user.isExpert) return AppRoutes.taskExpertsIntro;
    return null;
  },
  builder: (context, state) => const ExpertProfileEditView(),
),
```

Note: the `flutter_bloc` import for `context.read` is already available via GoRouter's context.

**Step 3: Update profile menu to point to new route**

In `lib/features/profile/views/profile_menu_widgets.dart`, change the onTap of the "达人管理" row:
```dart
// Change:
onTap: () => context.push('/expert-applications-management'),
// To:
onTap: () => context.push('/expert-dashboard'),
```

**Step 4: Verify**
```bash
flutter analyze lib/core/router/ lib/features/profile/views/profile_menu_widgets.dart
```

**Step 5: Commit**
```bash
git add link2ur/lib/core/router/ link2ur/lib/features/profile/views/profile_menu_widgets.dart
git commit -m "feat(expert): add expert dashboard routes and update profile menu entry"
```

---

## Task 6: Expert Dashboard shell view

**Files:**
- Create: `lib/features/task_expert/views/expert_dashboard_view.dart`

```dart
// lib/features/task_expert/views/expert_dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../bloc/expert_dashboard_bloc.dart';
import '../bloc/task_expert_bloc.dart';
import 'expert_dashboard_stats_tab.dart';
import 'expert_dashboard_services_tab.dart';
import 'expert_dashboard_applications_tab.dart';
import 'expert_dashboard_timeslots_tab.dart';
import 'expert_dashboard_schedule_tab.dart';

class ExpertDashboardView extends StatelessWidget {
  const ExpertDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ExpertDashboardBloc(
            repository: context.read<TaskExpertRepository>(),
          )..add(const ExpertDashboardLoadStats())
            ..add(const ExpertDashboardLoadServices()),
        ),
        BlocProvider(
          create: (context) => TaskExpertBloc(
            taskExpertRepository: context.read<TaskExpertRepository>(),
          )..add(const TaskExpertLoadExpertApplications()),
        ),
      ],
      child: const _ExpertDashboardContent(),
    );
  }
}

class _ExpertDashboardContent extends StatefulWidget {
  const _ExpertDashboardContent();

  @override
  State<_ExpertDashboardContent> createState() =>
      _ExpertDashboardContentState();
}

class _ExpertDashboardContentState extends State<_ExpertDashboardContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expertDashboardTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.expertDashboardEditProfile,
            onPressed: () => context.push('/expert-profile-edit'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l10n.expertDashboardTabStats),
            Tab(text: l10n.expertDashboardTabServices),
            Tab(text: l10n.expertDashboardTabApplications),
            Tab(text: l10n.expertDashboardTabTimeSlots),
            Tab(text: l10n.expertDashboardTabSchedule),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ExpertDashboardStatsTab(),
          ExpertDashboardServicesTab(),
          ExpertDashboardApplicationsTab(),
          ExpertDashboardTimeSlotsTab(),
          ExpertDashboardScheduleTab(),
        ],
      ),
    );
  }
}
```

**Verify:** `flutter analyze lib/features/task_expert/views/expert_dashboard_view.dart`

**Commit:**
```bash
git add link2ur/lib/features/task_expert/views/expert_dashboard_view.dart
git commit -m "feat(expert): add ExpertDashboardView shell with TabBar"
```

---

## Task 7: Stats tab

**Files:**
- Create: `lib/features/task_expert/views/expert_dashboard_stats_tab.dart`

```dart
// lib/features/task_expert/views/expert_dashboard_stats_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../bloc/expert_dashboard_bloc.dart';

class ExpertDashboardStatsTab extends StatelessWidget {
  const ExpertDashboardStatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpertDashboardBloc, ExpertDashboardState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status || prev.stats != curr.stats,
      builder: (context, state) {
        if (state.isLoading) return const LoadingView();
        if (state.status == ExpertDashboardStatus.error) {
          return ErrorStateView(
            message: state.errorMessage ?? '',
            onRetry: () => context
                .read<ExpertDashboardBloc>()
                .add(const ExpertDashboardLoadStats()),
          );
        }
        return _StatsGrid(stats: state.stats);
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final cards = [
      _StatCard(
        label: l10n.expertDashboardTotalServices,
        value: '${stats['total_services'] ?? 0}',
        sub: l10n.expertDashboardActiveServices,
        subValue: '${stats['active_services'] ?? 0}',
        color: AppColors.primary,
        icon: Icons.design_services_outlined,
      ),
      _StatCard(
        label: l10n.expertDashboardTotalApplications,
        value: '${stats['total_applications'] ?? 0}',
        sub: l10n.expertDashboardPendingApplications,
        subValue: '${stats['pending_applications'] ?? 0}',
        color: AppColors.warning,
        icon: Icons.inbox_outlined,
      ),
      _StatCard(
        label: l10n.expertDashboardUpcomingSlots,
        value: '${stats['upcoming_time_slots'] ?? 0}',
        color: AppColors.success,
        icon: Icons.calendar_today_outlined,
        fullWidth: true,
      ),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        context
            .read<ExpertDashboardBloc>()
            .add(const ExpertDashboardLoadStats());
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.3,
            children: cards.where((c) => !c.fullWidth).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...cards.where((c) => c.fullWidth),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.sub,
    this.subValue,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String? sub;
  final String? subValue;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight)),
              ),
            ],
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color)),
          if (sub != null && subValue != null)
            Text('$sub: $subValue',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight)),
        ],
      ),
    );
  }
}
```

**Commit:**
```bash
git add link2ur/lib/features/task_expert/views/expert_dashboard_stats_tab.dart
git commit -m "feat(expert): add dashboard stats tab"
```

---

## Task 8: Services tab

**Files:**
- Create: `lib/features/task_expert/views/expert_dashboard_services_tab.dart`

```dart
// lib/features/task_expert/views/expert_dashboard_services_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/expert_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../bloc/expert_dashboard_bloc.dart';

class ExpertDashboardServicesTab extends StatelessWidget {
  const ExpertDashboardServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpertDashboardBloc, ExpertDashboardState>(
      listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        final msg = state.actionMessage;
        if (msg == null) return;
        final l10n = context.l10n;
        final text = switch (msg) {
          'service_created' => l10n.expertServiceSubmitted,
          'service_updated' => l10n.expertServiceUpdated,
          'service_deleted' => l10n.expertServiceDeleted,
          _ => msg,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      },
      buildWhen: (prev, curr) =>
          prev.status != curr.status || prev.services != curr.services,
      builder: (context, state) {
        if (state.isLoading) return const LoadingView();
        if (state.status == ExpertDashboardStatus.error) {
          return ErrorStateView(
            message: state.errorMessage ?? '',
            onRetry: () => context
                .read<ExpertDashboardBloc>()
                .add(const ExpertDashboardLoadServices()),
          );
        }
        return _ServicesList(services: state.services);
      },
    );
  }
}

class _ServicesList extends StatelessWidget {
  const _ServicesList({required this.services});
  final List<Map<String, dynamic>> services;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: services.isEmpty
          ? EmptyStateView(
              title: l10n.expertServicesEmpty,
              message: l10n.expertServicesEmptyMessage,
            )
          : RefreshIndicator(
              onRefresh: () async => context
                  .read<ExpertDashboardBloc>()
                  .add(const ExpertDashboardLoadServices()),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: services.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final service = services[index];
                  return _ServiceCard(
                    service: service,
                    onEdit: () => _showServiceSheet(context, service: service),
                    onDelete: () => _confirmDelete(context, service),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showServiceSheet(BuildContext context,
      {Map<String, dynamic>? service}) {
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<ExpertDashboardBloc>(),
        child: _ServiceFormSheet(existing: service),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Map<String, dynamic> service) async {
    final l10n = context.l10n;
    final confirmed = await AdaptiveDialogs.showConfirmDialog<bool>(
      context: context,
      title: l10n.expertServiceConfirmDelete,
      content: l10n.expertServiceConfirmDeleteMessage,
      confirmText: l10n.expertServiceDelete,
      cancelText: l10n.commonCancel,
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      context.read<ExpertDashboardBloc>().add(
            ExpertDashboardDeleteService(service['id'] as int),
          );
    }
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final images = (service['images'] as List?)?.cast<String>() ?? [];
    final status = service['status'] as String? ?? 'pending';
    final currency = service['currency'] as String? ?? 'GBP';
    final price = service['base_price'];

    final statusColor = switch (status) {
      'active' => AppColors.success,
      'rejected' => AppColors.error,
      'inactive' => AppColors.textSecondaryLight,
      _ => AppColors.warning,
    };
    final statusLabel = switch (status) {
      'active' => l10n.expertServiceStatusActive,
      'rejected' => l10n.expertServiceStatusRejected,
      'inactive' => l10n.expertServiceStatusInactive,
      _ => l10n.expertServiceStatusPending,
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
      ),
      child: Row(
        children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12)),
              child: AsyncImageView(
                imageUrl: images.first,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
              child: const Icon(Icons.design_services_outlined,
                  color: AppColors.primary),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['service_name'] as String? ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currency ${price ?? '--'}',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            color: statusColor, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20)),
              IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.error)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceFormSheet extends StatefulWidget {
  const _ServiceFormSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _nameController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descController = TextEditingController();
  final _descEnController = TextEditingController();
  final _priceController = TextEditingController();
  String _currency = 'GBP';
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    if (s != null) {
      _nameController.text = s['service_name'] as String? ?? '';
      _nameEnController.text = s['service_name_en'] as String? ?? '';
      _descController.text = s['description'] as String? ?? '';
      _descEnController.text = s['description_en'] as String? ?? '';
      _priceController.text = '${s['base_price'] ?? ''}';
      _currency = s['currency'] as String? ?? 'GBP';
      _images = ((s['images'] as List?)?.cast<String>()) ?? [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _descController.dispose();
    _descEnController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final price = double.tryParse(_priceController.text.trim());
    if (_nameController.text.trim().isEmpty || price == null) return;

    final data = {
      'service_name': _nameController.text.trim(),
      if (_nameEnController.text.trim().isNotEmpty)
        'service_name_en': _nameEnController.text.trim(),
      'description': _descController.text.trim(),
      if (_descEnController.text.trim().isNotEmpty)
        'description_en': _descEnController.text.trim(),
      'base_price': price,
      'currency': _currency,
      if (_images.isNotEmpty) 'images': _images,
    };

    if (widget.existing != null) {
      context.read<ExpertDashboardBloc>().add(
            ExpertDashboardUpdateService(
                widget.existing!['id'] as int, data),
          );
    } else {
      context.read<ExpertDashboardBloc>().add(
            ExpertDashboardCreateService(data),
          );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEdit = widget.existing != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? l10n.expertServiceEdit : l10n.expertServiceCreate,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.expertServiceName,
                  hintText: l10n.expertServiceNameHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameEnController,
                decoration: InputDecoration(
                  labelText: l10n.expertServiceNameEn,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.expertServiceDescription,
                  hintText: l10n.expertServiceDescriptionHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descEnController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.expertServiceDescriptionEn,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.expertServicePrice,
                        hintText: l10n.expertServicePriceHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _currency,
                    items: kExpertServiceCurrencies
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _currency = v ?? 'GBP'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: Text(isEdit
                    ? l10n.expertServiceEdit
                    : l10n.expertServiceCreate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Commit:**
```bash
git add link2ur/lib/features/task_expert/views/expert_dashboard_services_tab.dart
git commit -m "feat(expert): add services management tab"
```

---

## Task 9: Applications tab (migrate existing)

**Files:**
- Create: `lib/features/task_expert/views/expert_dashboard_applications_tab.dart`

This wraps the existing `ExpertApplicationsManagementView` body logic. The simplest approach is to embed it directly — the `TaskExpertBloc` is already provided by the dashboard shell.

```dart
// lib/features/task_expert/views/expert_dashboard_applications_tab.dart

// Re-export the existing view's content as a tab.
// The TaskExpertBloc is provided by ExpertDashboardView's MultiBlocProvider.

export 'expert_applications_management_view.dart'
    show ExpertApplicationsManagementView;
```

Wait — actually since the existing view creates its own `BlocProvider`, wrapping it in a tab would create a *second* BLoC. Instead, create a thin wrapper that renders the body of the existing view without the Scaffold/AppBar:

```dart
// lib/features/task_expert/views/expert_dashboard_applications_tab.dart

import 'package:flutter/material.dart';
import 'expert_applications_management_view.dart';

/// Wraps ExpertApplicationsManagementView for use inside TabBarView.
/// Removes the top AppBar since the dashboard already has one.
class ExpertDashboardApplicationsTab extends StatelessWidget {
  const ExpertDashboardApplicationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // The TaskExpertBloc is provided by ExpertDashboardView.
    // ExpertApplicationsManagementView creates its own BlocProvider internally,
    // but we need to reuse the one from the dashboard.
    // Use the inner content widget directly.
    return const _ExpertApplicationsManagementContent();
  }
}
```

Note: `_ExpertApplicationsManagementContent` is a private class in `expert_applications_management_view.dart`. To avoid refactoring the private widget, the simplest solution is to just render the full `ExpertApplicationsManagementView` which creates its own BLoC (separate instance is fine for the applications tab):

```dart
// lib/features/task_expert/views/expert_dashboard_applications_tab.dart

import 'package:flutter/material.dart';
import '../../../core/utils/l10n_extension.dart';
import 'expert_applications_management_view.dart';

class ExpertDashboardApplicationsTab extends StatelessWidget {
  const ExpertDashboardApplicationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Renders the full view; its internal BlocProvider creates a fresh
    // TaskExpertBloc scoped to the applications tab — this is fine since
    // applications management is independent of the stats/services state.
    return const ExpertApplicationsManagementView(showAppBar: false);
  }
}
```

To support `showAppBar: false`, modify `expert_applications_management_view.dart`:

In `ExpertApplicationsManagementView`, add a `showAppBar` parameter:
```dart
class ExpertApplicationsManagementView extends StatelessWidget {
  const ExpertApplicationsManagementView({super.key, this.showAppBar = true});
  final bool showAppBar;
  // ...
}
```

In `_ExpertApplicationsManagementContent.build()`, find the `Scaffold` and make AppBar conditional:
```dart
appBar: widget.showAppBar  // pass through to inner content
    ? AppBar(title: Text(l10n.expertApplicationsTitle))
    : null,
```

To pass `showAppBar` to the content widget, change `_ExpertApplicationsManagementContent` to accept it:
```dart
class _ExpertApplicationsManagementContent extends StatelessWidget {
  const _ExpertApplicationsManagementContent({required this.showAppBar});
  final bool showAppBar;
  // ...
  appBar: showAppBar ? AppBar(...) : null,
}
```

And in `ExpertApplicationsManagementView.build()`:
```dart
child: _ExpertApplicationsManagementContent(showAppBar: showAppBar),
```

**Commit:**
```bash
git add link2ur/lib/features/task_expert/views/expert_applications_management_view.dart link2ur/lib/features/task_expert/views/expert_dashboard_applications_tab.dart
git commit -m "feat(expert): add applications tab to dashboard"
```

---

## Task 10: Time slots tab

**Files:**
- Create: `lib/features/task_expert/views/expert_dashboard_timeslots_tab.dart`

```dart
// lib/features/task_expert/views/expert_dashboard_timeslots_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../bloc/expert_dashboard_bloc.dart';

class ExpertDashboardTimeSlotsTab extends StatelessWidget {
  const ExpertDashboardTimeSlotsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpertDashboardBloc, ExpertDashboardState>(
      listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        final msg = state.actionMessage;
        if (msg == null) return;
        final l10n = context.l10n;
        final text = switch (msg) {
          'time_slot_created' => l10n.expertTimeSlotCreated,
          'time_slot_deleted' => l10n.expertTimeSlotDeleted,
          _ => msg,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      },
      builder: (context, state) {
        return _TimeSlotsBody(state: state);
      },
    );
  }
}

class _TimeSlotsBody extends StatelessWidget {
  const _TimeSlotsBody({required this.state});
  final ExpertDashboardState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final services = state.services;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Service selector
          if (services.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: DropdownButtonFormField<int>(
                value: state.selectedServiceId,
                decoration: InputDecoration(
                  labelText: l10n.expertDashboardTabServices,
                  border: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium),
                ),
                items: services
                    .map((s) => DropdownMenuItem<int>(
                          value: s['id'] as int?,
                          child: Text(
                            s['service_name'] as String? ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id != null) {
                    context
                        .read<ExpertDashboardBloc>()
                        .add(ExpertDashboardLoadTimeSlots(id));
                  }
                },
              ),
            ),
          Expanded(
            child: state.selectedServiceId == null
                ? EmptyStateView(
                    title: l10n.expertTimeSlotsEmpty,
                    message: l10n.expertTimeSlotsEmptyMessage,
                  )
                : state.isLoadingTimeSlots
                    ? const LoadingView()
                    : state.timeSlots.isEmpty
                        ? EmptyStateView(
                            title: l10n.expertTimeSlotsEmpty,
                            message: l10n.expertTimeSlotsEmptyMessage,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md),
                            itemCount: state.timeSlots.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final slot = state.timeSlots[i];
                              return _SlotTile(
                                slot: slot,
                                serviceId: state.selectedServiceId!,
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: state.selectedServiceId != null
          ? FloatingActionButton(
              onPressed: () => _showAddSlotSheet(
                  context, state.selectedServiceId!),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddSlotSheet(BuildContext context, int serviceId) {
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<ExpertDashboardBloc>(),
        child: _AddSlotSheet(serviceId: serviceId),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.serviceId});
  final Map<String, dynamic> slot;
  final int serviceId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(slot['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await AdaptiveDialogs.showConfirmDialog<bool>(
          context: context,
          title: l10n.expertTimeSlotConfirmDelete,
          content: '',
          confirmText: l10n.commonDelete,
          cancelText: l10n.commonCancel,
          isDestructive: true,
        );
      },
      onDismissed: (_) {
        context.read<ExpertDashboardBloc>().add(
              ExpertDashboardDeleteTimeSlot(
                serviceId: serviceId,
                slotId: slot['id'] as int,
              ),
            );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot['slot_date'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${slot['start_time']} – ${slot['end_time']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '£${slot['price_per_participant'] ?? '--'}',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'Max: ${slot['max_participants'] ?? '--'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSlotSheet extends StatefulWidget {
  const _AddSlotSheet({required this.serviceId});
  final int serviceId;

  @override
  State<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends State<_AddSlotSheet> {
  DateTime? _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _priceController = TextEditingController();
  final _maxController = TextEditingController(text: '1');

  @override
  void dispose() {
    _priceController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _submit() {
    if (_date == null || _startTime == null || _endTime == null) return;
    final price = double.tryParse(_priceController.text.trim());
    final max = int.tryParse(_maxController.text.trim()) ?? 1;
    if (price == null) return;

    context.read<ExpertDashboardBloc>().add(
          ExpertDashboardCreateTimeSlot(widget.serviceId, {
            'slot_date':
                '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}',
            'start_time': _fmt(_startTime!),
            'end_time': _fmt(_endTime!),
            'price_per_participant': price,
            'max_participants': max,
          }),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.expertTimeSlotCreate,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.expertTimeSlotDate),
              trailing: Text(_date == null
                  ? '--'
                  : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate:
                      DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            // Start time
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.expertTimeSlotStartTime),
              trailing: Text(
                  _startTime == null ? '--' : _fmt(_startTime!)),
              onTap: () async {
                final t = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 9, minute: 0));
                if (t != null) setState(() => _startTime = t);
              },
            ),
            // End time
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.expertTimeSlotEndTime),
              trailing:
                  Text(_endTime == null ? '--' : _fmt(_endTime!)),
              onTap: () async {
                final t = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 10, minute: 0));
                if (t != null) setState(() => _endTime = t);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                        labelText: l10n.expertTimeSlotPrice),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: l10n.expertTimeSlotMaxParticipants),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _submit,
                child: Text(l10n.expertTimeSlotCreate)),
          ],
        ),
      ),
    );
  }
}
```

**Commit:**
```bash
git add link2ur/lib/features/task_expert/views/expert_dashboard_timeslots_tab.dart
git commit -m "feat(expert): add time slots management tab"
```

---

## Task 11: Schedule tab (closed dates)

**Files:**
- Create: `lib/features/task_expert/views/expert_dashboard_schedule_tab.dart`

```dart
// lib/features/task_expert/views/expert_dashboard_schedule_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../bloc/expert_dashboard_bloc.dart';

class ExpertDashboardScheduleTab extends StatefulWidget {
  const ExpertDashboardScheduleTab({super.key});

  @override
  State<ExpertDashboardScheduleTab> createState() =>
      _ExpertDashboardScheduleTabState();
}

class _ExpertDashboardScheduleTabState
    extends State<ExpertDashboardScheduleTab> {
  DateTime _focusedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<ExpertDashboardBloc>()
          .add(const ExpertDashboardLoadClosedDates());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpertDashboardBloc, ExpertDashboardState>(
      listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        final msg = state.actionMessage;
        if (msg == null) return;
        final l10n = context.l10n;
        final text = switch (msg) {
          'closed_date_created' => l10n.expertScheduleClosedAdded,
          'closed_date_deleted' => l10n.expertScheduleClosedRemoved,
          _ => msg,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      },
      builder: (context, state) {
        if (state.isLoadingClosedDates) return const LoadingView();
        return _ScheduleBody(
          closedDates: state.closedDates,
          focusedMonth: _focusedMonth,
          onMonthChanged: (m) => setState(() => _focusedMonth = m),
        );
      },
    );
  }
}

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({
    required this.closedDates,
    required this.focusedMonth,
    required this.onMonthChanged,
  });

  final List<Map<String, dynamic>> closedDates;
  final DateTime focusedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  Set<String> get _closedSet =>
      closedDates.map((d) => d['closed_date'] as String).toSet();

  bool _isClosed(DateTime day) {
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _closedSet.contains(key);
  }

  String _dateKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final daysInMonth =
        DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final firstDay =
        DateTime(focusedMonth.year, focusedMonth.month, 1);
    final startWeekday = firstDay.weekday % 7; // 0=Sun

    return Column(
      children: [
        // Month navigation
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onMonthChanged(DateTime(
                    focusedMonth.year, focusedMonth.month - 1)),
              ),
              Text(
                '${focusedMonth.year} / ${focusedMonth.month.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onMonthChanged(DateTime(
                    focusedMonth.year, focusedMonth.month + 1)),
              ),
            ],
          ),
        ),
        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox();
              final day = index - startWeekday + 1;
              final date =
                  DateTime(focusedMonth.year, focusedMonth.month, day);
              final closed = _isClosed(date);
              final isPast = date.isBefore(
                  DateTime.now().subtract(const Duration(days: 1)));

              return GestureDetector(
                onTap: isPast
                    ? null
                    : () => _onDayTap(context, date, closed),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: closed
                        ? AppColors.error.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: closed
                        ? Border.all(
                            color: AppColors.error.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isPast
                              ? AppColors.textTertiaryLight
                              : closed
                                  ? AppColors.error
                                  : null,
                        ),
                      ),
                      if (closed)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 24),
        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4)),
                ),
              ),
              const SizedBox(width: 6),
              Text(l10n.expertScheduleSetClosed,
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  void _onDayTap(BuildContext context, DateTime date, bool isClosed) {
    final l10n = context.l10n;
    final dateKey = _dateKey(date);

    if (isClosed) {
      // Find the closed date entry to get its ID
      final entry = closedDates.firstWhere(
        (d) => d['closed_date'] == dateKey,
        orElse: () => {},
      );
      final id = entry['id'] as int?;
      if (id != null) {
        context
            .read<ExpertDashboardBloc>()
            .add(ExpertDashboardDeleteClosedDate(id));
      }
    } else {
      // Show dialog to add reason
      _showAddClosedDateDialog(context, dateKey);
    }
  }

  void _showAddClosedDateDialog(BuildContext context, String dateKey) {
    final l10n = context.l10n;
    final reasonController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.expertScheduleSetClosed),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: l10n.expertScheduleClosedReason,
            hintText: l10n.expertScheduleClosedReasonHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ExpertDashboardBloc>().add(
                    ExpertDashboardCreateClosedDate(
                      date: dateKey,
                      reason: reasonController.text.trim().isEmpty
                          ? null
                          : reasonController.text.trim(),
                    ),
                  );
            },
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }
}
```

**Commit:**
```bash
git add link2ur/lib/features/task_expert/views/expert_dashboard_schedule_tab.dart
git commit -m "feat(expert): add schedule/closed dates management tab"
```

---

## Task 12: Expert profile edit page

**Files:**
- Create: `lib/features/task_expert/views/expert_profile_edit_view.dart`

```dart
// lib/features/task_expert/views/expert_profile_edit_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/expert_dashboard_bloc.dart';

class ExpertProfileEditView extends StatelessWidget {
  const ExpertProfileEditView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExpertDashboardBloc(
        repository: context.read<TaskExpertRepository>(),
      ),
      child: const _ExpertProfileEditContent(),
    );
  }
}

class _ExpertProfileEditContent extends StatefulWidget {
  const _ExpertProfileEditContent();

  @override
  State<_ExpertProfileEditContent> createState() =>
      _ExpertProfileEditContentState();
}

class _ExpertProfileEditContentState
    extends State<_ExpertProfileEditContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _bioController = TextEditingController();
    _avatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<ExpertDashboardBloc, ExpertDashboardState>(
      listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        if (state.actionMessage == 'profile_update_submitted') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.expertProfileEditSubmitted)),
          );
          Navigator.of(context).pop();
        } else if (state.status == ExpertDashboardStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? '')),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.expertProfileEditTitle)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar
                Center(
                  child: GestureDetector(
                    onTap: () {/* image picker — TODO */},
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: _avatarUrl != null
                              ? ClipOval(
                                  child: AsyncImageView(
                                    imageUrl: _avatarUrl!,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.person,
                                  size: 48, color: AppColors.primary),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Name
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.expertProfileEditName,
                    hintText: l10n.expertProfileEditNameHint,
                  ),
                ),
                const SizedBox(height: 16),
                // Bio
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: l10n.expertProfileEditBio,
                    hintText: l10n.expertProfileEditBioHint,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.isSubmitting ? null : _submit,
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.expertProfileEditSubmit),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submit() {
    context.read<ExpertDashboardBloc>().add(
          ExpertDashboardSubmitProfileUpdate(
            name: _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim(),
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            avatar: _avatarUrl,
          ),
        );
  }
}
```

**Commit:**
```bash
git add link2ur/lib/features/task_expert/views/expert_profile_edit_view.dart
git commit -m "feat(expert): add expert profile edit page"
```

---

## Task 13: "查看任务" button in MyServiceApplicationsView

**Files:**
- Modify: `lib/features/task_expert/views/my_service_applications_view.dart`

**Step 1: Find where application cards are rendered**

Search for `status` rendering in the file. Find the widget/method that displays each application item — look for where `application['status']` is read.

**Step 2: Add "查看任务" button**

After the status display, add:
```dart
// Inside the application card widget, after status text:
if (application['status'] == 'approved' &&
    application['task_id'] != null) ...[
  const SizedBox(height: 8),
  TextButton.icon(
    onPressed: () {
      final taskId = application['task_id'];
      context.goToTaskDetail(taskId is int
          ? taskId.toString()
          : taskId as String);
    },
    icon: const Icon(Icons.assignment_outlined, size: 16),
    label: Text(context.l10n.expertViewTask),
    style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
  ),
],
```

**Step 3: Verify**
```bash
flutter analyze lib/features/task_expert/views/my_service_applications_view.dart
```

**Step 4: Commit**
```bash
git add link2ur/lib/features/task_expert/views/my_service_applications_view.dart
git commit -m "feat(expert): add view task button for approved service applications"
```

---

## Task 14: Search sort options

**Files:**
- Modify: `lib/features/task_expert/views/task_expert_search_view.dart`
- Modify: `lib/features/task_expert/bloc/task_expert_bloc.dart` (add sort to FilterChanged event)
- Modify: `lib/data/repositories/task_expert_repository.dart` (pass sort param)

**Step 1: Add sort to TaskExpertFilterChanged event**

In `task_expert_bloc.dart`, find `TaskExpertFilterChanged` event class and add sort field:
```dart
class TaskExpertFilterChanged extends TaskExpertEvent {
  const TaskExpertFilterChanged({
    this.category,
    this.city,
    this.sort,          // NEW
  });
  final String? category;
  final String? city;
  final String? sort;  // NEW: 'rating_desc' | 'completed_desc' | 'newest'

  @override
  List<Object?> get props => [category, city, sort];
}
```

Add `selectedSort` to `TaskExpertState`:
```dart
// In TaskExpertState, add field:
final String selectedSort;   // default: ''

// In constructor default:
this.selectedSort = '',

// In copyWith:
String? selectedSort,
// In return:
selectedSort: selectedSort ?? this.selectedSort,

// In props list:
selectedSort,
```

**Step 2: Pass sort to repository**

In `task_expert_repository.dart`, `getExperts()` method, add sort to params:
```dart
if (sort != null && sort.isNotEmpty) 'sort': sort,
```
And add `String? sort` parameter to `getExperts()`.

In `task_expert_bloc.dart`, in `_onFilterChanged` handler (or wherever `TaskExpertFilterChanged` is handled), pass `sort` to repository call.

**Step 3: Add sort dropdown to search view**

In `task_expert_search_view.dart`, above or below the existing filter row, add:
```dart
// Sort dropdown
DropdownButton<String>(
  value: state.selectedSort.isEmpty ? null : state.selectedSort,
  hint: Text(context.l10n.expertSearchSortLabel),
  items: [
    DropdownMenuItem(
      value: 'rating_desc',
      child: Text(context.l10n.expertSearchSortRating),
    ),
    DropdownMenuItem(
      value: 'completed_desc',
      child: Text(context.l10n.expertSearchSortCompleted),
    ),
    DropdownMenuItem(
      value: 'newest',
      child: Text(context.l10n.expertSearchSortNewest),
    ),
  ],
  onChanged: (sort) {
    context.read<TaskExpertBloc>().add(
          TaskExpertFilterChanged(
            category: state.selectedCategory,
            city: state.selectedCity,
            sort: sort,
          ),
        );
  },
),
```

**Step 4: Verify + Commit**
```bash
flutter analyze lib/features/task_expert/
git add link2ur/lib/features/task_expert/ link2ur/lib/data/repositories/task_expert_repository.dart
git commit -m "feat(expert): add sort options to expert search"
```

---

## Task 15: Final analyze + push

**Step 1: Full analyze**
```bash
cd F:\python_work\LinkU\link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze
```
Fix any remaining issues.

**Step 2: Run all tests**
```bash
flutter test
```
Expected: all pass.

**Step 3: Push**
```bash
cd F:\python_work\LinkU
git push origin main
```

---

## Execution order summary

| # | Task | Files touched |
|---|------|---------------|
| 1 | Category constants | expert_constants.dart, list_view, search_view |
| 2 | l10n + officialBadge fix | 3 ARB files, list_view |
| 3 | API endpoints + repo methods | api_endpoints.dart, task_expert_repository.dart |
| 4 | ExpertDashboardBloc + tests | expert_dashboard_bloc.dart, bloc_test |
| 5 | Routes + profile menu | task_expert_routes.dart, app_routes.dart, profile_menu_widgets.dart |
| 6 | Dashboard shell | expert_dashboard_view.dart |
| 7 | Stats tab | expert_dashboard_stats_tab.dart |
| 8 | Services tab | expert_dashboard_services_tab.dart |
| 9 | Applications tab | expert_applications_management_view.dart (showAppBar param), expert_dashboard_applications_tab.dart |
| 10 | Time slots tab | expert_dashboard_timeslots_tab.dart |
| 11 | Schedule tab | expert_dashboard_schedule_tab.dart |
| 12 | Profile edit page | expert_profile_edit_view.dart |
| 13 | "查看任务" button | my_service_applications_view.dart |
| 14 | Search sort | task_expert_search_view.dart, bloc, repo |
| 15 | Final verify + push | — |
