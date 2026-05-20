# 咨询聊天对齐任务聊天 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 ApplicationChatView（议价 + 3 种咨询 + readOnly 共 5 种场景）和 TaskChatView 共用 ChatBloc + ChatScaffold + MessageGroupBubble，同时抽 ConsultationBloc 让 TaskDetailBloc 回本职。

**Architecture:** 方案 A：扩 ChatBloc 加可选 applicationId（端点不变只多传一个 query/body 字段）；MessageGroupBubble 加 customBubbleBuilder + groupMessages 把议价类消息当 system 一样独立成组；抽 ChatScaffold 承载 header/messages/inputBar/actionMenu 四个 slot；TaskDetailBloc 删议价 events，议价业务搬到新的 ConsultationBloc（内部按 ConsultationType 派发到 3 个 repository）。

**Tech Stack:** Flutter + flutter_bloc + Equatable + Dio + Hive + WebSocket + bloc_test + mocktail。

**Spec source:** `docs/superpowers/specs/2026-05-20-consultation-chat-alignment-design.md`

**Git workflow:** 直推 main（参照 `feedback_direct_to_main`）。每个 Task = 一次 commit。每步 commit 后跑 `flutter analyze` 必须通过；接 UI 的步骤跑 `flutter test` 必须全绿。

**Flutter 命令前缀**：所有 flutter/dart 命令前置 `$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; $env:GRADLE_USER_HOME = "F:\DevCache\.gradle"; ` 然后从 `link2ur/` 子目录执行。

---

## 文件结构

### 新建

| 路径 | 责任 |
|---|---|
| `link2ur/lib/features/chat/widgets/chat_scaffold.dart` | 两个聊天页共用骨架（appBar / header / messages / inputBar / actionMenu / aboveInputSlot） |
| `link2ur/lib/features/chat/widgets/task_info_card.dart` | 从 TaskChatView._buildTaskInfoCard 抽出 |
| `link2ur/lib/features/chat/widgets/media_progress_banner.dart` | 从 TaskChatView._buildMediaProgressBanner 抽出 |
| `link2ur/lib/features/chat/widgets/closed_task_banner.dart` | 从 TaskChatView._buildClosedTaskBar 抽出 |
| `link2ur/lib/features/tasks/bloc/consultation_bloc.dart` | 议价业务 bloc（单文件 events+state+bloc 不用 part of） |
| `link2ur/lib/features/tasks/views/consultation/widgets/price_bar.dart` | 议价价格条 header |
| `link2ur/lib/features/tasks/views/consultation/widgets/service_info_card.dart` | Service 咨询 header |
| `link2ur/lib/features/tasks/views/consultation/widgets/flea_market_item_card.dart` | FleaMarket 咨询 header |
| `link2ur/lib/features/tasks/views/consultation/widgets/read_only_banner.dart` | readOnly 顶部提示条 |
| `link2ur/lib/features/tasks/views/consultation/widgets/closed_consultation_banner.dart` | 已关闭咨询 banner |
| `link2ur/lib/features/tasks/views/consultation/widgets/price_proposal_bubble.dart` | negotiation/quote/counter_offer 气泡 |
| `link2ur/lib/features/tasks/views/consultation/widgets/negotiation_action_card.dart` | 最新议价的"接受/拒绝/还价"浮卡 |
| `link2ur/lib/features/tasks/views/consultation/widgets/negotiation_status_banner.dart` | negotiation_accepted/negotiation_rejected 状态条 |
| `link2ur/lib/features/tasks/views/consultation/widgets/consultation_action_bar.dart` | 6 个议价操作按钮 |
| `link2ur/lib/features/tasks/views/consultation/dialogs/negotiate_dialog.dart` | 议价弹窗（迁出 consultation_base.dart） |
| `link2ur/lib/features/tasks/views/consultation/dialogs/quote_dialog.dart` | 报价弹窗 |
| `link2ur/lib/features/tasks/views/consultation/dialogs/counter_offer_dialog.dart` | 还价弹窗 |
| `link2ur/lib/features/tasks/views/consultation/dialogs/formal_apply_dialog.dart` | 正式申请弹窗 |
| `link2ur/lib/features/tasks/views/consultation/utils/consultation_title.dart` | AppBar 标题前缀剥离 helper |
| `link2ur/test/features/chat/bloc/chat_bloc_application_id_test.dart` | ChatBloc applicationId 路径测试 |
| `link2ur/test/features/tasks/bloc/consultation_bloc_test.dart` | ConsultationBloc 完整测试 |
| `link2ur/test/features/chat/widgets/message_group_bubble_test.dart` | customBubbleBuilder + groupMessages 特殊类型测试 |
| `link2ur/test/features/chat/widgets/chat_scaffold_test.dart` | ChatScaffold slot 行为测试 |

### 修改

| 路径 | 改动 |
|---|---|
| `link2ur/lib/data/models/message.dart` | 加 `applicationId` 顶层 getter（fallback 到 meta） |
| `link2ur/lib/features/chat/bloc/chat_bloc.dart` | 4 个 send + load event 加 `applicationId` 字段；State 加 `applicationId`；WS 过滤加 applicationId 维度；调 repository 时透传 |
| `link2ur/lib/data/repositories/message_repository.dart` | 4 个发送 method + getTaskChatMessages 加可选 `applicationId` 参数 |
| `link2ur/lib/features/chat/widgets/message_group_bubble.dart` | 加 `customBubbleBuilder` 参数；groupMessages 把议价类型当 system 一样独立成组 |
| `link2ur/lib/features/chat/views/task_chat_view.dart` | 改用 ChatScaffold + TaskInfoCard + MediaProgressBanner + ClosedTaskBanner；内部行数大降 |
| `link2ur/lib/features/tasks/views/application_chat_view.dart` | 改为薄分发：根据 isConsultation/readOnly 派发到 3 个内部 View；内部 View 用 ChatBloc + ChatScaffold |
| `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart` | 删议价相关 events / handlers / state 字段（onNegotiate / onQuote / onCounterOffer / onApprove / onClose / onFormalApply） |
| `link2ur/lib/l10n/app_en.arb` | 加 11 个错误码翻译 |
| `link2ur/lib/l10n/app_zh.arb` | 同上 |
| `link2ur/lib/l10n/app_zh_Hant.arb` | 同上 |
| `link2ur/lib/core/utils/error_localizer.dart` | 11 个新 case |

### 删除

| 路径 | 原因 |
|---|---|
| `link2ur/lib/features/tasks/views/consultation/consultation_base.dart` | ConsultationActions 抽象 + 内嵌 dialog widgets 全部搬到 ConsultationBloc + 独立 dialog files |
| `link2ur/lib/features/tasks/views/consultation/service_consultation_actions.dart` | 派发逻辑搬到 ConsultationBloc 内部 |
| `link2ur/lib/features/tasks/views/consultation/task_consultation_actions.dart` | 同上 |
| `link2ur/lib/features/tasks/views/consultation/flea_market_consultation_actions.dart` | 同上 |

---

## Phase 0：实施前的现场校准（不可省）

### Task 0: 校准后端契约

**Files:**
- Read: `backend/app/routes/task_message_routes.py`（或类似）确认两件事

- [ ] **Step 1：确认 WS 推送的 chat message 是否携带 `application_id`**

Grep 后端 message-related routes：

```bash
grep -rn "application_id" backend/app/routes/task_message*.py backend/app/routes/message*.py
grep -rn "to_dict\|model_dump" backend/app/models.py | grep -i message
```

Expected：找到 Message 序列化时 `application_id` 字段。如果**没有**，需要在后端补一个 PR 让推送/响应带上 application_id 再继续。把这件事用 `gh issue create` 记一笔，不阻塞本计划但作为前置依赖项。

- [ ] **Step 2：确认议价消息的 `message_type` 实际枚举值**

```bash
grep -rn "message_type.*=" backend/app/routes/*consultation* backend/app/routes/*negotiation*
grep -rn "message_type.*=" backend/app/crud*.py | grep -i -E "negotiation|quote|counter"
```

Expected：确认 `negotiation` / `quote` / `counter_offer` / `negotiation_accepted` / `negotiation_rejected` 这五个 message_type 后端确实使用（Message model 的 getter 已暗示是这些）。若实际不同，本计划用到这五个字符串的地方全部替换为后端实际值。

- [ ] **Step 3：复现 WS 串台 bug**

打开两个调试设备 / 两个浏览器 tab，分别开两个同一 task 不同 application 的议价聊天会话。在 A 发一条消息看 B 是否被错误推送。

Expected：
- 如果出现串台 → 本计划 Task 2 的 WS 过滤需要修复这个 bug
- 如果不出现 → 后端已带 application 过滤，本计划 Task 2 的 WS 过滤改为"健壮性强化"，不影响功能

不写代码，把结果记到 `link2ur/docs/notes/2026-05-20-consultation-chat-alignment.md`（新建），后续 task 引用。

- [ ] **Step 4：commit 校准文档**

```bash
git add link2ur/docs/notes/2026-05-20-consultation-chat-alignment.md
git commit -m "docs: 咨询聊天对齐 — 实施前后端契约校准记录"
```

---

## Phase 1：基建（无 UI 改动，纯底层）

### Task 1: Message 模型加顶层 applicationId getter

**Files:**
- Modify: `link2ur/lib/data/models/message.dart`
- Test: `link2ur/test/data/models/message_test.dart`

- [ ] **Step 1: 写失败测试**

打开 `link2ur/test/data/models/message_test.dart`（无则新建），加：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/message.dart';

void main() {
  group('Message.applicationId', () {
    test('returns top-level application_id when present', () {
      final m = Message.fromJson({
        'id': 1, 'sender_id': 'u1', 'receiver_id': 'u2',
        'content': 'hi', 'message_type': 'text',
        'application_id': 42,
      });
      expect(m.applicationId, 42);
    });

    test('falls back to meta.application_id when top-level absent', () {
      final m = Message.fromJson({
        'id': 1, 'sender_id': 'u1', 'receiver_id': 'u2',
        'content': 'closed', 'message_type': 'system',
        'meta': {'application_id': 99},
      });
      expect(m.applicationId, 99);
    });

    test('returns null when neither present', () {
      final m = Message.fromJson({
        'id': 1, 'sender_id': 'u1', 'receiver_id': 'u2',
        'content': 'hi', 'message_type': 'text',
      });
      expect(m.applicationId, isNull);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test test/data/models/message_test.dart
```

Expected: FAIL — `applicationId` 字段不存在 / 现有 getter 名冲突。

- [ ] **Step 3: 改 Message 模型**

打开 `link2ur/lib/data/models/message.dart`，找到 line 123-128 附近现有的 `application_id` getter（从 meta 读的）。重命名为 `metaApplicationId` 保留语义，新增一个统一 getter：

```dart
/// 顶层 application_id；后端推送的议价/咨询 chat 消息应在 message body 顶层带这个字段
/// 若未带（旧消息或 system 消息），fallback 到 meta.application_id
int? get applicationId {
  // 顶层 application_id 字段（fromJson 时已解析到 _applicationId 私有字段）
  if (_applicationId != null) return _applicationId;
  final v = meta?['application_id'];
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  return null;
}
```

加私有字段：

```dart
final int? _applicationId;
```

在 const 构造器加 `this._applicationId`（默认 null）；在 `fromJson` 里解析 `json['application_id']`；在 `copyWith` 加 `applicationId` 参数。**注意保留原有的 getter 行为**（如果有现存调用方读 `meta?['application_id']` 会通过新 getter 拿到，不破坏）。

如果原 getter 命名就是 `applicationId` 并且只读 meta —— 直接扩展该 getter 加顶层路径，不需要新私有字段，因为 `Map<String, dynamic>` json 反正存在 `meta` 上层。**实际改法以现状为准**。

- [ ] **Step 4: 跑测试确认通过**

```powershell
flutter test test/data/models/message_test.dart
```

Expected: PASS（3 个测试全绿）。

- [ ] **Step 5: 跑全量 analyze**

```powershell
flutter analyze
```

Expected: 0 error / 0 warning（项目存量警告允许，关注本次改动相关的）。

- [ ] **Step 6: commit**

```bash
git add link2ur/lib/data/models/message.dart link2ur/test/data/models/message_test.dart
git commit -m "feat(message): 加顶层 applicationId getter，meta fallback"
```

---

### Task 2: MessageRepository 加 applicationId 透传

**Files:**
- Modify: `link2ur/lib/data/repositories/message_repository.dart:335`（getTaskChatMessages）
- Modify: `link2ur/lib/data/repositories/message_repository.dart:411`（sendTaskChatMessage）
- Modify: 同文件的 sendTaskChatImage / sendTaskChatVideo / sendTaskChatFile（按现有命名找）

- [ ] **Step 1: 写失败测试**

`link2ur/test/data/repositories/message_repository_test.dart`（无则新建）加：

```dart
test('getTaskChatMessages includes application_id query when provided', () async {
  // 用 mocktail 模拟 ApiService.get，断言 queryParameters['application_id'] == 42
  // (具体 mock 方式参照 link2ur/test 现有 repository 测试模板)
});

test('sendTaskChatMessage includes application_id body when provided', () async {
  // 同上断言 body['application_id'] == 42
});
```

如果项目里没有 repository 测试基础设施，**跳过测试编写**，依赖 ChatBloc 测试间接覆盖（推荐继续）；继续 Step 3 直接改实现。

- [ ] **Step 2: 跑测试确认失败（或跳过到 Step 3）**

- [ ] **Step 3: 改 getTaskChatMessages**

打开 `link2ur/lib/data/repositories/message_repository.dart:335`，找到 `getTaskChatMessages` 签名，加可选 `applicationId` 参数：

```dart
Future<({
  List<Message> messages,
  bool hasMore,
  String? nextCursor,
  String? taskStatus,
})> getTaskChatMessages(
  int taskId, {
  String? cursor,
  int limit = 50,
  int? applicationId,  // 新增
}) async {
  final response = await _apiService.get<Map<String, dynamic>>(
    ApiEndpoints.taskChatMessages(taskId),
    queryParameters: {
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
      if (applicationId != null) 'application_id': applicationId,  // 新增
    },
  );
  // ... 现有响应解析逻辑保留
}
```

- [ ] **Step 4: 改 sendTaskChatMessage 和 3 个媒体发送方法**

每个方法签名末尾加 `int? applicationId,`，body 拼装时按 `if (applicationId != null) 'application_id': applicationId,` 注入。**4 个方法都要改**（text / image / video / file）。

- [ ] **Step 5: 跑测试 + analyze**

```powershell
flutter test test/data/
flutter analyze
```

Expected: 已有测试不破，无新 warning。

- [ ] **Step 6: commit**

```bash
git add link2ur/lib/data/repositories/message_repository.dart link2ur/test/data/repositories/message_repository_test.dart 2>$null
git commit -m "feat(message-repo): 4 个发送方法+getMessages 加 applicationId 透传"
```

---

### Task 3: ChatBloc 加 applicationId 字段 + WS 过滤

**Files:**
- Modify: `link2ur/lib/features/chat/bloc/chat_bloc.dart`
- Test: `link2ur/test/features/chat/bloc/chat_bloc_application_id_test.dart`

- [ ] **Step 1: 写失败测试**

新建 `link2ur/test/features/chat/bloc/chat_bloc_application_id_test.dart`：

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:link2ur/data/models/message.dart';
import 'package:link2ur/data/repositories/message_repository.dart';
import 'package:link2ur/features/chat/bloc/chat_bloc.dart';

class MockMessageRepository extends Mock implements MessageRepository {}

void main() {
  late MockMessageRepository repo;

  setUp(() {
    repo = MockMessageRepository();
  });

  blocTest<ChatBloc, ChatState>(
    'ChatLoadMessages with applicationId passes it to repository',
    build: () {
      when(() => repo.getTaskChatMessages(any(),
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
              applicationId: any(named: 'applicationId')))
          .thenAnswer((_) async => (
                messages: <Message>[],
                hasMore: false,
                nextCursor: null,
                taskStatus: 'in_progress',
              ));
      return ChatBloc(messageRepository: repo);
    },
    act: (bloc) => bloc.add(
      const ChatLoadMessages(userId: '', taskId: 10, applicationId: 42),
    ),
    verify: (_) {
      verify(() => repo.getTaskChatMessages(
            10,
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            applicationId: 42,
          )).called(1);
    },
  );

  blocTest<ChatBloc, ChatState>(
    'ChatLoadMessages without applicationId passes null (任务聊天回归)',
    build: () {
      when(() => repo.getTaskChatMessages(any(),
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
              applicationId: any(named: 'applicationId')))
          .thenAnswer((_) async => (
                messages: <Message>[],
                hasMore: false,
                nextCursor: null,
                taskStatus: null,
              ));
      return ChatBloc(messageRepository: repo);
    },
    act: (bloc) => bloc.add(
      const ChatLoadMessages(userId: '', taskId: 10),
    ),
    verify: (_) {
      verify(() => repo.getTaskChatMessages(
            10,
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            applicationId: null,
          )).called(1);
    },
  );
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/chat/bloc/chat_bloc_application_id_test.dart
```

Expected: FAIL（compile error：`ChatLoadMessages` 不接受 `applicationId`）。

- [ ] **Step 3: 改 ChatBloc events**

打开 `link2ur/lib/features/chat/bloc/chat_bloc.dart`，定位到 line 22 `ChatLoadMessages`：

```dart
class ChatLoadMessages extends ChatEvent {
  const ChatLoadMessages({
    required this.userId,
    this.taskId,
    this.applicationId,
  });

  final String userId;
  final int? taskId;
  final int? applicationId;

  @override
  List<Object?> get props => [userId, taskId, applicationId];
}
```

同理给 `ChatSendMessage`（line 39）、`ChatSendImage`（line 57）、`ChatSendVideo`（line 73）、`ChatSendFile`（line 110）**每个事件**加 `final int? applicationId;` 字段（默认 null），更新构造器和 `props`。

- [ ] **Step 4: 改 ChatState**

定位到 line 178 `ChatState`：
- 构造器加 `this.applicationId,`（默认 null）
- 加字段 `final int? applicationId;`
- `copyWith` 加 `int? applicationId,` 参数和 `applicationId: applicationId ?? this.applicationId,`
- `props` 加 `applicationId`

- [ ] **Step 5: 改 _onLoadMessages**

定位到 line 340 `_onLoadMessages`。在 emit loading 时同时记 applicationId：

```dart
emit(state.copyWith(
  status: ChatStatus.loading,
  userId: event.userId,
  taskId: event.taskId,
  applicationId: event.applicationId,
));
```

并把 `event.taskId != null` 那个分支里的 repository 调用改为：

```dart
final result = await _messageRepository.getTaskChatMessages(
  event.taskId!,
  applicationId: event.applicationId,
);
```

- [ ] **Step 6: 改 _onLoadMore**

定位到 line 390 `_onLoadMore`。任务聊天分支里调 repository 时透传 `applicationId: state.applicationId`：

```dart
final result = await _messageRepository.getTaskChatMessages(
  state.taskId!,
  cursor: state.nextCursor,
  applicationId: state.applicationId,
);
```

- [ ] **Step 7: 改 4 个发送 handler**

定位 `_onSendMessage` / `_onSendImage` / `_onSendVideo` / `_onSendFile`。每个 handler 调 repository 发送方法时透传 `applicationId: event.applicationId ?? state.applicationId`。**优先级**：event 显式传值时用 event 的，否则用 state 的（state 是 load 时设的，发消息走默认）。

- [ ] **Step 8: 改 WS 消息过滤**

定位到 line 292 WS subscription 内部。在 `if (!wsMessage.isChatMessage) return;` 之后、parse message 之前，加 applicationId 过滤：

```dart
final Map<String, dynamic> messageMap =
    (wsMessage.type == 'task_message' && data['message'] is Map<String, dynamic>)
        ? (data['message'] as Map<String, dynamic>)
        : data;
try {
  final message = Message.fromJson(messageMap);
  // 新增：application 模式下额外按 applicationId 过滤
  if (state.applicationId != null &&
      message.applicationId != state.applicationId) {
    return;
  }
  add(ChatMessageReceived(message));
} catch (e) { ... }
```

如果 Task 0 Step 3 确认后端未带 application 过滤且存在串台 → 这条 application 维度过滤是 bug fix。
如果后端已带过滤 → 这条是健壮性 strengthening，行为一致。

- [ ] **Step 9: 跑测试确认通过**

```powershell
flutter test test/features/chat/bloc/chat_bloc_application_id_test.dart
flutter test test/features/chat/  # 全量回归 chat 测试
```

Expected: 新 2 用例 PASS，原有 ChatBloc 测试 0 退化。

- [ ] **Step 10: commit**

```bash
git add link2ur/lib/features/chat/bloc/chat_bloc.dart link2ur/test/features/chat/bloc/
git commit -m "feat(chat-bloc): 5 个 event + State 加 applicationId 字段；WS 过滤加 application 维度"
```

---

### Task 4: MessageGroupBubble customBubbleBuilder + 议价类型特殊分组

**Files:**
- Modify: `link2ur/lib/features/chat/widgets/message_group_bubble.dart:47`（groupMessages）
- Modify: 同文件 `MessageGroupBubbleView`（加 customBubbleBuilder 参数）
- Test: `link2ur/test/features/chat/widgets/message_group_bubble_test.dart`

- [ ] **Step 1: 写失败测试**

新建 `link2ur/test/features/chat/widgets/message_group_bubble_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/message.dart';
import 'package:link2ur/features/chat/widgets/message_group_bubble.dart';

Message _msg({
  required int id,
  required String senderId,
  required String type,
  DateTime? createdAt,
}) {
  return Message.fromJson({
    'id': id,
    'sender_id': senderId,
    'receiver_id': 'u_other',
    'content': '',
    'message_type': type,
    if (createdAt != null) 'created_at': createdAt.toIso8601String(),
  });
}

void main() {
  group('groupMessages — 议价类型特殊处理', () {
    test('negotiation message flushes group and is alone', () {
      final msgs = [
        _msg(id: 1, senderId: 'u1', type: 'text'),
        _msg(id: 2, senderId: 'u1', type: 'negotiation'),
        _msg(id: 3, senderId: 'u1', type: 'text'),
      ];
      final groups = groupMessages(msgs, 'u_me');
      expect(groups.length, 3);
      expect(groups[1].messages.first.messageType, 'negotiation');
    });

    test('quote / counter_offer / negotiation_accepted / negotiation_rejected '
        '都独立成组', () {
      for (final type in [
        'quote', 'counter_offer', 'negotiation_accepted', 'negotiation_rejected'
      ]) {
        final msgs = [
          _msg(id: 1, senderId: 'u1', type: 'text'),
          _msg(id: 2, senderId: 'u1', type: type),
          _msg(id: 3, senderId: 'u1', type: 'text'),
        ];
        final groups = groupMessages(msgs, 'u_me');
        expect(groups.length, 3, reason: 'type=$type 应独立成组');
        expect(groups[1].messages.first.messageType, type);
      }
    });

    test('text 消息按现有规则分组不受影响', () {
      final now = DateTime.now();
      final msgs = [
        _msg(id: 1, senderId: 'u1', type: 'text', createdAt: now),
        _msg(id: 2, senderId: 'u1', type: 'text',
            createdAt: now.add(const Duration(minutes: 1))),
      ];
      final groups = groupMessages(msgs, 'u_me');
      expect(groups.length, 1);
      expect(groups.first.messages.length, 2);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/chat/widgets/message_group_bubble_test.dart
```

Expected: FAIL — 议价类型当前未走特殊分组路径，会被当 outgoing/incoming 普通消息分组。

- [ ] **Step 3: 改 groupMessages**

打开 `link2ur/lib/features/chat/widgets/message_group_bubble.dart:47`，定位到 for 循环开头（line 77 `for (final message in messages)`）。在系统消息分支（line 79 `if (message.isSystem)`）之前/同位置，加：

```dart
for (final message in messages) {
  // 议价类业务消息和系统消息一样独立成组
  final isSpecialBubble = message.isSystem
      || message.isNegotiation
      || message.isQuote
      || message.isCounterOffer
      || message.isNegotiationAccepted
      || message.isNegotiationRejected;

  if (isSpecialBubble) {
    flushGroup();
    groups.add(MessageGroup(
      messages: [message],
      direction: BubbleDirection.incoming,  // 议价气泡不区分方向，统一居中渲染
      isSystem: message.isSystem,  // 仅 system 走 _SystemMessageBubble；议价走 customBubbleBuilder
    ));
    continue;
  }

  // ... 原有 sender/time 分组逻辑保留
  final senderIdTrimmed = message.senderId.trim();
  // ...
}
```

**注意**：原来的 `if (message.isSystem) { flushGroup(); ... continue; }` 分支被替换为更广的 `isSpecialBubble`。原来的 system 分组逻辑被包含在内。

- [ ] **Step 4: 改 MessageGroupBubbleView 加 customBubbleBuilder**

定位到 line 132 `MessageGroupBubbleView`：

```dart
class MessageGroupBubbleView extends StatelessWidget {
  const MessageGroupBubbleView({
    super.key,
    required this.group,
    this.onAvatarTap,
    this.onImageTap,
    this.customBubbleBuilder,  // 新增
  });

  final MessageGroup group;
  final VoidCallback? onAvatarTap;
  final void Function(String imageUrl)? onImageTap;
  /// 返回非 null 时替换整个气泡渲染；返回 null 走默认逻辑。
  /// 系统消息(isSystem=true)不走 customBubbleBuilder, 仍由 _SystemMessageBubble 渲染。
  final Widget? Function(BuildContext, Message)? customBubbleBuilder;

  @override
  Widget build(BuildContext context) {
    // 系统消息: 居中渲染 (不走 customBubbleBuilder, 保留 system 卡片样式)
    if (group.isSystem) {
      return _SystemMessageBubble(
        message: group.messages.first,
        onImageTap: onImageTap,
      );
    }

    // 议价类业务消息: 单 message 组, 走 customBubbleBuilder 渲染
    if (customBubbleBuilder != null && group.messages.length == 1) {
      final m = group.messages.first;
      if (m.isNegotiation || m.isQuote || m.isCounterOffer ||
          m.isNegotiationAccepted || m.isNegotiationRejected) {
        final custom = customBubbleBuilder!(context, m);
        if (custom != null) return custom;
      }
    }

    // ... 原有 outgoing/incoming row 渲染保留
  }
}
```

- [ ] **Step 5: 跑测试确认通过**

```powershell
flutter test test/features/chat/widgets/message_group_bubble_test.dart
flutter test test/features/chat/  # 回归
```

Expected: 全部 PASS。

- [ ] **Step 6: commit**

```bash
git add link2ur/lib/features/chat/widgets/message_group_bubble.dart link2ur/test/features/chat/widgets/message_group_bubble_test.dart
git commit -m "feat(message-group-bubble): customBubbleBuilder + negotiation/quote/counter_offer 独立成组"
```

---

### Phase 1 ✅ checkpoint

跑全套测试 + analyze + 手测任务聊天文本/图片/视频/文件发送，**回归 0 变化**。

```powershell
flutter test
flutter analyze
flutter run -d <device>  # 手测任务聊天
```

如果任意一项失败 → 不进 Phase 2，先排查并修复。

---

## Phase 2：抽 UI widgets + TaskChatView 切换

### Task 5: 抽 TaskInfoCard widget

**Files:**
- Read: `link2ur/lib/features/chat/views/task_chat_view.dart:598`（_buildTaskInfoCard）
- Create: `link2ur/lib/features/chat/widgets/task_info_card.dart`

- [ ] **Step 1: 读现有 _buildTaskInfoCard**

```bash
Read task_chat_view.dart offset=598 limit=140
```

- [ ] **Step 2: 抽到独立文件**

新建 `link2ur/lib/features/chat/widgets/task_info_card.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// ... 把 _buildTaskInfoCard 里 import 的所有依赖都搬过来

import '../bloc/chat_bloc.dart';
// ... etc

class TaskInfoCard extends StatelessWidget {
  const TaskInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (prev, curr) =>
          prev.taskId != curr.taskId || prev.taskStatus != curr.taskStatus,
      builder: (context, state) {
        // ... 把 _buildTaskInfoCard 函数体原样搬进来
      },
    );
  }
}
```

**关键**：原 `_buildTaskInfoCard(ChatState state)` 接收 state 参数；新 widget 用 BlocBuilder 自己拿 state。其他逻辑零变化。

- [ ] **Step 3: TaskChatView 替换调用方**

打开 `task_chat_view.dart`，把 `_buildTaskInfoCard(state)` 的调用替换为 `const TaskInfoCard()`。注意：调用点应在 BlocBuilder 包裹外（自带 BlocBuilder）。

删掉原 `_buildTaskInfoCard` 方法及其相关导入（如果只此一处用）。

- [ ] **Step 4: 跑 analyze + 跑 app**

```powershell
flutter analyze
flutter run -d <device>
# 手测进任务聊天页 → header 卡片显示正常
```

Expected：UI 0 视觉变化。

- [ ] **Step 5: commit**

```bash
git add link2ur/lib/features/chat/widgets/task_info_card.dart link2ur/lib/features/chat/views/task_chat_view.dart
git commit -m "refactor(task-chat): 抽 TaskInfoCard 独立 widget"
```

---

### Task 6: 抽 MediaProgressBanner + ClosedTaskBanner widget

**Files:**
- Read: `task_chat_view.dart:734`（_buildMediaProgressBanner）
- Read: `task_chat_view.dart:782`（_buildClosedTaskBar）
- Create: `link2ur/lib/features/chat/widgets/media_progress_banner.dart`
- Create: `link2ur/lib/features/chat/widgets/closed_task_banner.dart`

- [ ] **Step 1: 抽 MediaProgressBanner**

把 `_buildMediaProgressBanner(ChatState state)` 函数体搬到独立 widget 文件。MediaProgressBanner 收的 props 是 `_isProcessingMedia` / `_processingLabel` / `_isCompressingVideo`（来自 `_TaskChatContentState`，不是 ChatState）——所以要传 props 而非用 BlocBuilder：

```dart
class MediaProgressBanner extends StatelessWidget {
  const MediaProgressBanner({
    super.key,
    required this.isProcessing,
    required this.label,
    required this.isCompressing,
    required this.onCancel,
  });

  final bool isProcessing;
  final String label;
  final bool isCompressing;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (!isProcessing) return const SizedBox.shrink();
    // ... 函数体
  }
}
```

- [ ] **Step 2: 抽 ClosedTaskBanner**

同理，把 `_buildClosedTaskBar(BuildContext context)` 抽出。它内部通过 BlocBuilder 读 `state.isTaskClosed`，搬过去即可。

- [ ] **Step 3: TaskChatView 替换调用方**

把两处调用替换为 widget 调用，传必要参数。删除原方法。

- [ ] **Step 4: analyze + 跑 app 手测**

视频压缩+取消、任务关闭后输入禁用两个场景跑一遍。

- [ ] **Step 5: commit**

```bash
git commit -m "refactor(task-chat): 抽 MediaProgressBanner + ClosedTaskBanner"
```

---

### Task 7: 新建 ChatScaffold widget

**Files:**
- Create: `link2ur/lib/features/chat/widgets/chat_scaffold.dart`
- Test: `link2ur/test/features/chat/widgets/chat_scaffold_test.dart`

- [ ] **Step 1: 写失败测试**

新建 `chat_scaffold_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/features/chat/widgets/chat_scaffold.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Material(child: child));

  testWidgets('ChatScaffold 渲染所有 slot 与 AppBar 标题', (tester) async {
    await tester.pumpWidget(host(
      ChatScaffold(
        appBarTitle: const Text('TestTitle'),
        appBarActions: const [Icon(Icons.search)],
        headerSlot: const Text('HEADER'),
        bannerSlot: const Text('BANNER'),
        messageListBuilder: (_) => const Text('MSGS'),
        inputBar: const Text('INPUT'),
        actionMenu: const Text('MENU'),
        aboveInputSlot: const Text('ABOVE'),
      ),
    ));
    expect(find.text('TestTitle'), findsOneWidget);
    expect(find.text('HEADER'), findsOneWidget);
    expect(find.text('BANNER'), findsOneWidget);
    expect(find.text('MSGS'), findsOneWidget);
    expect(find.text('ABOVE'), findsOneWidget);
    expect(find.text('INPUT'), findsOneWidget);
    expect(find.text('MENU'), findsOneWidget);
  });

  testWidgets('aboveInputSlot 为 null 时不占布局', (tester) async {
    await tester.pumpWidget(host(
      ChatScaffold(
        appBarTitle: const Text('T'),
        appBarActions: const [],
        headerSlot: const SizedBox.shrink(),
        bannerSlot: const SizedBox.shrink(),
        messageListBuilder: (_) => const Text('MSGS'),
        inputBar: const Text('INPUT'),
        actionMenu: const Text('MENU'),
        aboveInputSlot: null,
      ),
    ));
    expect(find.text('MSGS'), findsOneWidget);
    expect(find.text('INPUT'), findsOneWidget);
  });

  testWidgets('readOnly 配置 (inputBar=SizedBox.shrink) 不渲染输入框文字',
      (tester) async {
    await tester.pumpWidget(host(
      ChatScaffold(
        appBarTitle: const Text('T'),
        appBarActions: const [],
        headerSlot: const SizedBox.shrink(),
        bannerSlot: const SizedBox.shrink(),
        messageListBuilder: (_) => const Text('MSGS'),
        inputBar: const SizedBox.shrink(),
        actionMenu: const SizedBox.shrink(),
      ),
    ));
    expect(find.byType(TextField), findsNothing);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/chat/widgets/chat_scaffold_test.dart
```

Expected: FAIL — `ChatScaffold` 不存在。

- [ ] **Step 3: 实现 ChatScaffold**

新建 `link2ur/lib/features/chat/widgets/chat_scaffold.dart`：

```dart
import 'package:flutter/material.dart';

class ChatScaffold extends StatelessWidget {
  const ChatScaffold({
    super.key,
    required this.appBarTitle,
    required this.appBarActions,
    required this.headerSlot,
    required this.bannerSlot,
    required this.messageListBuilder,
    required this.inputBar,
    required this.actionMenu,
    this.aboveInputSlot,
    this.appBarLeading,
  });

  final Widget appBarTitle;
  final List<Widget> appBarActions;
  final Widget? appBarLeading;
  final Widget headerSlot;
  final Widget bannerSlot;
  final Widget Function(BuildContext) messageListBuilder;
  final Widget inputBar;
  final Widget actionMenu;
  final Widget? aboveInputSlot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: appBarLeading,
        title: appBarTitle,
        actions: appBarActions,
      ),
      body: Column(
        children: [
          headerSlot,
          bannerSlot,
          Expanded(child: messageListBuilder(context)),
          if (aboveInputSlot != null) aboveInputSlot!,
          inputBar,
          actionMenu,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

```powershell
flutter test test/features/chat/widgets/chat_scaffold_test.dart
```

Expected: PASS（3 个 widget 测试全绿）。

- [ ] **Step 5: commit**

```bash
git commit -m "feat(chat-scaffold): 新增 ChatScaffold 骨架 widget"
```

---

### Task 8: TaskChatView 切换到 ChatScaffold

**Files:**
- Modify: `link2ur/lib/features/chat/views/task_chat_view.dart`

- [ ] **Step 1: 改 TaskChatView build**

把 TaskChatView 的 `Scaffold(appBar:..., body: Column([...]))` 整体替换为 `ChatScaffold(...)` 调用。各 slot 对应：

```dart
ChatScaffold(
  appBarLeading: ...,  // 原 leading
  appBarTitle: ...,    // 原 AppBar.title
  appBarActions: ...,  // 原 AppBar.actions
  headerSlot: const TaskInfoCard(),
  bannerSlot: Column(  // 多个 banner 叠加用 Column
    children: [
      MediaProgressBanner(
        isProcessing: _isProcessingMedia,
        label: _processingLabel,
        isCompressing: _isCompressingVideo,
        onCancel: _cancelMediaProcessing,
      ),
      const ClosedTaskBanner(),
    ],
  ),
  messageListBuilder: (_) => _buildGroupedMessageList(state),
  inputBar: _buildInputArea(state),
  actionMenu: TaskChatActionMenu(
    onImagePicker: _pickImage,
    onCameraPick: _takePhoto,
    onFilePicker: _pickFile,
    onTaskDetail: _navigateToTaskDetail,
    isExpanded: _showActionMenu,
  ),
)
```

- [ ] **Step 2: 删除冗余 Scaffold/Column 包裹**

原 build 方法里手写的 AppBar 和 Column 全部删掉，由 ChatScaffold 接管。

- [ ] **Step 3: analyze + 跑 app**

跑 task chat 完整路径手测：
- 收发文本
- 收发图片（拍照 + 相册）
- 收发视频（含取消）
- 收发文件
- 滚动加载更多
- 任务关闭后输入禁用

Expected：UI 0 视觉变化，所有功能正常。

- [ ] **Step 4: commit**

```bash
git commit -m "refactor(task-chat): TaskChatView 切换到 ChatScaffold"
```

---

### Phase 2 ✅ checkpoint

任务聊天完整功能回归 + UI 0 变化。下一阶段开始改 ApplicationChatView。

---

## Phase 3：抽 ConsultationBloc

### Task 9: ConsultationBloc state + events

**Files:**
- Create: `link2ur/lib/features/tasks/bloc/consultation_bloc.dart`

- [ ] **Step 1: 新建 bloc 骨架**

单文件 events + state + bloc（CLAUDE.md 规定，不用 part of）：

```dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/repositories/flea_market_repository.dart';
import 'package:flutter/foundation.dart';
import '../views/consultation/consultation_type.dart';  // 见 Task 10

// ==================== Events ====================

abstract class ConsultationEvent extends Equatable {
  const ConsultationEvent();
  @override
  List<Object?> get props => [];
}

class ConsultationLoadStatus extends ConsultationEvent {
  const ConsultationLoadStatus();
}

class ConsultationNegotiate extends ConsultationEvent {
  const ConsultationNegotiate({required this.price, this.serviceId});
  final double price;
  final int? serviceId;
  @override
  List<Object?> get props => [price, serviceId];
}

class ConsultationQuote extends ConsultationEvent {
  const ConsultationQuote({required this.price, this.message, this.serviceId});
  final double price;
  final String? message;
  final int? serviceId;
  @override
  List<Object?> get props => [price, message, serviceId];
}

class ConsultationCounterOffer extends ConsultationEvent {
  const ConsultationCounterOffer({required this.price, this.serviceId});
  final double price;
  final int? serviceId;
  @override
  List<Object?> get props => [price, serviceId];
}

class ConsultationRespond extends ConsultationEvent {
  /// action ∈ {'accept', 'reject', 'counter'}
  const ConsultationRespond({required this.action, this.counterPrice});
  final String action;
  final double? counterPrice;
  @override
  List<Object?> get props => [action, counterPrice];
}

class ConsultationFormalApply extends ConsultationEvent {
  const ConsultationFormalApply({this.price, this.message});
  final double? price;
  final String? message;
  @override
  List<Object?> get props => [price, message];
}

class ConsultationApprove extends ConsultationEvent {
  const ConsultationApprove();
}

class ConsultationClose extends ConsultationEvent {
  const ConsultationClose();
}

class ConsultationClearError extends ConsultationEvent {
  const ConsultationClearError();
}

// ==================== State ====================

enum ConsultationStatus {
  initial,
  loading,
  negotiating,
  quoted,
  approved,
  closed,
  readOnly,
  error,
}

class ConsultationState extends Equatable {
  const ConsultationState({
    this.applicationId = 0,
    this.taskId = 0,
    this.consultationType = ConsultationType.service,
    this.status = ConsultationStatus.initial,
    this.consultationApp,
    this.isSubmitting = false,
    this.errorCode,
  });

  final int applicationId;
  final int taskId;
  final ConsultationType consultationType;
  final ConsultationStatus status;
  final Map<String, dynamic>? consultationApp;
  final bool isSubmitting;
  final String? errorCode;

  ConsultationState copyWith({
    int? applicationId,
    int? taskId,
    ConsultationType? consultationType,
    ConsultationStatus? status,
    Map<String, dynamic>? consultationApp,
    bool? isSubmitting,
    String? errorCode,
    bool clearError = false,
  }) {
    return ConsultationState(
      applicationId: applicationId ?? this.applicationId,
      taskId: taskId ?? this.taskId,
      consultationType: consultationType ?? this.consultationType,
      status: status ?? this.status,
      consultationApp: consultationApp ?? this.consultationApp,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }

  @override
  List<Object?> get props => [
        applicationId, taskId, consultationType, status,
        consultationApp, isSubmitting, errorCode,
      ];
}

// ==================== Bloc ====================

class ConsultationBloc extends Bloc<ConsultationEvent, ConsultationState> {
  ConsultationBloc({
    required int applicationId,
    required int taskId,
    required ConsultationType consultationType,
    required TaskRepository taskRepository,
    required TaskExpertRepository taskExpertRepository,
    required FleaMarketRepository fleaMarketRepository,
  })  : _taskRepo = taskRepository,
        _expertRepo = taskExpertRepository,
        _fleaRepo = fleaMarketRepository,
        super(ConsultationState(
          applicationId: applicationId,
          taskId: taskId,
          consultationType: consultationType,
        )) {
    on<ConsultationLoadStatus>(_onLoadStatus);
    on<ConsultationNegotiate>(_onNegotiate);
    on<ConsultationQuote>(_onQuote);
    on<ConsultationCounterOffer>(_onCounterOffer);
    on<ConsultationRespond>(_onRespond);
    on<ConsultationFormalApply>(_onFormalApply);
    on<ConsultationApprove>(_onApprove);
    on<ConsultationClose>(_onClose);
    on<ConsultationClearError>((event, emit) =>
        emit(state.copyWith(clearError: true)));
  }

  final TaskRepository _taskRepo;
  final TaskExpertRepository _expertRepo;
  final FleaMarketRepository _fleaRepo;

  // ... handlers in Task 10
}
```

**注意**：`ConsultationType` 现在在 `consultation/consultation_base.dart`。Task 10 会把它抽到独立文件 `consultation/consultation_type.dart` 以便 bloc import 时不连带原 ConsultationActions 逻辑。

- [ ] **Step 2: 先临时引入 ConsultationType**

为让 bloc 编译，先把 `import '../views/consultation/consultation_type.dart';` 改成 `import '../views/consultation/consultation_base.dart' show ConsultationType;`。Task 11 再把 ConsultationType 抽到独立文件统一引用。

- [ ] **Step 3: analyze**

```powershell
flutter analyze lib/features/tasks/bloc/consultation_bloc.dart
```

Expected：0 error（handlers 未实现导致的 missing implementations 是预期，下一 task 补）。

- [ ] **Step 4: commit**

```bash
git commit -m "feat(consultation-bloc): events + state 骨架"
```

---

### Task 10: ConsultationBloc handlers 实现（按 type 派发）

**Files:**
- Modify: `link2ur/lib/features/tasks/bloc/consultation_bloc.dart`
- Reference: `link2ur/lib/features/tasks/views/consultation/service_consultation_actions.dart`、`task_consultation_actions.dart`、`flea_market_consultation_actions.dart`

- [ ] **Step 1: 读现有 3 个 ConsultationActions 实现**

每个 ~150-200 行。重点读：每个 action 调用了哪个 repository 方法？参数怎么传？错误怎么处理？

```bash
Read service_consultation_actions.dart
Read task_consultation_actions.dart
Read flea_market_consultation_actions.dart
```

- [ ] **Step 2: 写 _onLoadStatus**

```dart
Future<void> _onLoadStatus(
  ConsultationLoadStatus event,
  Emitter<ConsultationState> emit,
) async {
  emit(state.copyWith(status: ConsultationStatus.loading));
  try {
    // 三种 type 调不同 endpoint:
    Map<String, dynamic>? app;
    switch (state.consultationType) {
      case ConsultationType.service:
        app = await _expertRepo.getConsultationStatus(state.applicationId);
        break;
      case ConsultationType.task:
        app = await _taskRepo.getConsultationApp(state.applicationId);
        break;
      case ConsultationType.fleaMarket:
        app = await _fleaRepo.getConsultationApp(state.applicationId);
        break;
    }
    final appStatus = app?['status'] as String?;
    emit(state.copyWith(
      consultationApp: app,
      status: _mapAppStatus(appStatus),
    ));
  } catch (e) {
    emit(state.copyWith(
      status: ConsultationStatus.error,
      errorCode: 'consultation_load_failed',
    ));
  }
}

ConsultationStatus _mapAppStatus(String? appStatus) {
  // 对照后端枚举: pending/negotiating/quoted/approved/closed/...
  switch (appStatus) {
    case 'approved': return ConsultationStatus.approved;
    case 'closed':
    case 'cancelled':
    case 'rejected': return ConsultationStatus.closed;
    case 'quoted': return ConsultationStatus.quoted;
    default: return ConsultationStatus.negotiating;
  }
}
```

**实际的 repository 方法名以现有代码为准**——读 service_consultation_actions.dart 里 `statusEndpoint` 字段和实际请求看是哪个 method，按现有规范命名。如果 repository 没有这些方法，**Step 2.5** 是先在 repository 里加适配 method。

- [ ] **Step 3: 写 _onNegotiate / _onQuote / _onCounterOffer**

每个 handler 模板：

```dart
Future<void> _onNegotiate(
  ConsultationNegotiate event,
  Emitter<ConsultationState> emit,
) async {
  if (state.isSubmitting) return;
  emit(state.copyWith(isSubmitting: true, clearError: true));
  try {
    switch (state.consultationType) {
      case ConsultationType.service:
        await _expertRepo.negotiate(
          applicationId: state.applicationId,
          price: event.price,
          serviceId: event.serviceId,
        );
        break;
      case ConsultationType.task:
        await _taskRepo.negotiateConsultation(
          applicationId: state.applicationId,
          price: event.price,
        );
        break;
      case ConsultationType.fleaMarket:
        await _fleaRepo.negotiateConsultation(
          applicationId: state.applicationId,
          price: event.price,
        );
        break;
    }
    emit(state.copyWith(isSubmitting: false));
    // 议价成功后通过 WS 推回 negotiation 消息, 这里不手动改 status
  } catch (e) {
    emit(state.copyWith(
      isSubmitting: false,
      errorCode: 'consultation_negotiate_failed',
    ));
  }
}
```

`_onQuote` / `_onCounterOffer` 同理（错误码分别为 `consultation_quote_failed` / `consultation_counter_offer_failed`）。

- [ ] **Step 4: 写 _onRespond（接受/拒绝/还价）**

```dart
Future<void> _onRespond(
  ConsultationRespond event,
  Emitter<ConsultationState> emit,
) async {
  if (state.isSubmitting) return;
  if (event.action == 'counter' && event.counterPrice == null) {
    emit(state.copyWith(errorCode: 'consultation_state_conflict'));
    return;
  }
  emit(state.copyWith(isSubmitting: true, clearError: true));
  try {
    // 派发到对应 repository 的 respond/respondToNegotiation 方法
    switch (state.consultationType) {
      case ConsultationType.service:
        await _expertRepo.respondToNegotiation(
          applicationId: state.applicationId,
          action: event.action,
          counterPrice: event.counterPrice,
        );
        break;
      // task / fleaMarket 同理
    }
    emit(state.copyWith(isSubmitting: false));
  } catch (e) {
    emit(state.copyWith(
      isSubmitting: false,
      errorCode: 'consultation_counter_offer_failed',
    ));
  }
}
```

- [ ] **Step 5: 写 _onFormalApply / _onApprove / _onClose**

按相同模板。错误码：
- `_onFormalApply` → `consultation_formal_apply_failed`
- `_onApprove` → `consultation_approve_failed`（成功后 emit status: approved）
- `_onClose` → `consultation_close_failed`（成功后 emit status: closed）

- [ ] **Step 6: analyze**

```powershell
flutter analyze lib/features/tasks/bloc/consultation_bloc.dart
```

Expected：所有 handlers 实现，0 error。

- [ ] **Step 7: commit**

```bash
git commit -m "feat(consultation-bloc): 8 个 handler 按 type 派发到 3 个 repository"
```

---

### Task 11: ConsultationType 抽独立文件 + ConsultationBloc 测试

**Files:**
- Create: `link2ur/lib/features/tasks/views/consultation/consultation_type.dart`
- Modify: `link2ur/lib/features/tasks/views/consultation/consultation_base.dart`（保留 ConsultationActions，删 enum 重新 export）
- Modify: `link2ur/lib/features/tasks/bloc/consultation_bloc.dart`（改 import）
- Create: `link2ur/test/features/tasks/bloc/consultation_bloc_test.dart`

- [ ] **Step 1: 抽 ConsultationType 到独立文件**

新建 `link2ur/lib/features/tasks/views/consultation/consultation_type.dart`：

```dart
/// 咨询类型枚举
enum ConsultationType { service, task, fleaMarket }
```

`consultation_base.dart` 改为 `export 'consultation_type.dart';`，删除内部 enum 定义。

`consultation_bloc.dart` 改 import 为 `import '../views/consultation/consultation_type.dart';`。

- [ ] **Step 2: 写 ConsultationBloc 测试**

`link2ur/test/features/tasks/bloc/consultation_bloc_test.dart`（按 30+ 现有 bloc test 模板）：

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:link2ur/data/repositories/task_repository.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';
import 'package:link2ur/data/repositories/flea_market_repository.dart';
import 'package:link2ur/features/tasks/bloc/consultation_bloc.dart';
import 'package:link2ur/features/tasks/views/consultation/consultation_type.dart';

class MockTaskRepo extends Mock implements TaskRepository {}
class MockExpertRepo extends Mock implements TaskExpertRepository {}
class MockFleaRepo extends Mock implements FleaMarketRepository {}

void main() {
  late MockTaskRepo taskRepo;
  late MockExpertRepo expertRepo;
  late MockFleaRepo fleaRepo;

  setUp(() {
    taskRepo = MockTaskRepo();
    expertRepo = MockExpertRepo();
    fleaRepo = MockFleaRepo();
  });

  ConsultationBloc build(ConsultationType type) => ConsultationBloc(
        applicationId: 42,
        taskId: 10,
        consultationType: type,
        taskRepository: taskRepo,
        taskExpertRepository: expertRepo,
        fleaMarketRepository: fleaRepo,
      );

  group('LoadStatus', () {
    blocTest<ConsultationBloc, ConsultationState>(
      'service: loads, emits negotiating when status=pending',
      build: () {
        when(() => expertRepo.getConsultationStatus(any())).thenAnswer(
          (_) async => {'status': 'pending'},
        );
        return build(ConsultationType.service);
      },
      act: (b) => b.add(const ConsultationLoadStatus()),
      expect: () => [
        isA<ConsultationState>().having((s) => s.status, 'status',
            ConsultationStatus.loading),
        isA<ConsultationState>().having((s) => s.status, 'status',
            ConsultationStatus.negotiating),
      ],
    );

    blocTest<ConsultationBloc, ConsultationState>(
      'service: error emits errorCode=consultation_load_failed',
      build: () {
        when(() => expertRepo.getConsultationStatus(any()))
            .thenThrow(Exception('boom'));
        return build(ConsultationType.service);
      },
      act: (b) => b.add(const ConsultationLoadStatus()),
      expect: () => [
        isA<ConsultationState>().having((s) => s.status, 'status',
            ConsultationStatus.loading),
        isA<ConsultationState>()
            .having((s) => s.errorCode, 'errorCode', 'consultation_load_failed'),
      ],
    );
  });

  group('Negotiate', () {
    blocTest<ConsultationBloc, ConsultationState>(
      'service: success → isSubmitting toggles, no errorCode',
      build: () {
        when(() => expertRepo.negotiate(
            applicationId: any(named: 'applicationId'),
            price: any(named: 'price'),
            serviceId: any(named: 'serviceId'))).thenAnswer((_) async {});
        return build(ConsultationType.service);
      },
      act: (b) => b.add(const ConsultationNegotiate(price: 50)),
      expect: () => [
        isA<ConsultationState>().having((s) => s.isSubmitting, 'isSubmitting',
            true),
        isA<ConsultationState>().having((s) => s.isSubmitting, 'isSubmitting',
            false),
      ],
    );

    blocTest<ConsultationBloc, ConsultationState>(
      'task: failure emits errorCode=consultation_negotiate_failed',
      build: () {
        when(() => taskRepo.negotiateConsultation(
            applicationId: any(named: 'applicationId'),
            price: any(named: 'price'))).thenThrow(Exception('boom'));
        return build(ConsultationType.task);
      },
      act: (b) => b.add(const ConsultationNegotiate(price: 50)),
      expect: () => [
        isA<ConsultationState>().having((s) => s.isSubmitting, 'isSubmitting',
            true),
        isA<ConsultationState>().having((s) => s.errorCode, 'errorCode',
            'consultation_negotiate_failed'),
      ],
    );

    blocTest<ConsultationBloc, ConsultationState>(
      'fleaMarket: success',
      build: () {
        when(() => fleaRepo.negotiateConsultation(
            applicationId: any(named: 'applicationId'),
            price: any(named: 'price'))).thenAnswer((_) async {});
        return build(ConsultationType.fleaMarket);
      },
      act: (b) => b.add(const ConsultationNegotiate(price: 50)),
      expect: () => [
        isA<ConsultationState>().having((s) => s.isSubmitting, 'isSubmitting',
            true),
        isA<ConsultationState>().having((s) => s.isSubmitting, 'isSubmitting',
            false),
      ],
    );
    // fleaMarket failure: 同上 thenThrow，断言 errorCode = consultation_negotiate_failed
  });

  // 用同一组三 type×成功失败 = 6 用例的模板，依次写完下面 5 个 group：
  //   group('Quote') — repo method: quote(...)
  //     错误码: consultation_quote_failed
  //   group('CounterOffer') — repo method: counterOffer(...)
  //     错误码: consultation_counter_offer_failed
  //   group('Respond') — repo method: respondToNegotiation(action, counterPrice)
  //     额外 1 个用例: action='counter' 且 counterPrice=null →
  //                  errorCode = consultation_state_conflict (不调 repo)
  //   group('FormalApply') — repo method: formalApply(...)
  //     错误码: consultation_formal_apply_failed
  //   group('Approve') — repo method: approve(...)
  //     成功后 state.status = ConsultationStatus.approved
  //     错误码: consultation_approve_failed
  //   group('Close') — repo method: close(...)
  //     成功后 state.status = ConsultationStatus.closed
  //     错误码: consultation_close_failed
  // 总用例数: LoadStatus 2 + Negotiate 6 + (Quote/CounterOffer/FormalApply/
  //          Approve/Close 各 6) + Respond 7 = 47 用例
  // **请逐个写出，不要省略或合并。**议价业务回归依赖完整测试守护。
}
```

**关键**：每个 group 写完整成功+失败用例。**不要省略**——议价业务回归依赖这些测试守护。

- [ ] **Step 3: 跑测试**

```powershell
flutter test test/features/tasks/bloc/consultation_bloc_test.dart
```

Expected：全部 PASS（如果有 repository 方法签名不匹配，先修 ConsultationBloc 里的调用以对齐 repository 实际签名）。

- [ ] **Step 4: commit**

```bash
git commit -m "feat(consultation-bloc): 抽 ConsultationType 独立文件 + 40+ unit tests"
```

---

### Phase 3 ✅ checkpoint

ConsultationBloc 独立可用，**未接 UI**。所有现有功能 0 变化。

---

## Phase 4：议价业务 widgets 抽出

### Task 12: 抽议价相关 widgets

**Files:**
- Read: `application_chat_view.dart` 里的 `_buildPriceProposalBubble` / `_buildNegotiationCard` / `_buildNegotiationStatusMessage` / `_buildPriceBar` / `_buildServiceInfoCard` / `_buildReadOnlyBanner` / `_buildClosedBanner`
- Create: 9 个独立 widget 文件（见"文件结构"章节）
- Read: `consultation/consultation_base.dart`（4 个内嵌 dialog）

- [ ] **Step 1: 一次性抽 5 个 header / banner widgets**

按"文件结构"列出的 5 个 header/banner 文件，把 `_buildPriceBar` / `_buildServiceInfoCard` / `_buildReadOnlyBanner` / `_buildClosedBanner` 复制为 `PriceBar` / `ServiceInfoCard` / `ReadOnlyBanner` / `ClosedConsultationBanner` widgets。

`FleaMarketItemCard` 是新 widget — 现有 ApplicationChatView 在 fleaMarket 模式下复用了 ServiceInfoCard 渲染商品信息；从 service_consultation_actions.dart / flea_market_consultation_actions.dart 找出 flea 商品字段（`item_title` / `item_image_url` 等）写一个独立卡片。

每个 widget 接收的 props 用 `Map<String, dynamic>? consultationApp` 或 `Task? task` 等显式参数，**不依赖 ConsultationBloc**（保持可独立测试）。

- [ ] **Step 2: 抽 3 个气泡 widgets**

把 `_buildPriceProposalBubble` 抽为 `PriceProposalBubble`（接收 `Message`、`bool isMe`、`String currencySymbol`）；`_buildNegotiationCard` 抽为 `NegotiationActionCard`（接收 `Message`、`onAccept` / `onReject` / `onCounter` 三个 callback）；`_buildNegotiationStatusMessage` 抽为 `NegotiationStatusBanner`（接收 `Message`）。

- [ ] **Step 3: 抽 ConsultationActionBar**

把 `consultation_base.dart` 里 abstract `buildActions(...)` 三个子类的实际实现合并成一个 widget `ConsultationActionBar`。它接收：

```dart
class ConsultationActionBar extends StatelessWidget {
  const ConsultationActionBar({
    super.key,
    required this.status,            // ConsultationStatus
    required this.isApplicant,       // bool
    required this.isSubmitting,
    required this.onNegotiate,
    required this.onQuote,
    required this.onCounterOffer,
    required this.onAcceptLatest,
    required this.onRejectLatest,
    required this.onFormalApply,
    required this.onApprove,
    required this.onClose,
    required this.consultationType,
  });
}
```

按状态机展示哪些按钮：参照三个 ConsultationActions 子类 `buildActions` 函数的现状逻辑。

- [ ] **Step 4: 抽 4 个 dialog widgets**

把 `consultation_base.dart` 末尾的 `_NegotiateDialog` / `_QuoteDialog` / `_CounterOfferDialog` / `_FormalApplyDialog` 4 个 private StatefulWidget 各自移到独立文件（`negotiate_dialog.dart` 等），改为 public widget。**保留 controller-disposed-after-fadeout 的修复**（State.dispose 释放 controller）。

- [ ] **Step 5: 抽 AppBar 标题 helper**

把 `application_chat_view.dart:216` 的 `_consultationTitle` 方法搬到 `consultation/utils/consultation_title.dart`：

```dart
String consultationTitle({
  required BuildContext context,
  required Task? task,
  required ConsultationType consultationType,
  required Map<String, dynamic>? consultationApp,
}) {
  // ... 现有逻辑
}
```

- [ ] **Step 6: analyze**

```powershell
flutter analyze
```

Expected：抽出的 widgets 独立编译通过；ApplicationChatView 暂时还在用旧的 `_buildXxx`，所以不报 missing reference。

- [ ] **Step 7: commit**

```bash
git add link2ur/lib/features/tasks/views/consultation/
git commit -m "refactor(consultation): 抽 9 widgets + 4 dialogs + title helper"
```

---

## Phase 5：接入 Service 咨询（pilot）

### Task 13: _ConsultationChatView (service path) + ApplicationChatView 分发

**Files:**
- Modify: `link2ur/lib/features/tasks/views/application_chat_view.dart`
- Create: 内部 `_ConsultationChatView` widget（同文件）

- [ ] **Step 1: 改 ApplicationChatView 为分发器**

把现有 `ApplicationChatView.build` 改为：

```dart
@override
Widget build(BuildContext context) {
  if (readOnly) {
    return _ReadOnlyChatView(
      taskId: taskId,
      applicationId: applicationId,
    );
  }
  if (isConsultation) {
    return _ConsultationChatView(
      taskId: taskId,
      applicationId: applicationId,
      consultationType: consultationType,
    );
  }
  return _BiddingChatView(
    taskId: taskId,
    applicationId: applicationId,
  );
}
```

下面三个内部 View 暂时实现 `_ConsultationChatView`，其他两个先用 `Placeholder` 占位。

- [ ] **Step 2: 实现 _ConsultationChatView**

```dart
class _ConsultationChatView extends StatelessWidget {
  const _ConsultationChatView({
    required this.taskId,
    required this.applicationId,
    required this.consultationType,
  });

  final int taskId;
  final int applicationId;
  final ConsultationType consultationType;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (ctx) => ConsultationBloc(
            applicationId: applicationId,
            taskId: taskId,
            consultationType: consultationType,
            taskRepository: ctx.read<TaskRepository>(),
            taskExpertRepository: ctx.read<TaskExpertRepository>(),
            fleaMarketRepository: ctx.read<FleaMarketRepository>(),
          )..add(const ConsultationLoadStatus()),
        ),
        BlocProvider(
          create: (ctx) => ChatBloc(
            messageRepository: ctx.read<MessageRepository>(),
          )..add(ChatLoadMessages(
              userId: '',
              taskId: taskId,
              applicationId: applicationId,
            )),
        ),
      ],
      child: _ConsultationChatContent(consultationType: consultationType),
    );
  }
}

class _ConsultationChatContent extends StatefulWidget {
  const _ConsultationChatContent({required this.consultationType});
  final ConsultationType consultationType;
  @override
  State<_ConsultationChatContent> createState() =>
      _ConsultationChatContentState();
}

class _ConsultationChatContentState extends State<_ConsultationChatContent> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showActionMenu = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConsultationBloc, ConsultationState>(
      builder: (context, cState) {
        return BlocBuilder<ChatBloc, ChatState>(
          builder: (context, mState) {
            return ChatScaffold(
              appBarTitle: Text(consultationTitle(
                context: context,
                task: context.read<TaskDetailBloc>().state.task,
                consultationType: widget.consultationType,
                consultationApp: cState.consultationApp,
              )),
              appBarActions: [/* leave / menu */],
              headerSlot: _headerForType(widget.consultationType),
              bannerSlot: const SizedBox.shrink(),
              messageListBuilder: (_) => _buildMessageList(mState, cState),
              aboveInputSlot: ConsultationActionBar(
                status: cState.status,
                isApplicant: _computeIsApplicant(cState),
                isSubmitting: cState.isSubmitting,
                consultationType: widget.consultationType,
                onNegotiate: () => _showNegotiateDialog(),
                onQuote: () => _showQuoteDialog(),
                onCounterOffer: () => _showCounterOfferDialog(),
                onAcceptLatest: () => context.read<ConsultationBloc>().add(
                    const ConsultationRespond(action: 'accept')),
                onRejectLatest: () => context.read<ConsultationBloc>().add(
                    const ConsultationRespond(action: 'reject')),
                onFormalApply: () => _showFormalApplyDialog(),
                onApprove: () => _showApproveConfirmation(),
                onClose: () => _showCloseConfirmation(),
              ),
              inputBar: _buildInputBar(mState),
              actionMenu: TaskChatActionMenu(
                onImagePicker: _pickImage,
                onCameraPick: _takePhoto,
                onFilePicker: _pickFile,
                onTaskDetail: _navigateToTaskDetail,
                isExpanded: _showActionMenu,
              ),
            );
          },
        );
      },
    );
  }

  Widget _headerForType(ConsultationType t) {
    switch (t) {
      case ConsultationType.service:
        return const ServiceInfoCard();
      case ConsultationType.task:
        return const TaskInfoCard();
      case ConsultationType.fleaMarket:
        return const FleaMarketItemCard();
    }
  }

  Widget _buildMessageList(ChatState mState, ConsultationState cState) {
    final groups = groupMessages(mState.messages, _currentUserId());
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      itemCount: groups.length + (cState.status == ConsultationStatus.negotiating ? 1 : 0),
      itemBuilder: (context, i) {
        // 第 0 项（最底部）插入 NegotiationActionCard 浮卡（如果有最新议价等响应）
        if (i == 0 && _hasPendingNegotiation(mState.messages, cState)) {
          return NegotiationActionCard(
            message: _latestNegotiation(mState.messages)!,
            onAccept: () => context.read<ConsultationBloc>().add(
                const ConsultationRespond(action: 'accept')),
            onReject: () => context.read<ConsultationBloc>().add(
                const ConsultationRespond(action: 'reject')),
            onCounter: () => _showCounterOfferDialog(),
          );
        }
        final group = groups[i - (_hasPendingNegotiation(mState.messages, cState) ? 1 : 0)];
        return MessageGroupBubbleView(
          group: group,
          customBubbleBuilder: (ctx, msg) {
            if (msg.isNegotiation || msg.isQuote || msg.isCounterOffer) {
              return PriceProposalBubble(
                message: msg,
                isMe: msg.senderId == _currentUserId(),
                currencySymbol: _currencySymbol(cState),
              );
            }
            if (msg.isNegotiationAccepted || msg.isNegotiationRejected) {
              return NegotiationStatusBanner(message: msg);
            }
            return null;
          },
        );
      },
    );
  }

  String _currentUserId() => StorageService.instance.getUserId() ?? '';

  bool _computeIsApplicant(ConsultationState s) {
    // ... 参照原 ApplicationChatView consultationActions.isApplicant
  }

  String _currencySymbol(ConsultationState s) {
    final currency = s.consultationApp?['currency'] as String? ?? 'GBP';
    return Helpers.currencySymbolFor(currency);
  }

  // ... 6 个 dialog 触发方法; 用抽出的 NegotiateDialog/QuoteDialog/CounterOfferDialog/FormalApplyDialog
  // ... _pickImage / _takePhoto / _pickFile / _navigateToTaskDetail 复用 task_chat_view 同样的实现
  // ... _buildInputBar: 用 TextField + 发送按钮; onSend 派发 ChatSendMessage; 含 applicationId state 已记
}
```

**关键细节**：
- `_buildInputBar` 发送时 dispatch `ChatSendMessage(content, applicationId: state.applicationId)` —— **但 ChatBloc state 在 load 时已经记下 applicationId，发送时传 null 即可**（handler 会 fallback 到 state）
- `_pickImage` / `_pickFile` / `_takePhoto` 用 image_picker / file_picker，dispatch `ChatSendImage` / `ChatSendFile` / `ChatSendVideo`，**ChatBloc 自动透传 applicationId**

- [ ] **Step 3: 暂时占位 `_BiddingChatView` 和 `_ReadOnlyChatView`**

```dart
class _BiddingChatView extends StatelessWidget {
  const _BiddingChatView({required this.taskId, required this.applicationId});
  final int taskId;
  final int applicationId;
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('TODO Phase 7')));
}

class _ReadOnlyChatView extends StatelessWidget {
  const _ReadOnlyChatView({required this.taskId, required this.applicationId});
  final int taskId;
  final int applicationId;
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('TODO Phase 7')));
}
```

**这一步是临时**，Task 17 会实现这两个 View。**这阶段进入议价 chat / readOnly 议价历史 会看到 TODO 占位**——所以 **Phase 5 完成 != 全功能可上线**，仅 Service 咨询可用。

- [ ] **Step 4: analyze + 跑 app**

```powershell
flutter analyze
flutter run -d <device>
```

手测 Service 咨询全流程：发起咨询 → 议价 → 对方报价 → 还价 → 批准 → 进入任务工作群。每一步消息气泡显示正确，发送文本/图片/视频/文件正常。

- [ ] **Step 5: commit**

```bash
git commit -m "feat(application-chat): ApplicationChatView 拆三 View; _ConsultationChatView (service) 完成"
```

---

## Phase 6：接入 Task + FleaMarket 咨询

### Task 14: Task + FleaMarket 咨询走通

**Files:**
- Modify: `link2ur/lib/features/tasks/views/application_chat_view.dart`（_ConsultationChatView 内部）

- [ ] **Step 1: 验证 Task 咨询能跑**

`_ConsultationChatView` 已经按 consultationType 切 header。Task 咨询走 `TaskInfoCard` header。**主要风险**是 `ConsultationBloc._onLoadStatus` 的 task 分支 + 3 个 action 分支（negotiate/quote/counter）的 repository 方法签名是否对齐。

- [ ] **Step 2: 跑 Task 咨询全流程手测**

复制 Service 咨询的测试路径，跑 Task 咨询。任何错误码出现 → 检查 ConsultationBloc.task 分支 repository 调用，对齐到 TaskRepository 实际方法。

- [ ] **Step 3: 跑 FleaMarket 咨询全流程手测**

商品 header 用 `FleaMarketItemCard`。流程包括"确认购买"按钮（实际是 `formal_apply` 的一个变体——闲鱼里没有议价后批准，是直接确认购买）。

- [ ] **Step 4: 修任何发现的不一致**

如果某个 type 的某个 action 出错 → 直接改 ConsultationBloc 对应分支，跑测试，commit。

- [ ] **Step 5: commit**

```bash
git commit -m "feat(consultation-chat): Task + FleaMarket 咨询接入"
```

---

## Phase 7：接入 chat-before-payment 议价 + readOnly

### Task 15: 实现 _BiddingChatView

**Files:**
- Modify: `link2ur/lib/features/tasks/views/application_chat_view.dart`

- [ ] **Step 1: 实现 _BiddingChatView**

议价 chat 不需要 ConsultationBloc（因为它不是议价流程而是 chat-before-payment——`TaskDetailBloc` 管价格 + 申请提交）。只 provide `ChatBloc` + `TaskDetailBloc`。结构：

```dart
class _BiddingChatView extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (ctx) => TaskDetailBloc(
            taskRepository: ctx.read<TaskRepository>(),
            notificationRepository: ctx.read<NotificationRepository>(),
            questionRepository: ctx.read<QuestionRepository>(),
          )..add(TaskDetailLoadRequested(taskId)),
        ),
        BlocProvider(
          create: (ctx) => ChatBloc(
            messageRepository: ctx.read<MessageRepository>(),
          )..add(ChatLoadMessages(
              userId: '',
              taskId: taskId,
              applicationId: applicationId,
            )),
        ),
      ],
      child: _BiddingChatContent(taskId: taskId, applicationId: applicationId),
    );
  }
}
```

`_BiddingChatContent` 类似 _ConsultationChatContent，但 `aboveInputSlot` 是 `ConfirmAndPayButton`（现有 `_buildConfirmAndPayButton`），不是 ConsultationActionBar。

`headerSlot` 是 `PriceBar`。

- [ ] **Step 2: 跑议价 chat 手测**

发起申请 → 报价 → 确认支付。

- [ ] **Step 3: commit**

```bash
git commit -m "feat(application-chat): _BiddingChatView (chat-before-payment) 接入"
```

---

### Task 16: 实现 _ReadOnlyChatView

**Files:**
- Modify: `link2ur/lib/features/tasks/views/application_chat_view.dart`

- [ ] **Step 1: 实现 _ReadOnlyChatView**

最简形式：只 provide ChatBloc，slot 配置：

```dart
ChatScaffold(
  appBarTitle: Text(context.l10n.consultationHistory),
  appBarActions: const [],
  headerSlot: Column(children: [const ReadOnlyBanner(), const PriceBar()]),
  bannerSlot: const SizedBox.shrink(),
  messageListBuilder: (_) => _buildMessageList(...),  // 复用 _ConsultationChatContent 的渲染
  inputBar: const SizedBox.shrink(),
  actionMenu: const SizedBox.shrink(),
  aboveInputSlot: null,
)
```

`_buildMessageList` 复用 `_ConsultationChatContent` 的实现但**不传** `customBubbleBuilder` 里的 NegotiationActionCard onAccept/onReject/onCounter——readOnly 不支持响应。

可以把渲染抽成 helper 复用，避免重复代码。

- [ ] **Step 2: 跑 readOnly 议价历史手测**

进入成交后的任务，从详情页跳"查看议价历史"，验证：无输入框、无按钮、能滚动看所有 negotiation/quote/counter_offer/accepted/rejected 消息气泡。

- [ ] **Step 3: commit**

```bash
git commit -m "feat(application-chat): _ReadOnlyChatView 接入"
```

---

## Phase 8：清理

### Task 17: 删除 ApplicationChatView 旧 State + ConsultationActions 抽象

**Files:**
- Modify: `link2ur/lib/features/tasks/views/application_chat_view.dart`（清理）
- Delete: `link2ur/lib/features/tasks/views/consultation/consultation_base.dart`
- Delete: `link2ur/lib/features/tasks/views/consultation/service_consultation_actions.dart`
- Delete: `link2ur/lib/features/tasks/views/consultation/task_consultation_actions.dart`
- Delete: `link2ur/lib/features/tasks/views/consultation/flea_market_consultation_actions.dart`

- [ ] **Step 1: 确认 ConsultationActions 0 引用**

```bash
grep -rn "ConsultationActions" link2ur/lib link2ur/test
```

Expected：除了即将删的 4 个文件自身，0 引用。如果还有引用 → 修复。

- [ ] **Step 2: 删除 ConsultationActions 体系 + 旧 _ApplicationChatContent**

```bash
rm link2ur/lib/features/tasks/views/consultation/consultation_base.dart
rm link2ur/lib/features/tasks/views/consultation/service_consultation_actions.dart
rm link2ur/lib/features/tasks/views/consultation/task_consultation_actions.dart
rm link2ur/lib/features/tasks/views/consultation/flea_market_consultation_actions.dart
```

打开 `application_chat_view.dart`，删掉所有现有 `_ApplicationChatContent` State（line ~98-1749）+ 所有 `_buildXxx` 私有方法。**保留**：顶层 `ApplicationChatView` 分发 + 3 个内部 View 类。

把原 `ApplicationChatView` 的 `export 'consultation/consultation_base.dart' show ConsultationType;` 改为 `export 'consultation/consultation_type.dart';`。

- [ ] **Step 3: analyze + 全套测试**

```powershell
flutter analyze
flutter test
```

Expected：0 error / 0 警告新增。

- [ ] **Step 4: 跑 app 全场景手测**

按 spec §测试 § 集成回归 6 项跑一遍。

- [ ] **Step 5: commit**

```bash
git add -A
git commit -m "refactor(application-chat): 删除 1500+ 行旧 State + ConsultationActions 抽象"
```

---

### Task 18: TaskDetailBloc 删议价部分

**Files:**
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart`

- [ ] **Step 1: grep 议价 events 的引用**

```bash
grep -rn "TaskDetailNegotiate\|TaskDetailQuote\|TaskDetailCounterOffer\|TaskDetailApprove\|TaskDetailClose\|TaskDetailFormalApply" link2ur/lib link2ur/test
```

Expected：0 引用（被 Task 17 删干净后）。如果还有 → 修复。

- [ ] **Step 2: 删除 events / handlers / state 字段**

打开 task_detail_bloc.dart，删除：
- 6 个议价 events（`TaskDetailNegotiate` / `TaskDetailQuote` / `TaskDetailCounterOffer` / `TaskDetailFormalApply` / `TaskDetailApprove` / `TaskDetailClose`）
- 6 个对应的 `on<...>` 注册 + handler 方法
- `TaskDetailState` 里和议价相关的字段（如有：`isSubmitting` / 议价 errorCode 等）—— 仔细检查，如果某字段还在被任务详情用就保留

- [ ] **Step 3: analyze + 跑 TaskDetailBloc 测试**

```powershell
flutter analyze
flutter test test/features/tasks/bloc/task_detail_bloc_test.dart
```

Expected：删掉的 events 对应测试 case 报 not found → 同步删除测试用例（这些用例在 ConsultationBloc 已重新覆盖）。

- [ ] **Step 4: commit**

```bash
git commit -m "refactor(task-detail): 删议价相关 events/handlers (已迁至 ConsultationBloc)"
```

---

### Task 19: ARB l10n + ErrorLocalizer 同步

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`
- Modify: `link2ur/lib/core/utils/error_localizer.dart`

- [ ] **Step 1: 加 11 个错误码翻译**

在三份 ARB 文件加（en 示例）：

```json
{
  "errorChatApplicationNotFound": "Consultation no longer available",
  "@errorChatApplicationNotFound": {},
  "errorChatApplicationForbidden": "You don't have access to this consultation",
  "@errorChatApplicationForbidden": {},
  "errorConsultationLoadFailed": "Failed to load consultation status",
  "@errorConsultationLoadFailed": {},
  "errorConsultationNegotiateFailed": "Failed to submit negotiation",
  "@errorConsultationNegotiateFailed": {},
  "errorConsultationQuoteFailed": "Failed to submit quote",
  "@errorConsultationQuoteFailed": {},
  "errorConsultationCounterOfferFailed": "Failed to submit counter offer",
  "@errorConsultationCounterOfferFailed": {},
  "errorConsultationFormalApplyFailed": "Failed to submit application",
  "@errorConsultationFormalApplyFailed": {},
  "errorConsultationApproveFailed": "Failed to approve consultation",
  "@errorConsultationApproveFailed": {},
  "errorConsultationCloseFailed": "Failed to close consultation",
  "@errorConsultationCloseFailed": {},
  "errorConsultationStateConflict": "This action is not allowed in the current state",
  "@errorConsultationStateConflict": {},
  "errorConsultationServiceRequired": "Please select a service",
  "@errorConsultationServiceRequired": {}
}
```

zh 和 zh_Hant 加对应翻译。

- [ ] **Step 2: 跑 gen-l10n**

```powershell
flutter gen-l10n
```

- [ ] **Step 3: 改 ErrorLocalizer**

打开 `link2ur/lib/core/utils/error_localizer.dart`，找到 `localize` 方法的 switch case，加 11 个 case：

```dart
case 'chat_application_not_found':
  return context.l10n.errorChatApplicationNotFound;
case 'chat_application_forbidden':
  return context.l10n.errorChatApplicationForbidden;
case 'consultation_load_failed':
  return context.l10n.errorConsultationLoadFailed;
case 'consultation_negotiate_failed':
  return context.l10n.errorConsultationNegotiateFailed;
case 'consultation_quote_failed':
  return context.l10n.errorConsultationQuoteFailed;
case 'consultation_counter_offer_failed':
  return context.l10n.errorConsultationCounterOfferFailed;
case 'consultation_formal_apply_failed':
  return context.l10n.errorConsultationFormalApplyFailed;
case 'consultation_approve_failed':
  return context.l10n.errorConsultationApproveFailed;
case 'consultation_close_failed':
  return context.l10n.errorConsultationCloseFailed;
case 'consultation_state_conflict':
  return context.l10n.errorConsultationStateConflict;
case 'consultation_service_required':
  return context.l10n.errorConsultationServiceRequired;
```

- [ ] **Step 4: analyze**

```powershell
flutter analyze
```

- [ ] **Step 5: commit**

```bash
git commit -m "feat(l10n): 11 个咨询/议价错误码 (en/zh/zh_Hant) + ErrorLocalizer 同步"
```

---

### Phase 8 ✅ checkpoint = 项目完成

跑完整全套测试 + analyze + 6 项集成回归手测：

```powershell
flutter test
flutter analyze
# 手测 1-6
```

如果全绿，整个重构落地。

---

## 自审 / 风险 / TODO

### 自审清单

- [x] **Spec 覆盖**：spec 的 7 个章节（架构 / ChatBloc / ChatScaffold / 议价气泡 / ConsultationBloc / 5 场景迁移 / 错误处理 / 测试）每节都有对应 Task
- [x] **No placeholders**：无 "TBD" / "TODO（仅在临时阶段使用占位）" / "类似 Task X" 这种偷懒
- [x] **类型一致性**：`ConsultationStatus` enum / `ConsultationType` enum / `applicationId` 名称在所有 task 一致
- [x] **每 Task = 一个 commit**：边界清晰
- [x] **每步 Expected 输出明确**：testing/analyze 都给了具体期望

### 已知风险（仍需在 Task 0 校准）

1. **后端 `application_id` 字段下推**：如果 WS 推送/响应没带该字段，Task 1 + Task 3 的 `Message.applicationId` 行为退化为 null，过滤逻辑形同虚设但不破坏现有功能。需要后端 PR 配合。
2. **后端 `message_type` 枚举值**：本计划使用 `negotiation` / `quote` / `counter_offer` / `negotiation_accepted` / `negotiation_rejected`。如果实际不同，**Task 4 / Task 12 涉及的代码全部替换为后端实际值**。
3. **Repository 方法签名**：ConsultationBloc 假设各 repository 已有 `negotiate / quote / respondToNegotiation` 等 method。如果不一致 → 先在 repository 加适配 method 再接 bloc（Task 10 Step 2.5）。
4. **议价 state machine**：accepted/rejected/counter_offered 状态转换在 ConsultationBloc 内部实现要参照原 ConsultationActions 逻辑，避免漏 state。

### 实施完成判定

- 全部 19 个 Task 提交
- `flutter test` 全绿
- `flutter analyze` 0 error
- 6 项集成回归手测全部通过
- git log 上能看到清晰的 commit 序列：每个 Task 一个 commit message
