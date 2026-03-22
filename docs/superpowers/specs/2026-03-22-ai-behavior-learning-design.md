# AI 驱动的用户行为学习系统设计

## 目标

在用户与 AI 聊天时，AI 实时分析用户的潜在兴趣、技能和生命周期信号，静默更新用户画像，驱动全平台推荐（首页、任务广场、附近推送）。

## 核心原则

- **简单** — 聊天时 AI 顺带分析，不额外调用 LLM
- **不阻塞** — 内存队列采集，后台批量写库
- **静默** — 用户无感知，不弹确认
- **全平台联动** — 画像更新后，推荐引擎、首页、附近推送都跟着变

## 整体架构

```
用户聊天 → AI Agent
    ↓ system prompt 加分析指令
    ↓ AI 通过 update_user_insights tool 输出分析（用户不可见）
    ↓
内存队列（BehaviorCollector）→ 30秒批量写入 user_behavior_events 表
    ↓
夜间定时任务（纯规则，不调 LLM）
    ↓ 聚合当天 insights + 月份 + 身份
    ↓
更新 UserDemand（stages、interests、inferred_skills）
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
        """后台守护线程，每30秒批量 INSERT"""

    def _flush(self):
        """取出队列所有事件，一次批量写入 user_behavior_events 表"""
```

- 单例模式，App 启动时初始化（`main.py`）
- 守护线程（daemon=True），进程退出自动停止
- 进程重启最多丢30秒数据，对画像分析无影响
- 写入失败静默记日志，不影响业务

---

## 三、AI Tool — `update_user_insights`

### 新增 AI 工具

在 `ai_tools.py` 注册一个内部工具 `update_user_insights`，AI 在正常回复用户的同时调用此工具输出分析结果。

**工具定义：**

```python
{
    "name": "update_user_insights",
    "description": "分析当前对话中用户的潜在兴趣、技能和生命周期信号。每轮对话结束前调用一次。",
    "parameters": {
        "inferred_interests": ["搬家", "租房"],       # 推断的兴趣/需求
        "inferred_skills": ["英语沟通", "驾驶"],      # 推断的潜在技能
        "stage_hints": ["house_hunting"],              # 生命周期信号
        "confidence": 0.8                              # 置信度 0-1
    }
}
```

**特殊处理：**
- 此工具的结果不流式返回给前端（用户不可见）
- AI Agent 执行此工具时，直接写入 BehaviorCollector 内存队列
- system prompt 指令：在每轮对话有足够信号时调用，不要每句话都调

### system prompt 新增指令

```
你在回复用户的同时，需要分析对话中的行为信号。当你识别到以下任何信号时，调用 update_user_insights 工具：
- 用户表达了某种需求或兴趣（如"我想找人帮搬家"）
- 用户透露了某种技能或经验（如"我以前做过家教"）
- 用户的行为暗示了生命周期阶段（如频繁问租房问题→找房期）
不要告诉用户你在做分析。如果没有明显信号，不需要调用。
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

## 五、夜间聚合任务

### 升级 `demand_inference.py`

将现有的 `nightly_demand_inference` 升级，不是新建。纯规则，不调 LLM。

**新流程：**

1. 查询当天有 `ai_insight` 事件的用户列表
2. 对每个用户：
   a. 读取当天所有 `ai_insight` 事件
   b. 合并 `inferred_interests` 到 `recent_interests`（频次累加，时间衰减：每天权重 ×0.95）
   c. 合并 `inferred_skills` 到 `UserDemand.inferred_skills`（去重，取最高置信度）
   d. 根据 `identity` + 当前月份 + `stage_hints` 重新计算 `user_stages`
   e. 根据新阶段 + 新兴趣生成 `predicted_needs`
   f. 更新 `UserDemand`

**保留现有逻辑：** 没有聊天行为的用户，仍按任务行为 + 注册天数推断（向后兼容）。

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
| 修改 | `backend/app/services/ai_tools.py` | 新增 `update_user_insights` 工具 |
| 修改 | `backend/app/services/ai_agent.py` | system prompt 加分析指令；insights tool 执行时写队列 |
| 修改 | `backend/app/services/demand_inference.py` | 升级聚合逻辑（月份 + 身份 + insights） |
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
- AI 聊天前端 — `update_user_insights` 的结果不返回前端，无需改动
