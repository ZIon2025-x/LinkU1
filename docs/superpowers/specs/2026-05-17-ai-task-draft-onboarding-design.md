# AI 任务起草引导 Spec

**状态**：设计完成，**实施延后** — 阻塞于"AI 单次消耗根因优化"spec（见 Prerequisites）

**日期**：2026-05-17

**作者**：Claude + Ryan（brainstorm 协作）

---

## 1. 背景与目标

### 1.1 起源
2026-05-17 brainstorm 起点："距离 AI native 还有多远"。最初切入语义检索/embedding 方向，确认数据量小不构成痛点后转向 AI 冷启动方向，最终聚焦"发布任务起草"这一个高门槛转化点。

### 1.2 真实痛点
- 新用户从 `NewbieTasksCenter` 的 `first_post` 任务跳转到 PublishView 后，看到的是**空白表单**（标题、类型、奖励、描述、地点、deadline、照片……），是流失高发地
- 现有 onboarding 体系（`OnboardingView` 静态引导 + `IdentityOnboardingView` profile 流程 + `NewbieTasksCenterView` 任务清单）覆盖了"教什么"，但不覆盖**高门槛创建表单内的辅助**
- 后端 AI 基础设施已成熟（40+ tools、`prepare_task_draft` 已存在、`TaskDraftCard` widget 已存在），但**反向入口缺失**

### 1.3 目标
在 PublishView 顶部加 "✨ AI 帮我写" 按钮，串联现有 ai_agent + prepare_task_draft + TaskDraftCard 链路，并补足 **task_type 模板预设**，让用户：
- 不用 AI 也能看到模板示例（hintText）学会怎么写
- 用 AI 时获得定制化草稿，跳回表单审阅后发布

---

## 2. Prerequisites（实施前必须完成）

### 2.1 AI 单次消耗根因优化（阻塞）
用户反馈普通 chat **几次（3-5 次）就用完 50K daily budget**，意味着单次实际消耗 10K-16K tokens，远高于估算。

可能根因：
- 40+ tools schema 每次全量发送
- prompt cache 没真正命中（或缓存的 tokens 仍被算进 budget）
- 20 turns history 每次重发
- system prompt 太长
- 大模型路径成本更高

**AI 起草本身比普通 chat 更重**（system prompt 注入模板 few-shot、多轮 tool 调用），如果根因不解决，AI 起草上线后用户会被卡得更频繁。**所以本 spec 实施前必须先完成"AI 单次消耗根因优化"spec。**

### 2.2 Quota 临时调整（建议但非阻塞）
如果根因优化没能把单次消耗降到 2-5K tokens 级别，可作为后备方案将 `AI_DAILY_TOKEN_BUDGET` 从 50,000 调到 100,000，但治标不治本。

---

## 3. 范围

### 3.1 MVP 内
- 只做"发布任务起草"一个流程（不含 Service / FleaMarket / Forum）
- 三语支持（zh / en / zh_Hant），zh_Hant 内容用 OpenCC 从 zh 转换初稿 + 人工修订术语，**不 fallback 到 zh**
- 所有用户可见 AI 按钮，但 NewbieTasksCenter 的 `first_post` 跳转带 `source=newbie` 参数，PublishView 据此首次展示一次性 highlight tooltip 指向 AI 按钮
- 静态 dict 存储 task_type 模板，不上 DB；如需 admin 编辑后续迁移

### 3.2 MVP 外（扩展点）
- Service / FleaMarket / Forum 同模式起草（spec 设计可复制）
- "AI 主动推送你该发任务了"（push notification 形式）
- 模板的 admin 后台编辑界面
- "重新起草"按钮（用户拒绝）

---

## 4. 架构总览

### 4.1 端到端数据流

```
┌──────────────────────────────────────────────────────────────┐
│ ① PublishView (link2ur/lib/features/publish/...)             │
│   顶部新增 [✨ AI 帮我写] 按钮                                  │
│   onTap → context.push('/ai-chat/task-draft')                │
│   选 task_type 后, title/description hintText 显示模板示例     │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│ ② UnifiedChat (任务起草模式 mode=task_draft)                   │
│   - 新增路由 /ai-chat/task-draft (复用现有 UnifiedChatView)    │
│   - 后端注入特定 system prompt: 任务起草助手                    │
│     + 用户上下文 (city, preferred_task_types)                  │
│     + 对应 task_type 的模板 few-shot                           │
│   - AI 主动开场: "你想找人帮你做什么?"                          │
│   - AI 可调 tool: prepare_task_draft, get_my_profile           │
└────────────────────────────┬─────────────────────────────────┘
                             │ AI 调用 prepare_task_draft
                             │ 后端校验+规整后返回 draft dict
                             ▼
┌──────────────────────────────────────────────────────────────┐
│ ③ TaskDraftCard 渲染 (已存在的 widget)                          │
│   - 显示 draft 各字段                                          │
│   - 按钮"使用此草稿" → onConfirm 回调                          │
└────────────────────────────┬─────────────────────────────────┘
                             │ context.go('/publish', extra: draft)
                             ▼
┌──────────────────────────────────────────────────────────────┐
│ ④ PublishView (回到表单, 实际值预填)                            │
│   - 接收 GoRouter extra: TaskDraft                            │
│   - PublishBloc emit PublishPrefillFromDraft(draft) event     │
│   - 各 controller / state 被填入 AI 生成值                     │
│   - 顶部小标识 "由 AI 起草"                                    │
│   - 用户审阅 → 修改 → 发布(走原有 createTask 流程)              │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 模板预设的双场景

| 场景 | 字段表现 |
|------|---------|
| **A. 用户直接进 PublishView（没用 AI）** | 选 task_type → title / description 显示 hintText（模板示例），用户输入时 hint 消失 |
| **B. 用户从 AI chat 起草跳回 PublishView** | 字段为实际值预填（AI 生成的内容），可编辑 |

---

## 5. 后端改动

### 5.1 新增 TaskTypeTemplates 静态数据
**位置**：`backend/app/data/task_type_templates.py`

结构：
```python
TASK_TYPE_TEMPLATES = {
    "courier": {
        "title_example_zh": "代取学校快递（North London）",
        "title_example_en": "Pick up campus parcel (North London)",
        "title_example_zh_Hant": "代取學校快遞（North London）",
        "description_template_zh": "件数：X 件\n取件点：X\n时间：X\n备注：X",
        "description_template_en": "Items: X\nPickup point: X\nTime: X\nNotes: X",
        "description_template_zh_Hant": "件數：X 件\n取件點：X\n時間：X\n備註：X",
        "suggested_skills": ["细心", "准时"],
        "suggested_skills_en": ["careful", "punctual"],
        "suggested_skills_zh_Hant": ["細心", "準時"],
        "suggested_price_range": {"min": 5, "max": 15, "currency": "GBP"},
        "location_hint": "offline",
    },
    # ... 其他 task_type
}
```

### 5.2 新增 API
**位置**：`backend/app/routes/task_type_template_routes.py`

- `GET /api/task-types/templates?lang=zh` — 返回全部模板的对应语言版本
- `GET /api/task-types/{type}/template?lang=zh` — 单个

注册到 `main.py`。

### 5.3 改造 prepare_task_draft 调用前的 system prompt
**位置**：`backend/app/services/ai_agent.py`（或独立 prompt 文件）

任务起草模式下，build system prompt 时：
1. 基础 prompt：身份 + 目标（任务起草助手）+ 限制（必须调 prepare_task_draft）
2. 用户上下文：`user.city`, `user.preferred_task_types`
3. **Few-shot 注入**：从用户偏好 task_type 取 1-2 个模板，注入到 prompt 作为参考范例

伪代码：
```python
def build_task_draft_system_prompt(user_lang, user_city, user_preferred_types):
    base = AI_TASK_DRAFT_BASE_PROMPT[user_lang]
    templates_snippet = render_templates_few_shot(user_preferred_types, user_lang)
    user_context = f"用户城市: {user_city}, 偏好类型: {user_preferred_types}"
    return f"{base}\n\n{user_context}\n\n参考范例:\n{templates_snippet}"
```

### 5.4 入口 mode 区分
`unified_chat` 后端 chat endpoint 接受 `mode=task_draft` 参数，按 mode 切换 system prompt 和工具子集。

---

## 6. 前端改动（Flutter）

### 6.1 新增

| 文件 | 内容 |
|------|------|
| `link2ur/lib/data/models/task_type_template.dart` | Equatable model, fromJson, 单语言字段（API 按 lang 返回） |
| `link2ur/lib/data/repositories/task_type_template_repository.dart` | `getAll()` / `getByType(type)`，Hive 缓存 24h |
| 新路由 `/ai-chat/task-draft` | 在 `core/router/routes/ai_chat_routes.dart` 注册，复用 UnifiedChatView 但 mode=task_draft |

### 6.2 改造

**`publish_view.dart`**：
1. 顶部加 "✨ AI 帮我写" 按钮 → `context.push('/ai-chat/task-draft')`
2. 选 task_type 后，title / description 的 `hintText` 切换为对应模板示例
3. 价格栏下方加"建议 £X-£Y"提示文字
4. 接收 GoRouter `extra: TaskDraft` 参数 → 初始化时预填
5. 检测 `source=newbie` query param → 首次进入显示 highlight tooltip 指向 AI 按钮（使用 StorageService flag `task_publish_ai_tip_seen` 只显示一次）

**`publish_bloc.dart`**：
1. 新增 `PublishPrefillFromDraft(draft)` event
2. State 加 `bool prefilledByAI` 标记
3. UI 据此展示"由 AI 起草"小标识

**`task_draft_card.dart`**：
- `onConfirm` 实现：`context.go('/publish', extra: draft)`（已有 callback，仅需调用方实现）

**`unified_chat_view.dart`**：
1. 接受 `mode` 参数（task_draft / general）
2. task_draft 模式下：自动发起开场消息、TaskDraftCard 的 onConfirm 跳回 `/publish`

**`newbie_tasks_center_view.dart:28`**：
- `'first_post': AppRoutes.createTask` → 改为带 `source=newbie` 参数

### 6.3 预填字段映射表

| AI draft 字段 | PublishView 字段 |
|--------------|-----------------|
| `title` | titleController.text |
| `description` | descriptionController.text |
| `task_type` | _selectedTaskType state |
| `reward` | rewardController.text（int pence × 100） |
| `currency` | _selectedCurrency state |
| `pricing_type` | _pricingType (fixed/negotiable) |
| `task_mode` | _taskMode (online/offline/both) |
| `required_skills` | _selectedSkills List |
| `location` | _selectedCity state |
| `deadline` | _selectedDeadline DateTime |

---

## 7. 错误处理与边界

| 场景 | 处理 |
|------|------|
| 用户描述太简略 AI 没法生成完整草稿 | AI chat 中追问 1-2 轮，超过 3 轮提示"要不要先看看示例"链回 PublishView |
| `prepare_task_draft` 返回 errors | `TaskDraftCard` 显示部分填充字段 + 红色提示需补充字段，引导跳回表单完善 |
| API 调用失败（z.ai 抖动 / 网络） | UnifiedChatView 现有错误处理沿用 SnackBar 提示，不阻塞用户改用表单 |
| 模板加载失败 | Repository 内置兜底空 dict，PublishView 退化为无 hint 的纯空白表单，业务不阻塞 |
| 用户在 AI chat 中途退出 | 现有 UnifiedChat 行为：返回上一页，会话保留在历史 |
| AI 起草字段含敏感信息 | 复用现有 prepare_task_draft 后端校验 + Task 创建时的安全过滤 |
| 用户从 AI 跳回 PublishView 后想清空重来 | 表单页本身有"重置"行为或 close 重进，不另做"清除 AI 内容"按钮 |
| 新手 highlight tooltip 已显示过 | StorageService 存 flag `task_publish_ai_tip_seen`，只显示一次 |

i18n 错误文案：复用 `ErrorLocalizer` 体系。

---

## 8. 测试策略

### 8.1 后端
- pytest：`task_type_templates.py` dict 结构完整性 schema 测试
- pytest：`prepare_task_draft` 各种残缺 input 的边界
- pytest + TestClient：`GET /api/task-types/templates?lang=zh|en|zh_Hant` 返回正确，不 fallback
- pytest + monkeypatch：mock LLM client，验证 system prompt 包含对应 task_type 模板片段

### 8.2 Flutter
- flutter_test：`TaskTypeTemplate.fromJson` 多语言字段解析
- bloc_test + mocktail：`PublishBloc` 接收 `PublishPrefillFromDraft` event → state 各字段正确填充
- flutter_test (widget)：`PublishView` 选不同 task_type 时 hintText 切换；按下 AI 按钮触发 push 路由

### 8.3 手动验证 Golden Path
1. 新用户首次进入 PublishView → AI 按钮 highlight tooltip 出现一次
2. 不选 task_type → title/description 没有 hint
3. 选 task_type "代取快递" → title hint "例：代取学校快递"
4. 切换语言到 en → hint 切换英文
5. 点 AI 按钮 → 进入 chat → AI 主动开场
6. 输入需求 → AI 起草 → TaskDraftCard 出现
7. 点 "使用此草稿" → 跳回 PublishView，所有字段已预填
8. 修改一个字段 → 发布成功
9. zh_Hant 模式重复 3-7

### 8.4 不做
- E2E 自动化（项目目前无 E2E 框架）

---

## 9. 分阶段上线计划

**前提**：Prerequisites（AI 单次消耗根因优化）已完成。

1. **Phase 1**：后端 `task_type_templates.py` + API endpoint + 测试
2. **Phase 2**：Flutter `TaskTypeTemplate` model + Repository + Hive 缓存
3. **Phase 3**：PublishView hintText 模板（不依赖 AI），灰度验证模板教育效果
4. **Phase 4**：AI 起草链路（按钮 + 路由 + system prompt + TaskDraftCard.onConfirm 跳转）
5. **Phase 5**：NewbieTasksCenter `source=newbie` + highlight tooltip
6. **Phase 6**：metric / 数据观察

Phase 1-3 完成后即有独立价值（用户能看模板写），Phase 4 才上 AI 起草。

---

## 10. 风险与未决问题

- **z.ai system prompt cache 行为**：注入 task_type 模板 few-shot 让 prompt 变长，能否命中 cache 需要在 Prerequisites spec 中先解决（这是为什么要 prerequisite）
- **task_type 总数 / 完整度**：需要先在 backend 确认 `_VALID_TASK_TYPES` 全集，spec 实施时为每个 task_type 写模板（10-20 个）
- **新手 tooltip 的视觉强度**：要不要带蒙层 / 自动消失时长 — 实施时与设计对齐
- **GoRouter extra 序列化**：跨页面传 Map 对象，是否会被 Flutter web 兼容层吞掉，实施前测一下

---

## 附录 A：AI Daily Quota 调整（独立但相关）

如果 Prerequisites spec 无法把单次消耗降到 2-5K tokens 级别，作为后备调整：

| 配置 | 当前 | 后备值 |
|------|------|-------|
| `AI_DAILY_TOKEN_BUDGET` | 50,000 | 100,000 |
| `AI_DAILY_REQUEST_LIMIT` | 100 | 200 |
| `AI_RATE_LIMIT_RPM` | 10 | 不动 |

加 admin metric：`backend/app/services/ai_usage_metrics.py` 聚合每日被拒次数、token 用量 p50/p90/p99、起草成功 vs 失败次数。`GET /api/admin/ai/usage-stats`。

**优先级**：根因优化完成后再判断是否需要这个后备方案。
