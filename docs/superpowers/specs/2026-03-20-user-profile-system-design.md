# 用户画像系统设计文档

## 概述

为 Link2Ur 平台构建四维用户画像系统，用于支撑智能任务匹配、附近任务推送和需求预测等功能。

## 设计决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 数据来源 | 混合模式（引导填写 + 行为推断） | 新用户（留学生）急需匹配，不能等行为积累 |
| 可靠度计算 | 事件驱动增量更新 | 事件频率低、成本低、近实时 |
| 推荐触达 | 应用内卡片 + Push（频控） | 高置信度推送，低置信度卡片，每天最多1条 Push |
| 技能模型 | 重新设计，两层结构（大类 → 技能） | 现有技能体系未使用，两层够用不过度设计 |
| 偏好采集 | 注册问2-3题 + 行为渐进补充 | 减少注册流失，靠行为数据修正 |
| 存储方式 | 分表存储（每个维度独立表） | 可靠度需频繁更新，能力需索引查询，结构清晰 |
| 需求推断 | 事件触发 + 定时兜底 | 关键时刻即时推断，每天兜底全量更新 |

## 数据模型

### 维度A：能力画像 — `UserCapability`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | Integer PK | 主键 |
| `user_id` | String(8) FK | 用户 ID |
| `category_id` | Integer FK | 技能大类 ID |
| `skill_name` | String(100) | 具体技能名称 |
| `proficiency` | Enum | beginner / intermediate / expert |
| `verification_source` | Enum | self_declared / task_verified / platform_verified |
| `verified_task_count` | Integer | 通过该技能完成的任务数（自动统计） |
| `last_used_at` | DateTime | 最近一次使用该技能的时间 |
| `created_at` | DateTime | 创建时间 |

**唯一约束：** `(user_id, skill_name)`

**两层技能分类：**

| 大类 | 技能示例 |
|------|----------|
| 语言 | 英语沟通、中文翻译、粤语 |
| 出行 | 开车、接机、陪同出行 |
| 生活服务 | 搬家、组装家具、代买代取 |
| 专业服务 | 写简历、改论文、拍照剪视频 |
| 本地经验 | 银行开户、租房流程、签证办理、学校注册 |

**数据来源：** 注册引导选择 + 完成任务后自动标记 + 用户手动补充

**与现有技能体系的关系：** 现有 `UserSkill` 和 `SkillCategory` 表基本未被使用（仅排行榜引用）。新表 `UserCapability` 替代 `UserSkill`，新增 proficiency、verification_source 等字段。`SkillCategory` 表保留并扩展，作为大类定义。排行榜逻辑需迁移到新表。

### 维度B：偏好画像 — `UserPreference`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | Integer PK | 主键 |
| `user_id` | String(8) FK | 用户 ID（唯一） |
| `mode` | Enum | online / offline / both |
| `duration_type` | Enum | one_time / long_term / both |
| `reward_preference` | Enum | frequent_low / rare_high / no_preference |
| `preferred_time_slots` | JSON | 如 `["weekday_evening", "weekend"]` |
| `preferred_categories` | JSON | 感兴趣的任务大类 ID 列表 |
| `preferred_helper_types` | JSON | 如 `["newcomer", "student", "same_city"]` |
| `updated_at` | DateTime | 最近更新时间 |

**唯一约束：** `(user_id)` — 每用户一条记录

**采集方式：**
- 注册引导：问 mode（线上/线下）和 preferred_categories（感兴趣的大类）
- 行为推断：根据接单历史自动更新 reward_preference、preferred_time_slots 等
- 偶尔弹窗：在关键交互后轻量询问补充

**与现有 `UserPreferences` 表的关系：** 现有 `UserPreferences` 表存储 task_types、locations、task_levels、keywords 用于推荐过滤。新表侧重用户偏好画像（线上/线下、时段等），两者互补，不冲突。推荐引擎同时使用两个表的数据。

### 维度C：可靠度画像 — `UserReliability`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | Integer PK | 主键 |
| `user_id` | String(8) FK | 用户 ID（唯一） |
| `response_speed_avg` | Float | 平均接单响应时间（秒） |
| `completion_rate` | Float | 完成率（0.0 - 1.0） |
| `on_time_rate` | Float | 守时率（0.0 - 1.0） |
| `complaint_rate` | Float | 被投诉率（0.0 - 1.0） |
| `communication_score` | Float | 沟通评分（1.0 - 5.0，从评价提取） |
| `repeat_rate` | Float | 复购率（0.0 - 1.0） |
| `cancellation_rate` | Float | 中途取消率（0.0 - 1.0） |
| `reliability_score` | Float | 综合可靠度分数（0 - 100） |
| `total_tasks_taken` | Integer | 总接单数（计算基数） |
| `last_calculated_at` | DateTime | 最近计算时间 |

**唯一约束：** `(user_id)` — 每用户一条记录

**综合分数计算公式：**
```
reliability_score = (
    completion_rate * 30 +
    on_time_rate * 25 +
    (1 - cancellation_rate) * 20 +
    (communication_score / 5) * 15 +
    (1 - complaint_rate) * 10
)
```

**更新触发事件：**
- 任务完成（`task_completed`）→ 更新 completion_rate、on_time_rate
- 任务取消（`task_cancelled`）→ 更新 cancellation_rate
- 收到评价（`review_created`）→ 更新 communication_score
- 收到投诉（`complaint_created`）→ 更新 complaint_rate
- 被同一用户再次选择（`repeat_selection`）→ 更新 repeat_rate

### 维度D：需求画像 — `UserDemand`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | Integer PK | 主键 |
| `user_id` | String(8) FK | 用户 ID（唯一） |
| `user_stage` | Enum | new_arrival / settling / established / experienced |
| `predicted_needs` | JSON | 预测需求列表，含类别、置信度、具体项 |
| `recent_interests` | JSON | 最近浏览/收藏的任务类型统计 |
| `last_inferred_at` | DateTime | 最近推断时间 |
| `inference_version` | String(20) | 推断算法版本号 |

**唯一约束：** `(user_id)` — 每用户一条记录

**`predicted_needs` 结构示例：**
```json
[
  {
    "category": "settling",
    "confidence": 0.85,
    "items": ["接机", "搬家", "银行开户"],
    "reason": "new_arrival_pattern"
  },
  {
    "category": "daily_life",
    "confidence": 0.6,
    "items": ["代买代取", "取快递"],
    "reason": "browsing_frequency"
  }
]
```

**用户阶段判断规则：**
| 阶段 | 判断条件 |
|------|----------|
| new_arrival | 注册 < 7天，或自填"刚到英国" |
| settling | 注册 7-30天，发布/浏览安顿类任务 |
| established | 注册 > 30天，有完成任务记录 |
| experienced | 注册 > 90天，完成 > 10个任务 |

**推断触发时机：**
- 注册时立即推断（基于填写的城市、技能、偏好）
- 关键行为触发：浏览某类目 > 5次、发布任务、收藏任务
- 每天凌晨定时兜底更新全量活跃用户

**推荐触达规则：**
| 置信度 | 触达方式 | 频控 |
|--------|----------|------|
| > 0.8 | Push 通知 | 每天最多1条 |
| 0.5 - 0.8 | 应用内卡片 | 首页最多展示3条 |
| < 0.5 | 不触达 | — |

## 后端服务层

### `UserProfileService`

统一的画像服务，职责：

1. **画像 CRUD** — 创建、查询、更新四个维度的画像数据
2. **可靠度计算** — 事件驱动的增量更新逻辑
3. **需求推断** — 基于规则 + 行为统计的推断引擎
4. **画像查询接口** — 供推荐引擎和匹配系统调用

### API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/profile/capabilities` | 获取当前用户能力画像 |
| PUT | `/api/profile/capabilities` | 更新能力画像（添加/修改技能） |
| DELETE | `/api/profile/capabilities/{id}` | 删除某个技能 |
| GET | `/api/profile/preferences` | 获取偏好画像 |
| PUT | `/api/profile/preferences` | 更新偏好画像 |
| GET | `/api/profile/reliability` | 获取可靠度画像（只读） |
| GET | `/api/profile/demand` | 获取需求画像（只读） |
| GET | `/api/profile/summary` | 获取四维画像汇总 |
| POST | `/api/profile/onboarding` | 注册引导提交（批量设置初始能力 + 偏好） |

### 定时任务

| 任务 | 频率 | 说明 |
|------|------|------|
| 需求画像兜底更新 | 每天凌晨3点 | 更新所有7天内活跃用户的需求画像 |
| 可靠度分数校准 | 每周一次 | 全量重算，修正增量更新可能的累积误差 |

## Flutter 端

### 新增页面

1. **注册引导页（Onboarding）** — 注册完成后展示，选择2-3个技能大类 + 线上/线下偏好，可跳过
2. **我的画像页** — 个人中心入口，展示四个维度的可视化摘要
3. **能力管理页** — 添加/编辑/删除技能，设置熟练度
4. **偏好设置页** — 编辑线上/线下、时段、任务类型等偏好
5. **首页推荐卡片** — 基于需求画像展示"你可能需要"

### 新增 BLoC

| BLoC | 级别 | 说明 |
|------|------|------|
| `UserProfileBloc` | 页面级 | 管理画像查看和编辑 |
| `OnboardingBloc` | 页面级 | 管理注册引导流程 |

### 新增 Repository

| Repository | 说明 |
|------------|------|
| `UserProfileRepository` | 封装 `/api/profile/*` 端点调用 |

## 迁移策略

1. 现有 `UserSkill` 数据迁移到 `UserCapability`（proficiency 默认 beginner，verification_source 默认 self_declared）
2. 现有 `SkillCategory` 表保留，扩展字段
3. 排行榜查询从 `UserSkill` 迁移到 `UserCapability`
4. 现有 `UserPreferences` 表保留，与新 `UserPreference` 表并存（前者用于推荐过滤，后者用于画像）
5. 用户现有的 `completed_task_count`、`avg_rating` 等数据用于初始化 `UserReliability`

## 不在范围内

以下功能属于后续子项目，本次不实现：
- 智能任务匹配（子项目2）— 画像接入推荐引擎
- 附近任务推送（子项目3）— 1公里半径触发
- 需求预测主动推荐（子项目4）— Push 通知投递
- 技能认证/审核流程
- 画像数据分析后台
