# 管理员发布多人任务功能开发日志

> **版本**: v1.2  
> **创建日期**: 2025-01-20  
> **最后更新**: 2025-01-20  
> **设计原则**: 向后兼容、可扩展、安全优先  
> **重要说明**: 本文档描述管理员发布多人任务功能的完整开发方案

---

## 📋 需求概述

开发管理员可以发布多人任务的功能，允许一个任务由多个用户协作完成。与现有的单人任务系统（一个任务只能被一个用户接受）不同，多人任务可以设置最大参与人数，允许多个用户同时参与完成。

**核心功能：**
- **管理员发布官方多人任务**：管理员可以创建需要多人协作完成的任务，标记为"官方任务"，所有人都可以看到和申请
- **自动接受机制**：官方多人任务不需要管理员同意，用户申请后自动接受并立即进入任务聊天室
- **多人申请机制**：多个用户可以对同一任务进行申请，达到最大参与人数后停止接受申请
- **参与人数限制**：任务可以设置最大参与人数（如：需要7人完成）
- **参与状态管理**：跟踪每个参与者的状态（已接受、进行中、已完成、退出申请中）
- **任务完成判定**：可以设置完成条件（如：所有参与者完成、或达到最小完成人数）
- **积分奖励机制**：多人任务可以只使用积分奖励，不需要现金奖励
- **退出申请机制**：参与者退出任务需要申请，等待管理员审核
- **禁止议价**：多人任务不支持议价功能
- **即时聊天**：用户申请后立即进入任务聊天室，可以与其他参与者聊天
- **向后兼容**：不影响现有的单人任务系统

**业务价值：**
- 支持需要多人协作的大型任务
- 提高任务完成效率
- 增加平台任务类型多样性
- 提升用户参与度和活跃度
- 通过官方任务提升平台权威性和用户信任度

---

## 🗄️ 数据库模型设计

### 1. 修改 Task 表

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
  - `cash`: 仅现金奖励
  - `points`: 仅积分奖励
  - `both`: 现金+积分奖励
- `points_reward`: 积分奖励数量（如果reward_type包含points）
- `auto_accept`: 是否自动接受申请（官方多人任务默认true，用户申请后立即接受）
- `allow_negotiation`: 是否允许议价（多人任务默认false，不支持议价）
- `created_by_admin`: 标识任务是否由管理员创建
- `admin_creator_id`: 创建任务的管理员ID（可为空，用于普通用户创建的单人任务，使用VARCHAR(36)以支持UUID格式）

### 2. 创建 TaskParticipant 表

存储任务参与者信息：

```sql
CREATE TABLE task_participants (
    id BIGSERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending',  -- pending, accepted, in_progress, completed, exit_requested, exited, cancelled
    previous_status VARCHAR(20),  -- 前一个状态（用于退出申请被拒绝时恢复）
    reward_amount DECIMAL(12, 2),  -- 该参与者应得的现金奖励（如果reward_distribution=custom）
    points_reward BIGINT DEFAULT 0,  -- 该参与者应得的积分奖励
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
    CONSTRAINT uq_task_participant UNIQUE(task_id, user_id),  -- 确保同一用户不能重复申请同一任务
    CONSTRAINT uq_participant_idempotency UNIQUE(idempotency_key),  -- 幂等键唯一约束
    CONSTRAINT chk_participant_status CHECK (
        status IN ('pending', 'accepted', 'in_progress', 'completed', 'exit_requested', 'exited', 'cancelled')
    )
);

CREATE INDEX idx_task_participants_task ON task_participants(task_id);
CREATE INDEX idx_task_participants_user ON task_participants(user_id);
CREATE INDEX idx_task_participants_status ON task_participants(status);
CREATE INDEX idx_task_participants_task_status ON task_participants(task_id, status);
CREATE INDEX idx_task_participants_task_user ON task_participants(task_id, user_id);  -- 覆盖唯一约束的查询
CREATE INDEX idx_task_participants_task_status_updated ON task_participants(task_id, status, updated_at);  -- 用于管理页排序查询
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
- `reward_amount`: 该参与者**计划**应得的现金奖励金额（仅在reward_distribution=custom时使用，建议重命名为 `planned_reward_amount`）
- `points_reward`: 该参与者**计划**应得的积分奖励（建议重命名为 `planned_points_reward`）

**重要说明**：
- 参与者表中的 `reward_amount` 和 `points_reward` 字段为**计划值**，用于展示和初步计算
- **实际发放值**以 `task_participant_rewards` 表为准
- 读接口应根据 `task_participant_rewards` 表做聚合，返回实际发放值
- 如果计划值与实际值不一致，以实际值为准
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
    )
);

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
- `reward_amount`: 实际发放的现金奖励金额（如果reward_type包含cash，初始为NULL）
- `points_amount`: 实际发放的积分奖励（如果reward_type包含points，初始为NULL）
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
- `user_id`: 操作用户ID（可为空，用于管理员操作）
- `admin_id`: 操作管理员ID（可为空，用于用户操作）
- **互斥规则**：`user_id` 和 `admin_id` 必须有一个不为 NULL（应用层校验：(user_id IS NOT NULL) XOR (admin_id IS NOT NULL)）
- **代理操作场景**：如果管理员代表用户操作，应同时记录 `user_id`（被代理用户）和 `admin_id`（代理管理员），并在 `description` 中标注代理来源
- `action_type`: 操作类型（如：task_created, participant_applied, status_changed, reward_distributed, exit_approved等）
- `entity_type`: 实体类型（task, participant, reward）
- `old_value`: 变更前的值（JSON格式，便于查询和回滚）
- `new_value`: 变更后的值（JSON格式）
- `description`: 操作描述（人类可读的描述）
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

### 2. 用户申请参与多人任务（官方任务自动接受）

**接口**: `POST /api/tasks/{task_id}/apply`

**权限**: 需要用户认证

**请求体**:
```json
{
  "message": "我有相关经验，希望参与此任务",
  "idempotency_key": "unique-request-id-12345"  // 可选，用于防止重复申请
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
2. 验证任务状态为 `open`（**重要**：任务开始后（`in_progress` 状态）不允许新成员申请加入，如需支持"迟到加入"，需要明确策略，见"迟到加入规则"章节）
3. **并发控制**：开启数据库事务，对 `tasks` 记录使用 `SELECT ... FOR UPDATE` 锁定
4. **实时计数验证**：使用 `COUNT(*)` 查询 `task_participants` 表中状态为 `pending`、`accepted`、`in_progress` 的参与者数量，确认未达到 `max_participants`
5. 验证用户未重复申请（检查 `task_participants` 表，利用唯一约束）
6. **幂等性验证**：如果请求包含 `idempotency_key`，检查是否已存在相同键的记录，如果存在则返回已有记录
7. 验证任务是否允许议价（多人任务不允许议价，如果用户尝试议价则拒绝）
8. 创建 `task_participants` 记录：
   - 如果任务 `auto_accept=true`（官方任务），状态直接设为 `accepted`，`accepted_at` 等于 `applied_at`
   - 如果任务 `auto_accept=false`，状态设为 `pending`，`accepted_at` 为 NULL（等待管理员审核）
9. 如果自动接受：
   - 更新任务的 `current_participants` 计数（仅作为展示用缓存，决策仍以实时计数为准）
   - 自动创建或加入任务聊天室（使用不可预测的 `room_code`）
   - 发送欢迎消息到聊天室
   - 发送通知给用户（已成功加入任务）
10. 如果未自动接受：
    - 发送通知给管理员/发布者
11. **审计日志**：记录操作到 `task_audit_logs` 表
12. 提交事务
13. 返回参与者信息，包括是否可以聊天和聊天室ID（使用不可预测的 `room_code`，格式为 UUID，不暴露 `task_id`）

### 3. 参与者申请退出任务

**接口**: `POST /api/tasks/{task_id}/participants/me/exit-request`

**权限**: 需要用户认证，且用户必须是该任务的参与者

**请求体**:
```json
{
  "exit_reason": "因个人原因无法继续参与",
  "idempotency_key": "unique-request-id-12345"  // 可选，用于防止重复申请退出
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

### 4. 管理员批准/拒绝退出申请

**接口**: `POST /api/admin/tasks/{task_id}/participants/{participant_id}/approve-exit`
**接口**: `POST /api/admin/tasks/{task_id}/participants/{participant_id}/reject-exit`

**权限**: 需要管理员认证

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
1. 验证管理员权限
2. 验证参与者状态为 `exit_requested`
3. 更新参与者状态为 `exited`
4. 设置 `exited_at` 时间
5. 更新任务的 `current_participants` 计数（减1）
6. 从任务聊天室移除该用户（可选）
7. 发送通知给参与者
8. 在聊天室发送系统消息（可选）

**业务逻辑（拒绝）**:
1. 验证管理员权限
2. 验证参与者状态为 `exit_requested`
3. 开启数据库事务
4. 从 `previous_status` 字段恢复之前的状态（`accepted` 或 `in_progress`）
5. 清空 `exit_requested_at`、`exit_reason` 和 `previous_status`
6. **审计日志**：记录操作到 `task_audit_logs` 表，包含 `admin_operator_id`
7. 提交事务
8. 发送通知给参与者

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
  "idempotency_key": "unique-request-id-12345"  // 可选，用于防止重复提交完成
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

**请求体**:
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
  "total_reward_distributed": 500.00
}
```

**业务逻辑**:
1. 验证管理员权限
2. 验证任务状态为 `in_progress` 或已完成
3. **幂等性验证**：如果请求包含 `idempotency_key`，检查是否已存在相同键的奖励分配记录
4. 开启数据库事务
5. 如果 `reward_distribution=equal`：
   - 自动计算平均分配（仅针对状态为 `completed` 的参与者）
   - 现金奖励：`总现金奖励 / 已完成参与者数量`（四舍五入到2位小数）
   - 积分奖励：`总积分奖励 / 已完成参与者数量`（向下取整，余数分配给完成时间最早的参与者）
6. 如果 `reward_distribution=custom`，使用请求中的分配方案
7. **完整性约束验证**：
   - 现金奖励：验证所有参与者的 `reward_amount` 总和 <= 任务 `reward`（如果 `reward_type` 包含 `cash`）
   - 积分奖励：验证所有参与者的 `points_amount` 总和 <= 任务 `points_reward`（如果 `reward_type` 包含 `points`）
   - 如果 `reward_type='points'`，验证所有 `reward_amount` 必须为 NULL（不接受 0）
   - 如果 `reward_type='cash'`，验证所有 `points_amount` 必须为 NULL（不接受 0）
   - 如果 `reward_type='both'`，验证所有 `reward_amount` 和 `points_amount` 都不为 NULL
8. 创建 `task_participant_rewards` 记录，包含：
   - `idempotency_key`（客户端生成）
   - `admin_operator_id`（当前管理员ID）
9. 更新任务状态为 `completed`（如果尚未完成）
10. **审计日志**：记录操作到 `task_audit_logs` 表，包含完整的分配方案
11. 提交事务
12. 发送通知给所有参与者
13. 触发支付流程（如果需要，使用 `idempotency_key` 和 `external_txn_id` 确保幂等性）

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

### 2. 多人任务详情页面

**路径**: `/tasks/{task_id}`

**功能**:
- 显示任务基本信息
- 显示官方任务标识（如果是官方任务）
- 显示多人任务标识和参与人数信息（当前人数/最大人数）
- 显示奖励信息（现金/积分/现金+积分）
- 显示参与者列表（如果用户是参与者或管理员）
- 申请参与按钮（如果用户未申请且未达到最大人数）
- 参与状态显示（如果用户已申请/参与）
- **进入聊天室按钮**（如果用户已接受/参与，可以立即进入任务聊天室）
- 退出任务按钮（如果用户已参与，可以申请退出）
- 完成提交按钮（如果用户是参与者且任务进行中）
- 禁止议价提示（多人任务不支持议价）

### 3. 任务聊天室页面

**路径**: `/tasks/{task_id}/chat` 或 `/rooms/{room_code}`（推荐使用后者，彻底避免泄漏任务ID）

**路由策略**：
- **方案A（当前）**：使用 `/tasks/{task_id}/chat`，前端在进入页面时从后端获取 `room_code`，然后使用 `room_code` 建立 WebSocket 连接
- **方案B（推荐）**：使用 `/rooms/{room_code}` 作为路由参数，后端在进入页面时验证用户是否为该聊天室的参与者，然后 302 重定向或直接渲染页面，彻底避免泄漏任务ID

**功能**:
- 显示任务基本信息（标题、参与人数等）
- 显示参与者列表（所有已接受的参与者）
- 实时聊天功能（WebSocket）
- 消息发送和接收
- 图片上传和分享
- 系统消息显示（如：新成员加入、成员退出等）
- 聊天室权限控制（仅参与者可以发送消息）

**聊天室进入逻辑**:
- 用户申请参与官方任务后，状态立即变为 `accepted`
- 用户可以在任务详情页面点击"进入聊天室"按钮
- 或者系统自动跳转到聊天室页面
- **安全说明**：聊天室使用不可预测的 `room_code`（UUID格式），不暴露任务ID
- WebSocket连接时，服务器端需要验证：
  1. 用户身份（JWT token）
  2. 用户是否为该任务的参与者（查询 `task_participants` 表）
  3. 参与者状态是否为 `accepted`、`in_progress` 或 `completed`（允许已完成用户查看历史消息）

### 4. 管理员任务管理页面

**路径**: `/admin/tasks/{task_id}/manage`

**功能**:
- 显示任务详情
- 显示所有参与者列表（官方任务自动接受，无需审核）
- 显示退出申请列表（如果有参与者申请退出）
- 批准/拒绝退出申请按钮
- 开始任务按钮（当达到最小参与人数时，或手动开始）
- 参与者管理（查看、移除参与者）
- 任务完成确认和奖励分配（现金/积分）
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
- **申请退出**: 仅参与者本人可以操作
- **批准/拒绝退出**: 仅管理员可以操作
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

- **客户端生成幂等键**：所有可能重复的操作（申请、退出申请、完成、奖励分配）都应包含 `idempotency_key`
- **服务端缓存**：在 Redis 或内存中缓存幂等键（5-15分钟），拒绝重复请求
- **数据库唯一约束**：在相关表中添加 `idempotency_key` 唯一约束，作为最后一道防线
- **幂等返回**：如果检测到重复请求，返回已有的操作结果，而非错误

### 5. current_participants 字段说明

- `current_participants` 字段仅作为**展示用缓存**，不应用于业务逻辑决策
- 所有决策（如是否允许申请、是否达到最大人数）都应使用实时 `COUNT(*)` 查询
- **推荐方案**：使用数据库触发器自动维护 `current_participants`，禁止应用层直接 UPDATE 该字段
- 如果发现不一致，以实时计数为准

**触发器维护方案（可选）**：
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
- `completed`: 任务已完成，奖励已分配
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
| 已接受（accepted） | 管理员 | 无需退款（尚未开始工作） | 参与者 | 参与者状态 → cancelled，任务 current_participants -1 |
| 进行中（in_progress） | 管理员 | 按完成度部分退款/积分回退 | 参与者 | 参与者状态 → cancelled，任务 current_participants -1 |
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
- 现有的 `taker_id` 字段继续使用
- 现有的任务查询和显示逻辑不受影响

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

### 1. 普通用户发布多人任务

- 允许普通用户创建多人任务（需要权限验证）
- 添加发布费用机制

### 2. 任务分组和子任务

- 支持将大型任务分解为子任务
- 支持任务分组管理

### 3. 参与者评价系统

- 参与者之间可以互相评价
- 管理员可以评价参与者

### 4. 动态奖励分配

- 根据参与者贡献度自动分配奖励
- 支持按完成质量分配奖励

### 5. 任务协作工具

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
**版本**: v1.2

## 📝 版本变更日志

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

