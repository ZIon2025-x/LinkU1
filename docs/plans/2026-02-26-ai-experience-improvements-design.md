# AI Experience Improvements — Design Doc

Date: 2026-02-26
Status: Approved

## Problem Statement

The AI assistant (Linker) has several issues degrading the user experience:

1. **"满意" OFF_TOPIC bug** — `classify_intent()` blocks any message with `len < 3` as OFF_TOPIC, silently rejecting short Chinese confirmations like "满意" (2 chars), "好" (1 char), etc. after a task draft is generated.
2. **Streaming not working** — Dio `ResponseType.stream` is buffered by the Railway reverse proxy and/or the mobile HTTP client, causing users to wait for the full response before seeing any text.
3. **No Markdown rendering** — AI replies containing bold text, bullet lists, etc. display raw markdown syntax.
4. **Only 2 quick action buttons** — Welcome screen only has "查看我的任务" and "搜索任务".
5. **Tool call card is static** — No animation while the AI is calling a tool, shows raw tool name only.
6. **Query results are plain text only** — After tool calls (task list, activities, points), there are no navigation shortcuts; users must manually go find the relevant section.

## Design

### 1. Fix: "满意" OFF_TOPIC bug (Backend)

**File**: `backend/app/services/ai_agent.py` — `classify_intent()`

**Root cause**: Line ~358, `if len(msg_lower) < 3: return IntentType.OFF_TOPIC`. This was intended to block random keystrokes, but Chinese confirmations are 1–2 chars.

**Fix**:
- Remove the `len < 3` rule entirely.
- Add a `_CONFIRMATION_WORDS` set. If the message exactly matches a word in this set, return `UNKNOWN` (routes to LLM which handles it in context).
- Keep empty/whitespace-only messages returning `OFF_TOPIC`.

```python
_CONFIRMATION_WORDS = {
    # Chinese
    "满意", "好", "嗯", "是", "对", "可以", "确认", "同意",
    "不", "算了", "取消", "不对", "修改", "再改改", "不满意", "有问题",
    "好的", "好啊", "没问题", "行", "行的",
    # English
    "ok", "yes", "no", "sure", "fine", "good", "great", "thanks",
    "cancel", "stop", "change", "edit", "update",
}
```

### 2. Fix: Streaming Output (Backend + Flutter)

**Backend** (`backend/app/routers.py` or wherever the AI SSE route is defined):
- Add response headers: `X-Accel-Buffering: no`, `Cache-Control: no-cache` to the SSE endpoint. These disable Railway/Nginx proxy buffering.

**Flutter** (`link2ur/lib/data/services/ai_chat_service.dart`):
- Replace `dio.post(..., options: Options(responseType: ResponseType.stream))` with `dart:io` `HttpClient` for the SSE request. `HttpClient` delivers data as it arrives without intermediate buffering layers.
- Keep the same SSE parsing logic (`_parseSSEEvent`); only the transport layer changes.
- Reuse auth token from `StorageService` for the `Authorization` header.

### 3. Feature: Markdown Rendering (Flutter)

**Package**: Add `flutter_markdown: ^0.7.x` to `pubspec.yaml`.

**Files**:
- `link2ur/lib/features/ai_chat/widgets/ai_message_bubble.dart` — Replace `Text(message.content)` with `MarkdownBody(data: message.content)` for assistant messages. User messages remain plain `Text`.
- `link2ur/lib/features/ai_chat/views/ai_chat_view.dart` — `StreamingBubble` also uses `MarkdownBody` so streaming text renders markdown progressively.
- Theme: pass `styleSheet` derived from current `ThemeData` so markdown colors follow dark/light mode.

### 4. Feature: Expand Quick Actions (Flutter)

**File**: `link2ur/lib/features/ai_chat/views/ai_chat_view.dart` — `_WelcomeView`

Expand from 2 to 6 quick actions, in a `Wrap` layout (2 per row on small screens):

| Label (zh) | Label (en) | Message sent |
|---|---|---|
| 查看我的任务 | My tasks | "查看我的任务" / "Show my tasks" |
| 搜索任务 | Search tasks | "搜索任务" / "Search tasks" |
| 帮我发布任务 | Post a task | "帮我发布一个任务" / "Help me post a task" |
| 查我的积分 | My points | "我的积分余额" / "My points balance" |
| 有什么活动 | Activities | "有什么活动" / "What activities are on" |
| 联系客服 | Contact support | "转人工" / "Talk to a human agent" |

Use `context.l10n` for labels (add ARB keys for each). Quick action message sent uses the same l10n string.

### 5. Feature: Tool Call Card Animation (Flutter)

**File**: `link2ur/lib/features/ai_chat/widgets/tool_call_card.dart`

- Add a shimmer pulse animation (using `AnimationController` with repeat) around the card border or background.
- Keep the raw tool name display — no language mapping (app is multilingual, raw name is universal).
- Show a small animated spinner icon alongside the tool name.

### 6. Feature: Inline Action Buttons on Query Results (Flutter)

**Mechanism**: When the BLoC receives a `tool_result` SSE event after a query tool, it stores the `toolName` alongside the in-progress streaming message. When `_AIChatMessageCompleted` fires, the final `AIMessage` is created with `toolName` attached.

**Model change**: `AIMessage` gains an optional `toolName` field (not persisted to backend, client-side only).

**Widget**: `AIMessageBubble` checks `message.toolName` and renders a small tappable chip at the bottom of assistant bubbles:

| `toolName` | Button label | Navigation target |
|---|---|---|
| `query_my_tasks` | "View tasks →" | `/tasks` |
| `list_activities` | "View activities →" | `/activities` |
| `get_my_points_and_coupons` | "Go to wallet →" | `/wallet` |

No button for `prepare_task_draft` (already has `TaskDraftCard`), FAQ, or plain text responses.

## Out of Scope (Future)

- Structured result cards with full task data (Method B) — deferred
- Per-tool navigation buttons for `search_tasks`, `get_my_profile`, etc. — can add later
- Conversation-level state tracking (e.g., "pending draft confirmation" context) — future enhancement

## Files Changed

**Backend**
- `backend/app/services/ai_agent.py` — intent classifier fix
- `backend/app/routers.py` — SSE route headers

**Flutter**
- `pubspec.yaml` — add `flutter_markdown`
- `link2ur/lib/data/services/ai_chat_service.dart` — HttpClient streaming
- `link2ur/lib/data/models/ai_chat.dart` — `toolName` field on `AIMessage`
- `link2ur/lib/features/ai_chat/bloc/ai_chat_bloc.dart` — track toolName per message
- `link2ur/lib/features/ai_chat/views/ai_chat_view.dart` — quick actions, streaming bubble markdown
- `link2ur/lib/features/ai_chat/widgets/ai_message_bubble.dart` — markdown + action button
- `link2ur/lib/features/ai_chat/widgets/tool_call_card.dart` — shimmer animation
- `link2ur/lib/l10n/app_en.arb` + `app_zh.arb` + `app_zh_Hant.arb` — new l10n keys
