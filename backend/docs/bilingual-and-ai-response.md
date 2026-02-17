# 双语数据与 AI 回复约定

本文说明 Link2Ur 业务数据的双语字段约定、AI 回复语言策略，以及 **AI 工具返回给模型的数据**如何按用户请求语言使用 zh/en 字段。

## 业务数据双语约定

以下实体在数据库中具备中英双语列，用于多端（App / Web / AI）按语言展示：

| 实体 | 双语列 | 说明 |
|------|--------|------|
| Task（任务） | title_zh, title_en, description_zh, description_en | 主字段 title/description 保留兼容 |
| Activity（活动） | title_zh, title_en, description_zh, description_en | 同上 |
| ForumPost（论坛帖子） | title_zh, title_en, content_zh, content_en | 内容为 content_* |
| Notification（通知） | title（中文）, title_en | 无 title_zh 列 |
| CustomLeaderboard（排行榜） | name_zh, name_en, description_zh, description_en | name/description 保留兼容 |
| LeaderboardItem（排行榜项） | 仅 name, description | 无双语列 |
| FleaMarketItem（跳蚤市场） | 仅 title, description | 无双语列 |

展示时优先使用对应语种列（如 zh 用 title_zh），缺则回退到主字段（如 title）。

## AI 回复语言（单语）

- **默认语言为英文（en）**：未设置用户偏好且无 Accept-Language 时，按 en 处理；离题/错误等 fallback 文案亦为 en。
- AI **回复**与用户当前消息语言一致：用户用中文问 → 中文答；用英文问 → 英文答。
- 回复语言由 `_infer_reply_lang_from_message(user_message)` 推断，并用于系统提示、离题文案、FAQ 等，**不**在一条回复中同时输出中英双语。

## 工具返回给 AI 的数据按请求语言选语种

为让模型“看到”与用户语言一致的任务/活动等，**工具返回给 AI 的 payload** 中的标题、描述等按 **request_lang**（与回复语言一致）选择对应语种字段：

- **用户说「检查我的任务」「我的任务有哪些」** → request_lang 为 `zh` → 工具（如 `query_my_tasks`、`get_task_detail`）返回的 `title` / `description` 来自 **title_zh / description_zh**（缺则回退 title/description）。
- **用户说 "check my tasks"、"list my tasks"** → request_lang 为 `en` → 工具返回的 `title` / `description` 来自 **title_en / description_en**（缺则回退）。

这样 AI 在组织回复时，拿到的任务列表/详情已是用户所用语言，无需模型自行“翻译”或二选一。

### 涉及的工具与字段

| 工具 | 按 request_lang 使用的字段 |
|------|----------------------------|
| query_my_tasks | 每条任务的 title（task title_zh/title_en） |
| get_task_detail | title, description（task 双语列） |
| search_tasks | 每条任务的 title |
| list_activities | 每条活动的 title（activity 双语列） |
| get_my_notifications_summary | recent 中每条通知的 title（zh 用 title，en 用 title_en 或 title） |
| list_my_forum_posts | 每条帖子的 title（title_zh/title_en） |
| get_leaderboard_summary | 榜单的 name, description（name_zh/name_en、description_zh/description_en）；LeaderboardItem 无双语，保持 name/description |
| search_flea_market | 无双语列，不修改 |

实现位置：`app/services/ai_tool_executor.py`，通过 `_tool_lang()` 获取 request_lang，任务/活动使用 `app.utils.task_activity_display` 中的 `get_task_display_title`、`get_task_display_description`、`get_activity_display_title`、`get_activity_display_description`；帖子、通知、排行榜在 executor 内按 lang 取对应列并回退。

## 验收示例

- 用户发送「检查我的任务」或「我的任务有哪些」：工具返回的 tasks 中 title（及详情中的 description）为中文（来自 title_zh/description_zh 或回退）。
- 用户发送 "check my tasks" 或 "list my tasks"：工具返回的 tasks 中 title/description 为英文（来自 title_en/description_en 或回退）。
- 任务详情、活动列表、我的帖子、通知摘要、排行榜同理，均按请求语言单语展示给模型。
