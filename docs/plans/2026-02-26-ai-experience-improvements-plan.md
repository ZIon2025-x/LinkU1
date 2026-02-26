# AI Experience Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix streaming output, "满意" OFF_TOPIC bug, add Markdown rendering, expand quick actions, and add inline navigation buttons to query result messages.

**Architecture:** Backend fixes in `ai_agent.py` and `ai_agent_routes.py`. Flutter changes across `ai_chat_service.dart` (HttpClient streaming), `ai_chat.dart` (model), `ai_chat_bloc.dart` (state), and UI widgets. `flutter_markdown` added for rendering.

**Tech Stack:** Python FastAPI + sse_starlette (backend), Flutter BLoC, dart:io HttpClient, flutter_markdown

---

## Task 1: Backend — Fix OFF_TOPIC classifier for short messages

**Files:**
- Modify: `backend/app/services/ai_agent.py:249-384`

**Context:** `classify_intent()` at line 358 has `if len(msg_lower) < 3: return IntentType.OFF_TOPIC`. "满意" is 2 chars → blocked. Also single-char Chinese confirmations ("好", "嗯") are 1 char → blocked.

**Step 1: Add `_CONFIRMATION_WORDS` set** (after the `_PERSONAL_DATA_KEYWORDS` list, around line 351)

```python
_CONFIRMATION_WORDS = {
    # Chinese confirmations
    "满意", "好", "嗯", "是", "对", "可以", "确认", "同意",
    "不", "算了", "取消", "不对", "修改", "再改改", "不满意", "有问题",
    "好的", "好啊", "没问题", "行", "行的", "知道了", "收到",
    # English confirmations
    "ok", "yes", "no", "sure", "fine", "good", "great", "thanks",
    "cancel", "stop", "change", "edit", "update", "confirm",
}
```

**Step 2: Modify `classify_intent()` lines 354-358**

Replace:
```python
def classify_intent(message: str) -> str:
    msg_lower = message.lower().strip()
    if _OFF_TOPIC_RE.search(msg_lower):
        return IntentType.OFF_TOPIC
    if len(msg_lower) < 3:
        return IntentType.OFF_TOPIC
```

With:
```python
def classify_intent(message: str) -> str:
    msg_lower = message.lower().strip()
    if not msg_lower:
        return IntentType.OFF_TOPIC
    if msg_lower in _CONFIRMATION_WORDS:
        return IntentType.UNKNOWN
    if _OFF_TOPIC_RE.search(msg_lower):
        return IntentType.OFF_TOPIC
```

**Step 3: Verify manually**
- "满意" → UNKNOWN (routes to LLM)
- "好" → UNKNOWN
- "" (empty) → OFF_TOPIC
- "写一篇作文" → OFF_TOPIC (regex still catches it)

**Step 4: Commit**
```bash
git add backend/app/services/ai_agent.py
git commit -m "fix(ai): allow short confirmation messages to reach LLM"
```

---

## Task 2: Backend — Add anti-buffering headers to SSE route

**Files:**
- Modify: `backend/app/ai_agent_routes.py:130-133`

**Context:** Railway/Nginx may buffer the SSE response. Adding `X-Accel-Buffering: no` disables Nginx proxy buffering. `Cache-Control: no-cache` is required for SSE.

**Step 1: Update `EventSourceResponse` call (lines 130-133)**

Replace:
```python
    return EventSourceResponse(
        agent.process_message_stream(conversation_id, request_body.content),
        media_type="text/event-stream",
    )
```

With:
```python
    return EventSourceResponse(
        agent.process_message_stream(conversation_id, request_body.content),
        media_type="text/event-stream",
        headers={
            "X-Accel-Buffering": "no",
            "Cache-Control": "no-cache",
        },
    )
```

**Step 2: Commit**
```bash
git add backend/app/ai_agent_routes.py
git commit -m "fix(ai): disable proxy buffering for SSE streaming response"
```

---

## Task 3: Flutter — Fix SSE streaming with dart:io HttpClient

**Files:**
- Modify: `link2ur/lib/data/services/ai_chat_service.dart`

**Context:** Dio with `ResponseType.stream` may buffer responses through its interceptor chain. `dart:io` `HttpClient` delivers chunks as they arrive at the OS network layer, bypassing all buffering.

**Step 1: Add import at top of file**

The file already has `dart:async` and `dart:convert`. Add `dart:io`:
```dart
import 'dart:io';
```
Also add:
```dart
import '../../data/services/storage_service.dart';
import '../../core/config/app_config.dart';
```

**Step 2: Replace `_sendMessageStream` method entirely**

```dart
Future<void> _sendMessageStream(
  String conversationId,
  String content,
  StreamController<AIChatEvent> controller,
) async {
  final token = await StorageService.instance.getToken();
  final baseUrl = AppConfig.instance.baseUrl;
  final uri = Uri.parse('$baseUrl${ApiEndpoints.aiSendMessage(conversationId)}');

  final httpClient = HttpClient();
  httpClient.connectionTimeout = const Duration(seconds: 10);

  try {
    final request = await httpClient.postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    request.write(jsonEncode({'content': content}));

    final response = await request.close();

    if (response.statusCode == 429) {
      controller.add(AIChatEvent(
        type: AIChatEventType.error,
        error: '请求过于频繁，请稍后再试',
      ));
      return;
    }
    if (response.statusCode == 503) {
      controller.add(AIChatEvent(
        type: AIChatEventType.error,
        error: 'AI 服务暂不可用',
      ));
      return;
    }
    if (response.statusCode != 200) {
      controller.add(AIChatEvent(
        type: AIChatEventType.error,
        error: '网络错误，请重试',
      ));
      return;
    }

    String buffer = '';
    await for (final chunk in response.transform(utf8.decoder)) {
      buffer += chunk;
      buffer = buffer.replaceAll('\r\n', '\n');
      while (buffer.contains('\n\n')) {
        final idx = buffer.indexOf('\n\n');
        final eventBlock = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 2);
        if (eventBlock.isEmpty) continue;
        final event = _parseSSEEvent(eventBlock);
        if (event != null && !controller.isClosed) {
          controller.add(event);
        }
      }
    }
    if (buffer.trim().isNotEmpty) {
      final event = _parseSSEEvent(buffer.trim());
      if (event != null && !controller.isClosed) {
        controller.add(event);
      }
    }
  } catch (e) {
    AppLogger.error('AI chat SSE error', e);
    if (!controller.isClosed) {
      controller.add(AIChatEvent(
        type: AIChatEventType.error,
        error: '网络错误，请重试',
      ));
    }
  } finally {
    httpClient.close();
  }
}
```

**Step 3: Run the app and test streaming**

Send a message to the AI. You should now see text appearing progressively instead of waiting for the full response.

**Step 4: Commit**
```bash
git add link2ur/lib/data/services/ai_chat_service.dart
git commit -m "fix(ai): use dart:io HttpClient for SSE streaming to fix buffering"
```

---

## Task 4: Flutter — Add flutter_markdown and render AI messages

**Files:**
- Modify: `link2ur/pubspec.yaml`
- Modify: `link2ur/lib/features/ai_chat/widgets/ai_message_bubble.dart`

**Step 1: Add flutter_markdown to pubspec.yaml**

In `link2ur/pubspec.yaml`, under `dependencies:` (after `dio: ^5.4.3+1`), add:
```yaml
  flutter_markdown: ^0.7.4
```

**Step 2: Run pub get**
```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter pub get
```
Expected: resolves without errors.

**Step 3: Update `AIMessageBubble` to render markdown for assistant messages**

In `ai_message_bubble.dart`:

Add import at top:
```dart
import 'package:flutter_markdown/flutter_markdown.dart';
```

Replace the `SelectableText` widget in `AIMessageBubble.build()` (currently lines 65-75):
```dart
child: SelectableText(
  message.content,
  style: theme.textTheme.bodyMedium?.copyWith(...),
),
```

With:
```dart
child: isUser
    ? SelectableText(
        message.content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          height: 1.4,
        ),
      )
    : MarkdownBody(
        data: message.content,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.white : Colors.black87,
            height: 1.4,
          ),
          code: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            backgroundColor: isDark
                ? const Color(0xFF1C1C1E)
                : const Color(0xFFE8E8E8),
          ),
        ),
        selectable: true,
      ),
```

Note: the `isUser` variable is already defined in `build()` at line 24.

**Step 4: Update `StreamingBubble` to render markdown**

Replace the `content.isEmpty ? _ThinkingIndicator(...) : _TypewriterText(...)` block in `StreamingBubble.build()` (lines 146-155) with:

```dart
child: content.isEmpty
    ? _ThinkingIndicator(isDark: isDark)
    : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MarkdownBody(
            data: content,
            styleSheet: MarkdownStyleSheet.fromTheme(
              Theme.of(context),
            ).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
          const Text(
            ' ▍',
            style: TextStyle(color: AppColors.primary),
          ),
        ],
      ),
```

The `_TypewriterText` class and its state can be deleted (lines 165-237) — it is no longer used. Real-time streaming is now the "typewriter effect".

**Step 5: Hot reload and verify**

- Send a message. Assistant replies should render **bold**, lists, etc. correctly.
- While replying, the streaming bubble should show markdown + `▍` cursor.

**Step 6: Commit**
```bash
git add link2ur/pubspec.yaml link2ur/pubspec.lock link2ur/lib/features/ai_chat/widgets/ai_message_bubble.dart
git commit -m "feat(ai): render AI messages with Markdown using flutter_markdown"
```

---

## Task 5: Flutter — Track toolName in BLoC for inline action buttons

**Files:**
- Modify: `link2ur/lib/data/models/ai_chat.dart`
- Modify: `link2ur/lib/features/ai_chat/bloc/ai_chat_bloc.dart`

**Context:** When a tool_result SSE event arrives, we need to attach the `toolName` to the final assistant message so `AIMessageBubble` can show a navigation button. This field is client-side only (not persisted to backend).

**Step 1: Add `toolName` field to `AIMessage`**

In `ai_chat.dart`, update the `AIMessage` class:

```dart
class AIMessage extends Equatable {
  const AIMessage({
    this.id,
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolResults,
    this.createdAt,
    this.isStreaming = false,
    this.toolName,          // NEW: last tool called (client-side only)
  });

  // ... existing fields ...
  final String? toolName;  // NEW
```

Update `copyWith`:
```dart
AIMessage copyWith({
  // ... existing params ...
  String? toolName,
}) {
  return AIMessage(
    // ... existing ...
    toolName: toolName ?? this.toolName,
  );
}
```

Update `props`:
```dart
@override
List<Object?> get props => [id, role, content, isStreaming, toolName];
```

Do NOT add `toolName` to `fromJson` — it's client-side only.

**Step 2: Add `lastToolName` to `AIChatState`**

In `ai_chat_bloc.dart`, add field to `AIChatState`:
```dart
class AIChatState extends Equatable {
  const AIChatState({
    // ... existing ...
    this.lastToolName,       // NEW: tracks last tool_result during streaming
  });

  // ... existing fields ...
  final String? lastToolName; // NEW
```

Update `copyWith` to include `lastToolName`:
```dart
AIChatState copyWith({
  // ... existing params ...
  String? lastToolName,
}) {
  return AIChatState(
    // ... existing ...
    lastToolName: lastToolName,  // nullable, so null resets it
  );
}
```

Add to `props`:
```dart
@override
List<Object?> get props => [
  // ... existing ...
  lastToolName,
];
```

**Step 3: Update `_onToolResult` to record toolName**

```dart
void _onToolResult(
  _AIChatToolResult event,
  Emitter<AIChatState> emit,
) {
  emit(state.copyWith(lastToolName: event.toolName));
}
```

**Step 4: Update `_onMessageCompleted` to attach toolName to message**

```dart
void _onMessageCompleted(
  _AIChatMessageCompleted event,
  Emitter<AIChatState> emit,
) {
  if (state.streamingContent.isNotEmpty) {
    final assistantMessage = AIMessage(
      id: event.messageId,
      role: 'assistant',
      content: state.streamingContent,
      createdAt: DateTime.now(),
      toolName: state.lastToolName,   // NEW: attach last tool
    );
    emit(state.copyWith(
      messages: [...state.messages, assistantMessage],
      isReplying: false,
      streamingContent: '',
      lastToolName: null,   // reset
    ));
  } else {
    emit(state.copyWith(isReplying: false, lastToolName: null));
  }
}
```

Also reset `lastToolName` when sending a new message. In `_onSendMessage`, update the initial emit:
```dart
emit(state.copyWith(
  messages: [...state.messages, userMessage],
  isReplying: true,
  streamingContent: '',
  lastToolName: null,   // NEW: clear previous tool
));
```

**Step 5: Commit**
```bash
git add link2ur/lib/data/models/ai_chat.dart link2ur/lib/features/ai_chat/bloc/ai_chat_bloc.dart
git commit -m "feat(ai): track last tool name in BLoC for inline action buttons"
```

---

## Task 6: Flutter — Add inline action buttons to AIMessageBubble

**Files:**
- Modify: `link2ur/lib/features/ai_chat/widgets/ai_message_bubble.dart`

**Context:** Assistant messages that resulted from a tool call show a small tappable chip at the bottom. The chip navigates to the relevant screen.

**Step 1: Add router import**

At the top of `ai_message_bubble.dart`, add:
```dart
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
```

**Step 2: Add `_ActionButton` helper widget at the bottom of the file**

```dart
/// Navigation chip shown below tool-result messages
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
```

**Step 3: Add `_actionRoute` helper function**

Add this function inside `AIMessageBubble` class (or as a top-level private function):

```dart
/// Returns (label, route) for the action button, or null if no action.
(String, String)? _resolveAction(String? toolName, BuildContext context) {
  switch (toolName) {
    case 'query_my_tasks':
      return ('View tasks →', AppRoutes.tasks);
    case 'list_activities':
      return ('View activities →', AppRoutes.activities);
    case 'get_my_points_and_coupons':
      return ('Go to wallet →', AppRoutes.wallet);
    default:
      return null;
  }
}
```

Check `link2ur/lib/core/router/app_router.dart` for the exact route constant names. Common patterns: `AppRoutes.tasks`, `AppRoutes.wallet`, `AppRoutes.activities`. Adjust if they differ.

**Step 4: Update `AIMessageBubble.build()` to show action button**

The bubble currently wraps content in a `Container`. Change the assistant bubble to use a `Column` for content + optional action button.

Locate the `Flexible(child: Container(..., child: <content>))` for assistant messages and update it:

```dart
Flexible(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary
              : isDark
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.large),
            topRight: const Radius.circular(AppRadius.large),
            bottomLeft: isUser
                ? const Radius.circular(AppRadius.large)
                : const Radius.circular(AppRadius.tiny),
            bottomRight: isUser
                ? const Radius.circular(AppRadius.tiny)
                : const Radius.circular(AppRadius.large),
          ),
        ),
        child: isUser
            ? SelectableText(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  height: 1.4,
                ),
              )
            : MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                  code: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: isDark
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFE8E8E8),
                  ),
                ),
                selectable: true,
              ),
      ),
      if (!isUser)
        Builder(builder: (context) {
          final action = _resolveAction(message.toolName, context);
          if (action == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: _ActionButton(
              label: action.$1,
              onTap: () => context.go(action.$2),
            ),
          );
        }),
    ],
  ),
),
```

**Step 5: Hot reload and test**

- Ask AI "查看我的任务" → should show "View tasks →" button below the response
- Ask AI "有什么活动" → should show "View activities →" button
- Ask AI a FAQ question → no button shown
- Tap button → navigates to correct screen

**Step 6: Commit**
```bash
git add link2ur/lib/features/ai_chat/widgets/ai_message_bubble.dart
git commit -m "feat(ai): add inline navigation buttons to tool-result messages"
```

---

## Task 7: Flutter — Expand quick actions to 6

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`
- Modify: `link2ur/lib/features/ai_chat/views/ai_chat_view.dart`

**Step 1: Add 4 new l10n keys to `app_en.arb`**

After the existing `"aiChatSearchTasks"` entry (line 4045), insert:
```json
  "aiChatPostTask": "Help me post a task",
  "aiChatMyPoints": "My points & coupons",
  "aiChatActivities": "What activities are on",
  "aiChatContactSupport": "Talk to a human agent",
```

**Step 2: Add same keys to `app_zh.arb`**

After `"aiChatSearchTasks"` (line 3963):
```json
  "aiChatPostTask": "帮我发布任务",
  "aiChatMyPoints": "查我的积分与优惠券",
  "aiChatActivities": "有什么活动",
  "aiChatContactSupport": "转人工客服",
```

**Step 3: Add same keys to `app_zh_Hant.arb`**

Find the `aiChatSearchTasks` line and insert after it:
```json
  "aiChatPostTask": "幫我發布任務",
  "aiChatMyPoints": "查我的積分與優惠券",
  "aiChatActivities": "有什麼活動",
  "aiChatContactSupport": "轉人工客服",
```

**Step 4: Regenerate l10n**
```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```
Expected: no errors, `lib/l10n/generated/` updated.

**Step 5: Update `_WelcomeView` quick actions in `ai_chat_view.dart`**

Find the `Wrap` containing `_QuickAction` widgets (around line 283-296). Replace the two `_QuickAction` children with six:

```dart
Wrap(
  spacing: AppSpacing.sm,
  runSpacing: AppSpacing.sm,
  children: [
    _QuickAction(
      label: context.l10n.aiChatViewMyTasks,
      onTap: () => _sendQuickMessage(context, context.l10n.aiChatViewMyTasks),
    ),
    _QuickAction(
      label: context.l10n.aiChatSearchTasks,
      onTap: () => _sendQuickMessage(context, context.l10n.aiChatSearchTasks),
    ),
    _QuickAction(
      label: context.l10n.aiChatPostTask,
      onTap: () => _sendQuickMessage(context, context.l10n.aiChatPostTask),
    ),
    _QuickAction(
      label: context.l10n.aiChatMyPoints,
      onTap: () => _sendQuickMessage(context, context.l10n.aiChatMyPoints),
    ),
    _QuickAction(
      label: context.l10n.aiChatActivities,
      onTap: () => _sendQuickMessage(context, context.l10n.aiChatActivities),
    ),
    _QuickAction(
      label: context.l10n.aiChatContactSupport,
      onTap: () => _sendQuickMessage(context, context.l10n.aiChatContactSupport),
    ),
  ],
),
```

**Step 6: Hot reload and verify**

Navigate to AI chat welcome screen. Should show 6 quick action buttons in a wrap layout (2 per row on phone).

**Step 7: Commit**
```bash
git add link2ur/lib/l10n/app_en.arb link2ur/lib/l10n/app_zh.arb link2ur/lib/l10n/app_zh_Hant.arb link2ur/lib/features/ai_chat/views/ai_chat_view.dart
git commit -m "feat(ai): expand quick actions from 2 to 6 on AI welcome screen"
```

---

## Final Verification

After all tasks complete:

1. **"满意" bug**: Generate a task draft, reply "满意" → AI should respond in context (not say "I can only answer platform questions")
2. **Streaming**: Send any message → text should appear word-by-word, not wait for full response
3. **Markdown**: Ask AI a question with list-type answer → see rendered bullet points and bold text
4. **Quick actions**: Open fresh AI chat → see 6 buttons
5. **Inline navigation**: Ask "查看我的任务" → see "View tasks →" chip below AI reply, tap it → goes to tasks screen

## Notes

- `_TypewriterText` class in `ai_message_bubble.dart` is deleted in Task 4 (replaced by real streaming)
- `AppRoutes.tasks`, `AppRoutes.activities`, `AppRoutes.wallet` route constants — verify exact names in `link2ur/lib/core/router/app_router.dart` before Task 6
- The `StorageService.instance.getToken()` used in Task 3 returns `Future<String?>` — ensure async handling in the new HttpClient code
