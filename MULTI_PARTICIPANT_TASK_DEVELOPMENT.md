# 管理员发布多人任务功能开发日志

> **版本**: v1.1  
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
ALTER TABLE tasks ADD COLUMN admin_creator_id VARCHAR(5) REFERENCES admin_users(id);  -- 创建任务的管理员ID
```

**字段说明：**
- `is_multi_participant`: 标识是否为多人任务（false表示单人任务，保持向后兼容）
- `is_official_task`: 标识是否为官方任务（管理员发布的任务，所有人都可以看到和申请）
- `max_participants`: 最大参与人数，默认1（单人任务）
- `min_participants`: 最小参与人数，用于判定任务是否可以开始
- `current_participants`: 当前已接受的参与人数（实时统计）
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
- `admin_creator_id`: 创建任务的管理员ID（可为空，用于普通用户创建的单人任务）

### 2. 创建 TaskParticipant 表

存储任务参与者信息：

```sql
CREATE TABLE task_participants (
    id BIGSERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'accepted',  -- accepted, in_progress, completed, exit_requested, exited, cancelled
    reward_amount DECIMAL(12, 2),  -- 该参与者应得的现金奖励（如果reward_distribution=custom）
    points_reward BIGINT DEFAULT 0,  -- 该参与者应得的积分奖励
    applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,  -- 申请时间（也是接受时间，如果是自动接受）
    accepted_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,  -- 接受时间（自动接受时等于applied_at）
    started_at TIMESTAMPTZ,  -- 开始时间（任务开始）
    completed_at TIMESTAMPTZ,  -- 完成时间
    exit_requested_at TIMESTAMPTZ,  -- 退出申请时间
    exit_reason TEXT,  -- 退出原因
    exited_at TIMESTAMPTZ,  -- 退出时间（管理员批准退出）
    cancelled_at TIMESTAMPTZ,  -- 取消时间（管理员取消）
    completion_notes TEXT,  -- 完成备注
    admin_notes TEXT,  -- 管理员备注
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_task_participant UNIQUE(task_id, user_id),  -- 确保同一用户不能重复申请同一任务
    CONSTRAINT chk_participant_status CHECK (
        status IN ('accepted', 'in_progress', 'completed', 'exit_requested', 'exited', 'cancelled')
    )
);

CREATE INDEX idx_task_participants_task ON task_participants(task_id);
CREATE INDEX idx_task_participants_user ON task_participants(user_id);
CREATE INDEX idx_task_participants_status ON task_participants(status);
CREATE INDEX idx_task_participants_task_status ON task_participants(task_id, status);
```

**字段说明：**
- `task_id`: 关联的任务ID
- `user_id`: 参与者用户ID
- `status`: 参与者状态
  - `accepted`: 已接受（官方任务自动接受，用户申请后立即进入此状态，可以进入聊天室）
  - `in_progress`: 进行中（任务已开始，参与者正在工作）
  - `completed`: 已完成（参与者已完成自己的部分）
  - `exit_requested`: 退出申请中（参与者申请退出，等待管理员审核）
  - `exited`: 已退出（管理员批准退出）
  - `cancelled`: 已取消（管理员取消参与者资格）
- `reward_amount`: 该参与者应得的现金奖励金额（仅在reward_distribution=custom时使用）
- `points_reward`: 该参与者应得的积分奖励
- `applied_at`: 申请时间（也是接受时间，如果是自动接受）
- `accepted_at`: 接受时间（自动接受时等于applied_at）
- `started_at`: 开始时间（任务开始，参与者可以开始工作）
- `completed_at`: 完成时间（参与者完成自己的部分）
- `exit_requested_at`: 退出申请时间
- `exit_reason`: 退出原因（参与者申请退出时填写）
- `exited_at`: 退出时间（管理员批准退出）
- `cancelled_at`: 取消时间
- `completion_notes`: 完成备注（参与者提交完成时填写）
- `admin_notes`: 管理员备注（管理员可以添加备注）

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
    paid_at TIMESTAMPTZ,  -- 支付时间
    points_credited_at TIMESTAMPTZ,  -- 积分发放时间
    payment_method VARCHAR(50),  -- 支付方式
    payment_reference VARCHAR(100),  -- 支付参考号
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_reward_payment_status CHECK (
        payment_status IN ('pending', 'paid', 'failed', 'refunded')
    ),
    CONSTRAINT chk_reward_points_status CHECK (
        points_status IN ('pending', 'credited', 'failed', 'refunded')
    )
);

CREATE INDEX idx_participant_rewards_task ON task_participant_rewards(task_id);
CREATE INDEX idx_participant_rewards_participant ON task_participant_rewards(participant_id);
CREATE INDEX idx_participant_rewards_user ON task_participant_rewards(user_id);
CREATE INDEX idx_participant_rewards_payment_status ON task_participant_rewards(payment_status);
CREATE INDEX idx_participant_rewards_points_status ON task_participant_rewards(points_status);
```

**字段说明：**
- `task_id`: 关联的任务ID
- `participant_id`: 关联的参与者记录ID
- `user_id`: 参与者用户ID
- `reward_type`: 奖励类型（cash, points, both）
- `reward_amount`: 实际发放的现金奖励金额（如果reward_type包含cash）
- `points_amount`: 实际发放的积分奖励（如果reward_type包含points）
- `currency`: 货币类型
- `payment_status`: 现金支付状态
- `points_status`: 积分发放状态
- `paid_at`: 现金支付时间
- `points_credited_at`: 积分发放时间
- `payment_method`: 支付方式
- `payment_reference`: 支付参考号（用于对账）

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
  "reward": 500.00,
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

**响应**:
```json
{
  "id": 123,
  "title": "大型活动组织任务",
  "description": "需要多人协作完成的活动组织任务",
  "deadline": "2025-02-01T00:00:00Z",
  "reward": 500.00,
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
  "message": "我有相关经验，希望参与此任务"
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
  "chat_room_id": "task_123"
}
```

**业务逻辑**:
1. 验证任务是否存在且为多人任务
2. 验证任务状态为 `open`
3. 验证当前参与人数未达到 `max_participants`
4. 验证用户未重复申请（检查 `task_participants` 表）
5. 验证任务是否允许议价（多人任务不允许议价，如果用户尝试议价则拒绝）
6. 创建 `task_participants` 记录：
   - 如果任务 `auto_accept=true`（官方任务），状态直接设为 `accepted`，`accepted_at` 等于 `applied_at`
   - 如果任务 `auto_accept=false`，状态设为 `pending`（等待管理员审核）
7. 如果自动接受：
   - 更新任务的 `current_participants` 计数
   - 自动创建或加入任务聊天室
   - 发送欢迎消息到聊天室
   - 发送通知给用户（已成功加入任务）
8. 如果未自动接受：
   - 发送通知给管理员/发布者
9. 返回参与者信息，包括是否可以聊天和聊天室ID

### 3. 参与者申请退出任务

**接口**: `POST /api/tasks/{task_id}/participants/me/exit-request`

**权限**: 需要用户认证，且用户必须是该任务的参与者

**请求体**:
```json
{
  "exit_reason": "因个人原因无法继续参与"
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
3. 更新参与者状态为 `exit_requested`
4. 设置 `exit_requested_at` 和 `exit_reason`
5. 发送通知给管理员
6. 在聊天室发送系统消息（可选）

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
3. 恢复参与者状态为之前的状态（`accepted` 或 `in_progress`）
4. 清空 `exit_requested_at` 和 `exit_reason`
5. 发送通知给参与者

### 4. 管理员开始多人任务

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
3. 验证当前参与人数 >= `min_participants`
4. 更新任务状态为 `in_progress`
5. 更新所有 `accepted` 状态的参与者为 `in_progress`
6. 设置所有参与者的 `started_at` 时间
7. 发送通知给所有参与者

### 5. 参与者提交完成

**接口**: `POST /api/tasks/{task_id}/participants/me/complete`

**权限**: 需要用户认证，且用户必须是该任务的参与者

**请求体**:
```json
{
  "completion_notes": "已完成我的部分工作"
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
3. 更新参与者状态为 `completed`
4. 设置 `completed_at` 时间
5. 检查任务完成条件：
   - 如果 `completion_rule=all`，检查是否所有参与者都完成
   - 如果 `completion_rule=min`，检查是否达到最小完成人数
6. 如果满足完成条件，更新任务状态为 `completed`
7. 发送通知给管理员/发布者

### 6. 管理员确认任务完成并分配奖励

**接口**: `POST /api/admin/tasks/{task_id}/complete`

**权限**: 需要管理员认证

**请求体**:
```json
{
  "participant_rewards": [
    {
      "participant_id": 456,
      "reward_amount": 100.00
    },
    {
      "participant_id": 457,
      "reward_amount": 100.00
    }
  ]
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
2. 验证任务状态为 `in_progress` 或所有参与者都完成
3. 如果 `reward_distribution=equal`，自动计算平均分配
4. 如果 `reward_distribution=custom`，使用请求中的分配方案
5. 验证总分配金额不超过任务总奖励
6. 创建 `task_participant_rewards` 记录
7. 更新任务状态为 `completed`
8. 发送通知给所有参与者
9. 触发支付流程（如果需要）

### 7. 获取任务参与者列表

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

### 8. 获取用户参与的多人任务列表

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

**路径**: `/tasks/{task_id}/chat`

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
- 聊天室ID格式：`task_{task_id}`

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

### 4. 用户我的多人任务页面

**路径**: `/my-tasks/multi-participant`

**功能**:
- 显示用户参与的所有多人任务
- 按状态筛选（申请中、进行中、已完成）
- 显示每个任务的参与状态和奖励信息

---

## 🔒 权限和安全

### 1. 权限控制

- **创建多人任务**: 仅管理员可以创建
- **申请参与**: 所有认证用户都可以申请（官方任务所有人都可以看到）
- **自动接受**: 官方任务自动接受申请，无需管理员审核
- **进入聊天室**: 仅已接受的参与者可以进入和发送消息
- **开始任务**: 仅管理员可以操作（或达到min_participants自动开始）
- **提交完成**: 仅参与者本人可以操作
- **申请退出**: 仅参与者本人可以操作
- **批准/拒绝退出**: 仅管理员可以操作
- **确认完成和分配奖励**: 仅管理员可以操作

### 2. 数据验证

- 最大参与人数 >= 最小参与人数 >= 1
- 总奖励金额 >= 0（如果reward_type包含cash）
- 积分奖励 >= 0（如果reward_type包含points）
- 奖励分配总额不能超过任务总奖励（现金或积分）
- 参与者不能重复申请同一任务
- 多人任务不允许议价（`allow_negotiation=false`）
- 任务状态流转验证（如：不能从未开始直接到完成）
- 退出申请验证（已完成或已退出的不能再次申请退出）

### 3. 并发控制

- 使用数据库事务确保数据一致性
- 使用乐观锁或悲观锁防止并发问题
- 使用唯一约束防止重复申请

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
cancelled (已取消) [可发生在任何状态]
```

### 参与者状态流转（官方任务）

```
用户申请
  ↓ (自动接受，官方任务)
accepted (已接受，可进入聊天室)
  ↓ (管理员开始任务)
in_progress (进行中)
  ↓ (参与者提交完成)
completed (已完成)
  ↓
exit_requested (退出申请中) [可发生在accepted或in_progress状态]
  ↓ (管理员批准)
exited (已退出)
  ↓
cancelled (已取消) [管理员可取消参与者资格，可发生在任何状态]
```

**说明**：
- 官方任务（`auto_accept=true`）：用户申请后立即进入 `accepted` 状态，无需等待管理员审核
- 非官方任务（`auto_accept=false`）：用户申请后需要等待管理员审核（此功能暂不实现，当前仅支持官方任务）
- 参与者可以在 `accepted` 或 `in_progress` 状态申请退出
- 管理员可以随时取消参与者资格（状态变为 `cancelled`）

---

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
- 奖励分配总额验证（现金和积分分别验证）
- 并发申请处理（多个用户同时申请）
- 退出申请边界（已完成或已退出的不能再次申请退出）
- 聊天室权限边界（非参与者不能发送消息）
- 积分奖励边界（仅积分奖励的任务，现金奖励应为0）

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

