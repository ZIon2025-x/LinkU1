# Task Module Deep Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all bugs, inconsistencies, and quality issues found in the task module (BLoC, Views, Repository, Models)

**Architecture:** Incremental fixes organized by severity — critical bugs first, then error handling standardization, state management optimization, cache fixes, type safety, and finally tests. Each task is independent and can be committed separately.

**Tech Stack:** Flutter/Dart, BLoC, Equatable, Dio, GoRouter

---

## Phase 1: Critical Bugs (会导致崩溃或数据丢失)

### Task 1: CreateTaskBloc — errorMessage 未在成功时清除

**问题:** 提交成功后 `errorMessage` 仍保留上次的错误信息，UI 可能误显示旧错误。

**Files:**
- Fix: `lib/features/tasks/bloc/create_task_bloc.dart`
- Test: `test/features/tasks/bloc/create_task_bloc_test.dart`

**Step 1: Write the failing test**

```dart
// test/features/tasks/bloc/create_task_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:link2ur/features/tasks/bloc/create_task_bloc.dart';
import 'package:link2ur/data/repositories/task_repository.dart';
import 'package:link2ur/data/models/task.dart';

class MockTaskRepository extends Mock implements TaskRepository {}
class FakeCreateTaskRequest extends Fake implements CreateTaskRequest {}

void main() {
  late MockTaskRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(FakeCreateTaskRequest());
  });

  setUp(() {
    mockRepo = MockTaskRepository();
  });

  group('CreateTaskBloc', () {
    blocTest<CreateTaskBloc, CreateTaskState>(
      'clears errorMessage on successful submission after previous error',
      build: () {
        // First call fails, second succeeds
        var callCount = 0;
        when(() => mockRepo.createTask(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) throw Exception('network error');
          return Task.fromJson({'id': 1, 'title': 'Test'});
        });
        return CreateTaskBloc(taskRepository: mockRepo);
      },
      act: (bloc) async {
        final req = FakeCreateTaskRequest();
        bloc.add(CreateTaskSubmitted(req));
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(CreateTaskReset());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(CreateTaskSubmitted(req));
      },
      wait: const Duration(milliseconds: 300),
      expect: () => [
        // First attempt: submitting → error
        isA<CreateTaskState>().having((s) => s.status, 'status', CreateTaskStatus.submitting),
        isA<CreateTaskState>().having((s) => s.errorMessage, 'errorMessage', 'create_task_failed'),
        // Reset
        const CreateTaskState(),
        // Second attempt: submitting → success with null errorMessage
        isA<CreateTaskState>().having((s) => s.status, 'status', CreateTaskStatus.submitting),
        isA<CreateTaskState>()
            .having((s) => s.status, 'status', CreateTaskStatus.success)
            .having((s) => s.errorMessage, 'errorMessage', isNull),
      ],
    );
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd link2ur && flutter test test/features/tasks/bloc/create_task_bloc_test.dart -v
```
Expected: FAIL — success state still has stale errorMessage

**Step 3: Fix — clear errorMessage on success**

In `lib/features/tasks/bloc/create_task_bloc.dart`, find the success emit in `_onSubmitted`:

```dart
// BEFORE (around line 86-89):
emit(state.copyWith(
  status: CreateTaskStatus.success,
  createdTask: task,
));

// AFTER:
emit(state.copyWith(
  status: CreateTaskStatus.success,
  createdTask: task,
  errorMessage: null,
));
```

**Step 4: Run test to verify it passes**

```bash
cd link2ur && flutter test test/features/tasks/bloc/create_task_bloc_test.dart -v
```
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/tasks/bloc/create_task_bloc.dart test/features/tasks/bloc/create_task_bloc_test.dart
git commit -m "fix(tasks): clear errorMessage on successful task creation"
```

---

### Task 2: TaskDetailBloc._onAcceptApplicant — data! 空指针崩溃

**问题:** `_onAcceptApplicant` 中 `data!['customer_id']` 如果 `data` 为 null 会崩溃（line ~647）。虽然外层有 `data['client_secret']` 检查，但如果 API 返回格式异常（如 `{'client_secret': 'xx'}` 无其他字段），仍可能在后续字段出问题。

**Files:**
- Fix: `lib/features/tasks/bloc/task_detail_bloc.dart`

**Step 1: Review current code pattern**

当前代码大致为：
```dart
final data = await _taskRepository.acceptApplication(taskId, event.applicationId);
final needPayment = data != null &&
    (data['client_secret'] as String?)?.isNotEmpty == true;

if (needPayment) {
  final paymentData = AcceptPaymentData(
    taskId: _taskId!,
    clientSecret: (data!['client_secret'] as String?) ?? '',
    customerId: (data!['customer_id'] as String?) ?? '',
    ephemeralKeySecret: (data!['ephemeral_key_secret'] as String?) ?? '',
    // ...
  );
```

**Step 2: Fix — 使用 data (已确认非 null) 而非 data!**

`needPayment` 检查已确认 `data != null`，但 Dart 的 flow analysis 在闭包/条件中不总能推断非空。修改为在 if 分支内先做局部赋值：

```dart
if (needPayment) {
  final d = data!; // data is confirmed non-null by needPayment check
  final paymentData = AcceptPaymentData(
    taskId: _taskId!,
    clientSecret: (d['client_secret'] as String?) ?? '',
    customerId: (d['customer_id'] as String?) ?? '',
    ephemeralKeySecret: (d['ephemeral_key_secret'] as String?) ?? '',
    amountDisplay: d['amount_display']?.toString(),
    applicationId: event.applicationId,
    paymentExpiresAt: d['payment_expires_at']?.toString(),
    taskTitle: state.task?.title,
    applicantName: /* ... */,
    taskSource: state.task?.taskSource,
    fleaMarketItemId: /* ... */,
  );
```

实际上更好的方式是给 `data` 做 early return：

```dart
if (!needPayment || data == null) {
  // ... handle no-payment case
} else {
  // data is promoted to non-null here
  final paymentData = AcceptPaymentData(
    taskId: _taskId!,
    clientSecret: (data['client_secret'] as String?) ?? '',
    // ...
  );
}
```

**Step 3: Commit**

```bash
git add lib/features/tasks/bloc/task_detail_bloc.dart
git commit -m "fix(tasks): safe null handling in acceptApplicant payment data"
```

---

### Task 3: TaskDetailBloc._onToggleProfileVisibility — 缺少 task null 检查

**问题:** handler 只检查 `state.isSubmitting`，但直接用 `state.task!.id`。如果 task 为 null（极端情况，如页面还在 loading 时触发），会崩溃。

**Files:**
- Fix: `lib/features/tasks/bloc/task_detail_bloc.dart`

**Step 1: Fix — 添加 null guard**

找到 `_onToggleProfileVisibility` handler（约 line 1143-1147）:

```dart
// BEFORE:
if (state.isSubmitting) return;

// AFTER:
if (state.isSubmitting || state.task == null) return;
```

**Step 2: Commit**

```bash
git add lib/features/tasks/bloc/task_detail_bloc.dart
git commit -m "fix(tasks): add null guard in toggleProfileVisibility handler"
```

---

### Task 4: TaskDetailBloc._onRespondNegotiation — assert 在 release 中被移除

**问题:** `assert(event.action == 'accept' || event.action == 'reject')` 在 release build 被完全移除，无效参数会默默传到后端。

**Files:**
- Fix: `lib/features/tasks/bloc/task_detail_bloc.dart`

**Step 1: Fix — 替换 assert 为运行时检查**

```dart
// BEFORE (around line 1103):
assert(event.action == 'accept' || event.action == 'reject',
    'Invalid action: ${event.action}');

// AFTER:
if (event.action != 'accept' && event.action != 'reject') {
  emit(state.copyWith(
    isSubmitting: false,
    errorMessage: 'Invalid negotiation action: ${event.action}',
  ));
  return;
}
```

**Step 2: Commit**

```bash
git add lib/features/tasks/bloc/task_detail_bloc.dart
git commit -m "fix(tasks): replace assert with runtime check in respondNegotiation"
```

---

### Task 5: TaskDetailBloc._onQuoteDesignatedPrice — 部分失败静默吞错

**问题:** `applyTask()` 成功但 `acceptTask()` 失败时，嵌套 catch 用 `catch (_) {}` 完全吞掉错误。用户看到错误但不知道实际已 apply 成功。

**Files:**
- Fix: `lib/features/tasks/bloc/task_detail_bloc.dart`

**Step 1: Fix — 记录嵌套错误，区分两阶段失败**

```dart
// 在 _onQuoteDesignatedPrice 的外层 catch 中:
} catch (e) {
  if (applied) {
    // apply 已成功但 accept 失败，尝试刷新以显示真实状态
    AppLogger.warning('QuoteDesignatedPrice: apply succeeded but accept failed', error: e);
    try {
      final task = await _taskRepository.getTaskDetail(_taskId!);
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        errorMessage: 'task_quote_accept_failed',  // 用 error code
      ));
      return;
    } catch (refreshError) {
      AppLogger.error('QuoteDesignatedPrice: refresh also failed', error: refreshError);
    }
  }
  AppLogger.error('QuoteDesignatedPrice failed', error: e);
  emit(state.copyWith(
    isSubmitting: false,
    errorMessage: e is TaskException ? e.message : 'task_quote_failed',
  ));
}
```

**Step 2: 添加 error code 到 ErrorLocalizer**

在 `lib/core/utils/error_localizer.dart` 的 switch 中添加:

```dart
case 'task_quote_failed':
  return context.l10n.errorTaskQuoteFailed;
case 'task_quote_accept_failed':
  return context.l10n.errorTaskQuoteAcceptFailed;
```

在三个 ARB 文件中添加对应 key:

```json
// app_en.arb
"errorTaskQuoteFailed": "Failed to submit quote. Please try again.",
"errorTaskQuoteAcceptFailed": "Your application was submitted, but automatic acceptance failed. Please contact support.",

// app_zh.arb
"errorTaskQuoteFailed": "报价提交失败，请重试",
"errorTaskQuoteAcceptFailed": "报价已提交，但自动接单失败，请联系客服",

// app_zh_Hant.arb
"errorTaskQuoteFailed": "報價提交失敗，請重試",
"errorTaskQuoteAcceptFailed": "報價已提交，但自動接單失敗，請聯繫客服"
```

**Step 3: Commit**

```bash
git add lib/features/tasks/bloc/task_detail_bloc.dart lib/core/utils/error_localizer.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb
git commit -m "fix(tasks): log and report partial failure in quoteDesignatedPrice"
```

---

## Phase 2: Error Handling Standardization (统一错误码)

### Task 6: TaskDetailBloc — 将所有 e.toString() 替换为 error code

**问题:** 23 个 handler 中大部分用 `e.toString()` 作为 errorMessage，UI 显示原始异常文本（如 `Exception: DioException [connection timeout]`），用户看不懂。

**Files:**
- Fix: `lib/features/tasks/bloc/task_detail_bloc.dart`
- Fix: `lib/core/utils/error_localizer.dart`
- Fix: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_Hant.arb`

**Step 1: 定义所有缺失的 error code**

需要添加的 error code（按 handler 整理）：

| Handler | 当前 errorMessage | 改为 error code |
|---------|-------------------|-----------------|
| `_onLoadRequested` | `e.toString()` | `'task_detail_load_failed'` |
| `_onLoadApplications` | `e.toString()` | `'task_applications_load_failed'` |
| `_onLoadRefundStatus` | (silent clear) | 保持不变（静默清除是合理的） |
| `_onLoadReviews` | `e.toString()` | `'task_reviews_load_failed'` |
| `_onApplyRequested` | `'application_failed'` (error code) 或 `e.toString()` | 统一为 `'task_apply_failed'` |
| `_onCancelApplication` | `e.toString()` | `'task_cancel_application_failed'` |
| `_onAcceptApplicant` | `e.toString()` | `'task_accept_applicant_failed'` |
| `_onRejectApplicant` | `e.toString()` | `'task_reject_applicant_failed'` |
| `_onCompleteRequested` | `e.toString()` | `'task_complete_failed'` |
| `_onConfirmCompletion` | `e.toString()` | `'task_confirm_completion_failed'` |
| `_onCancelRequested` | `e.toString()` | `'task_cancel_failed'` |
| `_onReviewRequested` | `e.toString()` | `'task_review_failed'` |
| `_onRequestRefund` | `e.toString()` | `'task_refund_request_failed'` |
| `_onLoadRefundHistory` | `e.toString()` | `'task_refund_history_load_failed'` |
| `_onCancelRefund` | `e.toString()` | `'task_cancel_refund_failed'` |
| `_onSubmitRebuttal` | `e.toString()` | `'task_rebuttal_failed'` |
| `_onSendApplicationMessage` | `e.toString()` | `'task_send_message_failed'` |
| `_onSubmitCounterOffer` | `e.toString()` | `'task_counter_offer_failed'` |
| `_onRespondCounterOffer` | `e.toString()` | `'task_respond_counter_offer_failed'` |
| `_onRespondNegotiation` | `e.toString()` | `'task_respond_negotiation_failed'` |
| `_onToggleProfileVisibility` | `e.toString()` | `'task_visibility_update_failed'` |

**Step 2: 批量修改 task_detail_bloc.dart 中所有 catch 块**

每个 catch 块的模式从:
```dart
} catch (e) {
  AppLogger.error('...', error: e);
  emit(state.copyWith(
    isSubmitting: false,
    errorMessage: e.toString(),
  ));
}
```

改为:
```dart
} catch (e) {
  AppLogger.error('...', error: e);
  emit(state.copyWith(
    isSubmitting: false,
    errorMessage: 'task_xxx_failed',
  ));
}
```

**保留特殊处理:**
- `_onApplyRequested`: 保留 `TaskException('stripe_setup_required')` 特殊分支
- `_onRespondNegotiation`: 保留 `TaskException('negotiation_token_missing')` 检查
- `_onLoadRefundStatus`: 保留静默清除逻辑

**Step 3: 添加所有 error code 到 ErrorLocalizer**

在 `error_localizer.dart` switch 中添加（在 `create_task_failed` 附近）:

```dart
// Task detail error codes
case 'task_detail_load_failed':
  return context.l10n.errorTaskDetailLoadFailed;
case 'task_applications_load_failed':
  return context.l10n.errorTaskApplicationsLoadFailed;
case 'task_reviews_load_failed':
  return context.l10n.errorTaskReviewsLoadFailed;
case 'task_apply_failed':
  return context.l10n.errorTaskApplyFailed;
case 'task_cancel_application_failed':
  return context.l10n.errorTaskCancelApplicationFailed;
case 'task_accept_applicant_failed':
  return context.l10n.errorTaskAcceptApplicantFailed;
case 'task_reject_applicant_failed':
  return context.l10n.errorTaskRejectApplicantFailed;
case 'task_complete_failed':
  return context.l10n.errorTaskCompleteFailed;
case 'task_confirm_completion_failed':
  return context.l10n.errorTaskConfirmCompletionFailed;
case 'task_cancel_failed':
  return context.l10n.errorTaskCancelFailed;
case 'task_review_failed':
  return context.l10n.errorTaskReviewFailed;
case 'task_refund_request_failed':
  return context.l10n.errorTaskRefundRequestFailed;
case 'task_refund_history_load_failed':
  return context.l10n.errorTaskRefundHistoryLoadFailed;
case 'task_cancel_refund_failed':
  return context.l10n.errorTaskCancelRefundFailed;
case 'task_rebuttal_failed':
  return context.l10n.errorTaskRebuttalFailed;
case 'task_send_message_failed':
  return context.l10n.errorTaskSendMessageFailed;
case 'task_counter_offer_failed':
  return context.l10n.errorTaskCounterOfferFailed;
case 'task_respond_counter_offer_failed':
  return context.l10n.errorTaskRespondCounterOfferFailed;
case 'task_respond_negotiation_failed':
  return context.l10n.errorTaskRespondNegotiationFailed;
case 'task_visibility_update_failed':
  return context.l10n.errorTaskVisibilityUpdateFailed;
case 'task_list_load_failed':
  return context.l10n.errorTaskListLoadFailed;
```

**Step 4: 添加 ARB 翻译 (三个文件)**

`app_en.arb`:
```json
"errorTaskDetailLoadFailed": "Failed to load task details. Please try again.",
"errorTaskApplicationsLoadFailed": "Failed to load applications.",
"errorTaskReviewsLoadFailed": "Failed to load reviews.",
"errorTaskApplyFailed": "Failed to submit application. Please try again.",
"errorTaskCancelApplicationFailed": "Failed to cancel application.",
"errorTaskAcceptApplicantFailed": "Failed to accept applicant.",
"errorTaskRejectApplicantFailed": "Failed to reject applicant.",
"errorTaskCompleteFailed": "Failed to submit completion. Please try again.",
"errorTaskConfirmCompletionFailed": "Failed to confirm completion.",
"errorTaskCancelFailed": "Failed to cancel task.",
"errorTaskReviewFailed": "Failed to submit review.",
"errorTaskRefundRequestFailed": "Failed to submit refund request.",
"errorTaskRefundHistoryLoadFailed": "Failed to load refund history.",
"errorTaskCancelRefundFailed": "Failed to cancel refund request.",
"errorTaskRebuttalFailed": "Failed to submit rebuttal.",
"errorTaskSendMessageFailed": "Failed to send message.",
"errorTaskCounterOfferFailed": "Failed to submit counter offer.",
"errorTaskRespondCounterOfferFailed": "Failed to respond to counter offer.",
"errorTaskRespondNegotiationFailed": "Failed to respond to negotiation.",
"errorTaskVisibilityUpdateFailed": "Failed to update task visibility.",
"errorTaskListLoadFailed": "Failed to load tasks."
```

`app_zh.arb`:
```json
"errorTaskDetailLoadFailed": "加载任务详情失败，请重试",
"errorTaskApplicationsLoadFailed": "加载申请列表失败",
"errorTaskReviewsLoadFailed": "加载评价失败",
"errorTaskApplyFailed": "申请提交失败，请重试",
"errorTaskCancelApplicationFailed": "取消申请失败",
"errorTaskAcceptApplicantFailed": "接受申请人失败",
"errorTaskRejectApplicantFailed": "拒绝申请人失败",
"errorTaskCompleteFailed": "提交完成失败，请重试",
"errorTaskConfirmCompletionFailed": "确认完成失败",
"errorTaskCancelFailed": "取消任务失败",
"errorTaskReviewFailed": "提交评价失败",
"errorTaskRefundRequestFailed": "提交退款申请失败",
"errorTaskRefundHistoryLoadFailed": "加载退款记录失败",
"errorTaskCancelRefundFailed": "取消退款申请失败",
"errorTaskRebuttalFailed": "提交申诉失败",
"errorTaskSendMessageFailed": "发送消息失败",
"errorTaskCounterOfferFailed": "提交还价失败",
"errorTaskRespondCounterOfferFailed": "回复还价失败",
"errorTaskRespondNegotiationFailed": "回复议价失败",
"errorTaskVisibilityUpdateFailed": "更新任务可见性失败",
"errorTaskListLoadFailed": "加载任务列表失败"
```

`app_zh_Hant.arb`:
```json
"errorTaskDetailLoadFailed": "載入任務詳情失敗，請重試",
"errorTaskApplicationsLoadFailed": "載入申請列表失敗",
"errorTaskReviewsLoadFailed": "載入評價失敗",
"errorTaskApplyFailed": "申請提交失敗，請重試",
"errorTaskCancelApplicationFailed": "取消申請失敗",
"errorTaskAcceptApplicantFailed": "接受申請人失敗",
"errorTaskRejectApplicantFailed": "拒絕申請人失敗",
"errorTaskCompleteFailed": "提交完成失敗，請重試",
"errorTaskConfirmCompletionFailed": "確認完成失敗",
"errorTaskCancelFailed": "取消任務失敗",
"errorTaskReviewFailed": "提交評價失敗",
"errorTaskRefundRequestFailed": "提交退款申請失敗",
"errorTaskRefundHistoryLoadFailed": "載入退款記錄失敗",
"errorTaskCancelRefundFailed": "取消退款申請失敗",
"errorTaskRebuttalFailed": "提交申訴失敗",
"errorTaskSendMessageFailed": "傳送訊息失敗",
"errorTaskCounterOfferFailed": "提交還價失敗",
"errorTaskRespondCounterOfferFailed": "回覆還價失敗",
"errorTaskRespondNegotiationFailed": "回覆議價失敗",
"errorTaskVisibilityUpdateFailed": "更新任務可見性失敗",
"errorTaskListLoadFailed": "載入任務列表失敗"
```

**Step 5: 同时修复 TaskListBloc 的 error code**

在 `lib/features/tasks/bloc/task_list_bloc.dart` 的 `_fetchTasks` catch 中:

```dart
// BEFORE:
errorMessage: e.toString(),

// AFTER:
errorMessage: 'task_list_load_failed',
```

**Step 6: 生成 l10n 文件**

```bash
cd link2ur && flutter gen-l10n
```

**Step 7: Commit**

```bash
git add lib/features/tasks/bloc/task_detail_bloc.dart lib/features/tasks/bloc/task_list_bloc.dart lib/core/utils/error_localizer.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/
git commit -m "refactor(tasks): standardize all error messages to localized error codes"
```

---

### Task 7: TasksView 和 CreateTaskView — 错误消息本地化

**问题:** `tasks_view.dart` 的 `ErrorStateView` 直接传 `state.errorMessage`（现在是 error code），需确认 ErrorStateView 已使用 `context.localizeError()`。`create_task_view.dart` 的 snackbar 同理。

**Files:**
- Check/Fix: `lib/features/tasks/views/tasks_view.dart`
- Check/Fix: `lib/features/tasks/views/create_task_view.dart`

**Step 1: 检查 ErrorStateView 的实现**

读取 `lib/core/widgets/error_state_view.dart` 确认它是否自动本地化 errorMessage。如果不是，需要在调用处包装 `context.localizeError()`。

**Step 2: 确保所有 error 显示都走 localizeError**

在 `tasks_view.dart` 中，找到 ErrorStateView 的用法:
```dart
// 如果 ErrorStateView 不自动本地化:
ErrorStateView(
  message: context.localizeError(state.errorMessage),  // 包装
  onRetry: () => context.read<TaskListBloc>().add(const TaskListRefreshRequested()),
)
```

在 `create_task_view.dart` 的 BlocListener 中:
```dart
// 确保 snackbar 使用 localizeError:
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(context.localizeError(state.errorMessage))),
);
```

**Step 3: Commit**

```bash
git add lib/features/tasks/views/tasks_view.dart lib/features/tasks/views/create_task_view.dart
git commit -m "fix(tasks): localize error messages in task list and create views"
```

---

## Phase 3: State Management Optimization (性能和稳定性)

### Task 8: TaskDetailView — 添加 buildWhen 防止过度重建

**问题:** 主 `BlocConsumer` 没有 `buildWhen`，任何 state 变化（如 `isLoadingApplications`、`actionMessage`）都会触发整棵树重建。

**Files:**
- Fix: `lib/features/tasks/views/task_detail_view.dart`

**Step 1: 添加 buildWhen**

在 `BlocConsumer<TaskDetailBloc, TaskDetailState>` 上添加:

```dart
BlocConsumer<TaskDetailBloc, TaskDetailState>(
  buildWhen: (prev, curr) =>
      prev.status != curr.status ||
      prev.task != curr.task ||
      prev.isSubmitting != curr.isSubmitting ||
      prev.applications != curr.applications ||
      prev.userApplication != curr.userApplication ||
      prev.refundRequest != curr.refundRequest ||
      prev.reviews != curr.reviews ||
      prev.hasSubmittedReview != curr.hasSubmittedReview ||
      prev.isLoadingApplications != curr.isLoadingApplications ||
      prev.isLoadingReviews != curr.isLoadingReviews,
  listenWhen: (prev, curr) =>
      prev.actionMessage != curr.actionMessage ||
      prev.acceptPaymentData != curr.acceptPaymentData,
  // ...
)
```

关键点：`buildWhen` 排除 `actionMessage`、`errorMessage`（只通过 listener 处理）和 `isLoadingRefundStatus`/`isLoadingRefundHistory`（这些是子组件关心的）。

**Step 2: 将 context.read<AuthBloc>() 改为 context.select**

在 build 方法中找到所有 `context.read<AuthBloc>().state.user?.id` 调用，改为在 BlocConsumer 外层提取:

```dart
// 在 build() 方法开头:
final currentUserId = context.select<AuthBloc, String?>(
  (bloc) => bloc.state.user?.id,
);
```

**Step 3: Commit**

```bash
git add lib/features/tasks/views/task_detail_view.dart
git commit -m "perf(tasks): add buildWhen/listenWhen to TaskDetailView BlocConsumer"
```

---

### Task 9: TaskDetailBloc._onSendApplicationMessage — 发消息后不刷新

**问题:** 发送申请消息成功后只 emit `actionMessage`，不重新加载 applications 列表，UI 不显示新消息。

**Files:**
- Fix: `lib/features/tasks/bloc/task_detail_bloc.dart`

**Step 1: Fix — 发消息后重新加载 applications**

在 `_onSendApplicationMessage` handler 的成功分支中添加 reload:

```dart
// AFTER sendApplicationMessage 成功:
await _taskRepository.sendApplicationMessage(
  taskId: _taskId!,
  applicationId: event.applicationId,
  content: event.content,
);

// 重新加载 applications 以显示新消息
final apps = await _taskRepository.getTaskApplications(_taskId!);
// ... 解析 apps 为 List<TaskApplication>

emit(state.copyWith(
  isSubmitting: false,
  applications: parsedApps,
  actionMessage: 'application_message_sent',
));
```

注意：如果 reload 失败，仍然 emit 成功消息（消息已发送成功，只是 UI 未刷新）。

**Step 2: Commit**

```bash
git add lib/features/tasks/bloc/task_detail_bloc.dart
git commit -m "fix(tasks): reload applications after sending message"
```

---

## Phase 4: Cache Invalidation Fixes (数据一致性)

### Task 10: TaskRepository — 补充缺失的缓存失效

**问题:** 多个写操作不 invalidate 相关缓存，导致 UI 显示旧数据。

**Files:**
- Fix: `lib/data/repositories/task_repository.dart`

**Step 1: 逐个补充缓存失效**

| Method | 应添加的 invalidation |
|--------|----------------------|
| `reviewTask()` | `invalidateTaskDetailCache(taskId)` — 影响 `hasReviewed` |
| `requestRefund()` | `invalidateTaskDetailCache(taskId)` — 影响 task status |
| `cancelRefundRequest()` | `invalidateTaskDetailCache(taskId)` |
| `submitRefundRebuttal()` | `invalidateTaskDetailCache(taskId)` |
| `disputeTask()` | `invalidateTaskDetailCache(taskId)` |
| `negotiateApplication()` | `invalidateTaskDetailCache(taskId)` |
| `respondNegotiation()` | `invalidateTaskDetailCache(taskId)`, `invalidateMyApplicationsCache()` |
| `submitTakerCounterOffer()` | `invalidateTaskDetailCache(taskId)` |
| `respondTakerCounterOffer()` | `invalidateTaskDetailCache(taskId)` |

模式统一为在 API 调用成功后添加:
```dart
CacheManager.shared.remove('${CacheManager.prefixTaskDetail}$taskId');
```

**Step 2: 确认 CacheManager 的 prefix 常量和 invalidation 方法**

先读取 `CacheManager` 的实现确认 API：
- `CacheManager.shared.remove(key)`
- `CacheManager.shared.invalidate(prefix)` (按前缀批量清除)
- 或具体的 `invalidateTaskDetailCache(taskId)` 方法

**Step 3: Commit**

```bash
git add lib/data/repositories/task_repository.dart
git commit -m "fix(tasks): add missing cache invalidation for write operations"
```

---

## Phase 5: Type Safety Fixes (类型一致性)

### Task 11: TaskRepository — 修复 taskId 类型不一致

**问题:** `participantComplete()` 和 `participantExitRequest()` 用 `String taskId`，其他方法用 `int taskId`。

**Files:**
- Fix: `lib/data/repositories/task_repository.dart`

**Step 1: 检查 API endpoint 中 taskId 的类型**

读取 `api_endpoints.dart` 确认 multi-participant endpoint 格式：
- 如果 URL 用 `$taskId` 字符串插值，int 和 String 都能工作
- 但调用方可能传 int，导致类型不匹配

**Step 2: 统一为 int（与其他方法一致）**

```dart
// BEFORE:
Future<void> participantComplete(String taskId) async { ... }
Future<void> participantExitRequest(String taskId, String reason) async { ... }

// AFTER:
Future<void> participantComplete(int taskId) async { ... }
Future<void> participantExitRequest(int taskId, String reason) async { ... }
```

**Step 3: 检查调用方是否需要更新**

搜索 `participantComplete` 和 `participantExitRequest` 的调用方，更新参数类型。

**Step 4: Commit**

```bash
git add lib/data/repositories/task_repository.dart
# 如果有调用方需要更新:
# git add lib/features/...
git commit -m "fix(tasks): unify taskId parameter type to int in repository"
```

---

### Task 12: Model DateTime 一致性

**问题:** `TaskApplication.createdAt` 和 `RefundRequest.createdAt/updatedAt` 是 String，而 `Task` 用 DateTime。不影响运行但增加维护负担。

**Files:**
- Fix: `lib/data/models/task_application.dart`
- Fix: `lib/data/models/refund_request.dart`

**Step 1: 将 TaskApplication.createdAt 改为 DateTime?**

```dart
// BEFORE:
final String? createdAt;

// AFTER:
final DateTime? createdAt;

// fromJson:
createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
```

**Step 2: 将 RefundRequest 的时间字段改为 DateTime?**

同样处理 `createdAt`, `updatedAt`, `reviewedAt`, `processedAt`, `completedAt`, `rebuttalSubmittedAt`。

**Step 3: 检查消费方**

搜索所有使用这些字段的地方，确认格式化代码兼容 DateTime（通常用 `DateFormat` 格式化）。

**Step 4: Commit**

```bash
git add lib/data/models/task_application.dart lib/data/models/refund_request.dart
git commit -m "refactor(models): unify datetime fields to DateTime type across task models"
```

---

## Phase 6: BLoC Tests (测试覆盖)

### Task 13: TaskListBloc 测试

**Files:**
- Create: `test/features/tasks/bloc/task_list_bloc_test.dart`

**Step 1: Write tests**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:link2ur/features/tasks/bloc/task_list_bloc.dart';
import 'package:link2ur/data/repositories/task_repository.dart';
import 'package:link2ur/data/models/task.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late MockTaskRepository mockRepo;

  setUp(() {
    mockRepo = MockTaskRepository();
  });

  // 辅助方法：构造分页响应
  TaskListResponse makeResponse({
    List<Task>? tasks,
    int total = 10,
    bool hasMore = true,
  }) {
    return TaskListResponse(
      tasks: tasks ?? [Task.fromJson({'id': 1, 'title': 'Test'})],
      total: total,
      hasMore: hasMore,
    );
  }

  group('TaskListBloc', () {
    blocTest<TaskListBloc, TaskListState>(
      'emits [loading, loaded] on successful load',
      build: () {
        when(() => mockRepo.getTasks(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          taskType: any(named: 'taskType'),
          keyword: any(named: 'keyword'),
          sortBy: any(named: 'sortBy'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => makeResponse());
        return TaskListBloc(taskRepository: mockRepo);
      },
      act: (bloc) => bloc.add(const TaskListLoadRequested()),
      expect: () => [
        isA<TaskListState>().having((s) => s.status, 'status', TaskListStatus.loading),
        isA<TaskListState>().having((s) => s.status, 'status', TaskListStatus.loaded),
      ],
    );

    blocTest<TaskListBloc, TaskListState>(
      'emits error state on load failure',
      build: () {
        when(() => mockRepo.getTasks(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          taskType: any(named: 'taskType'),
          keyword: any(named: 'keyword'),
          sortBy: any(named: 'sortBy'),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(Exception('Network error'));
        return TaskListBloc(taskRepository: mockRepo);
      },
      act: (bloc) => bloc.add(const TaskListLoadRequested()),
      expect: () => [
        isA<TaskListState>().having((s) => s.status, 'status', TaskListStatus.loading),
        isA<TaskListState>()
            .having((s) => s.status, 'status', TaskListStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', 'task_list_load_failed'),
      ],
    );

    blocTest<TaskListBloc, TaskListState>(
      'appends tasks on loadMore',
      build: () {
        when(() => mockRepo.getTasks(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          taskType: any(named: 'taskType'),
          keyword: any(named: 'keyword'),
          sortBy: any(named: 'sortBy'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => makeResponse());
        return TaskListBloc(taskRepository: mockRepo);
      },
      seed: () => TaskListState(
        status: TaskListStatus.loaded,
        tasks: [Task.fromJson({'id': 0, 'title': 'Existing'})],
        page: 1,
        hasMore: true,
      ),
      act: (bloc) => bloc.add(const TaskListLoadMore()),
      expect: () => [
        isA<TaskListState>().having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<TaskListState>()
            .having((s) => s.tasks.length, 'tasks.length', 2)
            .having((s) => s.page, 'page', 2),
      ],
    );

    blocTest<TaskListBloc, TaskListState>(
      'does not loadMore when hasMore is false',
      build: () => TaskListBloc(taskRepository: mockRepo),
      seed: () => const TaskListState(
        status: TaskListStatus.loaded,
        hasMore: false,
      ),
      act: (bloc) => bloc.add(const TaskListLoadMore()),
      expect: () => [],  // no state changes
    );

    blocTest<TaskListBloc, TaskListState>(
      'resets page on category change',
      build: () {
        when(() => mockRepo.getTasks(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          taskType: any(named: 'taskType'),
          keyword: any(named: 'keyword'),
          sortBy: any(named: 'sortBy'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => makeResponse());
        return TaskListBloc(taskRepository: mockRepo);
      },
      seed: () => const TaskListState(
        status: TaskListStatus.loaded,
        page: 3,
        selectedCategory: 'housekeeping',
      ),
      act: (bloc) => bloc.add(const TaskListCategoryChanged('delivery')),
      expect: () => [
        isA<TaskListState>()
            .having((s) => s.selectedCategory, 'category', 'delivery')
            .having((s) => s.status, 'status', TaskListStatus.loading),
        isA<TaskListState>()
            .having((s) => s.page, 'page', 1),
      ],
    );
  });
}
```

**Step 2: Run tests**

```bash
cd link2ur && flutter test test/features/tasks/bloc/task_list_bloc_test.dart -v
```

注意：需要先确认 `TaskListResponse` 的实际返回格式，测试中的 mock 需要与实际 repository 方法签名匹配。根据实际代码调整 mock 设置。

**Step 3: Commit**

```bash
git add test/features/tasks/bloc/task_list_bloc_test.dart
git commit -m "test(tasks): add TaskListBloc unit tests"
```

---

### Task 14: TaskDetailBloc 核心操作测试

**Files:**
- Create: `test/features/tasks/bloc/task_detail_bloc_test.dart`

**Step 1: Write tests for key handlers**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:link2ur/features/tasks/bloc/task_detail_bloc.dart';
import 'package:link2ur/data/repositories/task_repository.dart';
import 'package:link2ur/data/repositories/notification_repository.dart';
import 'package:link2ur/data/models/task.dart';

class MockTaskRepository extends Mock implements TaskRepository {}
class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  late MockTaskRepository mockTaskRepo;
  late MockNotificationRepository mockNotifRepo;

  final testTask = Task.fromJson({
    'id': 42,
    'title': 'Test Task',
    'status': 'open',
    'reward': 10.0,
  });

  setUp(() {
    mockTaskRepo = MockTaskRepository();
    mockNotifRepo = MockNotificationRepository();
  });

  TaskDetailBloc buildBloc() => TaskDetailBloc(
    taskRepository: mockTaskRepo,
    notificationRepository: mockNotifRepo,
  );

  group('TaskDetailBloc', () {
    // --- Load ---
    blocTest<TaskDetailBloc, TaskDetailState>(
      'emits [loading, loaded] on successful load',
      build: () {
        when(() => mockTaskRepo.getTaskDetail(42))
            .thenAnswer((_) async => testTask);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const TaskDetailLoadRequested(42)),
      expect: () => [
        isA<TaskDetailState>().having((s) => s.status, 'status', TaskDetailStatus.loading),
        isA<TaskDetailState>()
            .having((s) => s.status, 'status', TaskDetailStatus.loaded)
            .having((s) => s.task?.id, 'task.id', 42),
      ],
    );

    blocTest<TaskDetailBloc, TaskDetailState>(
      'emits error on load failure',
      build: () {
        when(() => mockTaskRepo.getTaskDetail(42))
            .thenThrow(Exception('not found'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const TaskDetailLoadRequested(42)),
      expect: () => [
        isA<TaskDetailState>().having((s) => s.status, 'status', TaskDetailStatus.loading),
        isA<TaskDetailState>()
            .having((s) => s.status, 'status', TaskDetailStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', 'task_detail_load_failed'),
      ],
    );

    // --- Apply ---
    blocTest<TaskDetailBloc, TaskDetailState>(
      'emits submitting then success on apply',
      build: () {
        when(() => mockTaskRepo.applyTask(
          taskId: 42,
          message: any(named: 'message'),
        )).thenAnswer((_) async => {});
        when(() => mockTaskRepo.getTaskDetail(42))
            .thenAnswer((_) async => testTask);
        return buildBloc();
      },
      seed: () => TaskDetailState(
        status: TaskDetailStatus.loaded,
        task: testTask,
      ),
      act: (bloc) => bloc.add(const TaskDetailApplyRequested(message: 'Hi')),
      expect: () => [
        isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<TaskDetailState>()
            .having((s) => s.isSubmitting, 'isSubmitting', false)
            .having((s) => s.actionMessage, 'actionMessage', 'application_submitted'),
      ],
    );

    blocTest<TaskDetailBloc, TaskDetailState>(
      'emits stripe_setup_required on 428 error',
      build: () {
        when(() => mockTaskRepo.applyTask(
          taskId: 42,
          message: any(named: 'message'),
        )).thenThrow(TaskException('stripe_setup_required'));
        return buildBloc();
      },
      seed: () => TaskDetailState(
        status: TaskDetailStatus.loaded,
        task: testTask,
      ),
      act: (bloc) => bloc.add(const TaskDetailApplyRequested(message: 'Hi')),
      expect: () => [
        isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<TaskDetailState>()
            .having((s) => s.actionMessage, 'actionMessage', 'stripe_setup_required'),
      ],
    );

    // --- Cancel ---
    blocTest<TaskDetailBloc, TaskDetailState>(
      'emits task_cancelled on direct cancel',
      build: () {
        when(() => mockTaskRepo.cancelTask(42, reason: any(named: 'reason')))
            .thenAnswer((_) async => true);
        when(() => mockTaskRepo.getTaskDetail(42))
            .thenAnswer((_) async => testTask);
        return buildBloc();
      },
      seed: () => TaskDetailState(
        status: TaskDetailStatus.loaded,
        task: testTask,
      ),
      act: (bloc) => bloc.add(const TaskDetailCancelRequested()),
      expect: () => [
        isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<TaskDetailState>()
            .having((s) => s.actionMessage, 'actionMessage', 'task_cancelled'),
      ],
    );

    // --- Guard: no-op when task is null ---
    blocTest<TaskDetailBloc, TaskDetailState>(
      'does nothing when task is null and apply is requested',
      build: () => buildBloc(),
      seed: () => const TaskDetailState(),  // task is null
      act: (bloc) => bloc.add(const TaskDetailApplyRequested()),
      expect: () => [],  // no state changes
    );
  });
}
```

**Step 2: Run tests**

```bash
cd link2ur && flutter test test/features/tasks/bloc/task_detail_bloc_test.dart -v
```

注意：测试中的 mock 方法签名需要与实际 repository 匹配。根据实际 `applyTask()`、`cancelTask()` 等方法的参数名调整。

**Step 3: Commit**

```bash
git add test/features/tasks/bloc/task_detail_bloc_test.dart
git commit -m "test(tasks): add TaskDetailBloc unit tests for core operations"
```

---

## Phase 7: Minor Fixes (小修小补)

### Task 15: TaskExpert 硬编码中文 fallback

**问题:** `TaskExpert` 的 `displayName` 使用 `'达人$id'` 作为 fallback，应改为不依赖语言的默认值。

**Files:**
- Fix: `lib/data/models/task_expert.dart`

**Step 1: Fix**

```dart
// BEFORE:
String get displayName => expertName.isNotEmpty ? expertName : '达人$id';

// AFTER:
String get displayName => expertName.isNotEmpty ? expertName : 'Expert #$id';
```

注意：这是 model 层，不是 UI 层，用英文 ID 作为 fallback 更中立。或者如果有 locale 参数可以本地化，但 model 层通常不依赖 BuildContext。

**Step 2: Commit**

```bash
git add lib/data/models/task_expert.dart
git commit -m "fix(models): replace hardcoded Chinese fallback in TaskExpert.displayName"
```

---

## Summary

| Phase | Tasks | Priority | Impact |
|-------|-------|----------|--------|
| **1: Critical Bugs** | Task 1-5 | 🔴 高 | 修复崩溃、数据丢失、静默失败 |
| **2: Error Handling** | Task 6-7 | 🟡 中 | 用户看到可读错误而非技术异常 |
| **3: State Optimization** | Task 8-9 | 🟡 中 | 减少不必要重建，修复 UI 不刷新 |
| **4: Cache Fixes** | Task 10 | 🟡 中 | 防止显示过期数据 |
| **5: Type Safety** | Task 11-12 | 🟢 低 | 代码一致性，减少维护负担 |
| **6: Tests** | Task 13-14 | 🟡 中 | 防止回归，建立测试基线 |
| **7: Minor** | Task 15 | 🟢 低 | 国际化合规 |

**估计总变更:** ~15 个文件，~500 行修改/新增

---

## 注意事项

1. **不拆分 TaskDetailBloc**: 虽然 1,170 行偏大，但拆分是大型重构，风险高，当前结构可工作。通过添加测试和 error code 标准化来提高可维护性。
2. **不改 copyWith 模式**: `errorMessage` 直接赋值（不用 `??`）是项目架构约定，保持一致。
3. **ARB 文件**: 添加新 key 后必须运行 `flutter gen-l10n` 生成代码。
4. **每个 Task 独立可提交**: 各 task 之间无依赖（除 Task 6 的 error code 被 Task 7 使用），可按任意顺序执行。
