# AI Proactive Suggestions — Design Spec

**Date**: 2026-05-07
**Status**: 设计完成，未实施
**Author**: brainstorm session with user
**Related**: `architecture_ai_chat_state.md`, `project_admin_ai_prompt_editor.md`

---

## 1. 背景与目标

当前 AI 系统是**被动响应式**：用户必须主动开聊，AI 才会基于 `_step_llm` pipeline 给建议。`get_proactive_suggestions` 已经会在 system prompt 里注入 5 类待办（无人接单 / 待审申请 / 待确认 / 待评价 / 高匹配新任务），但**只在用户已经开聊时才会被自然地提到**——用户不开聊永远看不到。

**用户痛点**：希望 AI"像个活人朋友"主动联系他，告知可以接的任务、值得看的帖子、相关达人服务等，而不是用户主动来问才回应。

**目标**：把 AI 升级成**主动建议引擎**——
1. 每天主动给活跃用户发一条最相关的消息（任务推荐 / 服务推荐 / 论坛帖子 / 运营建议）
2. 三个 surface 同步呈现：系统 push、应用内通知、AI 对话历史
3. 用户可分项关闭，默认全开，首次 push 前在 AI 对话里发友好告知

---

## 2. 已确认决策（来自 brainstorm Q1-Q5）

| # | 决策点 | 选定方案 |
|---|---|---|
| Q1 | 主动强度 | **每天定时 1 条 push + 用户进 AI 页时 AI 主动开场（基于今日已生成的消息）** |
| Q2 | Reasoning 深度 | **B：当前工具延伸 + 用户运营建议**（推荐工具 + `get_proactive_suggestions` 5 类轮选；预留 C 跨域综合推理升级接口） |
| Q3 | Push 渠道 | **A + 系统 push + AI 对话同步 inject**（应用内通知 + FCM/APNs 系统推送 + AI 对话历史中作为 AIMessage） |
| Q4 | 覆盖人群 | **30 日活跃用户 + 注册 ≤7 天的新用户 + VIP 用户**（约 ~$240/月@5k 注册估算） |
| Q5 | 用户控制 | **三分项独立 toggle**：`系统 push` / `应用内通知` / `AI 主动开场`，默认全开；首次推送前发"友好告知"消息 |

---

## 3. 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│  Celery Beat: 每小时跑一次 ai_proactive_hourly_dispatch          │
│  → 查"现在是当地 9:00 - 10:00 的 qualified users"                │
│    （活跃 30 日 OR 注册 ≤7 天 OR VIP）                           │
└──────────────┬──────────────────────────────────────────────────┘
               │  fan-out 到 Celery 子任务（每用户一个）
               ▼
┌─────────────────────────────────────────────────────────────────┐
│  ai_proactive_engine.generate_for_user(user_id)                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ 1. 资格 & 用户偏好检查                                     │ │
│  │    - last_active_at / created_at / user_level             │ │
│  │    - ai_proactive_push_enabled / inapp / chat 任一开启      │ │
│  │ 2. 候选素材采集（无 LLM）                                  │ │
│  │    - 推荐类（max 5）：recommend_tasks / search_services /  │ │
│  │      list_task_experts / 论坛热帖（按 user.recent_interests）│ │
│  │    - 运营类（max 3）：get_proactive_suggestions 5 类提取    │ │
│  │ 3. LLM reasoning（小模型 Haiku，~$0.005/次）               │ │
│  │    输入：候选 + 用户画像 → 选最有价值的 1 条 + 自然语言    │ │
│  │    输出：JSON {selected_intent, push_title (≤60),         │ │
│  │           push_body (≤120), full_content (≤400), refs[]}  │ │
│  │ 4. 边界处理                                                 │ │
│  │    - LLM 返回 selected_intent=null → 当日 skip             │ │
│  │    - 候选为空 → 降级到平台热门 + welcome 模板              │ │
│  │    - LLM 调用失败 → 写日志，不重试                         │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────┬──────────────────────────────────────────────────┘
               │  单次 LLM 输出 → 同步分发到 3 个 surface
   ┌───────────┼───────────┬─────────────────────┐
   ▼           ▼           ▼                     ▼
AIMessage   Notification   FCM/APNs Push      AIProactiveMessage
(role=      (type=         (复用现有              (记账 + 幂等)
 assistant) 'ai_proactive') push_notification_   UNIQUE(user_id,
                            service)              target_date)
```

**关键约束**：
- 单 LLM 调用 → 三 surface 内容 100% 一致（push / 通知 / AI 消息同源）
- 每用户每天**最多 1 次** LLM reasoning（成本上界严格 = 活跃用户数 × ~$0.005）
- 全程异步、隔离、幂等：单用户失败不影响其他，重跑当日不会重复推
- 任何一个 surface 都可被用户关闭，但日志仍会记录"已生成"

---

## 4. 数据模型

### 4.1 新表：`ai_proactive_messages`

```python
class AIProactiveMessage(Base):
    __tablename__ = "ai_proactive_messages"
    id            = Column(BigInteger, primary_key=True)
    user_id       = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    target_date   = Column(Date, nullable=False)              # 用户当地时区下的日期
    title         = Column(String(120), nullable=False)        # push 标题（≤60 字符）
    body          = Column(String(280), nullable=False)        # push 正文（≤120 字符）
    full_content  = Column(Text, nullable=False)               # AI 对话里完整消息（≤400 字符）
    refs          = Column(JSON, nullable=True)                # 引用项 [{type, id, title}]
    intent        = Column(String(40), nullable=False)         # recommend_task | recommend_service |
                                                                # recommend_expert | recommend_forum_post |
                                                                # ops_advice | welcome | null
    model_used    = Column(String(50), default="")
    input_tokens  = Column(Integer, default=0)
    output_tokens = Column(Integer, default=0)

    # 三 surface 落地状态
    chat_message_id = Column(Integer, ForeignKey("ai_messages.id"), nullable=True)
    notification_id = Column(Integer, ForeignKey("notifications.id"), nullable=True)
    push_sent_at    = Column(DateTime(timezone=True), nullable=True)
    push_error      = Column(String(200), nullable=True)
    chat_seen_at    = Column(DateTime(timezone=True), nullable=True)  # 用户进 AI 页是否已见

    created_at = Column(DateTime(timezone=True), default=get_utc_time)

    __table_args__ = (
        UniqueConstraint("user_id", "target_date", name="uq_aipm_user_date"),
        Index("ix_aipm_target_date", "target_date"),
        Index("ix_aipm_user_created", "user_id", "created_at"),
    )
```

`UniqueConstraint(user_id, target_date)` 是幂等核心。子任务用 `INSERT ... ON CONFLICT DO NOTHING`，重跑当日完全安全。

### 4.2 User 表新增字段

```sql
ALTER TABLE users ADD COLUMN ai_proactive_push_enabled  BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN ai_proactive_inapp_enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN ai_proactive_chat_enabled  BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN last_active_at             TIMESTAMP WITH TIME ZONE;
CREATE INDEX ix_users_last_active_at ON users(last_active_at);
```

`last_active_at` 由现有 API 中间件每次有效请求更新一次，**带 1 小时节流**（避免每个请求都写 DB）：

```python
# 在 secure_auth middleware / get_current_user 之类的入口
if user.last_active_at is None or (utcnow() - user.last_active_at) > timedelta(hours=1):
    user.last_active_at = utcnow()
    db.commit()  # 异步 fire-and-forget
```

### 4.3 Migration 文件

按记忆 [DB migration pattern]：编号 SQL 文件，**先跑 DB 再 push 代码**：

- `backend/migrations/214_add_ai_proactive_messages.sql`
- `backend/migrations/215_add_user_ai_proactive_prefs.sql`

部署顺序（按记忆 [Migration before deploy]）：linktest DB → 验证 → prod DB → push 代码。

---

## 5. Reasoning 引擎 — 候选素材采集

新建 `backend/app/services/ai_proactive_engine.py`，与现有 `ai_agent.py` 解耦但复用其工具。

### 5.1 候选采集（无 LLM）

```python
async def collect_candidates(user: User, db) -> list[dict]:
    """
    采集 5-10 个候选素材，每个都是 {intent, ref, score, summary}。
    全程纯 SQL/Redis 查询，不调 LLM。
    """
    candidates = []

    # 推荐类（用户当下最可能感兴趣的事）
    candidates.extend(await _candidate_recommend_tasks(user, db, top_k=3))      # 复用 task_recommendation
    candidates.extend(await _candidate_recommend_services(user, db, top_k=2))   # 复用 search_services 工具
    candidates.extend(await _candidate_recommend_experts(user, db, top_k=1))    # 用户偏好类别的达人
    candidates.extend(await _candidate_hot_forum_posts(user, db, top_k=2))      # 按 recent_interests 过滤

    # 运营类（用户作为发布者的状态提醒，复用 get_proactive_suggestions 5 类）
    candidates.extend(await _candidate_ops_advice(user, db, top_k=3))

    # 新用户冷启动
    if _is_new_user(user):
        candidates.extend(await _candidate_welcome_starter_pack(user, db))

    return candidates[:15]  # 最多 15 条候选喂给 LLM
```

每个候选条目结构：
```python
{
    "intent": "recommend_task",         # 类型枚举
    "score": 0.85,                       # 候选采集器自打分（用于稀缺时降级排序）
    "ref": {"type": "task", "id": "abc123"},
    "summary": "搬家任务，£50，距离 2km，今天发布",  # 给 LLM 看的摘要（≤80 字）
    "user_context": "用户最近接过 3 个搬家任务，平均评分 4.8",  # 可选
}
```

### 5.2 LLM 选择 + 包装

```python
async def reason_and_compose(user, candidates, lang) -> ProactiveOutput | None:
    if not candidates:
        return None

    system_prompt = _PROACTIVE_SYSTEM_PROMPT.format(lang=lang, ...)
    user_prompt = json.dumps({
        "user_profile": build_user_profile_context(user.id, db),  # 复用现有
        "candidates": candidates,
    }, ensure_ascii=False)

    response = await llm.chat(
        messages=[{"role": "user", "content": user_prompt}],
        system=system_prompt,
        model_tier="small",  # Haiku
        max_tokens=600,
    )

    parsed = _parse_proactive_json(response)  # 健壮 JSON 解析（支持 markdown fences）
    if not parsed or parsed.get("selected_intent") in (None, "skip"):
        return None  # 今日无值得说的内容

    return ProactiveOutput(**parsed)
```

LLM prompt 模板（精简核心约束）：

```
你是 Link2Ur 的 AI 助手 Linker，每天给一个用户挑一条他最在意的内容并友好告知。

【任务】
从下面候选列表中选**最有价值**的 1 条，组装成一条主动消息。
"最有价值"的判断顺序：
1. 用户已发布内容遇到问题（ops_advice）：5 天没人接、待审申请等
2. 高匹配新机会（高 score 的 recommend_*）
3. 平台热门内容（welcome / hot_*）

【输出 JSON】
{
  "selected_intent": "recommend_task",   // 或 "skip" 表示今日没什么值得说
  "selected_index": 0,                    // 候选数组下标
  "push_title": "...",                    // ≤60 字符
  "push_body": "...",                     // ≤120 字符
  "full_content": "...",                  // ≤400 字符，AI 对话里展开版
  "refs": [{"type": "task", "id": "..."}] // 引用的具体内容
}

语言：{lang}（zh = 中文，en = English）
风格：像朋友说话，不要太正式，不要"尊敬的用户"。
不要加 markdown 标题。
不要重复用户已经看过的内容（参考 user_profile.recent_proactive_intents）。
```

### 5.3 输出 schema

```python
@dataclass
class ProactiveOutput:
    selected_intent: str  # recommend_task | recommend_service | ... | welcome
    push_title: str       # ≤60 字符
    push_body: str        # ≤120 字符
    full_content: str     # ≤400 字符
    refs: list[dict]      # [{"type": "task", "id": "...", "title": "..."}]
```

---

## 6. Celery 调度

### 6.1 Beat 配置（添加到 `backend/app/celery_app.py`）

```python
beat_schedule = {
    # 每小时整点跑一次，扫"现在是当地 9:00 上午"的活跃用户
    "ai-proactive-hourly-dispatch": {
        "task": "app.tasks.ai_proactive.hourly_dispatch",
        "schedule": crontab(minute=5),  # 每小时 5 分跑（避开整点高峰）
    },
}
```

### 6.2 Hourly Dispatch

```python
@celery_app.task(name="app.tasks.ai_proactive.hourly_dispatch")
def hourly_dispatch():
    """
    每小时跑一次。查"当下用户当地时间是 9-10 点"的 qualified user，
    fan-out 给每个用户一个独立子任务。
    """
    target_users = _select_users_in_morning_window()
    for uid in target_users:
        run_proactive_for_user.delay(uid)
    return {"dispatched": len(target_users)}


def _select_users_in_morning_window() -> list[str]:
    """
    SELECT id FROM users
    WHERE
      -- 当地时区当下小时 == 9
      EXTRACT(HOUR FROM (NOW() AT TIME ZONE timezone)) = 9
      -- 资格判定
      AND (
        last_active_at >= NOW() - INTERVAL '30 days'
        OR created_at >= NOW() - INTERVAL '7 days'
        OR user_level IN ('vip', 'super')
      )
      -- 至少有一个 surface 开着
      AND (ai_proactive_push_enabled OR ai_proactive_inapp_enabled OR ai_proactive_chat_enabled)
      -- 今天还没生成过
      AND NOT EXISTS (
        SELECT 1 FROM ai_proactive_messages
        WHERE user_id = users.id
          AND target_date = (NOW() AT TIME ZONE timezone)::date
      )
    """
```

### 6.3 单用户子任务

```python
@celery_app.task(name="app.tasks.ai_proactive.run_for_user", max_retries=0)
def run_proactive_for_user(user_id: str):
    """
    单用户：候选采集 → LLM → 落库 → 三 surface 分发。
    任何步骤失败都记录到 ai_proactive_messages.push_error 但不重试。
    """
    with session_scope() as db:
        user = db.query(User).filter_by(id=user_id).first()
        if not user:
            return

        target_date = _today_in_user_tz(user)

        # 二次检查幂等（防 race）
        if db.query(AIProactiveMessage).filter_by(user_id=user_id, target_date=target_date).first():
            return

        candidates = run_async(collect_candidates(user, db))
        output = run_async(reason_and_compose(user, candidates, user.language_preference))
        if not output:
            # 当日 skip，但记一行 status=skipped
            _record_skip(db, user_id, target_date)
            return

        # 入库（三 surface 分发由独立函数处理，每个失败都不影响别的）
        msg_row = _persist_proactive_message(db, user, target_date, output)
        _dispatch_to_chat(db, user, output, msg_row)
        _dispatch_to_notification(db, user, output, msg_row)
        _dispatch_to_push(db, user, output, msg_row)

        db.commit()
```

### 6.4 [默认决策] linktest 没 Celery 的处理

按记忆 [linktest 没 Celery, prod 有]：linktest 走 TaskScheduler 兜底，但 ai_proactive 是**典型的 beat 任务**——按记忆原则**只能 prod 灰度验证**。

linktest 上的处理：
- 写一个 `/api/admin/ai-proactive/dry-run/{user_id}` 端点，admin 可手动触发任意用户的 reasoning 看输出
- TaskScheduler 不挂 hourly_dispatch（避免误触发）

---

## 7. 三 Surface 分发实现

### 7.1 AI 对话同步

```python
def _dispatch_to_chat(db, user, output, msg_row):
    if not user.ai_proactive_chat_enabled:
        return

    # 复用或创建该用户的"主聊天"对话（避免每次新建一个）
    conv = _get_or_create_main_conversation(db, user.id)

    chat_msg = AIMessage(
        conversation_id=conv.id,
        role="assistant",
        content=output.full_content,
        tool_calls=None,
        tool_results=json.dumps({"refs": output.refs}, ensure_ascii=False),
        model_used="proactive",
    )
    db.add(chat_msg)
    db.flush()
    msg_row.chat_message_id = chat_msg.id
```

**Flutter 侧消费**：用户进 AI 页 → `AIChatBloc._onLoadHistory` 从后端拉 messages → 顶部出现今日主动消息（已经在历史里）→ 用户可以直接点 refs 跳详情或继续聊。

### 7.2 应用内通知

```python
def _dispatch_to_notification(db, user, output, msg_row):
    if not user.ai_proactive_inapp_enabled:
        return

    notif = Notification(
        user_id=user.id,
        type="ai_proactive",
        title=output.push_title,
        content=output.push_body,
        related_id=str(msg_row.id),  # 点击后跳到 ai-chat?proactive_id=...
        is_read=False,
    )
    db.add(notif)
    db.flush()
    msg_row.notification_id = notif.id
```

**Flutter 侧消费**：通知 tab 渲染 type='ai_proactive' 时用 `LinkerAvatar` 替代默认头像，点击跳到 AI 对话页定位到该消息。

### 7.3 系统 Push

```python
def _dispatch_to_push(db, user, output, msg_row):
    if not user.ai_proactive_push_enabled:
        return
    try:
        send_push_notification_async_safe(
            db=db,
            user_id=user.id,
            title=output.push_title,
            body=output.push_body,
            notification_type="ai_proactive",
            data={"proactive_id": str(msg_row.id), "refs": output.refs},
        )
        msg_row.push_sent_at = utcnow()
    except Exception as e:
        msg_row.push_error = str(e)[:200]
```

**前端处理 push tap**：`LinkUFirebaseMessagingService.kt` / iOS APNs handler 收到 `notification_type=ai_proactive` 时跳转到 `/support-chat?proactive_id=X`，AI 页面自动滚动到该消息。

---

## 8. Flutter UI 改动

### 8.1 通知 tab — 渲染 ai_proactive 类型

`link2ur/lib/features/notification/views/notification_list_view.dart`：识别 `notification.type == 'ai_proactive'`，渲染卡片：
- 左侧用 `LinkerAvatar(size: 40, withGlow: true)` 替代默认 icon
- 标题用 push_title，副标题用 push_body
- 点击 → `context.goToAIChat()` 并传 `proactive_id` query

### 8.2 AI 对话页 — 主动消息高亮

`unified_chat_view.dart`：路由参数收到 `proactive_id` 时：
- 加载历史后 scroll 到对应 message
- 该 message 加 800ms 黄色脉冲动画（参考记忆 [Forum replies are flat] 的 pulse 风格）

### 8.3 设置页 — 三 toggle

`link2ur/lib/features/settings/views/settings_view.dart`：在 "通知设置" 下新增 "AI 助手" 分组：
- `🔔 系统推送通知`
- `📱 应用内通知`
- `💬 AI 主动开场`

每个 toggle 调 `PUT /api/users/me/preferences` 更新对应字段。

### 8.4 首次"友好告知"消息

新用户首次符合资格时（`hourly_dispatch` 首次命中），先发一条**特殊 welcome 消息**：

> "Hi {name}！我是 Linker 🤖 — 你的 Link2Ur 智能助手。我会偶尔主动找你聊聊新机会和值得看的内容。如果不喜欢，可以在 设置 → 通知设置 → AI 助手 里关掉。"

这条消息 `intent='welcome_intro'`，确保每个用户一生只发一次（DB 标记 `users.proactive_intro_sent_at`）。

---

## 9. 用户控制 + 偏好同步

### 9.1 后端端点

新增 `backend/app/routes/user_routes.py` 端点（如已存在则扩展）：

```
PATCH /api/users/me/ai-preferences
Body: {push_enabled?, inapp_enabled?, chat_enabled?}
Returns: 当前最新 4 字段
```

### 9.2 关闭后的语义

| Toggle | 关闭后行为 |
|---|---|
| `push_enabled = false` | 系统 push 不发，但通知 tab 仍有，AI 对话仍有 |
| `inapp_enabled = false` | 通知 tab 不出现，push 仍发，AI 对话仍有 |
| `chat_enabled = false` | AI 对话不 inject，push + 通知仍发（点开通知会跳 AI 页但只看到普通对话） |
| 三个全关 | reasoning 直接 skip（不浪费 LLM 调用） |

### 9.3 全局 kill switch

新增 env `AI_PROACTIVE_ENABLED=true`（默认 true）。设为 false 时 hourly_dispatch 直接 noop——用于线上紧急关闭整个能力。

---

## 10. 冷启动 + 边界处理

### 10.1 新用户（注册 ≤7 天）

候选采集时 `_is_new_user(user) == True`：
- 跳过 ops_advice（用户没发布任何内容）
- 候选主要从平台热门内容来：top 3 任务、top 2 论坛热帖、top 2 推荐达人
- LLM prompt 加 `"This is a new user, focus on showcasing platform value naturally."`

首次推送一定走"友好告知"模板（见 §8.4），让新用户知道这功能存在并能找到关闭入口。

### 10.2 候选稀缺

如果整个候选列表 < 3 条（小城市 / 小众兴趣）：
- 降级到平台热门内容兜底
- 如果连兜底都没有 → LLM 返回 `selected_intent="skip"` → 当日不推

### 10.3 LLM 调用失败

- 记录到 `ai_proactive_messages` 一行 `status='llm_failed'`，不分发任何 surface
- 不重试（避免 LLM 偶发失败导致同一用户多次扣费）

### 10.4 Push 调用失败

- `ai_proactive_messages.push_error` 记错误信息
- 其它 surface 已经分发的不回滚（用户在 AI 页和通知 tab 仍能看到）

### 10.5 用户当日已生成（race condition）

`UNIQUE(user_id, target_date)` 兜底。子任务先 SELECT 检查再 INSERT，并发时 INSERT 冲突会被忽略。

### 10.6 成本上限保护

新增 env `AI_PROACTIVE_DAILY_TOKEN_BUDGET=500000`（默认 50 万 tokens 全平台/天）。Celery 任务跑前查当日累计：
```sql
SELECT SUM(input_tokens + output_tokens) FROM ai_proactive_messages
WHERE created_at >= today_utc_start
```
超过预算后 hourly_dispatch 自动跳过当日剩余调度，next day 0 点重置。

---

## 11. Admin 调试

新增 admin 路由 `backend/app/admin_ai_proactive_routes.py`：

| 端点 | 用途 |
|---|---|
| `GET /api/admin/ai-proactive/today?user_id=X` | 查某用户今日主动消息（dry view） |
| `POST /api/admin/ai-proactive/dry-run` body `{user_id}` | 在 linktest 触发某用户的 reasoning，不实际分发，返回 LLM 输出供 admin 观察 |
| `GET /api/admin/ai-proactive/stats?date=YYYY-MM-DD` | 当日统计：触发数 / 成功数 / push 失败数 / 总 token / intent 分布 |
| `POST /api/admin/ai-proactive/run-now` body `{user_ids:[...]}` | 强制立即跑（绕过时区窗口检查） |

均需 `Depends(get_current_admin)` + `@rate_limit("admin_operation")`。

Admin 前端页面 `admin/src/pages/admin/ai-proactive/AIProactivePage.tsx` 提供：
- 当日总览（触发数 / 成功率 / token 用量）
- 按用户搜索查最近 7 天主动消息历史
- "Dry-run for user" 工具

---

## 12. 测试策略

### 12.1 后端单元测试

- `tests/test_ai_proactive_engine.py`
  - 候选采集函数对各种用户状态返回符合预期的 candidates
  - LLM 输出 JSON 解析的健壮性（含 markdown fences / 截断 / 字段缺失）
  - `_select_users_in_morning_window` 的时区计算
- `tests/test_ai_proactive_dispatch.py`
  - 三 surface 分发各自独立失败的容错
  - 幂等：同一 (user_id, target_date) 跑两次只产 1 行
  - 用户 toggle 关闭时对应 surface 被跳过

### 12.2 集成测试

- linktest 上跑 dry-run 端点，对几个种子账户跑 reasoning，肉眼审查 LLM 输出质量
- VIP 账户 / 新用户 / 老用户 / 流失用户分别测一遍候选差异

### 12.3 灰度验证

- prod 上线第一周 `AI_PROACTIVE_ENABLED=true` 但只对 admin 自己 + 5 个内测账户开（白名单 env `AI_PROACTIVE_USER_WHITELIST=...`）
- 观察 LLM 输出质量、push 送达率、用户关闭率
- 第二周扩到 100 人，第三周全开

---

## 13. 部署上线步骤

按记忆 [Migration before deploy] 的教训：

1. **migration 先行**
   - linktest DB 跑 `214_add_ai_proactive_messages.sql` + `215_add_user_ai_proactive_prefs.sql`
   - 验证表结构 + 默认值 OK
   - prod DB 跑同样 migration
2. **后端代码 push** — 此时 `AI_PROACTIVE_ENABLED=false`（kill switch 关闭），整个 feature 处于 dark launch 状态
3. **Flutter 端 build**：通知卡片、设置页 toggle、AI 对话主动消息高亮
4. **管理员 dry-run 验证**：linktest 上对自己账户触发 dry-run，LLM 输出符合预期
5. **白名单灰度**：prod 设 `AI_PROACTIVE_ENABLED=true` + `AI_PROACTIVE_USER_WHITELIST=admin_id1,admin_id2,...`
6. **观察 1 周**：每日检查 admin stats 页面，token 成本、用户关闭率、用户反馈
7. **逐步扩大白名单**：白名单变成 100 人 → 500 人 → 全开（`AI_PROACTIVE_USER_WHITELIST=*` 或删除该 env）
8. **同步 Celery 与 scheduled_tasks**（按记忆 [scheduled_tasks 和 Celery 同步]）：linktest 不挂 hourly_dispatch（保持 dry-run 端点为唯一触发），prod 走 Celery beat。

---

## 14. 默认决策清单（brainstorm 没逐个确认的，需用户 review）

以下决策是基于已确认约束推导的默认选择，等用户 review 时如有异议可调整：

| # | 默认决策 | 理由 | 调整成本 |
|---|---|---|---|
| D1 | 推送时间 = 用户当地 9:00-10:00 | 早晨注意力高、不打扰睡眠 | 低（改 SQL EXTRACT 条件） |
| D2 | 候选数量上限 15 | 喂给 LLM 的 prompt 体积可控（~2-3k tokens） | 低 |
| D3 | LLM 用小模型 Haiku | 单价 ~$1/M，单次 reasoning ~$0.005 可控 | 低（model_tier 改 large） |
| D4 | 每用户每天最多 1 条 | "活人朋友"频率上限 | 中（要改 UNIQUE → 加 sequence） |
| D5 | "AI 主动开场"使用今日已生成的消息（不额外跑 LLM） | 进 AI 页零延迟 + 内容三处一致 | 高（改回每次进页跑就回到方案 A） |
| D6 | welcome 消息用预设模板（不跑 LLM） | 新用户首次体验确定性高 | 低 |
| D7 | 推送失败不重试 | 避免重复扣费/打扰 | 低 |
| D8 | LLM 失败记 log 但不告诉用户 | 用户感知不到"AI 偶尔不发消息" | 低 |
| D9 | 设置页 toggle 默认全开 | 主动性优先，让用户主动 opt-out | 低（改 column DEFAULT） |
| D10 | 全局 kill switch env `AI_PROACTIVE_ENABLED` | 紧急关闭整个能力的逃生口 | 低 |
| D11 | 全平台日 token 上限 50 万（保护性默认） | ~$0.50/天 上限保护 | 低 |
| D12 | 首次告知消息一生发一次（`proactive_intro_sent_at`） | 避免重复打扰 | 低 |

---

## 15. 工作量估算

| 模块 | 工作量 |
|---|---|
| Migration + User 表字段 + ai_proactive_messages 表 | 0.5 天 |
| Reasoning 引擎（候选采集 + LLM + JSON 解析） | 2 天 |
| Celery 调度（hourly + 单用户任务） | 1 天 |
| 三 surface 分发 + 用户 toggle | 1 天 |
| Flutter UI（通知卡片 + 设置页 + 对话页脉冲） | 1.5 天 |
| Admin dry-run + stats 页面 | 1 天 |
| 测试（单测 + 集成 + 灰度脚本） | 1 天 |
| **合计** | **~8 天** |

按 solo 项目实际日产出预估，1.5-2 个工作周。

---

## 16. 后续升级方向（不在本期 scope）

- **B → C 升级**：跨域综合推理（"你那个搬家任务没人接，达人 Lisa 正好擅长"），用 Sonnet 大模型，每日 token 预算翻倍
- **Push 时机优化**：用 ML 预测用户当日最佳触达时段（而不是固定 9-10 点）
- **多日序列**：连续几天的主动消息构成"剧情"（"前天给你推的那个达人怎么样了？"）
- **用户能"教 AI 闭嘴"**：每条主动消息底部加 "👎 这种类型不要再推了"，反向训练候选过滤器
- **跨语言风格**：英文用户更口语化，中文用户允许更亲切

---

## 附录 A — 关键复用现有代码

| 复用对象 | 位置 | 用途 |
|---|---|---|
| `get_proactive_suggestions` | `ai_agent.py:815` | 提取 5 类运营建议候选 |
| `build_user_profile_context` | `ai_agent.py:587` | 给 LLM 注入用户画像 |
| `get_llm_client()` | `ai_agent.py:65` | 复用 LLM 客户端 + 自动重建 |
| `tool_registry.get_handler("recommend_tasks")` 等 | `ai_tools.py` | 候选采集复用搜索/推荐工具 |
| `send_push_notification_async_safe` | `push_notification_service.py:748` | 系统 push 分发 |
| `task_recommendation.get_task_recommendations` | `task_recommendation.py` | 任务推荐评分 |
| `BehaviorCollector` | `services/behavior_collector.py` | 记录 ai_proactive_sent / ai_proactive_clicked 事件 |
| `_DEFAULT_SYSTEM_PROMPT` 占位符替换 | `ai_agent.py:573` | proactive prompt 也可以参考这种 placeholder 模式 |

---

## 附录 B — 风险清单

| 风险 | 等级 | 缓解 |
|---|---|---|
| LLM 输出 JSON 格式错误 | 中 | 健壮 JSON 解析 + skip 当日（不影响其他用户） |
| Push 服务限流（FCM/APNs） | 中 | 复用现有 push_notification_service 已有重试/超时 |
| 5 千用户同时跑 reasoning 把数据库打爆 | 中 | hourly 错峰 + Celery worker 并发上限 |
| 用户嫌烦关闭率 >50% | 高 | 灰度第一周观察关闭率，>30% 即停发优化 |
| LLM 输出涉嫌"骚扰式推销" | 中 | system prompt 强调"朋友语气"，admin dry-run 人工抽查 |
| 时区计算 bug → 半夜推送 | 高 | 单测覆盖 4 个时区（UTC / Asia/Shanghai / America/New_York / Europe/London） |
| 跨日边界 race | 低 | UNIQUE 索引兜底 |

---

**End of spec.**
