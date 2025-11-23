# 管理员发布多人任务功能开发日志

> **版本**: v1.5  
> **创建日期**: 2025-01-20  
> **最后更新**: 2025-01-20  
> **设计原则**: 向后兼容、可扩展、安全优先  
> **重要说明**: 本文档描述管理员发布多人任务功能的完整开发方案

---

## 📋 需求概述

开发管理员可以发布多人任务的功能，允许一个任务由多个用户协作完成。与现有的单人任务系统（一个任务只能被一个用户接受）不同，多人任务可以设置最大参与人数，允许多个用户同时参与完成。

**核心功能：**
- **管理员发布官方多人任务**：管理员可以创建需要多人协作完成的任务，标记为"官方任务"，所有人都可以看到和申请
- **任务达人发布多人任务**：任务达人（具有特定服务技能的用户）也可以创建多人任务，提供固定时间段固定人数的服务
- **固定时间段固定人数服务**：任务达人可以为特定服务设置固定时间段和每个时间段的人数限制（如：麻将服务，每小时一个时间段，每个时间段4人，从中午到晚上）
- **非固定时间段服务**：任务达人也可以不设置固定时间段，申请人需要选择截止日期或灵活时间（如：摄影服务，申请人可选择期望完成日期或选择时间灵活）
- **自动接受机制**：官方多人任务不需要管理员同意，用户申请后自动接受并立即进入任务聊天室
- **多人申请机制**：多个用户可以对同一任务进行申请，达到最大参与人数后停止接受申请
- **参与人数限制**：任务可以设置最大参与人数（如：需要7人完成）
- **参与状态管理**：跟踪每个参与者的状态（已接受、进行中、已完成、退出申请中）
- **任务完成判定**：可以设置完成条件（如：所有参与者完成、或达到最小完成人数）
- **积分奖励机制**：多人任务可以只使用积分奖励，不需要现金奖励
- **退出申请机制**：参与者退出任务需要申请，等待管理员审核
- **禁止议价**：多人任务不支持议价功能（`allow_negotiation=false`），用户不能对任务价格进行议价
- **任务达人折扣功能**：虽然多人任务不支持议价，但任务达人可以在发布任务时设置折扣，用于推广服务或填补特定时间段空缺（如：原价10镑，现价8镑，打8折）
- **即时聊天**：用户申请后立即进入任务聊天室，可以与其他参与者聊天
- **向后兼容**：不影响现有的单人任务系统

**业务价值：**
- 支持需要多人协作的大型任务
- 提高任务完成效率
- 增加平台任务类型多样性
- 提升用户参与度和活跃度
- 通过官方任务提升平台权威性和用户信任度
- 任务达人折扣功能帮助推广服务、填补特定时间段空缺、提高上座率

---

## 🎯 MVP 范围说明（v1.0 必须实现）

### 本次迭代必须实现的功能

**核心功能**：
- ✅ 管理员创建官方多人任务（仅支持积分奖励）
- ✅ 用户申请参与（官方任务自动接受）
- ✅ 任务聊天室（申请后自动加入）
- ✅ 参与者退出申请
- ✅ 管理员批准/拒绝退出申请
- ✅ 管理员手动开始任务（不支持自动开始）
- ✅ 参与者提交完成
- ✅ 管理员确认完成并分配奖励（仅支持平均分配积分）

**数据库字段**：
- ✅ 所有必要字段（为未来扩展预留字段，但业务逻辑暂不使用）
- ⚠️ `current_participants`：MVP阶段可以不存，实时 `COUNT(*)`
- ⚠️ `planned_reward_amount` / `planned_points_reward`：MVP阶段可以不存，仅在奖励分配时计算

**限制条件**：
- ❌ 不支持现金奖励（仅支持积分奖励）
- ❌ 不支持自定义奖励分配（仅支持平均分配）
- ❌ 不支持迟到加入（任务开始后禁止新成员申请）
- ❌ 不支持自动开始（仅管理员手动开始）
- ❌ 不支持普通用户发布多人任务（仅管理员）

### 未来扩展（不在本次迭代内）

以下功能在文档中已设计，但**不在 v1.0 实现范围**：
- 任务达人发布多人任务（v1.0 仅支持管理员发布）
- 任务达人设置固定时间段固定人数服务（v1.0 暂不支持）
- 自动开始功能（达到 min_participants 自动开始）
- 迟到加入功能（任务进行中补招）
- 现金奖励或现金+积分奖励
- 自定义奖励分配
- 复杂取消和退款流程（v1.0 仅支持基础取消）

**实现建议**：
- 数据库字段可以提前预留，但业务逻辑和测试优先只实现 MVP 功能
- 这样可以大大减少第一次上线的状态组合，测试工作量也会小很多
- 后续版本再逐步打开扩展功能

---

## 🗄️ 数据库模型设计

### 1. 修改 Task 表

**重要说明**：多人任务仍然创建在 `tasks` 表中，与单人任务共享同一张表。通过 `is_multi_participant` 字段区分任务类型。

**发布者和接收者处理**（重要业务逻辑）：
- **任务达人发布的多人任务**（`created_by_expert=true`）：
  - **任务达人是接收者（taker_id）**：任务达人提供服务，用户付费，所以任务达人是收钱的一方
  - **用户是参与者（task_participants）**：申请参与的用户是付费方，存储在 `task_participants` 表中
  - **poster_id**：可以设置为系统用户ID或NULL（根据业务需求，任务达人作为服务提供者，不是传统意义上的"发布者"）
  - **示例**：麻将服务，任务达人提供麻将桌和服务，用户付费参与，任务达人收钱
  
- **管理员发布的多人任务**（`created_by_admin=true`）：
  - **根据任务类型决定角色**：
    - **收钱任务**（用户付费给平台/管理员）：管理员是接收者（`taker_id`），用户是参与者（`task_participants`）
    - **发钱任务**（平台/管理员付费给用户）：管理员是发布者（`poster_id`），用户是参与者（`task_participants`），`taker_id` 为 NULL
  - **判断依据**：根据任务的 `reward_type` 和业务逻辑判断是收钱还是发钱
  - **示例**：
    - 收钱任务：平台组织的付费活动，用户付费参与，平台收钱
    - 发钱任务：平台发布的奖励任务，用户完成任务后获得奖励，平台发钱

- **参与者（task_participants）**：
  - 所有参与者信息存储在 `task_participants` 表中
  - 通过 `task_participants` 表关联查询所有参与者
  - 参与者可能是付费方（任务达人/管理员收钱）或奖励接收方（平台发钱）

添加多人任务相关字段：

```sql
ALTER TABLE tasks ADD COLUMN is_multi_participant BOOLEAN DEFAULT false;  -- 是否为多人任务
ALTER TABLE tasks ADD COLUMN is_official_task BOOLEAN DEFAULT false;  -- 是否为官方任务（管理员发布）
ALTER TABLE tasks ADD COLUMN max_participants INTEGER DEFAULT 1;  -- 最大参与人数（默认1，保持向后兼容）
ALTER TABLE tasks ADD COLUMN min_participants INTEGER DEFAULT 1;  -- 最小参与人数（用于判定任务是否可开始）
ALTER TABLE tasks ADD COLUMN current_participants INTEGER DEFAULT 0;  -- 当前参与人数
ALTER TABLE tasks ADD COLUMN completion_rule VARCHAR(20) DEFAULT 'all';  -- 完成规则：all（所有人完成）、min（达到最小人数即可）
ALTER TABLE tasks ADD COLUMN reward_distribution VARCHAR(20) DEFAULT 'equal';  -- 奖励分配方式：equal（平均分配）、custom（自定义）
ALTER TABLE tasks ADD COLUMN reward_type VARCHAR(20) DEFAULT 'cash';  -- 奖励类型：cash（现金）、points（积分）、both（现金+积分）
ALTER TABLE tasks ADD COLUMN points_reward BIGINT DEFAULT 0;  -- 积分奖励（如果reward_type包含points）
ALTER TABLE tasks ADD COLUMN auto_accept BOOLEAN DEFAULT false;  -- 是否自动接受申请（官方任务默认true）
ALTER TABLE tasks ADD COLUMN allow_negotiation BOOLEAN DEFAULT true;  -- 是否允许议价（多人任务默认false）
ALTER TABLE tasks ADD COLUMN created_by_admin BOOLEAN DEFAULT false;  -- 是否由管理员创建
ALTER TABLE tasks ADD COLUMN admin_creator_id VARCHAR(36) REFERENCES admin_users(id);  -- 创建任务的管理员ID（使用UUID格式，与admin_users表一致）
ALTER TABLE tasks ADD COLUMN created_by_expert BOOLEAN DEFAULT false;  -- 是否由任务达人创建
ALTER TABLE tasks ADD COLUMN expert_creator_id VARCHAR(8) REFERENCES users(id);  -- 创建任务的任务达人ID（使用VARCHAR(8)格式，与users表一致）
ALTER TABLE tasks ADD COLUMN expert_service_id INTEGER REFERENCES task_expert_services(id) ON DELETE RESTRICT;  -- 关联的达人服务ID（任务达人发布的多人任务必须关联一个达人服务）
ALTER TABLE tasks ADD COLUMN is_fixed_time_slot BOOLEAN DEFAULT false;  -- 是否为固定时间段服务（任务达人可设置，可选）
ALTER TABLE tasks ADD COLUMN time_slot_duration_minutes INTEGER;  -- 时间段时长（分钟，如60表示1小时，120表示2小时等，仅当is_fixed_time_slot=true时使用）
ALTER TABLE tasks ADD COLUMN time_slot_start_time TIME;  -- 时间段开始时间（如12:00表示中午12点开始，仅当is_fixed_time_slot=true时使用）
ALTER TABLE tasks ADD COLUMN time_slot_end_time TIME;  -- 时间段结束时间（如22:00表示晚上10点结束，仅当is_fixed_time_slot=true时使用）
ALTER TABLE tasks ADD COLUMN participants_per_slot INTEGER;  -- 每个时间段的人数限制（如4人，仅当is_fixed_time_slot=true时使用）
ALTER TABLE tasks ADD COLUMN original_price_per_participant DECIMAL(12, 2);  -- 原价（每人，仅用于任务达人发布的多人任务显示折扣）
ALTER TABLE tasks ADD COLUMN discount_percentage DECIMAL(5, 2);  -- 折扣百分比（0-100，如20表示打8折，仅用于任务达人发布的多人任务）
ALTER TABLE tasks ADD COLUMN discounted_price_per_participant DECIMAL(12, 2);  -- 折扣后价格（每人，仅用于任务达人发布的多人任务）

-- 添加数据库级CHECK约束（跨字段验证）
ALTER TABLE tasks ADD CONSTRAINT chk_tasks_participants_range CHECK (
    max_participants >= min_participants AND min_participants >= 1
);
ALTER TABLE tasks ADD CONSTRAINT chk_tasks_reward_non_negative CHECK (
    (reward IS NULL OR reward >= 0) AND (points_reward IS NULL OR points_reward >= 0)
);
ALTER TABLE tasks ADD CONSTRAINT chk_tasks_reward_type_consistency CHECK (
    (reward_type = 'cash' AND reward > 0 AND (points_reward IS NULL OR points_reward = 0)) OR
    (reward_type = 'points' AND points_reward > 0 AND (reward IS NULL OR reward = 0)) OR
    (reward_type = 'both' AND reward > 0 AND points_reward > 0)
);
-- MVP 限制约束（v1.0 仅支持官方多人积分任务 + 平均分配，未来可能移除）
ALTER TABLE tasks ADD CONSTRAINT chk_mvp_official_multi_points_equal CHECK (
    NOT is_multi_participant
    OR NOT is_official_task
    OR (reward_type = 'points' AND reward_distribution = 'equal')
);
-- 任务达人发布的多人任务必须关联达人服务
ALTER TABLE tasks ADD CONSTRAINT chk_expert_task_service CHECK (
    NOT created_by_expert OR expert_service_id IS NOT NULL
);
-- 固定时间段服务约束（如果is_fixed_time_slot=true，必须提供所有时间段相关字段；如果is_fixed_time_slot=false，时间段相关字段应为NULL）
ALTER TABLE tasks ADD CONSTRAINT chk_fixed_time_slot_fields CHECK (
    (NOT is_fixed_time_slot AND time_slot_duration_minutes IS NULL AND time_slot_start_time IS NULL AND time_slot_end_time IS NULL AND participants_per_slot IS NULL)
    OR (is_fixed_time_slot 
        AND time_slot_duration_minutes IS NOT NULL 
        AND time_slot_duration_minutes > 0
        AND time_slot_start_time IS NOT NULL
        AND time_slot_end_time IS NOT NULL
        AND time_slot_end_time > time_slot_start_time
        AND participants_per_slot IS NOT NULL
        AND participants_per_slot >= 1
        AND participants_per_slot <= max_participants)
);
-- 折扣相关约束（如果设置了折扣，必须提供原价和折扣后价格）
ALTER TABLE tasks ADD CONSTRAINT chk_discount_fields CHECK (
    (discount_percentage IS NULL AND original_price_per_participant IS NULL AND discounted_price_per_participant IS NULL)
    OR (discount_percentage IS NOT NULL 
        AND discount_percentage >= 0 
        AND discount_percentage <= 100
        AND original_price_per_participant IS NOT NULL
        AND original_price_per_participant > 0
        AND discounted_price_per_participant IS NOT NULL
        AND discounted_price_per_participant > 0
        AND discounted_price_per_participant <= original_price_per_participant
        AND ABS(discounted_price_per_participant - original_price_per_participant * (1 - discount_percentage / 100)) < 0.01)  -- 允许浮点数精度误差
);
```

**字段说明：**
- `is_multi_participant`: 标识是否为多人任务（false表示单人任务，保持向后兼容）
- `is_official_task`: 标识是否为官方任务（管理员发布的任务，所有人都可以看到和申请）
- `max_participants`: 最大参与人数，默认1（单人任务）
- `min_participants`: 最小参与人数，仅用于判定任务是否可以开始。一旦任务开始，即使后续有人退出导致人数 < `min_participants`，任务仍可继续进行
- `current_participants`: 当前已接受的参与人数（仅作为展示用缓存，业务决策使用实时COUNT(*)查询）
- `completion_rule`: 
  - `all`: 需要所有参与者都完成才能判定任务完成
  - `min`: 达到最小完成人数即可判定任务完成
- `reward_distribution`: 
  - `equal`: 总奖励平均分配给所有参与者
  - `custom`: 管理员可以自定义每个参与者的奖励
- `reward_type`: 
  - `cash`: 仅现金奖励（`reward > 0`，`points_reward = 0` 或 NULL）
  - `points`: 仅积分奖励（`points_reward > 0`，`reward = 0` 或 NULL）
  - `both`: 现金+积分奖励（`reward > 0` 且 `points_reward > 0`）
  - **重要说明**：当 `reward_type='both'` 时，任务级别同时有现金和积分奖励，但具体到某个参与者，可以只拿现金、只拿积分或两者都拿，按 `task_participant_rewards.reward_type` 为准
- `points_reward`: 积分奖励数量（如果reward_type包含points）
- `auto_accept`: 是否自动接受申请（官方多人任务默认true，用户申请后立即接受）
- `allow_negotiation`: 是否允许议价（多人任务默认false，不支持议价）
- `created_by_admin`: 标识任务是否由管理员创建
- `admin_creator_id`: 创建任务的管理员ID（可为空，用于普通用户创建的单人任务，使用VARCHAR(36)以支持UUID格式）
- `created_by_expert`: 标识任务是否由任务达人创建
- `expert_creator_id`: 创建任务的任务达人ID（可为空，用于管理员创建的任务，使用VARCHAR(8)格式，与users表一致）
- `expert_service_id`: 关联的达人服务ID（**任务达人发布的多人任务必须关联一个达人服务**）
  - 外键关联 `task_expert_services` 表
  - 当 `created_by_expert=true` 时，此字段必须设置
  - 用于标识此多人任务对应的达人服务
  - 申请人申请参与此任务时，实际上是在申请此达人服务
  - 价格基础：任务的 `reward` 字段应基于达人服务的 `base_price`，但任务达人可以设置折扣
- `is_fixed_time_slot`: 标识是否为固定时间段服务（任务达人可设置，可选，默认false）
  - `true`：固定时间段服务（如麻将服务，每小时一个时间段）
  - `false`：非固定时间段服务（申请人需要选择截止日期或灵活时间）
- `time_slot_duration_minutes`: 时间段时长（分钟），如60表示1小时，120表示2小时等（仅当is_fixed_time_slot=true时使用）
- `time_slot_start_time`: 时间段开始时间（TIME类型），如12:00表示从中午12点开始（仅当is_fixed_time_slot=true时使用）
- `time_slot_end_time`: 时间段结束时间（TIME类型），如22:00表示到晚上10点结束（仅当is_fixed_time_slot=true时使用）
- `participants_per_slot`: 每个时间段的人数限制，如4人（麻将需要4人，仅当is_fixed_time_slot=true时使用）
- `original_price_per_participant`: 原价（每人），仅用于任务达人发布的多人任务显示折扣信息（如：原价10镑）
- `discount_percentage`: 折扣百分比（0-100），如20表示打8折（原价10镑，现价8镑），仅用于任务达人发布的多人任务
- `discounted_price_per_participant`: 折扣后价格（每人），仅用于任务达人发布的多人任务（如：现价8镑）

### 2. 创建 TaskParticipant 表

存储任务参与者信息：

```sql
CREATE TABLE task_participants (
    id BIGSERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending',  -- pending, accepted, in_progress, completed, exit_requested, exited, cancelled
    previous_status VARCHAR(20),  -- 前一个状态（用于退出申请被拒绝时恢复）
    time_slot_id INTEGER,  -- 时间段ID（仅用于固定时间段服务，标识参与者申请的时间段）
    preferred_deadline TIMESTAMPTZ,  -- 申请人期望的截止日期（仅用于非固定时间段服务，申请人选择）
    is_flexible_time BOOLEAN DEFAULT false,  -- 是否为灵活时间（仅用于非固定时间段服务，申请人选择，true表示时间灵活，false表示有具体截止日期）
    planned_reward_amount DECIMAL(12, 2),  -- 该参与者计划应得的现金奖励（如果reward_distribution=custom，仅用于展示，实际值以task_participant_rewards表为准）
    planned_points_reward BIGINT DEFAULT 0,  -- 该参与者计划应得的积分奖励（仅用于展示，实际值以task_participant_rewards表为准）
    applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,  -- 申请时间
    accepted_at TIMESTAMPTZ,  -- 接受时间（自动接受时等于applied_at，待审核时为NULL）
    started_at TIMESTAMPTZ,  -- 开始时间（任务开始）
    completed_at TIMESTAMPTZ,  -- 完成时间
    exit_requested_at TIMESTAMPTZ,  -- 退出申请时间
    exit_reason TEXT,  -- 退出原因
    exited_at TIMESTAMPTZ,  -- 退出时间（管理员批准退出）
    cancelled_at TIMESTAMPTZ,  -- 取消时间（管理员取消）
    completion_notes TEXT,  -- 完成备注
    admin_notes TEXT,  -- 管理员备注
    idempotency_key VARCHAR(64),  -- 幂等键（用于防止重复操作）
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_task_participant UNIQUE(task_id, user_id),  -- 确保同一用户不能重复申请同一任务（普通多人任务，time_slot_id为NULL时使用此约束）
    -- 注意：对于固定时间段服务，需要在应用层验证同一用户不能重复申请同一时间段
    -- 可以使用部分唯一索引：CREATE UNIQUE INDEX idx_task_participant_time_slot ON task_participants(task_id, user_id, time_slot_id) WHERE time_slot_id IS NOT NULL;
    CONSTRAINT chk_participant_time_info CHECK (
        -- 如果任务有固定时间段，必须提供time_slot_id
        -- 如果任务没有固定时间段，必须提供preferred_deadline或is_flexible_time=true
        -- 此约束在应用层验证，数据库层不强制（因为需要关联tasks表）
    )
    CONSTRAINT uq_participant_idempotency UNIQUE(idempotency_key),  -- 幂等键唯一约束
    CONSTRAINT chk_participant_status CHECK (
        status IN ('pending', 'accepted', 'in_progress', 'completed', 'exit_requested', 'exited', 'cancelled')
    )
);

-- 索引优化说明：
-- 1. 唯一约束 uq_task_participant UNIQUE(task_id, user_id) 会自动创建索引，无需手动创建 idx_task_participants_task_user
-- 2. 复合索引 (task_id, status, updated_at) 可以覆盖单列查询（left prefix），因此单列的 task_id 索引可选
-- 3. 根据实际查询模式，保留以下索引：
CREATE INDEX idx_task_participants_user ON task_participants(user_id);  -- 用户查询自己的任务
CREATE INDEX idx_task_participants_status ON task_participants(status);  -- 状态过滤
CREATE INDEX idx_task_participants_task_status_updated ON task_participants(task_id, status, updated_at);  -- 管理页排序查询（覆盖 task_id 和 task_id+status 查询）
CREATE UNIQUE INDEX idx_task_participant_time_slot ON task_participants(task_id, user_id, time_slot_id) WHERE time_slot_id IS NOT NULL;  -- 固定时间段服务：确保同一用户不能重复申请同一时间段
CREATE INDEX idx_task_participants_time_slot ON task_participants(task_id, time_slot_id, status) WHERE time_slot_id IS NOT NULL;  -- 固定时间段服务：查询某个时间段的参与者数量
```

**字段说明：**
- `task_id`: 关联的任务ID
- `user_id`: 参与者用户ID
- `status`: 参与者状态
  - `pending`: 待审核（非官方任务需要等待管理员审核，官方任务不会进入此状态）
  - `accepted`: 已接受（官方任务自动接受，用户申请后立即进入此状态，可以进入聊天室）
  - `in_progress`: 进行中（任务已开始，参与者正在工作）
  - `completed`: 已完成（参与者已完成自己的部分）
  - `exit_requested`: 退出申请中（参与者申请退出，等待管理员审核）
  - `exited`: 已退出（管理员批准退出）
  - `cancelled`: 已取消（管理员取消参与者资格）
- `previous_status`: 前一个状态（当进入 `exit_requested` 时保存，用于拒绝退出申请时恢复）
- `time_slot_id`: 时间段ID（仅用于固定时间段服务，标识参与者申请的时间段，普通多人任务为NULL）
- `preferred_deadline`: 申请人期望的截止日期（仅用于非固定时间段服务，申请人选择，如果is_flexible_time=true则为NULL）
- `is_flexible_time`: 是否为灵活时间（仅用于非固定时间段服务，申请人选择，true表示时间灵活，false表示有具体截止日期）
- `planned_reward_amount`: 该参与者**计划**应得的现金奖励金额（仅在reward_distribution=custom时使用，仅用于展示）
- `planned_points_reward`: 该参与者**计划**应得的积分奖励（仅用于展示）

**重要说明**：
- 参与者表中的 `planned_reward_amount` 和 `planned_points_reward` 字段为**计划值**，仅用于展示和初步计算
- **实际发放值**以 `task_participant_rewards` 表为准（`reward_amount` 和 `points_amount`）
- 读接口应根据 `task_participant_rewards` 表做聚合，返回实际发放值
- 如果计划值与实际值不一致，以实际值为准
- **MVP阶段建议**：如果短期内只需要"平均分配积分"，可以不在参与者表存储计划值，仅在奖励分配时计算并写入 `task_participant_rewards` 表
- `applied_at`: 申请时间
- `accepted_at`: 接受时间（自动接受时等于applied_at，待审核时为NULL）
- `started_at`: 开始时间（任务开始，参与者可以开始工作，初始为NULL）
- `completed_at`: 完成时间（参与者完成自己的部分，初始为NULL）
- `exit_requested_at`: 退出申请时间（初始为NULL）
- `exit_reason`: 退出原因（参与者申请退出时填写）
- `exited_at`: 退出时间（管理员批准退出，初始为NULL）
- `cancelled_at`: 取消时间（初始为NULL）
- `completion_notes`: 完成备注（参与者提交完成时填写）
- `admin_notes`: 管理员备注（管理员可以添加备注）
- `idempotency_key`: 幂等键（用于防止重复操作，如重复申请、重复完成等）

### 3. 创建 TaskParticipantReward 表

存储参与者奖励分配记录（用于审计和支付）：

```sql
CREATE TABLE task_participant_rewards (
    id BIGSERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    participant_id BIGINT NOT NULL REFERENCES task_participants(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_type VARCHAR(20) DEFAULT 'cash',  -- cash, points, both
    reward_amount DECIMAL(12, 2),  -- 实际发放的现金奖励金额（如果reward_type包含cash）
    points_amount BIGINT,  -- 实际发放的积分奖励（如果reward_type包含points）
    currency CHAR(3) DEFAULT 'GBP',
    payment_status VARCHAR(20) DEFAULT 'pending',  -- pending, paid, failed, refunded
    points_status VARCHAR(20) DEFAULT 'pending',  -- pending, credited, failed, refunded
    paid_at TIMESTAMPTZ,  -- 支付时间（初始为NULL）
    points_credited_at TIMESTAMPTZ,  -- 积分发放时间（初始为NULL）
    payment_method VARCHAR(50),  -- 支付方式
    payment_reference VARCHAR(100),  -- 支付参考号
    idempotency_key VARCHAR(64),  -- 幂等键（用于防止重复支付/发放）
    external_txn_id VARCHAR(100),  -- 外部交易ID（支付网关返回的交易ID）
    reversal_reference VARCHAR(100),  -- 回退关联ID（用于关联原交易，用于积分/现金追回时的对账）
    admin_operator_id VARCHAR(36) REFERENCES admin_users(id) ON DELETE SET NULL,  -- 操作的管理员ID（用于审计）
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_reward_idempotency UNIQUE(idempotency_key),  -- 幂等键唯一约束
    CONSTRAINT uq_reward_external_txn UNIQUE(external_txn_id),  -- 外部交易ID唯一约束（防止重复处理）
    CONSTRAINT chk_reward_payment_status CHECK (
        payment_status IN ('pending', 'paid', 'failed', 'refunded')
    ),
    CONSTRAINT chk_reward_points_status CHECK (
        points_status IN ('pending', 'credited', 'failed', 'refunded')
    ),
    CONSTRAINT chk_reward_type_values CHECK (
        reward_type IN ('cash', 'points', 'both')
    ),
    CONSTRAINT chk_reward_type_amount CHECK (
        (reward_type = 'cash' AND reward_amount IS NOT NULL AND points_amount IS NULL) OR
        (reward_type = 'points' AND reward_amount IS NULL AND points_amount IS NOT NULL) OR
        (reward_type = 'both' AND reward_amount IS NOT NULL AND points_amount IS NOT NULL)
    ),
    CONSTRAINT chk_reward_positive_amount CHECK (
        (reward_amount IS NULL OR reward_amount > 0) AND
        (points_amount IS NULL OR points_amount > 0)
    )
);

-- 添加触发器，确保奖励表的reward_type与任务表的reward_type一致（应用层也应做此验证）
CREATE OR REPLACE FUNCTION validate_reward_type_consistency() RETURNS trigger AS $$
DECLARE
    task_reward_type VARCHAR(20);
BEGIN
    SELECT reward_type INTO task_reward_type FROM tasks WHERE id = NEW.task_id;
    IF task_reward_type IS NULL THEN
        RAISE EXCEPTION 'Task not found: %', NEW.task_id;
    END IF;
    -- 验证奖励类型一致性
    IF task_reward_type = 'points' AND NEW.reward_type != 'points' THEN
        RAISE EXCEPTION 'Reward type mismatch: task is points-only but reward type is %', NEW.reward_type;
    END IF;
    IF task_reward_type = 'cash' AND NEW.reward_type != 'cash' THEN
        RAISE EXCEPTION 'Reward type mismatch: task is cash-only but reward type is %', NEW.reward_type;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_reward_type_consistency
BEFORE INSERT OR UPDATE ON task_participant_rewards
FOR EACH ROW EXECUTE FUNCTION validate_reward_type_consistency();

CREATE INDEX idx_participant_rewards_task ON task_participant_rewards(task_id);
CREATE INDEX idx_participant_rewards_participant ON task_participant_rewards(participant_id);
CREATE INDEX idx_participant_rewards_user ON task_participant_rewards(user_id);
CREATE INDEX idx_participant_rewards_payment_status ON task_participant_rewards(payment_status);
CREATE INDEX idx_participant_rewards_points_status ON task_participant_rewards(points_status);
CREATE INDEX idx_participant_rewards_task_status ON task_participant_rewards(task_id, payment_status, points_status);  -- 用于查询任务奖励发放状态
```

**字段说明：**
- `task_id`: 关联的任务ID
- `participant_id`: 关联的参与者记录ID
- `user_id`: 参与者用户ID
- `reward_type`: 奖励类型（cash, points, both）
- `reward_amount`: 实际发放的现金奖励金额（如果reward_type包含cash，初始为NULL，不允许为0）
- `points_amount`: 实际发放的积分奖励（如果reward_type包含points，初始为NULL，不允许为0）
- **重要说明**：不允许 0 金额记录（`reward_amount` 和 `points_amount` 必须为 NULL 或 > 0），用于避免"看起来像发了奖励，实际给了 0"的歧义
- `currency`: 货币类型
- `payment_status`: 现金支付状态
- `points_status`: 积分发放状态
- `paid_at`: 现金支付时间（初始为NULL）
- `points_credited_at`: 积分发放时间（初始为NULL）
- `payment_method`: 支付方式
- `payment_reference`: 支付参考号（用于对账）
- `idempotency_key`: 幂等键（用于防止重复支付/发放，客户端生成）
- `external_txn_id`: 外部交易ID（支付网关返回的交易ID，用于对账和重试）
- `reversal_reference`: 回退关联ID（用于关联原交易，用于积分/现金追回时的对账）
- `admin_operator_id`: 操作的管理员ID（用于审计，记录是谁发起的奖励分配）

### 4. 创建 TaskAuditLog 表

存储任务和参与者的审计日志（用于追踪所有状态变更和操作）：

```sql
CREATE TABLE task_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    task_id INTEGER REFERENCES tasks(id) ON DELETE CASCADE,
    participant_id BIGINT REFERENCES task_participants(id) ON DELETE CASCADE,
    user_id VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    admin_id VARCHAR(36) REFERENCES admin_users(id) ON DELETE SET NULL,
    action_type VARCHAR(50) NOT NULL,  -- 操作类型：task_created, participant_applied, status_changed, reward_distributed等
    entity_type VARCHAR(20) NOT NULL,  -- 实体类型：task, participant, reward
    old_value JSONB,  -- 变更前的值（JSON格式）
    new_value JSONB,  -- 变更后的值（JSON格式）
    description TEXT,  -- 操作描述
    ip_address INET,  -- 操作者IP地址
    user_agent TEXT,  -- 用户代理
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_task ON task_audit_logs(task_id);
CREATE INDEX idx_audit_logs_participant ON task_audit_logs(participant_id);
CREATE INDEX idx_audit_logs_user ON task_audit_logs(user_id);
CREATE INDEX idx_audit_logs_admin ON task_audit_logs(admin_id);
CREATE INDEX idx_audit_logs_action ON task_audit_logs(action_type);
CREATE INDEX idx_audit_logs_created ON task_audit_logs(created_at);
CREATE INDEX idx_audit_logs_task_created ON task_audit_logs(task_id, created_at);  -- 用于查询任务操作历史
```

**字段说明：**
- `task_id`: 关联的任务ID（可为空，用于系统级操作）
- `participant_id`: 关联的参与者记录ID（可为空）
- `user_id`: 被影响的业务用户ID（可为空，用于管理员直接操作任务）
  - **语义**：记录操作主要涉及到的业务用户（如：用户申请参与、用户提交完成）
  - **代理场景**：管理员代表用户操作时，应同时记录 `user_id`（被代理用户）和 `admin_id`（代理管理员）
- `admin_id`: 操作执行者ID（管理员，可为空，用于用户操作）
  - **语义**：记录谁执行了这个操作（管理员）
  - **代理场景**：管理员代表用户操作时，应同时记录 `user_id`（被代理用户）和 `admin_id`（代理管理员）
- **操作者规则**：
  - **至少有一个不为 NULL**：`user_id` 和 `admin_id` 必须至少有一个不为 NULL
  - **允许两个都不为空**：代理操作场景下，`user_id` 和 `admin_id` 可以同时不为 NULL
  - **应用层校验**：`(user_id IS NOT NULL) OR (admin_id IS NOT NULL)`
- **实体关系说明**：
  - `entity_type` + `task_id`/`participant_id` 始终指：被修改的那条业务实体
  - `admin_id` = 操作执行者（谁执行了这个操作）
  - `user_id` = 被影响的业务用户（如果有，如参与者、任务发布者等）
  - **示例**：管理员A帮用户U批准退出参与者P
    - `admin_id` = A（操作执行者）
    - `user_id` = U（被影响的业务用户）
    - `participant_id` = P（被修改的实体）
    - `entity_type` = 'participant'
- `action_type`: 操作类型（如：task_created, participant_applied, status_changed, reward_distributed, exit_approved等）
- `entity_type`: 实体类型（task, participant, reward）
- `old_value`: 变更前的值（JSON格式，便于查询和回滚）
- `new_value`: 变更后的值（JSON格式）
- `description`: 操作描述（人类可读的描述，代理操作需标注代理来源）
- `ip_address`: 操作者IP地址（用于安全审计）
- `user_agent`: 用户代理（用于安全审计）

### 5. 创建 ChatRoom 表（用于不可预测的聊天室ID）

存储任务聊天室信息：

```sql
CREATE TABLE chat_rooms (
    id BIGSERIAL PRIMARY KEY,
    room_code VARCHAR(32) UNIQUE NOT NULL,  -- 不可预测的房间代码（UUID或随机字符串）
    task_id INTEGER UNIQUE REFERENCES tasks(id) ON DELETE CASCADE,
    room_type VARCHAR(20) DEFAULT 'task',  -- task, direct, group
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_chat_rooms_task ON chat_rooms(task_id);
CREATE INDEX idx_chat_rooms_code ON chat_rooms(room_code);
```

**字段说明：**
- `room_code`: 不可预测的房间代码（使用UUID或随机字符串，不暴露任务ID）
- `task_id`: 关联的任务ID（唯一约束，一个任务对应一个聊天室）
- `room_type`: 房间类型（task表示任务聊天室）

### 6. 为 Task 表添加索引

```sql
-- 为常用查询添加联合索引
CREATE INDEX idx_tasks_multi_official ON tasks(is_multi_participant, is_official_task, status);
CREATE INDEX idx_tasks_status_deadline ON tasks(status, deadline);
CREATE INDEX idx_tasks_admin_creator ON tasks(created_by_admin, admin_creator_id);
CREATE INDEX idx_tasks_reward_type ON tasks(reward_type, status);
-- 覆盖索引：用于列表页常用过滤和排序
CREATE INDEX idx_tasks_official_status_deadline ON tasks(is_official_task, status, deadline DESC) 
  WHERE is_official_task = true;  -- 部分索引，仅针对官方任务
-- 参与者列表常用排序索引
CREATE INDEX idx_task_participants_task_status_completed ON task_participants(task_id, status, completed_at DESC NULLS LAST);
```

### 7. 创建 updated_at 自动更新触发器

为所有需要乐观锁的表添加 `updated_at` 自动更新触发器：

```sql
-- 创建触发器函数
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为 tasks 表添加触发器
CREATE TRIGGER trg_tasks_updated_at
BEFORE UPDATE ON tasks
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 为 task_participants 表添加触发器
CREATE TRIGGER trg_task_participants_updated_at
BEFORE UPDATE ON task_participants
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 为 task_participant_rewards 表添加触发器
CREATE TRIGGER trg_task_participant_rewards_updated_at
BEFORE UPDATE ON task_participant_rewards
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 为 chat_rooms 表添加触发器
CREATE TRIGGER trg_chat_rooms_updated_at
BEFORE UPDATE ON chat_rooms
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 注意：task_audit_logs 表通常不需要 updated_at 自动更新（审计日志只插入不更新）
```

**说明**：这些触发器确保每次 UPDATE 操作时，`updated_at` 字段自动更新为当前时间，用于乐观锁机制。

---

## 🔌 API 接口设计

### 1. 管理员创建官方多人任务

**接口**: `POST /api/admin/tasks/multi-participant`

**权限**: 需要管理员认证

**请求体**:
```json
{
  "title": "大型活动组织任务",
  "description": "需要多人协作完成的活动组织任务",
  "deadline": "2025-02-01T00:00:00Z",
  "reward_type": "points",
  "points_reward": 5000,
  "currency": "GBP",
  "location": "London",
  "task_type": "Social Help",
  "max_participants": 7,
  "min_participants": 5,
  "completion_rule": "min",
  "reward_distribution": "equal",
  "images": ["url1", "url2"],
  "is_public": true
}
```

**注意**：当 `reward_type="points"` 时，`reward` 字段应省略或为 0，且数据库中的 `reward` 字段应为 0 或 NULL。

**响应**:
```json
{
  "id": 123,
  "title": "大型活动组织任务",
  "description": "需要多人协作完成的活动组织任务",
  "deadline": "2025-02-01T00:00:00Z",
  "reward": 0,
  "reward_type": "points",
  "points_reward": 5000,
  "currency": "GBP",
  "location": "London",
  "task_type": "Social Help",
  "status": "open",
  "is_multi_participant": true,
  "is_official_task": true,
  "max_participants": 7,
  "min_participants": 5,
  "current_participants": 0,
  "completion_rule": "min",
  "reward_distribution": "equal",
  "auto_accept": true,
  "allow_negotiation": false,
  "created_by_admin": true,
  "admin_creator_id": "A0001",
  "created_at": "2025-01-20T10:00:00Z"
}
```

**注意**：当 `reward_type="points"` 时，响应中的 `reward` 字段为 0，数据库中的 `reward` 字段应为 0 或 NULL。

**业务逻辑**:
1. 验证管理员权限
2. 验证任务数据（max_participants >= min_participants >= 1）
3. 验证奖励类型和金额（如果reward_type包含points，points_reward必须>0）
4. 创建任务记录，设置：
   - `is_multi_participant=true`
   - `is_official_task=true`（管理员发布的任务都是官方任务）
   - `created_by_admin=true`
   - `auto_accept=true`（官方任务自动接受申请）
   - `allow_negotiation=false`（多人任务不支持议价）
5. 设置 `poster_id` 为系统用户ID或管理员关联的用户ID（如果需要）
6. 返回创建的任务信息

### 2. 任务达人创建多人任务（固定时间段服务）

**接口**: `POST /api/expert/tasks/multi-participant`

**权限**: 需要用户认证，且用户必须是任务达人（expert）

**请求体（固定时间段服务，带折扣）**:
```json
{
  "title": "麻将服务",
  "description": "提供麻将娱乐服务，每小时一个时间段，每个时间段4人。1点到2点时间段缺人，特价优惠！",
  "deadline": "2025-02-01T00:00:00Z",
  "reward_type": "cash",
  "reward": 8.00,
  "currency": "GBP",
  "location": "London",
  "task_type": "Entertainment",
  "max_participants": 4,
  "min_participants": 4,
  "completion_rule": "all",
  "reward_distribution": "equal",
  "expert_service_id": 123,  // 必须：关联的达人服务ID
  "is_fixed_time_slot": true,
  "time_slot_duration_minutes": 60,
  "time_slot_start_time": "12:00",
  "time_slot_end_time": "22:00",
  "participants_per_slot": 4,
  "original_price_per_participant": 10.00,  // 基于达人服务的base_price
  "discount_percentage": 20.00,
  "discounted_price_per_participant": 8.00,
  "images": ["url1", "url2"],  // 可选，如果不提供则使用达人服务的images
  "is_public": true
}
```

**请求体（固定时间段服务，无折扣）**:
```json
{
  "title": "麻将服务",
  "description": "提供麻将娱乐服务，每小时一个时间段，每个时间段4人",
  "deadline": "2025-02-01T00:00:00Z",
  "reward_type": "cash",
  "reward": 10.00,
  "currency": "GBP",
  "location": "London",
  "task_type": "Entertainment",
  "max_participants": 4,
  "min_participants": 4,
  "completion_rule": "all",
  "reward_distribution": "equal",
  "expert_service_id": 123,  // 必须：关联的达人服务ID
  "is_fixed_time_slot": true,
  "time_slot_duration_minutes": 60,
  "time_slot_start_time": "12:00",
  "time_slot_end_time": "22:00",
  "participants_per_slot": 4,
  "images": ["url1", "url2"],  // 可选，如果不提供则使用达人服务的images
  "is_public": true
}
```

**请求体（非固定时间段服务，任务达人发布）**:
```json
{
  "title": "摄影服务",
  "description": "提供专业摄影服务，申请人可选择截止日期或灵活时间",
  "deadline": "2025-02-28T00:00:00Z",
  "reward_type": "cash",
  "reward": 150.00,
  "currency": "GBP",
  "location": "London",
  "task_type": "Photography",
  "max_participants": 1,
  "min_participants": 1,
  "completion_rule": "all",
  "reward_distribution": "equal",
  "expert_service_id": 124,  // 必须：关联的达人服务ID
  "is_fixed_time_slot": false,
  "images": ["url1", "url2"],  // 可选，如果不提供则使用达人服务的images
  "is_public": true
}
```

**请求体（普通多人任务，非固定时间段）**:
```json
{
  "title": "团队协作任务",
  "description": "需要多人协作完成的任务",
  "deadline": "2025-02-01T00:00:00Z",
  "reward_type": "points",
  "points_reward": 3000,
  "currency": "GBP",
  "location": "London",
  "task_type": "Social Help",
  "max_participants": 5,
  "min_participants": 3,
  "completion_rule": "min",
  "reward_distribution": "equal",
  "is_fixed_time_slot": false,
  "images": ["url1", "url2"],
  "is_public": true
}
```

**响应（带折扣）**:
```json
{
  "id": 124,
  "title": "麻将服务",
  "description": "提供麻将娱乐服务，每小时一个时间段，每个时间段4人。1点到2点时间段缺人，特价优惠！",
  "deadline": "2025-02-01T00:00:00Z",
  "reward": 8.00,
  "reward_type": "cash",
  "currency": "GBP",
  "location": "London",
  "task_type": "Entertainment",
  "status": "open",
  "is_multi_participant": true,
  "is_official_task": false,
  "created_by_expert": true,
  "expert_creator_id": "12345678",
  "max_participants": 4,
  "min_participants": 4,
  "current_participants": 0,
  "completion_rule": "all",
  "reward_distribution": "equal",
  "auto_accept": false,
  "allow_negotiation": false,
  "is_fixed_time_slot": true,
  "time_slot_duration_minutes": 60,
  "time_slot_start_time": "12:00",
  "time_slot_end_time": "22:00",
  "participants_per_slot": 4,
  "original_price_per_participant": 10.00,
  "discount_percentage": 20.00,
  "discounted_price_per_participant": 8.00,
  "has_discount": true,
  "time_slots": [
    {
      "slot_id": 1,
      "start_time": "12:00",
      "end_time": "13:00",
      "current_participants": 0,
      "max_participants": 4,
      "is_full": false
    },
    {
      "slot_id": 2,
      "start_time": "13:00",
      "end_time": "14:00",
      "current_participants": 0,
      "max_participants": 4,
      "is_full": false
    }
    // ... 更多时间段
  ],
  "created_at": "2025-01-20T10:00:00Z"
}
```

**业务逻辑**:
1. 验证用户是否为任务达人（expert）
2. **验证达人服务关联**（必需）：
   - 验证请求中包含 `expert_service_id`
   - 验证达人服务存在且属于当前任务达人（`task_expert_services.expert_id = 当前用户ID`）
   - 验证达人服务状态为 `active`
   - 获取达人服务的基础价格（`base_price`）作为原价基础
3. 验证任务数据（max_participants >= min_participants >= 1）
4. **固定时间段验证**（可选）：如果 `is_fixed_time_slot=true`，验证时间段相关字段：
   - `time_slot_duration_minutes` 必须 > 0（可以是60分钟、120分钟等，表示1小时、2小时等）
   - `time_slot_end_time` 必须 > `time_slot_start_time`
   - `participants_per_slot` 必须 >= 1 且 <= `max_participants`
   - 计算时间段总数，确保为整数
5. **非固定时间段**：如果 `is_fixed_time_slot=false`，时间段相关字段应为 NULL 或省略
6. 验证奖励类型和金额
7. **价格设置**：
   - 如果未设置折扣：`original_price_per_participant` 和 `reward` 应等于达人服务的 `base_price`
   - 如果设置了折扣：
     - `original_price_per_participant` 应等于达人服务的 `base_price`
     - `discount_percentage` 必须在 0-100 之间
     - `discounted_price_per_participant` 必须 > 0 且 <= `original_price_per_participant`
     - 验证 `discounted_price_per_participant` 是否等于 `original_price_per_participant * (1 - discount_percentage / 100)`（允许浮点数精度误差）
     - 任务的 `reward` 字段应等于 `discounted_price_per_participant`（或根据奖励分配方式计算总奖励）
8. **图片处理**：如果请求中未提供 `images`，使用达人服务的 `images`
9. 创建任务记录，设置：
   - `is_multi_participant=true`
   - `is_official_task=false`（任务达人发布的任务不是官方任务）
   - `created_by_expert=true`
   - `expert_creator_id` 为当前用户ID（任务达人ID）
   - `expert_service_id` 为请求中的达人服务ID（关联达人服务）
   - **重要**：`poster_id` 可以设置为系统用户ID或NULL（任务达人不是传统意义上的发布者，而是服务提供者）
   - **重要**：`taker_id` 必须设置为当前用户ID（任务达人提供服务，收钱，是接收者）
   - `auto_accept=false`（默认需要审核，可根据平台策略调整）
   - `allow_negotiation=false`（多人任务不支持议价，但任务达人可以自己设置折扣）
   - 如果未提供 `images`，从达人服务复制 `images`
10. 如果 `is_fixed_time_slot=true`，自动生成所有时间段列表
11. 返回创建的任务信息，包括时间段列表（如果有）和折扣信息（如果有），以及关联的达人服务信息

**时间段生成逻辑**:
- 根据 `time_slot_start_time`、`time_slot_end_time` 和 `time_slot_duration_minutes` 计算时间段数量
- 例如：12:00-22:00，每60分钟一个时间段，共10个时间段
- 每个时间段独立，有自己的参与人数限制

### 3. 用户申请参与多人任务（官方任务自动接受）

**接口**: `POST /api/tasks/{task_id}/apply`

**权限**: 需要用户认证

**请求体（普通多人任务）**:
```json
{
  "message": "我有相关经验，希望参与此任务",
  "idempotency_key": "unique-request-id-12345"  // 建议携带，用于防止重复申请
}
```

**请求体（固定时间段服务）**:
```json
{
  "message": "我想参与这个时间段",
  "time_slot_id": 1,  // 时间段ID（从任务详情的时间段列表中获取）
  "idempotency_key": "unique-request-id-12345"  // 建议携带，用于防止重复申请
}
```

**请求体（非固定时间段服务，任务达人发布）**:
```json
{
  "message": "我希望参与此服务",
  "is_flexible_time": false,  // 是否为灵活时间，false表示有具体截止日期，true表示时间灵活
  "preferred_deadline": "2025-02-15T18:00:00Z",  // 期望的截止日期（仅当is_flexible_time=false时提供）
  "idempotency_key": "unique-request-id-12345"  // 建议携带，用于防止重复申请
}
```

**请求体（非固定时间段服务，灵活时间）**:
```json
{
  "message": "我希望参与此服务，时间灵活",
  "is_flexible_time": true,  // 时间灵活，不需要具体截止日期
  "idempotency_key": "unique-request-id-12345"  // 建议携带，用于防止重复申请
}
```

**响应（官方任务，自动接受）**:
```json
{
  "id": 456,
  "task_id": 123,
  "user_id": "12345678",
  "status": "accepted",
  "applied_at": "2025-01-20T10:30:00Z",
  "accepted_at": "2025-01-20T10:30:00Z",
  "can_chat": true,
  "can_auto_accept": true,
  "room_code": "8b9f4e40-9a2c-4c7a-9f2a-7e2ce6a6b9a1"
}
```

**字段说明**：
- `can_auto_accept`: 标识任务是否支持自动接受（`true` 表示官方任务自动接受，`false` 表示需要等待管理员审核）
- `room_code`: 不可预测的聊天室代码（UUID格式），不暴露任务ID

**业务逻辑**:
1. 验证任务是否存在且为多人任务
2. **任务达人服务验证**（如果 `created_by_expert=true`）：
   - 验证任务关联的达人服务存在且状态为 `active`
   - 验证用户未重复申请此达人服务（通过 `task_participants` 表检查，同一用户不能重复申请同一任务的同一时间段）
   - **重要**：申请人申请参与此任务时，实际上是在申请此达人服务
   - **价格说明**：价格以任务达人发布任务时设置的价格为准（基于达人服务的 `base_price`，可能包含折扣）
   - **业务含义**：申请人以任务达人发布任务的价格申请到此达人服务
3. 验证任务状态为 `open`（**重要**：任务开始后（`in_progress` 状态）不允许新成员申请加入，如需支持"迟到加入"，需要明确策略，见"迟到加入规则"章节）
4. **固定时间段验证**：如果任务 `is_fixed_time_slot=true`：
   - 验证请求中包含 `time_slot_id`
   - 验证时间段是否存在且有效
   - 验证时间段是否已满（该时间段的参与者数量是否已达到 `participants_per_slot`）
   - 验证用户是否已申请该时间段（同一用户不能重复申请同一时间段）
5. **非固定时间段验证**：如果任务 `is_fixed_time_slot=false` 且 `created_by_expert=true`（任务达人发布的服务）：
   - 验证请求中包含 `is_flexible_time` 字段
   - 如果 `is_flexible_time=false`，验证请求中包含 `preferred_deadline` 且为有效的未来时间
   - 如果 `is_flexible_time=true`，`preferred_deadline` 应为 NULL
   - 验证 `preferred_deadline` 不早于当前时间（如果提供了）
6. **并发控制**：开启数据库事务，对 `tasks` 记录使用 `SELECT ... FOR UPDATE` 锁定
7. **实时计数验证**：
   - 如果 `is_fixed_time_slot=true`：使用 `COUNT(*)` 查询指定时间段的参与者数量，确认未达到 `participants_per_slot`
   - 如果 `is_fixed_time_slot=false`：使用 `COUNT(*)` 查询 `task_participants` 表中状态为 `pending`、`accepted`、`in_progress` 的参与者数量，确认未达到 `max_participants`
8. 验证用户未重复申请（检查 `task_participants` 表，利用唯一约束；固定时间段服务需要额外验证同一时间段）
9. **幂等性验证**：如果请求包含 `idempotency_key`，检查是否已存在相同键的记录，如果存在则返回已有记录
10. 验证任务是否允许议价（多人任务不允许议价，如果用户尝试议价则拒绝）
11. 创建 `task_participants` 记录：
    - 如果任务 `auto_accept=true`（官方任务），状态直接设为 `accepted`，`accepted_at` 等于 `applied_at`
    - 如果任务 `auto_accept=false`，状态设为 `pending`，`accepted_at` 为 NULL（等待管理员审核）
    - 如果 `is_fixed_time_slot=true`，记录 `time_slot_id`
    - 如果 `is_fixed_time_slot=false` 且 `created_by_expert=true`，记录 `is_flexible_time` 和 `preferred_deadline`
12. 如果自动接受：
    - 更新任务的 `current_participants` 计数（仅作为展示用缓存，决策仍以实时计数为准）
    - 自动创建或加入任务聊天室（使用不可预测的 `room_code`）
    - 发送欢迎消息到聊天室
    - 发送通知给用户（已成功加入任务）
    - **任务达人服务**：如果 `created_by_expert=true`，记录申请人已申请此达人服务
13. 如果未自动接受：
    - 发送通知给管理员/发布者（任务达人），通知中包含申请人的时间偏好信息
    - **任务达人服务**：如果 `created_by_expert=true`，通知任务达人有新的服务申请
14. **审计日志**：记录操作到 `task_audit_logs` 表，包含时间偏好信息（如果有）和关联的达人服务信息（如果有）
15. 提交事务
16. 返回参与者信息，包括是否可以聊天和聊天室ID（使用不可预测的 `room_code`，格式为 UUID，不暴露 `task_id`），以及关联的达人服务信息（如果有）

### 3. 参与者申请退出任务

**接口**: `POST /api/tasks/{task_id}/participants/me/exit-request`

**权限**: 需要用户认证，且用户必须是该任务的参与者

**请求体**:
```json
{
  "exit_reason": "因个人原因无法继续参与",
  "idempotency_key": "unique-request-id-12345"  // 建议携带，用于防止重复申请退出
}
```

**响应**:
```json
{
  "id": 456,
  "task_id": 123,
  "user_id": "12345678",
  "status": "exit_requested",
  "exit_requested_at": "2025-01-20T11:00:00Z",
  "exit_reason": "因个人原因无法继续参与"
}
```

**业务逻辑**:
1. 验证用户是该任务的参与者
2. 验证参与者状态为 `accepted` 或 `in_progress`（已完成或已退出的不能再次申请退出）
3. **幂等性验证**：如果请求包含 `idempotency_key`，检查是否已存在相同键的退出申请
4. 开启数据库事务
5. 保存当前状态到 `previous_status` 字段
6. 更新参与者状态为 `exit_requested`
7. 设置 `exit_requested_at` 和 `exit_reason`
8. **审计日志**：记录操作到 `task_audit_logs` 表
9. 提交事务
10. 发送通知给管理员
11. 在聊天室发送系统消息（可选）

### 4. 管理员/任务达人批准/拒绝退出申请

**接口**: `POST /api/admin/tasks/{task_id}/participants/{participant_id}/approve-exit`
**接口**: `POST /api/admin/tasks/{task_id}/participants/{participant_id}/reject-exit`
**接口**: `POST /api/expert/tasks/{task_id}/participants/{participant_id}/approve-exit`
**接口**: `POST /api/expert/tasks/{task_id}/participants/{participant_id}/reject-exit`

**权限**: 
- 管理员接口：需要管理员认证
- 任务达人接口：需要用户认证，且用户必须是该任务的创建者（`expert_creator_id` 或 `taker_id`）

**请求体（批准）**:
```json
{
  "admin_notes": "批准退出申请"
}
```

**请求体（拒绝）**:
```json
{
  "admin_notes": "任务进行中，暂不批准退出"
}
```

**响应（批准）**:
```json
{
  "id": 456,
  "task_id": 123,
  "user_id": "12345678",
  "status": "exited",
  "exited_at": "2025-01-20T12:00:00Z",
  "admin_notes": "批准退出申请"
}
```

**业务逻辑（批准）**:
1. 验证权限：
   - 管理员接口：验证管理员权限
   - 任务达人接口：验证用户是任务创建者（`expert_creator_id` 或 `taker_id`）
2. 验证参与者状态为 `exit_requested`
3. 开启数据库事务
4. 更新参与者状态为 `exited`
5. 设置 `exited_at` 时间
6. **人数统计**：如启用 `current_participants` 缓存字段，则在此处由触发器自动维护，无需应用层更新（详见"current_participants 字段说明"章节）
7. **从任务聊天室移除该用户**（必需）：
   - 从聊天室成员列表中移除
   - 禁止该用户继续发送消息
   - 该用户仍可查看历史消息（可选，根据业务需求）
8. **审计日志**：记录操作到 `task_audit_logs` 表，包含操作者ID（管理员ID或任务达人ID）
9. 提交事务
10. 发送通知给参与者
11. 在聊天室发送系统消息（必需）：通知其他参与者该用户已退出

**业务逻辑（拒绝）**:
1. 验证权限：
   - 管理员接口：验证管理员权限
   - 任务达人接口：验证用户是任务创建者（`expert_creator_id` 或 `taker_id`）
2. 验证参与者状态为 `exit_requested`
3. 开启数据库事务
4. 从 `previous_status` 字段恢复之前的状态（`accepted` 或 `in_progress`）
5. 清空 `exit_requested_at`、`exit_reason` 和 `previous_status`
6. **审计日志**：记录操作到 `task_audit_logs` 表，包含操作者ID（管理员ID或任务达人ID）
7. 提交事务
8. 发送通知给参与者
9. 在聊天室发送系统消息（可选）：通知其他参与者退出申请被拒绝

### 4.1. 管理员/任务达人踢出参与者

**接口**: `POST /api/admin/tasks/{task_id}/participants/{participant_id}/kick`
**接口**: `POST /api/expert/tasks/{task_id}/participants/{participant_id}/kick`

**权限**: 
- 管理员接口：需要管理员认证
- 任务达人接口：需要用户认证，且用户必须是该任务的创建者（`expert_creator_id` 或 `taker_id`）

**请求体**:
```json
{
  "reason": "违反聊天室规则",
  "admin_notes": "踢出原因说明"  // 可选，仅管理员接口
}
```

**响应**:
```json
{
  "id": 456,
  "task_id": 123,
  "user_id": "12345678",
  "status": "cancelled",
  "cancelled_at": "2025-01-20T12:30:00Z",
  "admin_notes": "违反聊天室规则"
}
```

**业务逻辑**:
1. 验证权限：
   - 管理员接口：验证管理员权限
   - 任务达人接口：验证用户是任务创建者（`expert_creator_id` 或 `taker_id`）
2. 验证参与者状态为 `accepted`、`in_progress` 或 `exit_requested`（不能踢出已完成或已退出的参与者）
3. 开启数据库事务
4. 更新参与者状态为 `cancelled`
5. 设置 `cancelled_at` 时间
6. 记录踢出原因到 `admin_notes` 字段
7. **人数统计**：如启用 `current_participants` 缓存字段，则在此处由触发器自动维护，无需应用层更新
8. **从任务聊天室移除该用户**（必需）：
   - 从聊天室成员列表中移除
   - 禁止该用户继续发送消息
   - 禁止该用户查看聊天室（可选，根据业务需求）
9. **审计日志**：记录操作到 `task_audit_logs` 表，包含操作者ID（管理员ID或任务达人ID）和踢出原因
10. 提交事务
11. 发送通知给被踢出的参与者
12. 在聊天室发送系统消息（必需）：通知其他参与者该用户已被踢出

**重要说明**：
- 踢出操作不可逆（与退出申请不同，退出申请需要批准）
- 被踢出的参与者状态变为 `cancelled`，不能再申请参与此任务
- 如果任务已开始（`in_progress`），踢出参与者不会影响任务继续进行
- 如果任务已完成（`completed`），不能踢出已完成状态的参与者

### 5. 管理员开始多人任务

**接口**: `POST /api/admin/tasks/{task_id}/start`

**权限**: 需要管理员认证

**请求体**:
```json
{}
```

**响应**:
```json
{
  "id": 123,
  "status": "in_progress",
  "started_at": "2025-01-20T12:00:00Z",
  "current_participants": 4
}
```

**业务逻辑**:
1. 验证管理员权限
2. 验证任务状态为 `open`
3. **实时计数验证**：使用 `COUNT(*)` 查询状态为 `accepted` 的参与者数量，确认 >= `min_participants`
   - **重要说明**：`min_participants` 仅用于"可开始"判定，一旦任务开始，即使后续有人退出导致人数 < `min_participants`，任务仍可继续进行
4. 开启数据库事务
5. 更新任务状态为 `in_progress`
6. 更新所有 `accepted` 状态的参与者为 `in_progress`
7. 设置所有参与者的 `started_at` 时间
8. **审计日志**：记录操作到 `task_audit_logs` 表，包含 `admin_operator_id`
9. 提交事务
10. 发送通知给所有参与者

**重要说明**：当前版本仅支持管理员手动开始任务。虽然状态流转图中提到"达到 min_participants 自动开始"，但此功能暂未实现。如需实现自动开始功能，需要：
- 创建异步守护任务（Job），监听 `task_participants` 表的 `accepted` 状态计数变化
- 当计数达到 `min_participants` 时，自动触发开始流程
- 记录审计日志，标注为"自动开始"而非管理员操作
- 考虑并发场景下的幂等性（防止重复触发）

### 6. 参与者提交完成

**接口**: `POST /api/tasks/{task_id}/participants/me/complete`

**权限**: 需要用户认证，且用户必须是该任务的参与者

**请求体**:
```json
{
  "completion_notes": "已完成我的部分工作",
  "idempotency_key": "unique-request-id-12345"  // 建议携带，用于防止重复提交完成
}
```

**响应**:
```json
{
  "id": 456,
  "status": "completed",
  "completed_at": "2025-01-20T15:00:00Z",
  "completion_notes": "已完成我的部分工作"
}
```

**业务逻辑**:
1. 验证用户是该任务的参与者
2. 验证参与者状态为 `in_progress`
3. **幂等性验证**：如果请求包含 `idempotency_key`，检查是否已存在相同键的完成记录
4. 开启数据库事务
5. 更新参与者状态为 `completed`
6. 设置 `completed_at` 时间
7. 检查任务完成条件：
   - 如果 `completion_rule=all`，检查是否所有状态为 `in_progress` 的参与者都完成
   - 如果 `completion_rule=min`，检查已完成参与者数量是否 >= `min_participants`
8. 如果满足完成条件：
   - 更新任务状态为 `completed`
   - **重要说明**：如果 `completion_rule=min`，未完成的参与者状态保持为 `in_progress`，但任务已标记为完成。这些参与者仍可提交完成，但不会影响任务完成状态。奖励分配时，仅已完成参与者参与分配（除非管理员手动调整）
9. **审计日志**：记录操作到 `task_audit_logs` 表
10. 提交事务
11. 发送通知给管理员/发布者

### 7. 管理员确认任务完成并分配奖励

**接口**: `POST /api/admin/tasks/{task_id}/complete`

**权限**: 需要管理员认证

**请求体（MVP版本，仅支持平均分配积分）**:
```json
{
  "idempotency_key": "unique-request-id-12345"  // 必需，用于防止重复分配奖励
}
```

**请求体（未来扩展版本，支持自定义分配）**:
```json
{
  "participant_rewards": [
    {
      "participant_id": 456,
      "reward_amount": 100.00,
      "points_amount": 1000
    },
    {
      "participant_id": 457,
      "reward_amount": 100.00,
      "points_amount": 1000
    }
  ],
  "idempotency_key": "unique-request-id-12345"  // 必需，用于防止重复分配奖励
}
```

**响应**:
```json
{
  "id": 123,
  "status": "completed",
  "completed_at": "2025-01-20T16:00:00Z",
  "total_points_distributed": 5000,
  "participant_rewards": [
    {
      "participant_id": 456,
      "user_id": "12345678",
      "points_amount": 2500
    },
    {
      "participant_id": 457,
      "user_id": "87654321",
      "points_amount": 2500
    }
  ]
}
```

**业务逻辑（MVP版本）**:
1. 验证管理员权限
2. 验证任务状态为 `in_progress` 或已完成
3. 验证任务 `reward_type='points'` 且 `reward_distribution='equal'`（MVP限制）
4. **幂等性验证**：检查 `idempotency_key` 是否已存在，如果存在则返回已有记录（幂等返回）
5. 开启数据库事务
6. **并发控制**：对 `tasks` 记录使用 `SELECT ... FOR UPDATE` 锁定，对相关 `task_participants` 记录使用 `SELECT ... FOR UPDATE` 锁定，确保"判定任务状态 + 计算完成人数 + 创建奖励记录 + 更新任务状态"在同一事务内原子执行
7. **自动计算平均分配**（仅针对状态为 `completed` 的参与者）：
   - 查询所有状态为 `completed` 的参与者
   - 积分奖励：`总积分奖励 / 已完成参与者数量`（向下取整，余数分配给完成时间最早的参与者）
8. **完整性约束验证**：
   - 验证所有参与者的 `points_amount` 总和 <= 任务 `points_reward`
   - 验证所有 `reward_amount` 必须为 NULL（不接受 0）
9. 创建 `task_participant_rewards` 记录，包含：
   - `reward_type='points'`
   - `points_amount`（计算出的平均分配值）
   - `idempotency_key`（客户端生成）
   - `admin_operator_id`（当前管理员ID）
10. 更新任务状态为 `completed`（如果尚未完成）
11. **审计日志**：记录操作到 `task_audit_logs` 表，包含完整的分配方案
12. 提交事务
13. 发送通知给所有参与者
14. 触发积分发放流程（使用 `idempotency_key` 确保幂等性）

**业务逻辑（未来扩展版本，支持自定义分配）**:
1-4. 同 MVP 版本
5. 开启数据库事务
6. 如果 `reward_distribution=equal`：
   - 自动计算平均分配（同 MVP 版本）
7. 如果 `reward_distribution=custom`，使用请求中的分配方案
8. **完整性约束验证**：
   - 现金奖励：验证所有参与者的 `reward_amount` 总和 <= 任务 `reward`（如果 `reward_type` 包含 `cash`）
   - 积分奖励：验证所有参与者的 `points_amount` 总和 <= 任务 `points_reward`（如果 `reward_type` 包含 `points`）
   - 如果 `reward_type='points'`，验证所有 `reward_amount` 必须为 NULL（不接受 0）
   - 如果 `reward_type='cash'`，验证所有 `points_amount` 必须为 NULL（不接受 0）
   - 如果 `reward_type='both'`，验证所有 `reward_amount` 和 `points_amount` 都不为 NULL
9-13. 同 MVP 版本

### 8. 获取任务参与者列表

**接口**: `GET /api/tasks/{task_id}/participants`

**权限**: 需要用户认证

**查询参数**:
- `status`: 过滤参与者状态（可选）

**响应**:
```json
{
  "task_id": 123,
  "max_participants": 5,
  "min_participants": 3,
  "current_participants": 4,
  "participants": [
    {
      "id": 456,
      "user_id": "12345678",
      "user_name": "张三",
      "user_avatar": "avatar_url",
      "status": "in_progress",
      "reward_amount": 100.00,
      "applied_at": "2025-01-20T10:30:00Z",
      "accepted_at": "2025-01-20T11:00:00Z",
      "started_at": "2025-01-20T12:00:00Z",
      "completed_at": null
    }
  ]
}
```

### 9. 获取用户参与的多人任务列表

**接口**: `GET /api/users/me/multi-participant-tasks`

**权限**: 需要用户认证

**查询参数**:
- `status`: 过滤任务状态（可选）
- `participant_status`: 过滤参与者状态（可选）

**响应**:
```json
{
  "tasks": [
    {
      "id": 123,
      "title": "大型活动组织任务",
      "status": "in_progress",
      "my_participant_status": "in_progress",
      "max_participants": 5,
      "current_participants": 4,
      "reward": 500.00,
      "my_reward": 100.00
    }
  ]
}
```

---

## 🎨 前端实现

### 1. 管理员发布多人任务页面

**路径**: `/admin/publish-multi-task`

**功能**:
- 任务基本信息表单（标题、描述、截止时间等）
- 多人任务特定字段：
  - 最大参与人数选择器（如：7人）
  - 最小参与人数选择器（如：5人）
  - 完成规则选择（全部完成/最小人数完成）
  - 奖励分配方式选择（平均分配/自定义）
- 奖励设置：
  - 奖励类型选择（现金/积分/现金+积分）
  - 如果选择积分，显示积分输入框
  - 如果选择现金，显示金额输入框
- 自动设置：
  - `is_official_task=true`（管理员发布的任务自动标记为官方任务）
  - `auto_accept=true`（官方任务自动接受申请）
  - `allow_negotiation=false`（多人任务不支持议价）
- 图片上传
- 表单验证

### 1.1. 任务达人发布多人任务页面

**路径**: `/expert/publish-multi-task`

**功能**:
- 任务基本信息表单（标题、描述、截止时间等）
- 多人任务特定字段：
  - 最大参与人数选择器（如：4人）
  - 最小参与人数选择器（如：4人）
  - 完成规则选择（全部完成/最小人数完成）
  - 奖励分配方式选择（平均分配/自定义）
- 固定时间段设置（可选）：
  - 是否启用固定时间段服务（开关，默认关闭）
  - 如果启用：
    - 时间段时长选择器（分钟，如60分钟表示1小时，120分钟表示2小时等）
    - 时间段开始时间选择器（如12:00）
    - 时间段结束时间选择器（如22:00）
    - 每个时间段人数限制（如4人）
  - 如果不启用（非固定时间段服务）：
    - 提示信息："申请人将需要选择截止日期或灵活时间"
    - 时间段相关字段不显示或禁用
- 奖励设置：
  - 奖励类型选择（现金/积分/现金+积分）
  - 如果选择积分，显示积分输入框
  - 如果选择现金，显示金额输入框
- **折扣设置**（仅任务达人，可选）：
  - 是否设置折扣（开关）
  - 如果启用折扣：
    - 原价输入框（每人，如10.00镑）
    - 折扣百分比输入框（0-100，如20表示打8折）
    - 折扣后价格自动计算并显示（原价 × (1 - 折扣百分比/100)）
    - 显示节省金额（原价 - 折扣后价格）
    - 提示信息："多人任务不支持议价，但您可以设置折扣来推广服务或填补特定时间段空缺"
- 自动设置：
  - `is_official_task=false`（任务达人发布的任务不是官方任务）
  - `auto_accept=false`（默认需要审核，可根据平台策略调整）
  - `allow_negotiation=false`（多人任务不支持议价，但可以设置折扣）
  - `created_by_expert=true`
  - `expert_creator_id` 为当前用户ID
- 图片上传
- 表单验证：
  - 验证折扣相关字段的一致性
  - 验证折扣后价格 = 原价 × (1 - 折扣百分比/100)
  - 验证任务的 `reward` 字段与折扣后价格一致（或根据奖励分配方式计算）

### 2. 多人任务详情页面

**路径**: `/tasks/{task_id}`

**功能**:
- 显示任务基本信息
- 显示官方任务标识（如果是官方任务）
- 显示任务达人标识（如果是任务达人发布）
- 显示多人任务标识和参与人数信息（当前人数/最大人数）
- 显示奖励信息（现金/积分/现金+积分）
- **折扣信息显示**（仅任务达人发布的多人任务）：
  - 如果 `has_discount=true` 或 `discount_percentage IS NOT NULL`，显示折扣信息
  - 显示原价：`原价：£{original_price_per_participant}/人`（带删除线样式）
  - 显示现价：`现价：£{discounted_price_per_participant}/人`（突出显示，可用红色或加粗）
  - 显示折扣标签：`打{discount_percentage}折` 或 `节省{original_price_per_participant - discounted_price_per_participant}镑`
  - 折扣标签样式：可使用醒目的颜色（如红色、橙色）和图标（如"折扣"、"特价"图标）
  - **示例显示**：
    ```
    原价：£10.00/人  [删除线]
    现价：£8.00/人  [红色加粗]
    [折扣标签] 打8折 / 节省£2.00
    ```
- **任务状态显示**：
  - **任务状态**：`open` / `in_progress` / `completed` / `cancelled`
  - **奖励状态**（需查询 `task_participant_rewards` 表）：
    - 未结算：所有奖励记录的 `payment_status` 和 `points_status` 均为 `pending`
    - 结算中：部分奖励记录的 `payment_status` 或 `points_status` 为 `pending`
    - 已结算：所有奖励记录的 `payment_status` 和 `points_status` 均为 `paid`/`credited`
    - 部分失败：存在 `failed` 状态的奖励记录
  - **重要说明**：`status='completed'` 仅表示任务工作流程完成，不代表奖励已发放，需查看奖励状态
- 显示参与者列表（如果用户是参与者或管理员）
- **申请参与界面**（如果用户未申请且未达到最大人数）：
  - **固定时间段服务**：显示所有可用时间段列表，用户选择时间段后申请
  - **非固定时间段服务（任务达人发布）**：显示时间选择表单
    - 单选按钮或开关：选择"灵活时间"或"指定截止日期"
    - 如果选择"指定截止日期"：显示日期时间选择器，用户选择期望的截止日期
    - 如果选择"灵活时间"：显示提示信息"时间灵活，可与任务达人协商"
  - 申请消息输入框（可选）
  - 提交申请按钮
- 参与状态显示（如果用户已申请/参与）
- **进入聊天室按钮**（如果用户已接受/参与，可以立即进入任务聊天室）
  - 多人任务或达人多人服务都会进入多人任务聊天室
  - 在聊天室中，管理员和任务达人有权踢掉参与者
  - 申请者也可以申请退出取消此任务
- **申请退出按钮**（如果用户已参与，可以申请退出）
  - 点击后弹出退出申请表单
  - 需要填写退出原因
  - 提交后等待管理员/任务达人审核
- 完成提交按钮（如果用户是参与者且任务进行中）
- 禁止议价提示（多人任务不支持议价）

### 3. 任务聊天室页面

**路径**: `/rooms/{room_code}`（推荐，彻底避免泄漏任务ID）

**路由策略**：
- **推荐方案**：使用 `/rooms/{room_code}` 作为路由参数
  - 后端在进入页面时验证用户是否为该聊天室的参与者（根据 `room_code` 查询 `chat_rooms` 表，再验证 `task_participants` 表）
  - 验证通过后直接渲染页面，彻底避免在 URL 中暴露 `task_id`
  - WebSocket 连接时使用 `room_code` 而非 `task_id`
- **备选方案（不推荐）**：使用 `/tasks/{task_id}/chat`，前端在进入页面时从后端获取 `room_code`，然后使用 `room_code` 建立 WebSocket 连接
  - 缺点：URL 中暴露了 `task_id`，存在信息泄露风险

**功能**:
- 显示任务基本信息（标题、参与人数等）
- 显示参与者列表（所有已接受的参与者）
  - 每个参与者显示用户名、头像、状态
  - 管理员/任务达人可以看到"踢出"按钮（仅对 `accepted`、`in_progress` 状态的参与者）
  - 普通参与者可以看到自己的"申请退出"按钮
- 实时聊天功能（WebSocket）
- 消息发送和接收
- 图片上传和分享
- 系统消息显示（如：新成员加入、成员退出、成员被踢出等）
- 聊天室权限控制：
  - **发送消息权限**：仅状态为 `accepted`、`in_progress`、`completed` 的参与者可以发送消息
  - **查看消息权限**：参与者可以查看历史消息（即使被踢出，根据业务需求决定是否允许查看）
  - **管理权限**：管理员和任务达人（任务创建者）可以踢出参与者

**聊天室权限规则**（必须严格执行）：
- **允许进入聊天室的状态**：`accepted`、`in_progress`、`completed`
- **允许发送消息的状态**：`accepted`、`in_progress`、`completed`
- **禁止进入和发言的状态**：`pending`、`exit_requested`、`exited`、`cancelled`
- **说明**：
  - 已完成（`completed`）的参与者可以查看历史消息并继续发言
  - 退出申请中（`exit_requested`）的参与者可以查看消息但不能发送消息（等待审核）
  - 已退出（`exited`）或已取消（`cancelled`）的参与者不能进入聊天室
  - 被踢出的参与者（`cancelled`）不能进入聊天室，根据业务需求决定是否允许查看历史消息

**管理权限**：
- **管理员**：可以踢出任何参与者（状态为 `accepted`、`in_progress` 或 `exit_requested`）
- **任务达人**（任务创建者）：可以踢出自己创建的多人任务的参与者（状态为 `accepted`、`in_progress` 或 `exit_requested`）
- **普通参与者**：不能踢出其他参与者，只能申请退出

**聊天室进入逻辑**:
- 用户申请参与官方任务后，状态立即变为 `accepted`
- 用户可以在任务详情页面点击"进入聊天室"按钮
- 或者系统自动跳转到聊天室页面
- **安全说明**：聊天室使用不可预测的 `room_code`（UUID格式），不暴露任务ID
- WebSocket连接时，服务器端需要验证：
  1. 用户身份（JWT token）
  2. 用户是否为该任务的参与者（查询 `task_participants` 表）
  3. 参与者状态是否为 `accepted`、`in_progress` 或 `completed`（按上述权限规则）

### 4. 管理员任务管理页面

**路径**: `/admin/tasks/{task_id}/manage`

**功能**:
- 显示任务详情
- 显示所有参与者列表（官方任务自动接受，无需审核）
  - 每个参与者显示状态、申请时间、完成时间等信息
  - 对状态为 `accepted`、`in_progress` 的参与者显示"踢出"按钮
  - 对状态为 `exit_requested` 的参与者显示"批准退出"和"拒绝退出"按钮
- 显示退出申请列表（如果有参与者申请退出）
- 批准/拒绝退出申请按钮
- 踢出参与者按钮（可以踢出违反规则的参与者）
- 开始任务按钮（当达到最小参与人数时，或手动开始）
- 参与者管理（查看、移除参与者）
- 任务完成确认和奖励分配（现金/积分）
- 显示审计日志（可选）

### 4.1. 任务达人任务管理页面

**路径**: `/expert/tasks/{task_id}/manage`

**功能**:
- 显示任务详情（包括关联的达人服务信息）
- 显示所有参与者列表
  - 每个参与者显示状态、申请时间、时间偏好（如果是非固定时间段服务）、完成时间等信息
  - 对状态为 `accepted`、`in_progress` 的参与者显示"踢出"按钮
  - 对状态为 `exit_requested` 的参与者显示"批准退出"和"拒绝退出"按钮
- 显示退出申请列表（如果有参与者申请退出）
- 批准/拒绝退出申请按钮
- 踢出参与者按钮（可以踢出违反规则的参与者）
- 开始任务按钮（当达到最小参与人数时，或手动开始）
- 参与者管理（查看、移除参与者）
- 任务完成确认和奖励分配
- 显示审计日志（可选）

### 5. 用户我的多人任务页面

**路径**: `/my-tasks/multi-participant`

**功能**:
- 显示用户参与的所有多人任务
- 按状态筛选（待审核、已接受、进行中、已完成）
- 显示每个任务的参与状态和奖励信息

---

## 🔒 权限和安全

### 1. 权限控制

- **创建多人任务**: 仅管理员可以创建
- **申请参与**: 所有认证用户都可以申请（官方任务所有人都可以看到）
- **自动接受**: 官方任务自动接受申请，无需管理员审核
- **进入聊天室**: 仅已接受的参与者可以进入和发送消息（状态为 `accepted`、`in_progress` 或 `completed`）
- **开始任务**: 仅管理员可以操作（或达到min_participants自动开始）
- **提交完成**: 仅参与者本人可以操作
- **申请退出**: 仅参与者本人可以操作（申请者可以申请退出取消此任务）
- **批准/拒绝退出**: 管理员和任务达人（任务创建者）可以操作
- **踢出参与者**: 管理员和任务达人（任务创建者）可以操作（有权踢掉违反规则的参与者）
- **确认完成和分配奖励**: 仅管理员可以操作

### 2. 数据验证

- 最大参与人数 >= 最小参与人数 >= 1
- 总奖励金额 >= 0（如果reward_type包含cash）
- 积分奖励 >= 0（如果reward_type包含points）
- 奖励分配总额不能超过任务总奖励（现金或积分，在事务内实时验证）
- 参与者不能重复申请同一任务（利用唯一约束）
- 多人任务不允许议价（`reward_type` 和 `points_reward` 验证）
- 任务状态流转验证（如：不能从未开始直接到完成）
- 退出申请验证（已完成或已退出的不能再次申请退出）
- 奖励类型完整性验证（`reward_type='points'` 时现金字段必须为 NULL，不接受 0；`reward_type='cash'` 时积分字段必须为 NULL，不接受 0）

### 3. 安全措施

- **CSRF防护**：所有敏感 POST/PUT/DELETE 请求必须包含 CSRF token
- **Origin验证**：验证请求来源，防止跨站请求伪造
- **速率限制**：
  - 申请参与：每个用户每小时最多申请10个任务
  - 退出申请：每个用户每小时最多申请退出5次
  - 完成提交：每个用户每小时最多提交完成10次
  - 奖励分配：每个管理员每小时最多分配奖励20次
- **WebSocket安全**：
  - 握手时验证 JWT token
  - 验证用户是否为任务参与者（查询 `task_participants` 表）
  - 定期续签 token（每15分钟）
  - 断线重连时重新验证身份
  - 消息发送前再次验证参与者状态
- **反滥用策略**：
  - 检测异常申请模式（短时间内大量申请）
  - 检测刷奖励行为（同一用户多次参与高奖励任务）
  - 自动标记可疑账户，需要人工审核
- **审计追踪**：所有敏感操作记录到 `task_audit_logs` 表，包含IP地址和用户代理

### 3. 并发控制

- **申请参与时的并发控制**：
  - 使用数据库事务确保数据一致性
  - 对 `tasks` 记录使用 `SELECT ... FOR UPDATE` 锁定，防止并发修改
  - 使用实时 `COUNT(*)` 查询参与者数量（状态为 `pending`、`accepted`、`in_progress`），而非依赖 `current_participants` 字段
  - 使用唯一约束 `(task_id, user_id)` 防止重复申请
  - 使用幂等键防止重复请求
- **状态更新时的并发控制**：
  - 使用数据库事务
  - 使用乐观锁（`updated_at` 版本号）或悲观锁防止并发状态变更
- **奖励分配时的并发控制**：
  - 使用数据库事务
  - 使用幂等键防止重复分配
  - 验证总分配金额/积分不超过任务总额（在事务内实时计算）

### 4. 幂等性策略

- **统一规则**：所有会产生 side-effect 的 POST 操作（尤其是可能被用户"连点两次"的）都应包含 `idempotency_key`
  - **建议携带**：申请参与、退出申请、提交完成
  - **强制要求**：奖励分配、发起支付等关键操作
- **客户端生成幂等键**：客户端生成 UUID 格式的 `idempotency_key`
- **服务端缓存**：在 Redis 或内存中缓存幂等键（5-15分钟），拒绝重复请求
- **数据库唯一约束**：在相关表中添加 `idempotency_key` 唯一约束，作为最后一道防线
  - **全局唯一**：当前使用 `UNIQUE(idempotency_key)`，UUID 冲突概率几乎可以忽略
  - **可选优化**：如果希望不同用户可以复用同一个 key，可改为 `UNIQUE(user_id, idempotency_key)`
- **幂等返回规范**（必须严格执行）：
  - **原则**：当遇到 `UNIQUE(idempotency_key)` 冲突时，**不是返回 4xx 错误**，而是根据已有记录重放结果
  - **实现方式**：
    1. 查询数据库中已存在的记录（根据 `idempotency_key`）
    2. 返回该记录的完整信息，状态码为 200 OK
    3. 不在业务逻辑中重复执行操作
  - **具体示例**：
    - **申请参与**：查询 `task_participants` 表中 `idempotency_key` 对应的记录，返回该参与者信息（包括 `status`、`applied_at`、`accepted_at` 等）
    - **提交完成**：查询 `task_participants` 表中 `idempotency_key` 对应的记录，返回该参与者的完成信息（包括 `status='completed'`、`completed_at` 等）
    - **分配奖励**：查询 `task_participant_rewards` 表中 `idempotency_key` 对应的记录，聚合返回所有参与者的奖励分配结果

### 5. current_participants 字段说明

- `current_participants` 字段仅作为**展示用缓存**，不应用于业务逻辑决策
- 所有决策（如是否允许申请、是否达到最大人数）都应使用实时 `COUNT(*)` 查询
- **MVP阶段建议**：可以完全不存 `current_participants`，所有地方实时 `COUNT(*)`
  - 对于人数上限较小的任务（7人级别），`COUNT(*)` 性能足够
  - 如果后续发现列表页 QPS 很高，且 profiling 显示 `COUNT(*)` 是瓶颈，再考虑添加缓存字段
- **如果使用缓存字段**：
  - 使用数据库触发器自动维护 `current_participants`，禁止应用层直接 UPDATE 该字段
  - 触发器应使用增量更新（判断 old/new.status 是否从"占坑状态"变成"非占坑状态"再 ±1），而非每次都 `COUNT(*)` 全表计算
  - 如果发现不一致，以实时计数为准

**触发器维护方案（可选，MVP阶段不建议使用）**：

⚠️ **v1.0 不要实现本触发器，仅作为未来优化方案**。v1.0 阶段所有地方使用实时 `COUNT(*)` 查询，不维护 `current_participants` 缓存字段。如果实现触发器但上层逻辑仍用 `COUNT(*)` 做可信源，会导致两个值对不上。

```sql
-- 创建触发器函数，自动维护 current_participants
CREATE OR REPLACE FUNCTION update_task_participants_count() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE tasks 
    SET current_participants = (
      SELECT COUNT(*) FROM task_participants 
      WHERE task_id = NEW.task_id 
      AND status IN ('pending', 'accepted', 'in_progress')
    )
    WHERE id = NEW.task_id;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    -- 状态变更时更新计数
    IF OLD.status != NEW.status THEN
      UPDATE tasks 
      SET current_participants = (
        SELECT COUNT(*) FROM task_participants 
        WHERE task_id = NEW.task_id 
        AND status IN ('pending', 'accepted', 'in_progress')
      )
      WHERE id = NEW.task_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE tasks 
    SET current_participants = (
      SELECT COUNT(*) FROM task_participants 
      WHERE task_id = OLD.task_id 
      AND status IN ('pending', 'accepted', 'in_progress')
    )
    WHERE id = OLD.task_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 为 task_participants 表添加触发器
CREATE TRIGGER trg_update_task_participants_count
AFTER INSERT OR UPDATE OR DELETE ON task_participants
FOR EACH ROW EXECUTE FUNCTION update_task_participants_count();
```

**注意**：如果使用触发器方案，应用层代码中所有对 `current_participants` 的直接 UPDATE 操作都应移除，改为依赖触发器自动维护。

---

## 📊 状态流转

### 任务状态流转

```
open (开放申请)
  ↓ (管理员开始任务，或达到min_participants自动开始)
in_progress (进行中)
  ↓ (满足完成条件)
completed (已完成)
  ↓
cancelled (已取消) [可发生在任何状态，管理员操作]
```

**状态说明**：
- `open`: 任务开放申请，参与者可以申请参与
- `in_progress`: 任务进行中，参与者正在工作
- `completed`: 任务工作流程已完成（根据完成规则判定）
  - **重要说明**：`completed` 状态仅表示任务工作流程已完成，**不代表奖励已分配**
  - **奖励结算状态**：需查询 `task_participant_rewards` 表的 `payment_status` 和 `points_status` 字段判断奖励是否已发放
  - **前端展示建议**：
    - "任务执行完成" = `status = 'completed'`
    - "奖励结算完成" = 所有相关 `task_participant_rewards` 记录都进入 `paid`/`credited` 等终态
- `cancelled`: 任务已取消（可发生在任何状态，管理员操作）

**重要规则**：
- `min_participants` 仅用于"可开始"判定，一旦任务开始，即使后续有人退出导致人数 < `min_participants`，任务仍可继续进行
- 任务取消时，需要处理退款/积分回退（见"取消策略矩阵"章节）

---

## 📋 迟到加入规则

### 当前策略

**策略A（当前实现）**：任务开始后（`in_progress` 状态）**禁止**新成员申请加入。

**理由**：
- 简化状态管理，避免复杂的计时和奖励分配逻辑
- 确保所有参与者有相同的开始时间和工作周期
- 避免因新成员加入导致的任务完成条件重新计算

### 可选策略（未来扩展）

**策略B（可选）**：允许任务开始后补招至 `max_participants`。

**需要明确的规则**：
1. **新成员初始状态**：
   - 方案1：直接进入 `in_progress`（推荐，简化流程）
   - 方案2：先进入 `accepted`，再由管理员或系统自动转换为 `in_progress`

2. **`started_at` 计时规则**：
   - 方案1：使用任务开始时间（所有参与者统一计时）
   - 方案2：使用新成员加入时间（按实际参与时长计算）

3. **奖励分配规则**：
   - 方案1：按比例减少（根据参与时长或工作量调整）
   - 方案2：平均分配（所有参与者获得相同奖励）
   - 方案3：自定义分配（管理员手动调整）

4. **`completion_rule=min` 计数口径**：
   - 方案1：包含新成员（新成员也需要完成才能满足最小人数）
   - 方案2：不包含新成员（仅计算任务开始时的参与者）

5. **申请条件**：
   - 任务状态仍为 `in_progress`
   - 当前参与人数 < `max_participants`
   - 任务未完成

**实现建议**：
- 如果采用策略B，需要在申请接口中移除"任务状态必须为 `open`"的限制
- 添加"迟到加入"标识，便于前端显示和统计
- 在审计日志中记录"迟到加入"操作
- 考虑添加"迟到加入截止时间"字段，限制最晚加入时间

### 退出逻辑与占坑规则

**当前策略（策略A）**：
- 申请参与时计算人数：状态为 `pending`、`accepted`、`in_progress` 的参与者
- `exit_requested` 状态**不占坑**（因为当前策略下任务开始后不允许新成员加入，不会出现超卖问题）
- `completed` 状态**不占坑**（已完成者不占用参与名额）

**未来扩展（策略B，迟到加入）**：
- 如果开放"迟到加入"，需要将 `exit_requested` 状态也计入占坑人数，防止超卖
- 需要明确 `completed` 状态是否占坑：
  - 如果 `completed` 占坑：已完成者仍占用名额，新成员无法加入（除非有人退出）
  - 如果 `completed` 不占坑：已完成者释放名额，新成员可以补位
- **建议**：`completed` 不占坑，允许已完成者释放名额给新成员

---

### 参与者状态流转（官方任务）

```
用户申请
  ↓ (自动接受，官方任务 auto_accept=true)
accepted (已接受，可进入聊天室)
  ↓ (管理员开始任务)
in_progress (进行中)
  ↓ (参与者提交完成)
completed (已完成) [⚠️ 已完成状态不可再申请退出]
  ↓
exit_requested (退出申请中) [仅可发生在 accepted 或 in_progress 状态]
  ↓ (管理员批准)
exited (已退出)
  ↓ (管理员拒绝)
[恢复为 previous_status: accepted 或 in_progress]
  ↓
cancelled (已取消) [管理员可取消参与者资格，可发生在任何状态]
```

**重要规则**：
- `exit_requested` 状态**仅可**从 `accepted` 或 `in_progress` 状态进入
- `completed` 状态**不可**再申请退出（已完成者不能退出）
- `exited` 或 `cancelled` 状态**不可**再次申请退出

**非官方任务状态流转（暂不支持，预留）**：
```
用户申请
  ↓
pending (待审核)
  ↓ (管理员审核通过)
accepted (已接受)
  ↓ (管理员审核拒绝)
[记录被删除或状态为 rejected，当前不实现]
```

**状态说明**：
- `pending`: 待审核（非官方任务需要等待管理员审核，官方任务不会进入此状态）
- `accepted`: 已接受（官方任务自动接受，用户申请后立即进入此状态，可以进入聊天室）
- `in_progress`: 进行中（任务已开始，参与者正在工作）
- `completed`: 已完成（参与者已完成自己的部分）
- `exit_requested`: 退出申请中（参与者申请退出，等待管理员审核，此时 `previous_status` 保存前一个状态）
- `exited`: 已退出（管理员批准退出）
- `cancelled`: 已取消（管理员取消参与者资格，可发生在任何状态）

**重要规则**：
- 官方任务（`auto_accept=true`）：用户申请后立即进入 `accepted` 状态，无需等待管理员审核
- 非官方任务（`auto_accept=false`）：用户申请后需要等待管理员审核（此功能暂不实现，当前仅支持官方任务）
- 参与者**仅可**在 `accepted` 或 `in_progress` 状态申请退出，`completed`、`exited`、`cancelled` 状态不可再申请退出
- 退出申请被拒绝时，从 `previous_status` 恢复之前的状态
- 管理员可以随时取消参与者资格（状态变为 `cancelled`）
- 任务完成后，未完成的参与者仍可提交完成，但不会影响任务完成状态

---

## 📋 取消策略矩阵

⚠️ **重要说明**：本节为未来扩展设计，v1.0 仅实现「状态变更 + 审计日志」，不实现真实退款/积分回退逻辑。v1.0 的取消操作仅更新状态和记录审计日志，不涉及支付网关对接和积分扣除。

### 任务取消场景

| 取消时机 | 发起者 | 退款/回退策略 | 通知对象 | 状态变更 |
|---------|--------|--------------|---------|---------|
| 任务开始前（open状态） | 管理员 | 无需退款（尚未分配奖励） | 所有参与者 | 任务状态 → cancelled，参与者状态 → cancelled |
| 任务进行中（in_progress） | 管理员 | 按完成度部分退款/积分回退 | 所有参与者 | 任务状态 → cancelled，参与者状态 → cancelled |
| 任务已完成（completed） | 管理员 | 已发放奖励需追回（退款/积分扣除） | 所有参与者、财务部门 | 任务状态 → cancelled，参与者状态保持不变（已完成） |

### 参与者取消场景

| 取消时机 | 发起者 | 退款/回退策略 | 通知对象 | 状态变更 |
|---------|--------|--------------|---------|---------|
| 申请阶段（pending） | 管理员 | 无需处理 | 参与者 | 参与者状态 → cancelled |
| 已接受（accepted） | 管理员 | 无需退款（尚未开始工作） | 参与者 | 参与者状态 → cancelled（人数统计逻辑见"current_participants 字段说明"章节） |
| 进行中（in_progress） | 管理员 | 按完成度部分退款/积分回退 | 参与者 | 参与者状态 → cancelled（人数统计逻辑见"current_participants 字段说明"章节） |
| 已完成（completed） | 管理员 | 已发放奖励需追回（退款/积分扣除） | 参与者、财务部门 | 参与者状态 → cancelled，奖励记录标记为 refunded |

### 取消操作流程

1. **管理员发起取消**：
   - 验证管理员权限
   - 记录取消原因到 `admin_notes`
   - 更新状态为 `cancelled`
   - 设置 `cancelled_at` 时间
   - 记录审计日志

2. **退款/积分回退处理**：
   - 查询 `task_participant_rewards` 表，找出已发放的奖励
   - 如果 `payment_status='paid'`，触发退款流程（使用 `external_txn_id`）
   - 如果 `points_status='credited'`，从用户账户扣除积分
     - **积分扣除边界**：需要明确积分系统是否允许负积分
       - 如果允许负积分：直接扣除，用户账户可能出现负数
       - 如果不允许负积分：扣除到 0 为止，剩余部分记录为"欠账"或生成"扣回账单"
     - 在奖励表中增加 `reversal_reference` 字段，关联原交易记录，用于对账
   - 更新奖励记录状态为 `refunded`
   - 记录审计日志

3. **通知发送**：
   - 发送通知给所有相关用户
   - 在聊天室发送系统消息（如果任务有聊天室）
   - 发送邮件通知（可选）

## 🧪 测试计划

### 1. 单元测试

- 任务创建逻辑测试
- 参与者申请逻辑测试
- 状态流转逻辑测试
- 奖励分配计算测试

### 2. 集成测试

- 管理员创建官方多人任务流程（支持积分奖励）
- 用户申请参与流程（自动接受，立即进入聊天室）
- 任务聊天室功能测试（消息发送、接收、权限控制）
- 参与者退出申请流程
- 管理员批准/拒绝退出申请流程
- 任务开始流程
- 参与者完成流程
- 任务完成和奖励分配流程（支持积分奖励）
- 议价功能验证（多人任务禁止议价）

### 3. 边界测试

- 达到最大参与人数时的申请处理（应拒绝新申请）
- 未达到最小参与人数时的任务开始
- 任务开始后人数跌破 `min_participants` 的处理（任务应继续，不暂停）
- 奖励分配总额验证（现金和积分分别验证，在事务内实时计算）
- 并发申请处理（多个用户同时申请，使用 SELECT FOR UPDATE 锁定）
- 退出申请边界（已完成或已退出的不能再次申请退出）
- 退出申请拒绝后状态恢复（从 `previous_status` 恢复）
- 聊天室权限边界（非参与者不能发送消息，WebSocket 鉴权）
- 积分奖励边界（仅积分奖励的任务，现金奖励必须为 NULL，不接受 0）
- 任务完成后的参与者提交（`completion_rule=min` 时，未完成者仍可提交但不影响任务状态）
- 幂等键重复请求（应返回已有结果，不报错）
- 字段空值验证（`accepted_at`、`started_at`、`completed_at` 等初始应为 NULL）
- 奖励平均分配四舍五入与余数分配的一致性测试（多并发与重试场景下的快照测试）
- 相同 `idempotency_key` 多次提交只落一笔奖励的幂等性测试

### 4. 性能测试

- 大量参与者申请的性能
- 任务列表查询性能
- 参与者状态更新性能

---

## 📝 开发步骤

### 阶段一：数据库设计（1-2天）

1. 创建数据库迁移脚本
2. 添加 Task 表新字段
3. 创建 TaskParticipant 表
4. 创建 TaskParticipantReward 表
5. 创建必要的索引

### 阶段二：后端API开发（4-6天）

1. 实现管理员创建多人任务API（支持积分奖励）
2. 实现用户申请参与API（官方任务自动接受）
3. 实现任务聊天室集成（用户申请后自动加入聊天室）
4. 实现参与者退出申请API
5. 实现管理员批准/拒绝退出申请API
6. 实现管理员开始任务API
7. 实现参与者完成API
8. 实现管理员确认完成和奖励分配API（支持积分奖励）
9. 实现查询API（参与者列表、用户任务列表等）
10. 实现议价验证（多人任务禁止议价）

### 阶段三：前端开发（4-6天）

1. 开发管理员发布多人任务页面（支持积分奖励设置）
2. 修改任务详情页面支持多人任务（显示官方标识、参与人数、积分奖励等）
3. 开发任务聊天室页面（集成现有聊天功能）
4. 实现申请后自动跳转到聊天室功能
5. 开发退出申请功能
6. 开发管理员任务管理页面（退出申请审核）
7. 开发用户我的多人任务页面
8. 添加相关翻译文本
9. 添加官方任务标识UI

### 阶段四：测试和优化（2-3天）

1. 单元测试
2. 集成测试
3. 性能测试
4. Bug修复
5. 代码优化

### 阶段五：文档和部署（1天）

1. 更新API文档
2. 更新用户手册
3. 部署到测试环境
4. 部署到生产环境

---

## 🔄 向后兼容性

### 1. 现有单人任务

- 所有现有任务保持 `is_multi_participant=false`
- `max_participants=1` 保持单人任务逻辑
- 现有的 `taker_id` 字段继续使用（单人任务）
- 现有的任务查询和显示逻辑不受影响

### 1.1. 多人任务与单人任务的字段使用差异

**单人任务（is_multi_participant=false）**：
- `poster_id`：任务发布者ID（必需）
- `taker_id`：任务接收者ID（必需，任务被接受后设置）
- `task_participants` 表：不使用（或仅用于历史记录）

**多人任务（is_multi_participant=true）**：
- `poster_id`：任务发布者ID（根据任务类型决定）
  - **任务达人发布**：可以设置为系统用户ID或NULL（任务达人不是传统意义上的发布者，而是服务提供者）
  - **管理员发布（发钱任务）**：系统用户ID或管理员关联的用户ID（管理员作为发布者，发钱给用户）
  - **管理员发布（收钱任务）**：系统用户ID或管理员关联的用户ID（管理员作为发布者，但同时也是接收者）
- `taker_id`：任务接收者ID（根据任务类型决定）
  - **任务达人发布**：**必须设置为任务达人的用户ID**（任务达人提供服务，收钱）
  - **管理员发布（收钱任务）**：**必须设置为系统用户ID或管理员关联的用户ID**（管理员收钱）
  - **管理员发布（发钱任务）**：**必须为 NULL**（管理员发钱，不是接收者）
- `task_participants` 表：存储所有参与者信息
  - 通过 `task_participants.task_id` 关联查询所有参与者
  - 每个参与者一条记录，包含状态、时间偏好等信息
  - **参与者角色**：
    - 任务达人发布：参与者是付费方（付钱给任务达人）
    - 管理员发布（收钱）：参与者是付费方（付钱给平台）
    - 管理员发布（发钱）：参与者是奖励接收方（从平台获得奖励）

**查询示例**：
```sql
-- 查询多人任务的所有参与者（付费方或奖励接收方）
SELECT tp.*, u.name, u.avatar
FROM task_participants tp
JOIN users u ON tp.user_id = u.id
WHERE tp.task_id = 123
  AND tp.status IN ('accepted', 'in_progress', 'completed');

-- 查询任务达人发布的多人任务的接收者（任务达人，收钱方）
SELECT t.*, u.name, u.avatar
FROM tasks t
JOIN users u ON t.taker_id = u.id
WHERE t.id = 123
  AND t.is_multi_participant = true
  AND t.created_by_expert = true;

-- 查询管理员发布的收钱任务的接收者（管理员，收钱方）
SELECT t.*, u.name, u.avatar
FROM tasks t
JOIN users u ON t.taker_id = u.id
WHERE t.id = 124
  AND t.is_multi_participant = true
  AND t.created_by_admin = true
  AND t.taker_id IS NOT NULL;  -- 收钱任务，taker_id不为NULL

-- 查询单人任务的接收者（使用taker_id）
SELECT t.*, u.name, u.avatar
FROM tasks t
JOIN users u ON t.taker_id = u.id
WHERE t.id = 456
  AND t.is_multi_participant = false;
```

**数据一致性规则**：
1. **多人任务**：`is_multi_participant=true` 时
   - **任务达人发布**：`taker_id` 必须设置为任务达人的用户ID（`expert_creator_id`）
   - **管理员发布（收钱任务）**：`taker_id` 必须设置为系统用户ID或管理员关联的用户ID
   - **管理员发布（发钱任务）**：`taker_id` 必须为 NULL（管理员发钱，不是接收者）
   - 参与者信息必须存储在 `task_participants` 表中
   - 查询参与者时，必须从 `task_participants` 表查询
   - 查询接收者时，使用 `taker_id` 字段（如果设置了）
2. **单人任务**：`is_multi_participant=false` 时
   - `taker_id` 在任务被接受后必须设置（不为 NULL）
   - `task_participants` 表不使用（或仅用于历史记录）
   - 查询接收者时，使用 `taker_id` 字段
3. **数据验证**：应用层应验证
   - 如果 `is_multi_participant=true` 且 `created_by_expert=true`，则 `taker_id` 必须等于 `expert_creator_id`
   - 如果 `is_multi_participant=true` 且 `created_by_admin=true`，根据任务类型（收钱/发钱）验证 `taker_id`
   - 如果 `is_multi_participant=false`，则 `taker_id` 在任务被接受后不应为 NULL

### 2. API兼容性

- 现有的任务创建API继续支持单人任务
- 新增的多人任务API不影响现有API
- 任务列表API需要兼容两种类型的任务

### 3. 前端兼容性

- 现有的任务卡片和详情页面需要兼容显示两种类型
- 添加多人任务标识和参与人数显示
- 保持现有UI/UX的一致性

---

## 🌐 国际化与可访问性

### 1. 国际化（i18n）

- 所有用户可见文本需要支持多语言（英语、中文等）
- API 错误消息需要本地化
- 日期时间格式根据用户时区显示
- 货币格式根据用户地区显示

### 2. 可访问性（A11y）

- **屏幕阅读器支持**：
  - 所有交互元素添加 `aria-label` 或 `aria-labelledby`
  - 表单字段添加 `aria-describedby` 关联帮助文本
  - 状态变更使用 `aria-live` 区域通知
- **键盘导航**：
  - 所有功能可通过键盘访问（Tab、Enter、Esc等）
  - 焦点顺序符合逻辑流程
  - 焦点可见性（清晰的焦点指示器）
- **视觉辅助**：
  - 颜色对比度符合 WCAG AA 标准
  - 不依赖颜色传达信息（使用图标+文字）
  - 支持用户自定义字体大小
- **响应式设计**：
  - 支持移动端、平板、桌面端
  - 触摸目标大小符合最小44x44px标准

## 📊 观测性与运维

### 1. 关键指标（SLI/SLO）

- **申请成功率**：目标 > 99%（排除用户主动取消）
- **并发申请处理**：目标 < 100ms P95 响应时间
  - **细分指标**：
    - 数据库事务耗时：目标 < 50ms P95
    - 锁等待时间：目标 < 30ms P95（用于定位热点任务超卖竞争）
    - 业务逻辑处理时间：目标 < 20ms P95
- **奖励分配成功率**：目标 > 99.9%
- **WebSocket 连接稳定性**：目标 > 99.5% 在线率
- **数据库查询性能**：目标 < 50ms P95 查询时间

### 2. 监控指标

- **业务指标**：
  - 任务创建数量（按类型、管理员）
  - 申请参与数量（按任务、用户）
  - 申请失败率（原因分类：人数已满、重复申请、权限不足等）
  - 退出申请数量（批准率、拒绝率）
  - 任务完成率（按完成规则分类）
  - 奖励分配数量（按类型：现金、积分）
- **技术指标**：
  - API 响应时间（P50、P95、P99）
  - 数据库查询时间
  - WebSocket 连接数、消息发送速率
  - 错误率（4xx、5xx）
  - 并发请求数

### 3. 日志策略

- **结构化日志**：使用 JSON 格式，包含：
  - 请求ID（用于追踪）
  - 用户ID/管理员ID
  - 操作类型
  - 时间戳
  - 错误堆栈（如有）
- **日志级别**：
  - ERROR：系统错误、支付失败等
  - WARN：并发冲突、数据不一致等
  - INFO：关键业务操作（申请、完成、分配奖励等）
  - DEBUG：详细调试信息（开发环境）
- **日志保留**：
  - 审计日志：永久保留
  - 业务日志：保留90天
  - 调试日志：保留7天

### 4. 告警规则

- **紧急告警**（立即通知）：
  - 奖励分配失败率 > 1%
  - 数据库连接失败
  - 支付网关异常
- **重要告警**（1小时内通知）：
  - 申请失败率 > 5%
  - API 响应时间 P95 > 1s
  - WebSocket 连接数异常下降
- **一般告警**（24小时内通知）：
  - 任务创建数量异常
  - 数据库查询性能下降

### 5. 灰度发布与回滚

- **灰度策略**：
  - 新功能先对10%用户开放
  - 监控关键指标，无异常后逐步扩大
  - 支持功能开关（Feature Flag）
- **回滚预案**：
  - 数据库迁移回滚脚本
  - API 版本兼容（支持旧版本客户端）
  - 快速回滚流程（5分钟内完成）

## 🚀 未来扩展

### 1. 任务达人发布多人任务

- **功能概述**：允许任务达人（具有特定服务技能的用户）创建多人任务
- **权限要求**：用户需要被标记为"任务达人"（expert），具有特定服务技能认证
- **与管理员任务的区别**：
  - 任务达人发布的任务不是"官方任务"（`is_official_task=false`）
  - 任务达人发布的任务可能需要审核（`auto_accept=false`，或根据平台策略设置）
  - 任务达人可以设置固定时间段固定人数的服务

### 2. 任务达人固定时间段固定人数服务

- **功能概述**：任务达人可以为特定服务设置固定时间段和每个时间段的人数限制
- **应用场景**：
  - **固定时间段服务示例**：麻将达人可以设置一个时间段为1小时，从中午12:00到晚上22:00，每个时间段4人
    - 每个时间段独立，用户需要选择具体的时间段进行申请
    - 每个时间段最多允许指定人数申请（如麻将需要4人）
  - **非固定时间段服务示例**：摄影达人可以发布摄影服务，不设置固定时间段
    - 申请人可以选择期望的截止日期（如：希望在2月15日前完成）
    - 或者选择灵活时间（时间灵活，可与任务达人协商）
    - 任务达人可以根据申请人的时间偏好进行审核和安排
  - **折扣应用场景**：
    - 特定时间段缺人时，可以设置折扣吸引用户（如：1点到2点时间段缺人，原价10镑，现价8镑，打8折）
    - 推广新服务时，可以设置折扣吸引用户尝试
    - 淡季或非热门时间段，可以设置折扣提高上座率
- **数据库字段**：
  - `is_fixed_time_slot`: 标识是否为固定时间段服务
  - `time_slot_duration_minutes`: 时间段时长（分钟），如60表示1小时
  - `time_slot_start_time`: 时间段开始时间（TIME类型），如12:00
  - `time_slot_end_time`: 时间段结束时间（TIME类型），如22:00
  - `participants_per_slot`: 每个时间段的人数限制，如4人
  - `original_price_per_participant`: 原价（每人），如10镑
  - `discount_percentage`: 折扣百分比（0-100），如20表示打8折
  - `discounted_price_per_participant`: 折扣后价格（每人），如8镑
- **业务逻辑**：
  - 系统根据 `time_slot_start_time`、`time_slot_end_time` 和 `time_slot_duration_minutes` 自动生成所有可用时间段
  - 例如：12:00-22:00，每60分钟一个时间段，会生成10个时间段（12:00-13:00, 13:00-14:00, ..., 21:00-22:00）
  - 用户申请时，需要选择具体的时间段
  - 每个时间段独立计算参与人数，达到 `participants_per_slot` 后停止接受该时间段的申请
  - 不同时间段之间互不影响，可以同时进行多个时间段的申请
- **前端展示**：
  - **固定时间段服务**：
    - 显示所有可用时间段列表
    - 每个时间段显示当前申请人数/最大人数（如：2/4）
    - 已满的时间段显示"已满"标识，禁止申请
    - 用户可以选择一个时间段进行申请
  - **非固定时间段服务**：
    - 显示时间选择表单
    - 单选按钮或开关：选择"灵活时间"或"指定截止日期"
    - 如果选择"指定截止日期"：显示日期时间选择器
    - 如果选择"灵活时间"：显示提示信息
  - **折扣信息展示**（如果任务设置了折扣）：
    - 在任务详情页面顶部或奖励信息区域显示折扣信息
    - 显示原价（带删除线）和现价（突出显示）
    - 显示折扣百分比或节省金额
    - 使用醒目的视觉样式（如红色、橙色标签）吸引用户注意
- **API设计**：
  - 创建任务时，如果 `is_fixed_time_slot=true`，必须提供时间段相关字段
  - 申请参与时，需要指定 `time_slot` 参数（时间段标识或时间范围）
  - 查询任务详情时，返回所有时间段及其当前申请人数
- **数据验证**：
  - `time_slot_duration_minutes` 必须 > 0
  - `time_slot_end_time` 必须 > `time_slot_start_time`
  - `participants_per_slot` 必须 >= 1 且 <= `max_participants`
  - 时间段总数 = (结束时间 - 开始时间) / 时间段时长，必须为整数
  - **折扣验证**（如果设置了折扣）：
    - `original_price_per_participant` 必须 > 0
    - `discount_percentage` 必须在 0-100 之间
    - `discounted_price_per_participant` 必须 > 0 且 <= `original_price_per_participant`
    - `discounted_price_per_participant` 必须等于 `original_price_per_participant * (1 - discount_percentage / 100)`（允许浮点数精度误差）
    - 任务的 `reward` 字段应等于 `discounted_price_per_participant`（或根据奖励分配方式计算总奖励）

### 3. 普通用户发布多人任务

- 允许普通用户创建多人任务（需要权限验证）
- 添加发布费用机制

### 4. 任务分组和子任务

- 支持将大型任务分解为子任务
- 支持任务分组管理

### 5. 参与者评价系统

- 参与者之间可以互相评价
- 管理员可以评价参与者

### 6. 动态奖励分配

- 根据参与者贡献度自动分配奖励
- 支持按完成质量分配奖励

### 7. 任务协作工具

- 任务内聊天功能（已有基础）
- 文件共享功能
- 进度跟踪功能

---

## 📚 相关文档

- [任务聊天功能开发文档](./TASK_CHAT_DEVELOPMENT.md)
- [优惠券和积分系统开发日志](./COUPON_POINTS_SYSTEM_DEVELOPMENT.md)
- [API文档](./API_DOCUMENTATION.md)

---

## ✅ 检查清单

### 数据库
- [ ] Task 表添加多人任务字段
- [ ] 创建 TaskParticipant 表
- [ ] 创建 TaskParticipantReward 表
- [ ] 创建必要的索引
- [ ] 数据库迁移脚本测试

### 后端API
- [ ] 管理员创建多人任务API（支持积分奖励）
- [ ] 用户申请参与API（官方任务自动接受）
- [ ] 任务聊天室集成（申请后自动加入）
- [ ] 参与者退出申请API
- [ ] 管理员批准/拒绝退出申请API
- [ ] 管理员开始任务API
- [ ] 参与者完成API
- [ ] 管理员确认完成和奖励分配API（支持积分奖励）
- [ ] 查询API（参与者列表、用户任务列表）
- [ ] 议价验证（多人任务禁止议价）
- [ ] 权限验证
- [ ] 数据验证
- [ ] 错误处理

### 前端
- [ ] 管理员发布多人任务页面（支持积分奖励设置）
- [ ] 任务详情页面支持多人任务（官方标识、参与人数、积分奖励等）
- [ ] 任务聊天室页面（集成聊天功能）
- [ ] 申请后自动跳转到聊天室
- [ ] 退出申请功能
- [ ] 管理员任务管理页面（退出申请审核）
- [ ] 用户我的多人任务页面
- [ ] 翻译文本
- [ ] UI/UX优化
- [ ] 官方任务标识显示

### 测试
- [ ] 单元测试
- [ ] 集成测试
- [ ] 边界测试
- [ ] 性能测试

### 文档
- [ ] API文档更新
- [ ] 用户手册更新
- [ ] 开发文档更新

---

**最后更新**: 2025-01-20  
**文档维护者**: 开发团队  
**版本**: v1.5

## 📝 版本变更日志

### v1.5 (2025-01-20)

**关键修复（彻底清理重复版本）**：
1. ✅ 确认 TaskParticipant 表 DDL 只有一套版本（使用 `planned_reward_amount` / `planned_points_reward`）
2. ✅ 确认 TaskParticipantReward 表 DDL 只有一套版本（包含完整约束和触发器）
3. ✅ 确认 TaskAuditLog 表只有一套语义（允许代理场景同时记录 user_id + admin_id）
4. ✅ 确认 /complete 接口只有 MVP 和未来扩展两个版本
5. ✅ 确认 Task 表的 CHECK 约束只有严格版本（`reward > 0` 和 `points_reward > 0`）

**数据库约束增强**：
1. ✅ 添加 `chk_reward_positive_amount` 约束（不允许 0 金额记录）
2. ✅ 添加 `chk_mvp_official_multi_points_equal` 约束（MVP 限制：官方多人任务必须使用积分+平均分配）
3. ✅ 明确奖励金额字段说明（不允许为 0，必须为 NULL 或 > 0）

**业务逻辑优化**：
1. ✅ 在 /complete 接口添加并发控制说明（使用 `SELECT ... FOR UPDATE` 锁定）
2. ✅ 在前端任务详情页面添加奖励状态显示规范（区分任务状态和奖励状态）
3. ✅ 在触发器章节添加 v1.0 不实现的醒目警告

### v1.4 (2025-01-20)

**关键修复（必须修复）**：
1. ✅ 统一审计日志语义（删除旧版本描述，明确应用层校验规则：`(user_id IS NOT NULL) OR (admin_id IS NOT NULL)`）
2. ✅ 统一任务 completed 状态语义（明确区分"工作完成"和"奖励结算"，删除旧版本"奖励已分配"的描述）
3. ✅ 统一 task_participants 表 DDL（使用 `planned_reward_amount` / `planned_points_reward` 作为唯一规范版本）
4. ✅ 修正 current_participants 在流程描述中的引用（改为"人数统计逻辑见 current_participants 字段说明"）

**数据库约束优化**：
1. ✅ 收紧 CHECK 约束（`reward_type='cash'` 时要求 `reward > 0`，`reward_type='points'` 时要求 `points_reward > 0`）
2. ✅ 明确 `reward_type='both'` 的实际含义（任务级别有现金+积分，但参与者可以只拿其中一种）

**业务逻辑优化**：
1. ✅ 简化 MVP 下的完成接口（移除 `participant_rewards` 请求体，服务端自动计算平均分配）
2. ✅ 在取消矩阵显式标注「v1.0 不实现真实退款/积分回退逻辑」
3. ✅ 明确聊天室权限规则（允许进入/发言的状态：`accepted`、`in_progress`、`completed`）
4. ✅ 完善幂等键策略的落地规范（添加明确的实现示例：申请参与、提交完成、分配奖励）

### v1.3 (2025-01-20)

**高优先修复**：
1. ✅ 修复审计日志 `user_id`/`admin_id` 规则冲突，统一语义（采用方案B：至少有一个不为NULL，允许两个都不为空）
2. ✅ 明确审计日志字段语义（`admin_id`=操作执行者，`user_id`=被影响的业务用户）
3. ✅ 修复任务 `completed` 状态语义不一致，明确区分"工作完成"和"奖励结算"
4. ✅ 添加数据库级 CHECK 约束（跨字段验证：参与人数范围、奖励非负、奖励类型一致性）
5. ✅ 优化字段命名（`reward_amount` → `planned_reward_amount`，`points_reward` → `planned_points_reward`）
6. ✅ 添加奖励表与任务表的 `reward_type` 一致性验证触发器
7. ✅ 优化索引（删除冗余索引，保留必要索引）
8. ✅ 优化 `current_participants` 策略（MVP阶段建议不存，实时 `COUNT(*)`）

**中优先优化**：
1. ✅ 统一幂等键使用规则（所有 side-effect 操作建议携带，关键操作强制要求）
2. ✅ 明确退出逻辑与占坑规则（当前策略和未来扩展策略）
3. ✅ 明确聊天室路由策略（推荐使用 `/rooms/{room_code}`）
4. ✅ 添加 MVP 范围说明（明确 v1.0 必须实现的功能和未来扩展）

**低优先改进**：
1. ✅ 更新 API 接口中的幂等键说明（从"可选"改为"建议携带"）
2. ✅ 优化索引说明（解释为什么删除某些索引）

### v1.2 (2025-01-20)

**高优先修复**：
1. ✅ 修复聊天室 ID 返回值，改为不可预测的 `room_code`（UUID格式）
2. ✅ 修复仅积分任务示例，移除现金金额字段
3. ✅ 明确"自动开始"与"仅管理员开始"的语义（当前仅支持管理员手动开始）
4. ✅ 修复 `completed → exit_requested` 的图示歧义，明确已完成状态不可再申请退出
5. ✅ 统一幂等与完整性校验规则（points-only 时现金必须为 NULL，不接受 0）
6. ✅ 添加 `updated_at` 自动更新触发器，支持乐观锁机制
7. ✅ 统一版本号为 v1.2
8. ✅ 奖励表的 `admin_operator_id` 添加外键约束

**中优先优化**：
1. ✅ 明确 `current_participants` 字段的维护策略（推荐使用触发器）
2. ✅ 明确"迟到加入"规则（当前不允许任务开始后申请）
3. ✅ 明确奖励字段定位（参与者表为计划值，奖励表为实际值）
4. ✅ 添加 `reward_type` 字段的 CHECK 约束
5. ✅ 说明 `user_id` 长度统一问题（建议与 users 表保持一致）
6. ✅ 明确积分追回/扣除的边界规则
7. ✅ 明确审计日志的 `user_id/admin_id` 互斥语义

**低优先改进**：
1. ✅ 添加 `can_auto_accept` 字段到申请响应
2. ✅ 细化并发申请处理的指标（数据库事务、锁等待、业务逻辑）
3. ✅ 补充测试用例（奖励分配一致性、幂等性）
4. ✅ 优化路由策略（推荐使用 `/rooms/{room_code}`）
5. ✅ 优化索引覆盖面（覆盖索引、部分索引）

### v1.1 (2025-01-20)
- 初始版本，包含基础功能设计

