# Recommend Helpers by Intent — Design Spec

**Date**: 2026-05-12
**Status**: 设计完成，待实施
**Author**: brainstorm session with user
**Related**: `architecture_ai_chat_state.md`, `project_admin_ai_prompt_editor.md`, `project_ai_model_setup.md`, `2026-05-07-ai-proactive-suggestions-design.md`

---

## 1. 背景与目标

当前 AI 在用户表达需求时的行为是：

- 用户说「帮我发个搬家任务」→ AI 走 `prepare_task_draft` 生成草稿；
- 用户**已发布**任务后问「谁能做」→ AI 走 `recommend_takers` 工具；
- 用户问「我有什么特长」→ AI 走 `analyze_my_skills` 推荐发个人服务。

**链路缺失的一步**：用户在 AI 聊天里**隐式**表达需求（如「周末想找人陪我逛街」），但还没说要发任务，也没问"谁能帮"——AI 现在的行为是引导发任务，**不会主动说**「这里有几个陪逛达人，看看？喜欢的话再发任务定 ta」。

**用户痛点**：从"我有需求"到"我决定发任务"之间，缺一个让用户**先看看平台有谁能帮**的低成本探索步骤；目前用户必须先承诺发任务，才能拿到候选人，门槛偏高。

**目标**：新增 AI 工具 `recommend_helpers_by_intent`，让 AI 在用户表达具体需求时——

1. **先文本确认**（不直接调工具），降低误触
2. 用户同意后，调工具拿到 top N 合适的人选
3. 候选卡片在 AI 聊天里展示，整张卡可点击跳转到该用户主页
4. **不提供直接 CTA**（不发定向任务、不发咨询），保持「先看人」语义，避免骚扰

---

## 2. Non-Goals

明确不做：

- **不做用户 opt-out 开关**（YAGNI）。被推荐用户的 name/avatar/city 已经在 forum/leaderboard 公开暴露，AI 推荐不引入新隐私维度。被投诉再加。
- **不做候选卡片上的「发定向任务」/「咨询」按钮**。保持轻量"看主页"语义；用户进 profile 后用现有按钮完成转化。
- **不做后端意图分类器**。触发判断完全由 LLM 通过 system prompt 决定，不引入 NLP 模块。
- **不做新前端路由 / 新 user 卡片 widget**。复用现有 `/profile/:userId` 路由 + 在 `task_result_cards.dart` 内加一个内部 helper card 渲染函数。
- **不改 `recommend_takers`** 或 `search_services`。新工具独立，零回归风险。

---

## 3. 已确认决策（来自 brainstorm Q1-Q4 + 节级反馈）

| # | 决策点 | 选定方案 |
|---|---|---|
| Q1 | 候选池范围 | **服务发布者池 ∪ 同类任务完成者池**，服务发布者打分加权高（opt-in 信号） |
| Q2 | 触发时机 | **AI 自主判断 + 先文本确认**，类似 `prepare_task_draft` 的草稿模式 |
| Q3 | 候选卡片 CTA | **只「看主页」**，整张卡可点击跳 `/profile/:userId`，不提供发任务/咨询直 CTA |
| Q4 | Opt-out 开关 | **不加**（YAGNI），公开信息维度复用 |
| 节 3 反馈 | 地点匹配策略 | **软加权**而非硬过滤；跨城/未知城市候选保留参与排序，分数显著降低 |

---

## 4. 整体架构

```
┌──────────────────────────────────────────────────────────────────────┐
│ [用户] "周末想找人陪我去逛街"                                          │
│                                                                       │
│ [AI] system prompt 指引：检测到需求信号（task_type/skills/mode 可推断），│
│      不直接调工具，先文本回复：                                        │
│      "看起来你想找人陪你逛街。要我基于平台数据给你推荐几位合适的吗？" │
│                                                                       │
│ [用户] "好" / "嗯，推荐看看" / "可以"                                  │
│                                                                       │
│ [AI] 调 recommend_helpers_by_intent(                                  │
│         task_type="companion", skills=["陪同"],                       │
│         mode="offline", location="London")                            │
│           │                                                            │
│           ▼                                                            │
│ [Backend] helper_recommendation.py                                    │
│   ├─ A) 服务发布者池 SQL (base=0.6)                                   │
│   ├─ B) 同类任务完成者池 SQL (base=0.3)                               │
│   ├─ 合并去重（同人取 max score, source 标 'service'）                │
│   ├─ 评分 (rating/completed/skills boosts × geo_multiplier)           │
│   └─ desc 排序，取 limit（默认 5，最大 10）                            │
│           │                                                            │
│           ▼                                                            │
│ [AI tool result] {helpers: [...], total: 3, fallback_suggestion: null}│
│                                                                       │
│ [AI 回复文本] "为你找到 3 个合适的人选，点击下方卡片看 ta 的主页 👇"  │
│                                                                       │
│ [Flutter] task_result_cards.dart 新增 'helpers' 分支 → HelperCard 列表 │
│           每张卡 InkWell → context.push('/profile/u_xxx')             │
└──────────────────────────────────────────────────────────────────────┘
```

**关键设计点**：
- 触发判断**完全由 LLM 决定**，通过 system prompt 教学，不引入后端意图分类
- 确认步骤是**文本对话**（不是新工具），复用现有"等下一条 user message"对话循环
- 前端**零新 widget / 零新路由**

---

## 5. 新工具 `recommend_helpers_by_intent` 接口

### 5.1 Input schema

```python
{
  "task_type": "companion",         # 必填，来自 TASK_TYPES 枚举
  "skills": ["陪同", "购物"],        # 可空，AI 从聊天提取的 1-3 个关键技能词
  "location": "London",              # 可空，城市/区域名
  "mode": "offline",                 # 可空，online/offline/both
  "limit": 5,                        # 默认 5，最大 10
}
```

### 5.2 Output schema

```python
{
  "helpers": [
    {
      "user_id": "u_xxx",
      "name": "Alice",
      "avatar_url": "https://...",
      "source": "service",          # service | task_history
      "match_score": 0.87,           # 0-1，仅日志/调试用，AI 不展示给用户
      "match_reason": "发布了陪逛服务，评分 4.8（伦敦）",
      "profile_url": "/profile/u_xxx",
    },
    # ... 最多 limit 条
  ],
  "total": 3,                        # 实际返回数
  "fallback_suggestion": null,       # 空候选时为字符串提示
}
```

### 5.3 关键设计点

- **Input 不传 user_id**：调用方就是当前用户（`ctx.user.id`），后端自动排除自己
- **不附 service_id / task_id**：保持「看主页」语义，不引导到服务详情页
- **空候选时 `fallback_suggestion`** 返回一句给 AI 念给用户的引导：`"{location} 暂时还没有合适的人选，建议你发个任务让大家看到"`
- **match_score** 留给后端日志和未来调权重用，不展示给用户

---

## 6. 后端候选池 SQL & 评分算法

### 6.1 候选池构建（两条 SQL，UNION 后合并）

**A) 服务发布者池（opt-in 信号，base=0.6）：**

```sql
SELECT u.id, u.name, u.avatar_url, upref.city,
       'service' as source,
       s.service_name, s.avg_rating, s.completed_count,
       s.skills
FROM users u
JOIN task_expert_services s ON s.user_id = u.id
LEFT JOIN user_profile_preferences upref ON upref.user_id = u.id
WHERE s.service_type = 'personal'
  AND s.status = 'active'
  AND u.id != :current_user_id
  AND (s.category = :task_type
       OR (cardinality(:skills::text[]) > 0 AND s.skills && :skills::text[]))
LIMIT 100
```

**B) 任务完成者池（能力证明，base=0.3）：**

```sql
SELECT u.id, u.name, u.avatar_url, upref.city,
       'task_history' as source,
       COUNT(t.id) as completed_count,
       AVG(r.rating) as avg_rating
FROM users u
JOIN tasks t ON t.taker_id = u.id
LEFT JOIN reviews r ON r.task_id = t.id AND r.user_id != u.id
LEFT JOIN user_profile_preferences upref ON upref.user_id = u.id
WHERE t.status = 'completed'
  AND t.task_type = :task_type
  AND u.id != :current_user_id
GROUP BY u.id, u.name, u.avatar_url, upref.city
HAVING COUNT(t.id) >= 1
LIMIT 100
```

每池内部 `LIMIT 100` 是性能护栏，避免大用户表扫描。

### 6.2 评分公式（per candidate, 0-1）

| 加分项 | 加分 |
|---|---|
| Base: source='service' | `0.6` |
| Base: source='task_history' | `0.3` |
| `avg_rating >= 4.5` | `+0.15` |
| `4.0 <= avg_rating < 4.5` | `+0.10` |
| `completed_count >= 10` | `+0.10` |
| `3 <= completed_count < 10` | `+0.05` |
| 技能交集（与 input.skills） | `min(3, len(set(candidate.skills) ∩ set(input.skills))) × 0.05`（max +0.15） |

`avg_rating IS NULL` 或 `< 3.0` 时不加 rating boost（也不淘汰）。

### 6.3 地点加权乘子

| mode | 同城 | 跨城已知 | 未知城市（漏填） |
|---|---|---|---|
| offline | `× 1.3` | `× 0.4` | `× 0.6` |
| both / null | `× 1.2` | `× 0.7` | `× 0.9` |
| online | `× 1.0` | `× 1.0` | `× 1.0` |

**最终公式**：`score = min(1.0, (base + boosts) × geo_multiplier)`

**举例（用户在 London 找陪逛 offline）**：
- A: 同城服务发布者，rating 4.8，10 单 → `(0.6 + 0.15 + 0.10) × 1.3 = 1.11` → clamp **1.0**
- B: 跨城（Manchester）服务发布者，rating 4.5 → `(0.6 + 0.15) × 0.4 = **0.30**`
- C: 未填 city 的同类任务完成者 → `(0.3 + 0.05) × 0.6 = **0.21**`

### 6.4 合并去重

同一 `user_id` 同时出现在两池时：`max(score)` 优先，source 标为 `'service'`（高源优先）。

### 6.5 城市名归一化

匹配前 `lower().strip()`，并维护一张简单中英城市映射（伦敦↔London、曼城↔Manchester 等主要英国城市）。匹配不上时降级为「未知城市」档。

### 6.6 `match_reason` 生成

- service 源：
  - 同城：`"发布了{service_name}服务，评分 {avg_rating:.1f}（{city}）"`
  - 跨城：`"发布了{service_name}服务，评分 {avg_rating:.1f}（{city}，可线上协调）"`
  - 未知城市：`"发布了{service_name}服务，评分 {avg_rating:.1f}"`
- task_history 源：
  - 类似格式：`"完成过 {n} 个{task_type_label}任务，评分 {avg_rating:.1f}{city_suffix}"`

### 6.7 `fallback_suggestion` 生成

- 候选空且 location 有值：`"{location} 暂时还没有合适的人选，建议你发个任务让大家看到"`
- 候选空且 location 为空：`"还没有匹配的人选，建议你发个任务让大家看到"`

### 6.8 实现位置

新建 `backend/app/services/helper_recommendation.py`，工具 wrapper 在 `backend/app/services/ai_tools.py` 注册。把核心查询/评分逻辑放在独立模块，保持 `ai_tools.py` 不臃肿。

---

## 7. System Prompt 改动

### 7.1 在职责列表加一条

`_DEFAULT_SYSTEM_PROMPT` 的「你的职责范围」列表 #20：

```
20. 当用户表达具体需求时，主动提议基于平台数据推荐合适的人选
```

### 7.2 新增触发规则段（紧跟在「推荐接单人」段后）

```
【主动推荐合适的人 — 意图模式】
当用户在聊天中表达了具体需求（如"周末想找人陪我去逛街"、"需要有人帮我搬家"、
"有谁能教我英语"），且需求清晰到可以推断 task_type 时：

1. **不要直接** 调 recommend_helpers_by_intent 工具
2. **先用文本** 问确认："看起来你想找{需求描述}的人。要我基于平台数据
   给你推荐几位合适的吗？"
3. 用户答 yes / 好 / 可以 / 嗯 等肯定后，再调 recommend_helpers_by_intent
4. 用户答 no 或说"先帮我发任务" → 改走 prepare_task_draft

工具入参提取规则：
- task_type：必填，从 TASK_TYPES 枚举中选最贴近的
- skills：从需求里抽 1-3 个关键技能词
- mode：陪逛/搬家/家教面授等需见面 → "offline"；翻译/线上咨询/审稿 → "online"；
  不确定 → "both"
- location：用户聊天明说优先；其次用用户画像中的城市；都没有且 mode=offline 时
  **先文本问"你在哪个城市？"**，拿到再调工具

收到结果后的回复策略：
- helpers 非空：简短一句"为你找到 N 个合适的人选，点击下方卡片看 ta 的主页 👇"
  —— 不要逐个念 match_reason（前端会展示）
- helpers 空：把 fallback_suggestion 转给用户

与 prepare_task_draft 的关系：
- prepare_task_draft：用户明确说"帮我发任务"
- recommend_helpers_by_intent：用户只表达需求 → 主动提议"先看看人"
- 看人后用户说"我想定 ta" → 改走 prepare_task_draft
```

### 7.3 动态 prompt 兼容

Prod 如果已经设了 `AI_SYSTEM_PROMPT_SOURCE=db`（参考 [[project_admin_ai_prompt_editor]]），改 `_DEFAULT_SYSTEM_PROMPT` 不会立即生效——**需要同步更新 admin 后台 `/admin/ai-prompt` 里的 db 版 prompt**。部署 checklist 里加这一条。

---

## 8. Flutter 前端展示

### 8.1 SSE 数据流

现有 AI 工具结果通过 `AIMessage.toolResultData` 字段经 SSE 推到 Flutter，由 `unified_chat_view.dart` 检测后交给 `task_result_cards.dart` 渲染。

现在 `task_result_cards.dart` 识别 5 类 key：`tasks` / `services` / `experts` / `items` / `posts`。**加第 6 类 `helpers`**。

### 8.2 修改点

**A) `link2ur/lib/features/ai_chat/views/unified_chat_view.dart`**

`_buildMessageList` 里检测 toolResultData 的 const list 加 `'helpers'`：

```dart
final hasTaskCards = rd != null &&
    const ['tasks', 'services', 'experts', 'items', 'posts', 'helpers']
        .any((k) => rd[k] is List && (rd[k] as List).isNotEmpty);
```

**B) `link2ur/lib/features/ai_chat/widgets/task_result_cards.dart`**

加 helpers 渲染分支 + 内部 `_HelperCard` widget（~60 行 dart）。

### 8.3 HelperCard 视觉

```
┌──────────────────────────────────────────────┐
│  [avatar]   Alice                            │
│  40×40      发布了陪逛服务，评分 4.8（伦敦）  │
│             ──────────────────────────  →    │
└──────────────────────────────────────────────┘
   ↑ 整张卡 InkWell → context.push('/profile/u_xxx')
```

### 8.4 关键设计点

- **整张卡可点击**，路由用 `helper.profile_url` 直接 push 到现有 `/profile/:userId`
- **不用新 l10n 字符串**：name + match_reason 全是后端 i18n 过的；不加额外"看主页"按钮
- **不展示 `match_score`**（后端只给 AI 看）
- **空 helpers 不渲染卡片块**（AI 文本里 fallback_suggestion 已经传达）

---

## 9. 错误处理与边界 case

### 9.1 Tool 错误

| 场景 | 处理 |
|---|---|
| AI 传非法 task_type（不在 TASK_TYPES 枚举） | 返回 `{"error": "invalid_task_type"}`，AI 改走 prepare_task_draft |
| 候选池 SQL 异常 / 超时 | 返回 `{"error": "internal_error"}`，AI 建议人工客服 |
| 候选池 SQL 性能保护 | 每子查询 `LIMIT 100` + 查询 timeout 5s |

### 9.2 业务 corner case

| 场景 | 处理 |
|---|---|
| 用户自己就是服务发布者 | SQL `u.id != :current_user_id` 自动排除 |
| 城市名大小写/中英不一致 | §6.5 归一化策略 |
| 候选评分低 (rating < 3.0) 或 NULL | 不加 rating boost（但不淘汰） |
| 用户连续触发同意图 | 走现有 `AI_RATE_LIMIT_RPM=10` + `AI_DAILY_REQUEST_LIMIT=100` 兜底 |

### 9.3 隐私

后端只返回 `user.name` / `avatar_url` / `city`——已经是 forum/leaderboard 公开暴露的字段。**不返回**手机/邮箱/真实姓名/其他 PII。

---

## 10. 测试策略

| 层 | 文件 | 测什么 |
|---|---|---|
| 后端单测 | `backend/tests/test_helper_recommendation.py` | 空候选 / 单池 / 双源去重 / 地点三档加权 / score clamp 1.0 / 服务权重 > 任务历史 / 城市归一化 |
| Flutter widget 测 | `link2ur/test/features/ai_chat/widgets/helper_card_test.dart` | 同城/跨城/未知城市三种 match_reason 渲染；点击 push 到 `/profile/:id`；空 helpers 不渲染 |
| System prompt smoke | **不自动化** | dev 环境手动：「陪逛 / 搬家 / 翻译」3 个典型场景，确认 AI 触发链路（先问 → 调工具 → 渲染） |

---

## 11. 监控日志

工具内部加 `logger.info`：

```python
logger.info(
    "recommend_helpers: user=%s task_type=%s mode=%s loc=%s n_results=%d",
    user_id, task_type, mode, location, len(helpers),
)
```

上线后可查：触发频率、空候选率。结合 Flutter 端 `/profile/:id` 访问日志，能算出「点 helper 卡 → 进 profile → 发任务」的转化漏斗。

---

## 12. 影响面 & 部署 checklist

### 12.1 改动文件清单

**后端**：
- `backend/app/services/helper_recommendation.py`（新建，~150-200 行）
- `backend/app/services/ai_tools.py`（注册新工具，~30 行）
- `backend/app/services/ai_agent.py`（`_DEFAULT_SYSTEM_PROMPT` 加 §7 内容）
- `backend/tests/test_helper_recommendation.py`（新建，~150 行）

**前端**：
- `link2ur/lib/features/ai_chat/widgets/task_result_cards.dart`（加 helpers 分支 + `_HelperCard`，~60 行）
- `link2ur/lib/features/ai_chat/views/unified_chat_view.dart`（const list 加 `'helpers'`，1 行）
- `link2ur/test/features/ai_chat/widgets/helper_card_test.dart`（新建，~80 行）

**文档**：
- `backend/docs/ai-agent.md`（工具列表 37 → 38，加 recommend_helpers_by_intent 简介）

### 12.2 部署 checklist

- [ ] 跑后端 unit test `pytest backend/tests/test_helper_recommendation.py`
- [ ] 跑前端 widget test `flutter test test/features/ai_chat/widgets/helper_card_test.dart`
- [ ] 跑 `flutter analyze`，确认零 issue
- [ ] **如果 prod 设了 `AI_SYSTEM_PROMPT_SOURCE=db`**：同步把 admin 后台 prompt 加 §7 段落
- [ ] dev 环境 smoke：跑「陪逛 / 搬家 / 翻译」3 个场景验证触发链路
- [ ] Commit 直推 main（solo 项目惯例）

### 12.3 风险

- **LLM 误触发**：GLM-4.7-FlashX 的工具调用稳定性不如 Claude，可能在用户闲聊或表达模糊需求时强行调工具。**缓解**：system prompt §7 强调「先文本确认再调」；上线后看日志 `n_results=0` 的占比，过高说明误触发或候选池设计有问题。
- **prod prompt 漂移**：如果 db 版 prompt 没同步加 §7，新工具在 prod 不会被调用。Checklist 列入。
- **性能**：候选池两条 SQL JOIN user_profile_preferences，大用户基数下可能慢。每池 `LIMIT 100` + 查询 timeout 5s 兜底，监控 P95 延迟。

---

## 13. 后续可扩展（不在本期范围）

- **基于 user.recent_interests / inferred_skills 的预过滤召回**：现在只用 task_type + skills 召回，未来可以加用户最近浏览/搜索过的 task_type 反向过滤候选
- **加 service_id / 一键跳服务详情**：如果数据表明用户点击 helper 后转化率低，可以加一个次级 CTA「看 ta 发布的相关服务」
- **意图分类器升级**：如果 LLM 误触发率持续高，可以加一个后端轻量规则做二次确认
- **Group recommendation**：用户说「找 3 个人帮我搬家」时返回组合候选（团队场景）
