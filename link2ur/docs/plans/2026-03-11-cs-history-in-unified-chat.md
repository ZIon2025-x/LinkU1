# CS 历史记录加载到统一聊天页 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 点击客服历史记录时，将消息加载到统一聊天界面显示（已结束=只读，未结束=可继续对话），替代当前的只读底部弹窗。

**Architecture:** 在 UnifiedChatBloc 新增 `UnifiedChatLoadCSHistory` 事件，根据 `is_ended` 字段决定模式：已结束 → `csEnded` 模式（只读），未结束 → 通过 CS sub-bloc 恢复连接。历史 sheet 的 onTap 改为 dispatch 该事件并关闭 sheet。删除废弃的 `_showCSChatMessagesSheet`。

**Tech Stack:** Flutter, BLoC, Dart

---

### Task 1: 新增 UnifiedChatLoadCSHistory 事件

**Files:**
- Modify: `lib/features/ai_chat/bloc/unified_chat_bloc.dart`

**Step 1: 添加事件类和处理器注册**

在 `UnifiedChatClearTaskDraft` 之后（约第78行后）添加事件：

```dart
/// 加载客服聊天历史（从历史记录入口进入）
class UnifiedChatLoadCSHistory extends UnifiedChatEvent {
  const UnifiedChatLoadCSHistory({
    required this.chatId,
    required this.isEnded,
  });

  final String chatId;
  final bool isEnded;

  @override
  List<Object?> get props => [chatId, isEnded];
}
```

在构造函数中注册 handler（约第206行后）：

```dart
on<UnifiedChatLoadCSHistory>(_onLoadCSHistory);
```

**Step 2: 实现 handler**

在 `_onClearTaskDraft` 方法之后添加：

```dart
/// 加载客服聊天历史
Future<void> _onLoadCSHistory(
  UnifiedChatLoadCSHistory event,
  Emitter<UnifiedChatState> emit,
) async {
  try {
    final rawMessages =
        await _repository.getCustomerServiceMessages(event.chatId);
    final messages = rawMessages
        .map((m) => CustomerServiceMessage.fromJson(m))
        .toList();

    if (event.isEnded) {
      // 已结束：只读模式，仅展示历史消息
      emit(state.copyWith(
        mode: ChatMode.csEnded,
        csMessages: messages,
        csChatId: event.chatId,
      ));
    } else {
      // 未结束：恢复 CS 连接（通过 assign 重连同一会话）
      emit(state.copyWith(
        mode: ChatMode.csConnected,
        csMessages: messages,
        csChatId: event.chatId,
      ));
      _csBloc.add(const CustomerServiceConnectRequested());
    }
  } catch (e) {
    emit(state.copyWith(
      errorMessage: e.toString().replaceAll('CommonException: ', ''),
    ));
  }
}
```

注意：`_repository` 已经是 `CommonRepository` 类型，`getCustomerServiceMessages` 方法已存在。

**Step 3: 添加 repository 字段引用**

bloc 构造函数中已有 `CommonRepository commonRepository` 参数但未保存引用（当前只传给 `_csBloc`）。需要保存：

检查 `unified_chat_bloc.dart:192-196`，当前：
```dart
UnifiedChatBloc({
  required AIChatService aiChatService,
  required CommonRepository commonRepository,
})  : _aiBloc = AIChatBloc(aiChatService: aiChatService),
      _csBloc = CustomerServiceBloc(commonRepository: commonRepository),
      super(const UnifiedChatState()) {
```

改为：
```dart
UnifiedChatBloc({
  required AIChatService aiChatService,
  required CommonRepository commonRepository,
})  : _repository = commonRepository,
      _aiBloc = AIChatBloc(aiChatService: aiChatService),
      _csBloc = CustomerServiceBloc(commonRepository: commonRepository),
      super(const UnifiedChatState()) {
```

在 `_aiBloc` 声明前（约第219行）添加：
```dart
final CommonRepository _repository;
```

**Step 4: Commit**

```bash
git add lib/features/ai_chat/bloc/unified_chat_bloc.dart
git commit -m "feat(chat): add UnifiedChatLoadCSHistory event for loading CS history into unified view"
```

---

### Task 2: 修改历史 sheet 的客服 onTap

**Files:**
- Modify: `lib/features/ai_chat/views/unified_chat_view.dart`

**Step 1: 替换 CS 历史 onTap（第277-299行）**

将当前的 async 获取消息+弹 sheet 逻辑替换为 dispatch 事件：

```dart
onTap: () {
  if (chatId.isEmpty) return;
  final isEnded = chat['is_ended'] == true;
  blocContext.read<UnifiedChatBloc>().add(
    UnifiedChatLoadCSHistory(
      chatId: chatId,
      isEnded: isEnded,
    ),
  );
  if (sheetContext.mounted) Navigator.pop(sheetContext);
},
```

**Step 2: 删除 `_showCSChatMessagesSheet` 方法（第326-397行）**

整个方法已不再被调用，直接删除。

**Step 3: Commit**

```bash
git add lib/features/ai_chat/views/unified_chat_view.dart
git commit -m "feat(chat): navigate CS history into unified chat view instead of read-only sheet"
```

---

### Task 3: 验证 & 清理

**Step 1: 检查未使用的 import**

删除 `_showCSChatMessagesSheet` 后，检查 `unified_chat_view.dart` 顶部是否有因此变为未使用的 import（预期没有，因为 `CustomerServiceMessage` 等仍被 `_buildCSMessageBubble` 使用）。

**Step 2: 运行分析**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze
```

Expected: No new warnings/errors.

**Step 3: 功能验证**

手动验证流程：
1. 打开统一聊天页 → 点击历史记录按钮
2. 看到客服历史列表项
3. 点击已结束的客服对话 → 消息以气泡形式显示在聊天区域，输入框显示"对话已结束"状态
4. 点击未结束的客服对话 → 消息加载并恢复连接，可以继续发消息

**Step 4: Commit（如有清理）**

```bash
git add -A
git commit -m "chore: cleanup unused code after CS history refactor"
```
