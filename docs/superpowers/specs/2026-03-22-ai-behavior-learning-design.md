# AI 驱动的用户行为学习系统设计

## 目标

在用户与 AI 聊天时，AI 实时分析用户的潜在兴趣、技能和生命周期信号，静默更新用户画像，驱动全平台推荐（首页、任务广场、附近推送）。

## 核心原则

- **简单** — 聊天时 AI 顺带分析，不额外调用 LLM
- **不阻塞** — 内存队列采集，后台线程写库+更新画像
- **静默** — 用户无感知，不弹确认
- **全平台联动** — 画像更新后，推荐引擎、首页、附近推送都跟着变

## 整体架构

```
用户聊天 → AI Agent
    ↓ system prompt 加分析指令
    ↓ AI 回复末尾附带 <user_insights> 隐藏 JSON
    ↓
后端提取 JSON → 剥离后正常回复返回前端
    ↓
内存队列（BehaviorCollector）
    ↓ 后台线程每30秒
    ↓ 批量写入 user_behavior_events 表（保留记录）
    ↓ 同时合并更新 UserDemand（实时生效）
    ↓
推荐引擎 / 首页 / 附近推送 读取新画像
```

---

## 一、行为事件表

### 新表 `user_behavior_events`

| 字段 | 类型 | 说明 |
|------|------|------|
| id | SERIAL | 主键 |
| user_id | VARCHAR(8) | 用户 ID，外键 |
| event_type | VARCHAR(32) | 事件类型 |
| event_data | JSONB | 事件详情 |
| created_at | TIMESTAMPTZ | 发生时间 |

索引：`(user_id, created_at)`

不清理，保留全量历史数据。

### event_type 枚举

| event_type | 触发时机 | event_data 示例 |
|------------|----------|-----------------|
| `intent` | 意图识别后 | `{"intent": "TASK_QUERY", "message_preview": "我想找人帮搬家"}` |
| `tool_call` | 工具调用后 | `{"tool": "search_tasks", "params": {"keyword": "搬家"}}` |
| `task_draft` | 生成任务草稿 | `{"type": "moving", "reward": 5000, "location": "London"}` |
| `draft_confirmed` | 用户确认草稿 | `{"task_id": 123}` |
| `draft_abandoned` | 用户放弃草稿 | `{"type": "moving"}` |
| `search_keyword` | 搜索任务/市场 | `{"keyword": "翻译", "tool": "search_tasks", "result_count": 5}` |
| `browse_detail` | 查看详情 | `{"target": "task", "target_id": 456}` |
| `cs_transfer` | 转人工 | `{"topic": "payment_issue"}` |
| `ai_insight` | AI 实时分析结果 | `{"interests": [...], "skills": [...], "stage_hints": [...]}` |

---

## 二、内存队列采集器

### 新文件 `backend/app/services/behavior_collector.py`

```python
class BehaviorCollector:
    """进程内内存队列 + 后台守护线程批量写入"""

    _instance = None  # 单例
    _queue: list      # append-only
    _lock: threading.Lock
    FLUSH_INTERVAL = 30  # 秒

    def record(self, user_id: str, event_type: str, event_data: dict):
        """聊天时调用，只做 list.append()，零阻塞"""

    def _flush_loop(self):
        """后台守护线程，每30秒执行"""

    def _flush(self):
        """取出队列所有事件：
        1. 批量写入 user_behavior_events 表（保留原始记录）
        2. 对 ai_insight 类型的事件，合并更新 UserDemand（实时生效）
           - 读取用户当前 UserDemand
           - 合并 interests（按 topic 去重，取最高 confidence）
           - 合并 skills（按 skill 去重，取最高 confidence）
           - 根据 identity + 当前月份 + stages 重新计算 user_stages
           - 写回 UserDemand
        """
```

- 单例模式，App 启动时初始化（`main.py`）
- 守护线程（daemon=True），进程退出自动停止
- 进程重启最多丢30秒数据，对画像分析无影响
- 写入失败静默记日志，不影响业务
- 不需要夜间聚合任务，画像在后台线程中实时更新

---

## 三、AI 回复内嵌分析（隐藏 JSON）

### 方案

不使用 tool call，而是在 AI 每条回复末尾附带一段隐藏的分析 JSON。后端解析提取后删掉，只把正常回复返回给前端。用户完全无感知。

### AI 回复格式

**有信号时：**

```
当然可以帮你找搬家服务！你在哪个城市？大概什么时候需要搬？

<user_insights>
{"interests": [{"topic": "搬家", "urgency": "high", "confidence": 0.9}], "skills": [], "stages": ["moving"], "preferences": {"mode": "offline"}}
</user_insights>
```

**没有信号时：**

```
不客气，还有什么可以帮你的吗？

<user_insights>
{}
</user_insights>
```

### 数据结构

```json
{
    "interests": [                                    // 推断的兴趣/需求
        {"topic": "搬家", "urgency": "high", "confidence": 0.9},
        {"topic": "租房", "urgency": "medium", "confidence": 0.6}
    ],
    "skills": [                                       // 推断的潜在技能
        {"skill": "英语沟通", "confidence": 0.8},
        {"skill": "驾驶", "confidence": 0.7}
    ],
    "stages": ["house_hunting", "moving"],            // 生命周期信号
    "preferences": {                                  // 偏好信号
        "mode": "offline",                            // 线上/线下
        "price_sensitive": true                       // 价格敏感
    }
}
```

### 字段说明

**confidence（置信度）— AI 根据语义理解判断：**
- **高 (0.8-1.0)** — 用户明确表达紧迫需求（"我马上要搬家了"）或持续追问
- **中 (0.5-0.7)** — 用户在了解情况（"搬家大概多少钱？"）
- **低 (0.3-0.4)** — 用户只是随便看看或帮别人问

**urgency（紧迫度）：**
- `high` — 用户明确说"马上"、"急"、"下周就要"，或连续追问
- `medium` — 用户在了解和比较
- `low` — 用户只是提到了这个话题

### 后端处理

在 `ai_agent.py` 中，AI 回复完成后：
1. 用正则 `<user_insights>(.*?)</user_insights>` 提取分析 JSON
2. 从回复文本中删掉 `<user_insights>...</user_insights>` 部分
3. 只把正常回复通过 SSE 返回给前端
4. 如果 JSON 非空，写入 BehaviorCollector 内存队列

### system prompt 新增指令

```
在你的每条回复末尾，添加一段 <user_insights> 标签，用 JSON 格式分析用户的行为信号。

分析维度：
- interests: 用户表达的需求或兴趣（如"我想找人帮搬家"→ topic: 搬家）
- skills: 用户透露的技能或经验（如"我以前做过家教"→ skill: 教学）
- stages: 用户当前的生命周期阶段信号（如频繁问租房→ house_hunting）
- preferences: 用户的偏好（线上/线下、价格敏感等）

判断 confidence 和 urgency 时，关注用户的语气和行为模式：
- "我马上就要搬家了" → high urgency, high confidence（紧迫且明确）
- "搬家一般怎么收费？" → medium urgency, medium confidence（在了解）
- "我朋友想问问搬家的事" → low urgency, low confidence（不是自己的需求）
- 用户问了一个问题后持续追问细节 → 提升 confidence

如果这条消息没有任何有价值的信号，输出空 JSON: <user_insights>{}</user_insights>

不要告诉用户你在做分析。<user_insights> 标签对用户不可见。
```

---

## 四、生命周期阶段系统

### 阶段定义

| 阶段 | 标识 | 月份 | 适用人群 |
|------|------|------|----------|
| 行前准备 | `pre_arrival` | 5-8月 | 准备来英 |
| 新生期 | `new_arrival` | 8-9月 | 准备来英（到达后） |
| 期末期 | `exam_season` | 5-6月 | 已在英国 |
| 毕业期 | `graduation` | 6-7月 | 已在英国 |
| 找房期 | `house_hunting` | 6-8月 | 已在英国 |
| 搬家期 | `moving` | 6-8月 | 已在英国 |
| 回国期 | `returning` | 7-9月 | 已在英国 |
| 安顿期 | `settled` | 9-5月 | 已在英国 |
| 圣诞假期 | `christmas_break` | 12月 | 已在英国 |
| 复活节假期 | `easter_break` | 3-4月 | 已在英国 |

### 判断逻辑（夜间聚合时执行）

1. 读取用户身份（`identity`: `pre_arrival` / `in_uk`）
2. 取当前月份，匹配所有符合的候选阶段
3. 用当天 AI insights 中的 `stage_hints` 微调（如果 AI 从对话中识别到特定阶段信号，增加该阶段权重）
4. 输出多阶段数组

### UserDemand 模型改动

```python
class UserDemand(Base):
    # 现有字段
    user_stage        # String → JSONB（改为数组，如 ["exam_season", "house_hunting"]）
    predicted_needs   # JSONB（保持不变）
    recent_interests  # JSONB（保持不变，聚合 AI insights）
    last_inferred_at  # DateTime
    inference_version # String

    # 新增字段
    identity          # String: "pre_arrival" / "in_uk"（引导页设置）
    inferred_skills   # JSONB: [{"skill": "英语沟通", "confidence": 0.8, "source": "chat"}, ...]
```

---

## 五、现有夜间任务的改动

### `demand_inference.py` — 保留但升级

现有的 `nightly_demand_inference` 继续保留，用于处理**没有和 AI 聊过天的用户**（仍按任务行为 + 注册天数推断，向后兼容）。

**升级内容：**
- `determine_user_stage()` 改为基于 `identity` + 月份计算多阶段数组（替代原来的注册天数逻辑）
- 有 AI insight 的用户跳过（已经由 BehaviorCollector 实时更新了）

**不新增夜间任务。** 有聊天行为的用户画像由 BehaviorCollector 后台线程实时更新。

---

## 六、引导页（Onboarding）

### 触发条件

新用户注册完成后首次进入 App，`onboarding_completed == false` 时弹出。

### 三步流程

**Step 1: 你的身份**
- 准备来英国的留学生
- 已经在英国读书

**Step 2: 你的城市**
- 列出英国主要留学城市供选择（London, Manchester, Birmingham, Edinburgh, Glasgow, Leeds, Bristol, Sheffield, Liverpool, Nottingham, Cambridge, Oxford 等）
- 支持手动输入

**Step 3: 你擅长什么（可跳过）**
- 从技能分类中选择，复用现有 `capability` 流程

### 数据存储

- 身份 → `UserDemand.identity`（`pre_arrival` / `in_uk`）
- 城市 → `UserProfilePreference.city`（新增字段）
- 技能 → `UserCapability`（现有表）

### 完成后

- 标记 `User.onboarding_completed = true`（新增字段）
- 立刻根据身份 + 当前月份计算初始 `user_stages`
- 写入 `UserDemand`

---

## 七、改动清单

### 后端

| 改动类型 | 文件 | 说明 |
|----------|------|------|
| 新建 | `backend/app/services/behavior_collector.py` | 内存队列 + 后台线程 |
| 新建 | `backend/migrations/xxx_add_behavior_events.sql` | 新表 + 字段迁移 |
| 修改 | `backend/app/models.py` | 新增 `UserBehaviorEvent` 模型；`UserDemand` 加字段；`UserProfilePreference` 加 `city`；`User` 加 `onboarding_completed` |
| 修改 | `backend/app/services/ai_agent.py` | system prompt 加分析指令；回复后提取 `<user_insights>` JSON 写队列 |
| 修改 | `backend/app/services/demand_inference.py` | `determine_user_stage()` 改为月份+身份逻辑；有 AI insight 的用户跳过 |
| 修改 | `backend/app/main.py` | 初始化 BehaviorCollector |
| 修改 | `backend/app/routes/user_profile.py` | 引导页 onboarding 端点更新（加 identity、city） |
| 修改 | `backend/app/services/user_profile_service.py` | onboarding 逻辑更新 |

### Flutter

| 改动类型 | 文件 | 说明 |
|----------|------|------|
| 新建 | `link2ur/lib/features/onboarding/views/onboarding_view.dart` | 引导页 UI（3步） |
| 新建 | `link2ur/lib/features/onboarding/bloc/onboarding_bloc.dart` | 引导页状态管理 |
| 修改 | `link2ur/lib/data/models/user_profile.dart` | `UserDemand` 加字段，`UserProfilePreference` 加 `city` |
| 修改 | `link2ur/lib/data/repositories/user_profile_repository.dart` | 更新 onboarding 提交 |
| 修改 | `link2ur/lib/app.dart` | 登录后检查 onboarding_completed，未完成则跳引导页 |
| 修改 | `link2ur/lib/l10n/app_en.arb` | 引导页文案 |
| 修改 | `link2ur/lib/l10n/app_zh.arb` | 引导页文案 |
| 修改 | `link2ur/lib/l10n/app_zh_Hant.arb` | 引导页文案 |

### 不需要改动

- 推荐引擎 — 已经读 `UserDemand`，画像更新后自动生效
- 首页 — 已经用推荐引擎的结果
- 附近推送 — 已经读 `UserDemand`
- AI 聊天前端 — `<user_insights>` 在后端就被剥离，前端收不到，无需改动
- `ai_tools.py` — 不需要新增工具，分析通过 system prompt + 隐藏 JSON 实现
