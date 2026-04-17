# 达人独立活动（抽奖/抢位）设计方案

> Date: 2026-04-17

## 概述

允许达人（Expert Team）在不关联服务的前提下，发布抽奖（lottery）和抢位（first_come）活动。现有的普通活动（standard）流程不变，仍须关联服务。

## 活动类型定义

| activity_type | 说明 | 是否需要关联服务 |
|---|---|---|
| `standard` | 普通活动（现有） | 必须 |
| `lottery` | 抽奖活动 — 截止后随机抽取中奖者 | 可选 |
| `first_come` | 抢位活动 — 先到先得，满员即止 | 可选 |

## 奖品类型

达人活动只允许以下 2 种 `prize_type`：

| prize_type | 说明 |
|---|---|
| `physical` | 实物奖品 |
| `in_person` | 线下到场奖品 |

`points` 和 `voucher_code` 为官方专属，达人不可使用。

## 收费规则

- **可选收费**：达人可以设置参与费（走 Stripe 支付），也可以免费
- **Stripe onboarding 校验**：
  - 免费活动：不要求 Stripe onboarding
  - 收费活动：必须完成 Stripe onboarding
  - 关联服务的活动（standard）：维持现有逻辑，始终要求 Stripe onboarding

## 后端变更

### 1. Schema — `TeamActivityCreate`（expert_activity_routes.py）

```python
# 改动字段
expert_service_id: Optional[int] = None  # 原为必填 int

# 放开 activity_type
activity_type: str = 'standard'  # 'standard' | 'lottery' | 'first_come'

# 新增字段（lottery / first_come 专用）
prize_type: Optional[str] = None       # 'physical' | 'in_person'（达人限定）
prize_description: Optional[str] = None
prize_description_en: Optional[str] = None
prize_count: Optional[int] = None      # 中奖名额 / 抢位名额
draw_mode: Optional[str] = None        # 'auto' | 'manual'（lottery only）
draw_at: Optional[datetime] = None     # 自动开奖时间（lottery + auto + by_time/both）
draw_trigger: Optional[str] = None     # 'by_time' | 'by_count' | 'both'（auto only）
draw_participant_count: Optional[int] = None  # 满员开奖人数（auto + by_count/both）
```

### 2. 路由校验逻辑（expert_activity_routes.py `create_team_activity`）

分叉逻辑：

```
if activity_type == 'standard':
    expert_service_id 必填
    走现有完整校验（服务归属、active、价格继承、Stripe onboarding）

if activity_type in ('lottery', 'first_come'):
    prize_type 必填，且只能是 'physical' | 'in_person'
    prize_count 必填，> 0
    if activity_type == 'lottery':
        draw_mode 必填（'auto' | 'manual'）
        if draw_mode == 'auto':
            draw_trigger 必填（'by_time' | 'by_count' | 'both'）
            if draw_trigger in ('by_time', 'both'): draw_at 必填
            if draw_trigger in ('by_count', 'both'): draw_participant_count 必填，> prize_count
    # max_participants 自动推导：
    if activity_type == 'first_come':
        max_participants = prize_count
    elif activity_type == 'lottery':
        if draw_trigger in ('by_count', 'both'):
            max_participants = draw_participant_count
        else:  # by_time 或 manual
            max_participants = 用户传值 or prize_count * 10

    if expert_service_id 有值:
        校验服务归属和 active 状态，价格可从服务继承
    else:
        跳过服务校验
    if 有收费字段（original_price_per_participant > 0）:
        校验 Stripe onboarding
    else:
        不要求 Stripe onboarding
```

Activity 模型赋值时，新增字段直接写入：
- `prize_type`, `prize_description`, `prize_description_en`, `prize_count`
- `draw_mode`, `draw_at`, `draw_trigger`, `draw_participant_count`

> `draw_trigger` 和 `draw_participant_count` 是新增 DB 列，需要 migration（见 DB 变更章节）。

### 3. 报名逻辑（lottery / first_come）

**复用 `OfficialActivityApplication` 表和 `official_activity_routes.py` 的报名端点。**

现有 `POST /api/official-activities/{activity_id}/apply` 已实现：
- lottery：报名状态为 `pending`，等开奖
- first_come：检查已 `attending` 人数 < `prize_count`，满员返回 400，未满直接 `attending`

当前端点限制了 `activity_type.in_(["lottery", "first_come"])`，无需区分官方/达人，因为查询条件只看活动类型和状态。达人发布的 lottery/first_come 活动也能被同一端点处理，**无需新建报名端点**。

唯一需要调整：如果达人活动设置了参与费（收费），报名前需走支付流程。在报名端点增加判断：
- `original_price_per_participant > 0`：返回 `requires_payment: true`，前端引导支付后再确认报名
- 免费：直接报名（现有逻辑）

### 4. 开奖任务复用（official_draw_task.py）

扩展扫描范围，支持两种自动触发：

**a) 定时开奖（by_time / both）— 定时任务扫描：**

```python
# 扫所有 lottery + auto + 未开奖 + draw_trigger 含时间 + 到期的活动
where(
    Activity.activity_type == 'lottery',
    Activity.draw_mode == 'auto',
    Activity.is_drawn == False,
    Activity.draw_trigger.in_(['by_time', 'both']),
    Activity.draw_at <= now,
)
```

**b) 满员开奖（by_count / both）— 报名端点触发：**

在 `official_activity_routes.py` 的报名端点中，每次成功报名后检查：
```python
if activity.draw_trigger in ('by_count', 'both') and not activity.is_drawn:
    current_applicants = count(pending applications)
    if current_applicants >= activity.draw_participant_count:
        执行开奖（调用共享的 _do_draw() 函数）
```

> `both` 模式：时间到或人数满，哪个先到先触发。

**c) 共享开奖函数：**

抽取一个 `_do_draw(db, activity)` 函数，被定时任务、满员触发、手动开奖三处复用。

开奖后根据 `prize_type` 分支：
- `points` / `voucher_code`：走现有官方逻辑（发积分/发券码）
- `physical` / `in_person`：只写 `winners` JSON，标记 `is_drawn = True`，不做额外发放

### 5. 手动开奖端点（新增）

```
POST /api/experts/{expert_id}/activities/{activity_id}/draw
```

- 权限：team owner 或 admin
- 校验：`activity_type == 'lottery'`，`is_drawn == False`（manual 模式，或 auto 模式下达人想提前手动开）
- 逻辑：从报名用户中随机抽取 `prize_count` 个中奖者，写入 `winners`，标记 `is_drawn = True`
- 返回中奖者列表

## Flutter 端变更

### 1. 活动发布入口

第一步选择活动类型：
- **普通活动** → 进入现有流程（选服务 → 填信息）
- **抽奖活动** → 进入新流程
- **抢位活动** → 进入新流程

### 2. 抽奖/抢位发布流程

不要求选服务（可选关联），表单字段：

| 字段 | 必填 | 说明 |
|---|---|---|
| title | Y | 活动标题 |
| description | Y | 活动描述 |
| location | Y | 活动地点 |
| prize_type | Y | 奖品类型（实物 / 线下） |
| prize_description | Y | 奖品描述 |
| prize_count | Y | 名额数 |
| draw_mode | lottery only | 开奖方式（自动 / 手动） |
| draw_trigger | auto only | 触发条件（按时间 / 按人数 / 两者取先） |
| draw_at | by_time/both | 自动开奖时间 |
| draw_participant_count | by_count/both | 满多少人开奖 |
| deadline | Y | 报名截止时间 |
| max_participants | N | 自动推导（见下），lottery by_time/manual 可手动覆盖 |
| images | N | 活动图片 |
| original_price_per_participant | N | 参与费（不填则免费） |
| expert_service_id | N | 可选关联服务 |

### 3. 活动详情页

- 展示奖品信息（类型、描述、名额）
- 抽奖活动：显示开奖倒计时（auto）或"等待开奖"（manual）
- 开奖后：展示中奖名单
- 抢位活动：显示剩余名额，满员显示"已满"

### 4. 达人管理页

- 抽奖活动（manual）：增加"开奖"按钮
- 查看中奖名单

## DB 变更

已有列（无需迁移）：
- `activity_type`（String(20)，default 'standard'）
- `prize_type`（String(20)，nullable）
- `prize_description` / `prize_description_en`（Text，nullable）
- `prize_count`（Integer，nullable）
- `draw_mode`（String(10)，nullable）
- `draw_at`（DateTime(timezone=True)，nullable）
- `drawn_at`（DateTime(timezone=True)，nullable）
- `winners`（JSONB，nullable）
- `is_drawn`（Boolean，default False）
- `expert_service_id`（Integer，nullable）

**需要 migration（新增 2 列）：**

```sql
-- migration: NNN_add_draw_trigger_columns.sql
ALTER TABLE activities ADD COLUMN draw_trigger VARCHAR(10) DEFAULT NULL;
-- 'by_time' | 'by_count' | 'both'

ALTER TABLE activities ADD COLUMN draw_participant_count INTEGER DEFAULT NULL;
-- 满员开奖人数阈值
```

同步在 `models.py` Activity 模型中新增：
```python
draw_trigger = Column(String(10), nullable=True)       # by_time / by_count / both
draw_participant_count = Column(Integer, nullable=True) # 满员开奖阈值
```

## 不改动的部分

- `admin_official_routes.py` — 官方活动创建逻辑不变
- 现有 standard 活动的完整流程不变
- DB schema 不变
- `voucher_codes` 字段达人不使用，保持 null
