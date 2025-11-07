# 任务聊天功能开发文档

## 一、需求概述

将现有的联系人列表聊天系统改造为基于任务的聊天系统。通过任务来建立聊天会话，每个任务对应一个聊天频道。

## 二、数据库模型改动

### 2.1 修改 Task 表

添加原始价格和最终成交价格字段：

```sql
ALTER TABLE tasks ADD COLUMN base_reward DECIMAL(12,2);  -- 原始标价
ALTER TABLE tasks ADD COLUMN agreed_reward DECIMAL(12,2);  -- 最终成交价（如果有议价）
ALTER TABLE tasks ADD COLUMN currency CHAR(3) DEFAULT 'GBP';  -- 货币类型
```

**字段说明：**
- `base_reward`: 任务原始标价（创建任务时的价格）
- `agreed_reward`: 最终成交价（如果接受了议价，存储议价后的价格）
- `currency`: 货币类型（默认GBP）
- **注意：** 不要覆盖原有的 `reward` 字段，保持向后兼容

### 2.2 修改 TaskApplication 表

添加议价价格字段和唯一约束：

```sql
ALTER TABLE task_applications ADD COLUMN negotiated_price DECIMAL(12,2);
ALTER TABLE task_applications ADD COLUMN currency CHAR(3) DEFAULT 'GBP';
ALTER TABLE task_applications ADD CONSTRAINT uq_task_applicant UNIQUE(task_id, applicant_id);
```

**字段说明：**
- `negotiated_price`: 申请者提出的议价价格（可为空，使用DECIMAL避免精度问题）
- `currency`: 货币类型（默认GBP）
- **唯一约束：** 确保一个用户对同一任务只能申请一次（包括被拒绝后也不能再次申请）

### 2.3 修改 Message 表

添加任务关联和消息类型字段：

```sql
ALTER TABLE messages ADD COLUMN task_id INTEGER REFERENCES tasks(id);
ALTER TABLE messages ADD COLUMN message_type VARCHAR(20) DEFAULT 'normal';
ALTER TABLE messages ADD COLUMN conversation_type VARCHAR(20) DEFAULT 'task';  -- task/customer_service/global
ALTER TABLE messages ADD COLUMN meta TEXT;  -- JSON格式存储元数据（如 is_prestart_note 等）
```

**字段说明：**
- `task_id`: 关联的任务ID
  - **任务消息：** 必须关联任务ID（`conversation_type = 'task'` 时，`task_id` 不能为空）
  - **客服消息：** 可以为空（`conversation_type = 'customer_service'`）
  - **历史消息：** 如果无法确定对应的任务，可以保持为空（但新消息必须关联）
- `message_type`: 消息类型
  - `normal`: 普通消息
  - `system`: 系统消息（如申请状态变更通知）
  - **约束：** 建议加 CHECK 约束限定集合：`CHECK (message_type IN ('normal', 'system'))`，或使用 DB enum
- `conversation_type`: 会话类型
  - `task`: 任务聊天消息
  - `customer_service`: 客服消息
  - `global`: 全局消息
  - **约束：** 建议加 CHECK 约束限定集合：`CHECK (conversation_type IN ('task', 'customer_service', 'global'))`，或使用 DB enum
- `meta`: JSON格式存储元数据
  - 例如：`{"is_prestart_note": true}` 用于标记发布者在任务未开始阶段发送的说明类消息

**索引：**
```sql
CREATE INDEX ix_messages_task_id ON messages(task_id);
CREATE INDEX ix_messages_task_type ON messages(task_id, message_type);
CREATE INDEX ix_messages_task_created ON messages(task_id, created_at DESC, id DESC);  -- 用于游标分页（最新→更旧）
-- 注意：如果不支持降序索引，可建 (task_id, created_at, id)，查询使用 ORDER BY created_at DESC, id DESC 也能走覆盖索引
CREATE INDEX ix_messages_conversation_type ON messages(conversation_type, task_id);
-- 列表聚合常用查询补强：减少回表
CREATE INDEX ix_messages_task_id_id ON messages(task_id, id);  -- 用于未读数聚合（配合 message_read_cursors）
```

**约束：**
```sql
-- 确保任务消息必须关联 task_id
ALTER TABLE messages
ADD CONSTRAINT ck_messages_task_bind
CHECK (conversation_type <> 'task' OR task_id IS NOT NULL);

-- 枚举约束：限定 message_type 和 conversation_type 的合法值
-- 注意：如果不支持 CHECK 约束，改用应用层校验或触发器
ALTER TABLE messages
ADD CONSTRAINT ck_messages_type
CHECK (message_type IN ('normal', 'system'));

ALTER TABLE messages
ADD CONSTRAINT ck_messages_conversation_type
CHECK (conversation_type IN ('task', 'customer_service', 'global'));
```

**约束说明：**
- 任务消息（`conversation_type = 'task'`）必须关联 `task_id`
- 数据库层面强制约束，防止脏写
- 客服消息和全局消息不受此约束限制

### 2.4 新增 MessageReads 表

用于记录消息的已读状态（按用户维度）：

```sql
CREATE TABLE message_reads (
    id INTEGER PRIMARY KEY,
    message_id INTEGER NOT NULL,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id),
    read_at DATETIME NOT NULL,
    UNIQUE(message_id, user_id),
    FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
);

CREATE INDEX ix_message_reads_message_id ON message_reads(message_id);
CREATE INDEX ix_message_reads_user_id ON message_reads(user_id);
CREATE INDEX ix_message_reads_task_user ON message_reads(message_id, user_id);
```

**外键删除策略：**
- `message_id` 外键使用 `ON DELETE CASCADE`，删除消息时自动删除对应的已读记录
- 避免孤儿记录

**字段说明：**
- `message_id`: 消息ID
- `user_id`: 用户ID
- `read_at`: 已读时间
- **唯一约束：** 确保每个用户对每条消息只记录一次已读状态

### 2.5 新增 MessageAttachments 表

用于存储消息附件（支持多图/文件等）：

```sql
CREATE TABLE message_attachments (
    id INTEGER PRIMARY KEY,
    message_id INTEGER NOT NULL,
    attachment_type VARCHAR(20) NOT NULL,  -- image/file/video等
    url VARCHAR(500),  -- 附件URL（公开附件）
    blob_id VARCHAR(100),  -- 私密文件ID（私密附件）
    meta TEXT,  -- JSON格式存储元数据（文件名、大小、MIME类型、缩略图信息、content_hash等）
    created_at DATETIME NOT NULL,
    FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE,
    -- 存在性约束：url 和 blob_id 必须二选一，避免两者皆空/皆有
    CHECK ((url IS NOT NULL AND blob_id IS NULL) OR (url IS NULL AND blob_id IS NOT NULL))
);

CREATE INDEX ix_message_attachments_message_id ON message_attachments(message_id);
```

**外键删除策略：**
- `message_id` 外键使用 `ON DELETE CASCADE`，删除消息时自动删除对应的附件记录
- 避免孤儿记录

**字段说明：**
- `message_id`: 关联的消息ID
- `attachment_type`: 附件类型（image/file/video等）
- `url`: 附件URL（公开附件）
- `blob_id`: 私密文件ID（私密附件）
- `meta`: JSON格式的元数据
  ```json
  {
    "filename": "example.jpg",
    "size": 1024000,
    "mime_type": "image/jpeg",
    "width": 1920,
    "height": 1080,
    "thumbnail": {
      "url": "https://...",
      "width": 320,
      "height": 240
    },
    "duration": 120,  // 视频时长（秒）
    "frame_cover": "https://...",  // 视频帧封面
    "content_hash": "sha256:..."  // 内容哈希，便于去重与风控协同
  }
  ```

### 2.6 新增 Notifications 表

用于存储系统通知（支持审计）：

```sql
CREATE TABLE notifications (
    id INTEGER PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id),
    type VARCHAR(32) NOT NULL,  -- e.g. 'negotiation_offer', 'task_application', 'task_approved' 等
    related_id INTEGER,  -- application_id 或 task_id（根据 type 而定）
    content TEXT NOT NULL,  -- JSON 格式存储通知数据
    created_at DATETIME NOT NULL,
    read_at DATETIME  -- 已读时间（可为空）
);

CREATE INDEX ix_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX ix_notifications_type ON notifications(type, related_id);
```

**字段说明：**
- `user_id`: 接收通知的用户ID
- `type`: 通知类型（如 `negotiation_offer`、`task_application`、`task_approved` 等）
- `related_id`: 关联ID（根据通知类型，可能是 `application_id` 或 `task_id`）
- `content`: JSON 格式存储通知数据（任务标题、议价价格、留言等）
- `created_at`: 通知创建时间
- `read_at`: 已读时间（可为空）

**设计原则：**
- 此表用于存储所有系统通知
- `content` 字段使用 JSON 格式，便于扩展
- 支持按用户和时间查询未读通知

### 2.7 新增 NegotiationResponseLog 表

用于记录议价响应操作日志（可审计记录）：

```sql
CREATE TABLE negotiation_response_logs (
    id INTEGER PRIMARY KEY,
    notification_id INTEGER REFERENCES notifications(id),  -- 可为空（如果通知被删除）
    task_id INTEGER NOT NULL REFERENCES tasks(id),
    application_id INTEGER NOT NULL REFERENCES task_applications(id),
    user_id VARCHAR(8) NOT NULL REFERENCES users(id),
    action VARCHAR(20) NOT NULL,  -- 'accept' 或 'reject' 或 'withdraw'
    negotiated_price DECIMAL(12,2),  -- 议价价格（如果接受）
    responded_at DATETIME NOT NULL,
    ip_address VARCHAR(45),  -- 操作IP（可选，用于审计）
    user_agent TEXT,  -- 用户代理（可选，用于审计）
    -- 业务级唯一约束：防止重复落库（包括重放/抖动）
    UNIQUE(application_id, action)  -- 同一申请同一动作只能记录一次
);

CREATE INDEX ix_negotiation_log_notification ON negotiation_response_logs(notification_id);
CREATE INDEX ix_negotiation_log_task ON negotiation_response_logs(task_id);
CREATE INDEX ix_negotiation_log_application ON negotiation_response_logs(application_id);
CREATE INDEX ix_negotiation_log_user ON negotiation_response_logs(user_id);
```

**字段说明：**
- `notification_id`: 关联的通知ID
- `task_id`: 任务ID
- `application_id`: 申请ID
- `user_id`: 操作用户ID
- `action`: 操作类型（accept/reject）
- `negotiated_price`: 议价价格（如果接受）
- `responded_at`: 响应时间
- `ip_address`: 操作IP（可选）
- `user_agent`: 用户代理（可选）

**设计原则：**
- 此表作为业务操作日志，记录所有议价响应操作
- 无需专门的 token 表，追溯依赖业务事件
- 与业务事务一起写入，保证数据一致性

### 2.8 新增 MessageReadCursors 表（默认必开）

用于按任务维度记录已读游标，降低写放大：

```sql
CREATE TABLE message_read_cursors (
    id INTEGER PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id),
    user_id VARCHAR(8) NOT NULL REFERENCES users(id),
    last_read_message_id INTEGER NOT NULL REFERENCES messages(id),
    updated_at DATETIME NOT NULL,
    UNIQUE(task_id, user_id)
);

CREATE INDEX ix_message_read_cursors_task_user ON message_read_cursors(task_id, user_id);
CREATE INDEX ix_message_read_cursors_message ON message_read_cursors(last_read_message_id);
```

**字段说明：**
- `task_id`: 任务ID
- `user_id`: 用户ID
- `last_read_message_id`: 最后已读的消息ID
- `updated_at`: 更新时间

**设计原则（默认必开）：**
- **主口径：** `message_read_cursors` 作为未读数计算的主口径，列表页几乎处处要未读数，`message_reads` 写放大明显
- **更新策略：** 接口以"更新游标"为主，`message_reads` 仅做"跨端补读/精确回溯"的稀疏记录
- **未读数计算：** `message.id > last_read_message_id`（同时排除自己发送的消息）
- **性能优化：** 未读聚合若频繁，可考虑物化缓存/异步刷新（新消息/读游标推进时更新）
- **与 `message_reads` 表配合使用，保持"排除自己消息"的口径一致**

### 2.9 申请信息存储策略

**重要：** 以 `TaskApplication` 表为唯一真相源，不在 `Message` 表中存储申请信息。

**设计原则：**
- `TaskApplication` 表是申请信息的唯一数据源
- 聊天框中显示的申请信息从 `TaskApplication` 表实时查询
- 不在 `Message` 表中创建 `message_type = "application"` 的消息
- 如果需要通知申请状态变更，可以创建 `message_type = "system"` 的系统消息，仅包含 `application_id` 引用

**系统消息格式（可选）：**
```json
{
  "type": "system",
  "event": "application_created",  // 或 "application_approved", "application_rejected"
  "application_id": 123,
  "content": "系统消息：申请已创建/已接受/已拒绝"
}
```

## 三、业务逻辑

### 3.1 任务状态逻辑

#### 3.1.1 任务大厅显示逻辑

- **显示条件：** `status = "open"` 且 `taker_id` 为空
- **隐藏条件：** 
  - `status = "in_progress"` 或 `status = "completed"` 或 `status = "cancelled"`
  - 或者 `taker_id` 不为空（已有接受者）

#### 3.1.2 我的任务页面显示逻辑

**发布者视角：**
- `posted` 标签页：
  - 显示所有发布的任务
  - 如果有待处理的申请（`TaskApplication.status = "pending"`），显示为 `taken` 状态（视觉上）
  - 如果有已接受的申请者（`Task.taker_id` 不为空），显示为 `in_progress` 状态
  - **状态判定来源：** 使用 `Task.taker_id` 和 `Task.status` 作为唯一来源
    - 如果 `taker_id` 为空且 `status = "open"`，保持 `open`
    - 如果 `taker_id` 不为空，更新为 `in_progress`
    - `TaskApplication` 仅作为候选/历史，不用于主状态判定

**申请者视角：**
- `taken` 标签页：
  - 显示所有已申请的任务（`TaskApplication` 表中存在记录）
  - 如果申请状态为 `pending`，显示为 `taken` 状态（视觉上）
  - 如果申请状态为 `approved`，显示为 `in_progress` 状态
  - **状态判定来源：** 使用 `Task.taker_id` 和 `Task.status` 作为唯一来源
    - 如果任务 `taker_id` 为空且 `status = "open"`，保持 `open`
    - 如果任务 `taker_id` 不为空，更新为 `in_progress`

### 3.2 申请流程

#### 3.2.1 申请任务

1. 用户在任务详情页点击"申请任务"
2. 弹出申请弹窗，包含：
   - 申请留言输入框（可选）
   - 议价选项（可选）
     - 如果选择议价，显示价格输入框
   - 默认申请按钮（不输入任何内容）
3. 提交申请：
   - 创建 `TaskApplication` 记录（唯一真相源）
   - 如果选择了议价，设置 `negotiated_price`（DECIMAL类型）
   - **不在 Message 表中创建申请消息**（申请信息从 TaskApplication 表实时查询）
   - 可选：创建系统消息（`message_type = "system"`）通知申请创建，仅包含 `application_id` 引用
   - 发送通知给任务发布者

#### 3.2.2 申请信息显示规则

**在任务聊天框中：**
- **申请信息从 `TaskApplication` 表实时查询**（唯一真相源）
- **显示条件：**
  - 申请状态为 `pending`（待处理）的申请信息才会显示
  - 如果申请被接受（`status = "approved"`）或拒绝（`status = "rejected"`），则不再显示
- **权限过滤：**
  - **发布者可以看到：** 所有待处理的申请信息（包括留言、议价等）
  - **申请者可以看到：** 只能看到自己的待处理申请信息
  - **已接受的申请者：** 看不到申请信息（因为状态已变为 `approved`）
- **前端实现：**
  - 申请信息显示在聊天框的"申请卡片区"（独立于消息流）
  - 或作为特殊样式的消息气泡渲染（但数据来源是 TaskApplication 表，不是 Message 表）

### 3.3 接受/拒绝申请

#### 3.3.1 接受申请

1. 发布者在任务聊天框中点击"接受"按钮（针对某个申请信息）
2. **并发控制与幂等性：**
   - 使用数据库事务 + `SELECT ... FOR UPDATE` 锁定任务行
   - 检查任务是否还有名额：`Task.taker_id` 是否为空
   - 如果 `taker_id` 不为空，返回明确错误码（任务已被接受）
   - 幂等性：如果再次接受同一申请（`TaskApplication.status = "approved"`），直接返回成功
3. 如果还有名额：
   - 更新 `Task.taker_id` 为申请者的ID
   - 如果申请包含议价（`negotiated_price` 不为空）：
     - 更新任务的 `agreed_reward` 字段（不覆盖 `base_reward`）
     - **注意：** 不更新 `reward` 字段，前端显示统一使用：`display_reward = agreed_reward ?? base_reward`
   - 更新 `TaskApplication.status = "approved"`
   - 发送通知给申请者
4. **接受申请后更新任务状态：**
   - 更新任务 `status = "in_progress"`
   - 自动拒绝所有其他待处理的申请（`TaskApplication.status = "rejected"`）
   - 任务从任务大厅移除

#### 3.3.2 拒绝申请

1. 发布者在任务聊天框中点击"拒绝"按钮
2. 更新 `TaskApplication.status = "rejected"`
3. 发送通知给申请者
4. **拒绝后的影响：**
   - 申请者在"我的任务"页面看不到此任务
   - 申请者不能再次申请此任务（通过 `TaskApplication` 表检查）

### 3.4 再次议价流程

#### 3.4.1 发布者发起再次议价

1. 发布者在任务聊天框中点击"再次议价"按钮（针对某个申请信息）
2. 弹出议价弹窗：
   - 显示当前任务价格（`base_reward` 或 `agreed_reward`）
   - 输入新的议价价格（DECIMAL类型）
   - 输入留言（可选）
3. 提交议价：
   - 更新 `TaskApplication.negotiated_price`（DECIMAL类型）
   - 生成一次性签名 token（绑定用户+动作+申请ID+时间戳，有效期5分钟）
   - **Token 存储：** 存储在 Redis 中，key 格式：`negotiation_token:{token}`
   - **Payload 字段统一：** `{user_id, action, application_id, task_id, notification_id, nonce, exp, expires_at}`
     - `user_id`: 申请者用户ID
     - `action`: "accept" 或 "reject"
     - `application_id`: 申请ID
     - `task_id`: 任务ID
     - `notification_id`: 通知ID
     - `nonce`: 随机数（防重放）
     - `exp`: 过期时间戳（便于服务端二次校验与审计回放）
     - `expires_at`: 过期时间字符串
   - 创建系统通知（`Notification`）发送给申请者
     - `type = "negotiation_offer"`
     - `related_id = application_id`
     - `content` 包含 JSON 格式的通知数据（任务标题、议价价格、留言等）
   - 通知内容包含：
     - 任务标题
     - 新的议价价格
     - 申请者之前的留言
     - 发布者的留言
     - "同意"按钮（携带一次性签名 token，链接到处理议价的接口）
     - "拒绝"按钮（携带一次性签名 token，链接到拒绝议价的接口）

#### 3.4.2 申请者处理再次议价

1. 申请者在通知中心看到议价通知
2. 点击"同意"按钮：
   - **直接执行接受任务操作**（无需跳转，但需要验证一次性签名 token）
   - **Token 校验（Redis）：**
     - 使用 `GETDEL`（Redis 6.2+）或 Lua 脚本一次性"取值+删除"原子操作，比"GET 后再 DEL"更原子，避免并发穿插
     - 如果不存在或已过期，返回 403 Forbidden
     - **命中后校验：** 验证 token payload 中的 `exp`、`user_id`、`action`、`task_id`、`application_id` 是否匹配
     - 验证 token 绑定的用户ID是否匹配当前用户
     - 验证 token 绑定的申请ID和任务ID是否匹配
   - **业务操作（数据库事务）：**
     - 使用事务 + `SELECT ... FOR UPDATE` 锁定任务行
     - 更新 `Task.taker_id` 为申请者的ID
     - 更新任务的 `agreed_reward` 字段为议价价格（不覆盖 `base_reward`）
     - 更新 `TaskApplication.status = "approved"`
     - 更新任务 `status = "in_progress"`
     - 自动拒绝所有其他待处理的申请
     - **写入操作日志：** 在 `negotiation_response_logs` 表中记录操作（与业务事务一起提交）
   - **Token 消费（Redis）：**
     - 已在权限检查阶段通过 `GETDEL` 或 Lua 脚本一次性完成（原子操作，防重放）
   - 发送通知给发布者
3. 点击"拒绝"按钮：
   - **直接执行拒绝任务操作**（无需跳转，但需要验证一次性签名 token）
   - **Token 校验（Redis）：** 使用 `GETDEL` 或 Lua 脚本原子取值并删除，命中后校验 `exp`/`user_id`/`action`/`task_id`/`application_id`（同上）
   - **业务操作（数据库事务）：**
     - 更新 `TaskApplication.status = "rejected"`
     - **写入操作日志：** 在 `negotiation_response_logs` 表中记录操作（与业务事务一起提交）
   - **Token 消费（Redis）：**
     - 已在权限检查阶段通过 `GETDEL` 或 Lua 脚本一次性完成（原子操作，防重放）
   - 发送通知给发布者
   - 申请者在"我的任务"页面看不到此任务
   - 申请者不能再次申请此任务

### 3.5 对话权限控制

#### 3.5.1 任务未开始（`status = "open"` 且 `taker_id` 为空）

- **发布者：**
  - 可以查看所有申请信息
  - 可以接受/拒绝申请
  - 可以发起再次议价
  - **可以发送说明类消息**（用于需求澄清，但限制频率）
    - **频率限制：** 最多 1 条/分钟，日上限 20 条
    - 超限返回 `429 Too Many Requests`
    - 消息表 `meta` 字段中标记 `is_prestart_note: true` 便于审计
  - 普通聊天消息需要任务开始后才能发送
- **申请者：**
  - 只能看到自己的申请信息
  - **不能发送普通消息**（避免骚扰）
  - 可以通过通知处理再次议价
  - 可以通过申请卡片与发布者沟通

#### 3.5.2 任务进行中（`status = "in_progress"` 或 `taker_id` 不为空）

- **所有参与者（发布者 + 接受者）：**
  - 可以正常发送和接收消息
  - 可以看到所有普通消息
  - 消息显示发送者头像和名字
  - 需要让所有人知道此消息是谁发布的（显示发送者信息）
  - 看不到申请信息（因为申请信息只在 `pending` 状态时显示）

### 3.6 任务显示逻辑

#### 3.6.1 任务卡片显示

- 显示方式与现在一样
- 显示任务标题、类型、金额、位置等

#### 3.6.2 任务详情页显示逻辑

**任务详情内容：**
- 显示任务描述
- 显示任务金额

**操作按钮：**
- **发布者：**
  - 如果任务还没有接受者（`taker_id` 为空），显示"查看申请"按钮（点击后弹出申请列表弹窗）
  - 如果任务已有接受者（`taker_id` 不为空），显示"进行中"状态
- **申请者：**
  - 如果已申请且状态为 `pending`，不显示"申请任务"按钮，显示"已申请"状态
  - 如果申请被拒绝（`status = "rejected"`），不显示"申请任务"按钮，显示"申请已拒绝"状态
  - 如果申请被接受（`Task.taker_id` 匹配），显示"进行中"状态
- **其他用户：**
  - 如果任务还没有接受者（`taker_id` 为空），显示"申请任务"按钮
  - 如果任务已有接受者（`taker_id` 不为空），显示"已被接受"状态

## 四、API 接口设计

### 4.1 任务相关接口

#### 4.1.1 获取任务聊天列表

```
GET /api/messages/tasks
```

**功能：** 获取当前用户相关的所有任务（用于聊天列表）

**查询参数：**
- `limit`: 每页数量（默认20）
- `offset`: 偏移量（默认0）

**权限检查：**
- 返回用户作为发布者或接受者的所有任务

**返回数据：**
```json
{
  "tasks": [
    {
      "id": 123,
      "title": "任务标题",
      "task_type": "delivery",
      "images": ["url1", "url2"],
      "poster_id": "U1234567",
      "status": "open",
      "taker_id": null,
      "unread_count": 5,  // 基于 message_reads 表聚合计算
      "last_message": {  // 基于 messages 表查询最后一条消息
        "id": 100,
        "content": "最后一条消息",
        "sender_id": "U1234567",
        "sender_name": "用户名",
        "created_at": "2024-01-01T12:00:00Z"
      }
    }
  ],
  "total": 10
}
```

**说明：**
- `unread_count`: 未读数统计实现（性能/正确性双保险）
  - **首选方案（游标模式）：** 使用 `message_read_cursors.last_read_message_id` 聚合更快
    - SQL 逻辑：`COUNT(*) WHERE task_id = ? AND id > last_read_message_id AND sender_id <> current_user_id`
  - **兜底方案：** 对"跨端补读/离线补写"的零散场景，使用 `message_reads` 表兜底
    - SQL 逻辑：`COUNT(*) WHERE task_id = ? AND sender_id <> current_user_id AND NOT EXISTS (SELECT 1 FROM message_reads WHERE message_id = messages.id AND user_id = current_user_id)`
  - **业务口径（已写死，统一口径）：** 排除自己发送的消息（`sender_id <> current_user_id`），避免"我刚发完还显示未读"的尴尬
  - **重要：** 此口径在所有未读数计算场景中必须保持一致，排除 `sender_id = current_user_id` 的消息
- `last_message`: 基于 `messages` 表查询最后一条消息（按 `created_at DESC` 排序）
- 建议使用物化视图或缓存优化性能

#### 4.1.2 获取任务聊天消息

```
GET /api/messages/task/{task_id}
```

**功能：** 获取指定任务的所有聊天消息（仅消息，不包含申请信息）

**查询参数：**
- `limit`: 每页数量（默认20，最大100）
- `cursor`: 游标（基于 `created_at,id`，用于分页）
  - **格式：** `{ISO8601-UTC}_{id}`，例如：`"2024-01-01T12:00:00Z_123"`
  - **时区约定（重要）：** 
    - 后端一律输出 UTC ISO8601（带 Z）
    - 客户端请求里的 cursor 也必须是 UTC 格式
    - 统一使用 UTC 格式，避免不同时区环境出现"翻页重复/缺页"
  - 首次请求不传，返回最新消息（首屏）
  - 后续请求使用返回的 `next_cursor` 获取更旧的消息

**排序规则（固定）：**
- **排序固定：** `ORDER BY created_at DESC, id DESC`（最新→更旧）
- **排序键：** 以 `created_at DESC, id DESC` 作为稳定排序键
- 首屏返回最新的消息
- `next_cursor` = 本页最后一条（最旧）消息的 `{created_at}_{id}`
- 索引：`(task_id, created_at DESC, id DESC)` 支持此排序

**权限检查：**
- 必须是任务的参与者（发布者或接受者）
- 如果用户不是参与者，返回 403 Forbidden
- **权限一致性：** 对历史消息（`task_id` 为空）在查询层做显式排除，避免"旧全局消息"被混入任务频道
  - 查询条件：`WHERE task_id = ? AND conversation_type = 'task'`
  - 确保只返回任务相关的消息

**返回数据：**
```json
{
  "messages": [
    {
      "id": 1,
      "sender_id": "U1234567",
      "sender_name": "用户名",  // 从 users 表 JOIN 得到
      "sender_avatar": "头像URL",  // 从 users 表 JOIN 得到
      "content": "消息内容",
      "message_type": "normal",
      "task_id": 123,
      "created_at": "2024-01-01T12:00:00Z",
      "is_read": false,  // 基于 message_reads 表查询当前用户是否已读
      "attachments": [  // 从 message_attachments 表 JOIN 得到
        {
          "id": 1,
          "attachment_type": "image",
          "url": "https://example.com/image.jpg",
          "meta": {
            "filename": "image.jpg",
            "size": 1024000,
            "mime_type": "image/jpeg"
          }
        }
      ]
    }
  ],
  "task": {
    "id": 123,
    "title": "任务标题",
    "task_type": "delivery",
    "images": ["url1"],
    "poster_id": "U1234567",
    "taker_id": null,
    "status": "open",
    "base_reward": 100.00,
    "agreed_reward": null,
    "currency": "GBP"
  },
  "next_cursor": "2024-01-01T11:00:00Z_100",  // 用于下一页请求
  "has_more": true  // 是否还有更多消息
}
```

**说明：**
- `messages`: 普通消息列表（只包含 `message_type = "normal"` 或 `"system"` 的消息）
- `sender_name` 和 `sender_avatar` 通过 JOIN `users` 表得到
- `is_read` 基于 `message_reads` 表查询当前用户是否已读
- `attachments` 通过 JOIN `message_attachments` 表得到
- **未读数口径（统一）：** `is_read`/未读数统一口径：排除 `sender_id = current_user_id` 的消息，与列表接口保持一致
- **游标分页规范：** 详细规范请参考查询参数和排序规则部分（格式：`{ISO8601-UTC}_{id}`，排序：`ORDER BY created_at DESC, id DESC`，时区：UTC）
- 使用游标分页，基于 `(task_id, created_at DESC, id DESC)` 复合索引

#### 4.1.3 获取任务申请列表

```
GET /api/tasks/{task_id}/applications
```

**功能：** 获取任务的所有申请（独立接口，用于申请卡片区）

**查询参数：**
- `status`: 申请状态过滤（`pending`/`approved`/`rejected`，默认 `pending`）
- `limit`: 每页数量（默认20）
- `offset`: 偏移量（默认0）

**权限检查：**
- **发布者：** 可以看到所有状态的申请
- **申请者：** 只能看到自己的申请（后端自动过滤）
- **其他用户：** 返回 403 Forbidden

**返回数据：**
```json
{
  "applications": [
    {
      "id": 456,
      "applicant_id": "U7654321",
      "applicant_name": "申请者名字",  // 从 users 表 JOIN 得到
      "applicant_avatar": "头像URL",  // 从 users 表 JOIN 得到
      "message": "申请留言",
      "negotiated_price": 150.00,  // DECIMAL类型
      "currency": "GBP",
      "status": "pending",
      "created_at": "2024-01-01T11:00:00Z"
    }
  ],
  "total": 5,
  "limit": 20,
  "offset": 0
}
```

**说明：**
- 申请信息从 `TaskApplication` 表实时查询（唯一真相源）
- 后端根据用户角色自动过滤（发布者看全部，申请者只看自己的）

#### 4.1.4 发送任务消息

```
POST /api/messages/task/{task_id}/send
```

**功能：** 在任务聊天框中发送消息

**请求体：**
```json
{
  "content": "消息内容",
  "meta": {  // 可选，JSON 格式存储元数据（如 is_prestart_note 等）
    "is_prestart_note": true
  },
  "attachments": [  // 附件数组（支持多图/文件）
    {
      "attachment_type": "image",
      "blob_id": "图片ID",  // 或 "url": "https://..."
      "meta": {
        "filename": "image.jpg",
        "size": 1024000,
        "mime_type": "image/jpeg"
      }
    }
  ]
}
```

**请求体验证：**
- `meta` 字段（如果提供）：
  - 必须是合法 JSON 格式
  - 最大大小：4KB
  - 超限或格式错误返回 `422 Unprocessable Entity`

**权限检查：**
- 必须是任务的参与者（发布者或接受者）
- 如果用户不是参与者，返回 403 Forbidden
- 任务状态检查：
  - 如果 `status = "in_progress"` 或 `taker_id` 不为空：可以发送普通消息
  - 如果 `status = "open"` 且用户是发布者：可以发送说明类消息
    - **频率限制：** 最多 1 条/分钟，日上限 20 条
    - 超限返回 `429 Too Many Requests`
    - 消息表 `meta` 字段中标记 `is_prestart_note: true` 便于审计
  - 如果 `status = "open"` 且用户是申请者：返回 403 Forbidden（不能发送消息）

**附件限制：**
- 最大单文件大小：10MB
- 最大总大小（所有附件）：50MB
- 允许的 MIME 类型：
  - 图片：`image/jpeg`, `image/png`, `image/gif`, `image/webp`
  - 文档：`application/pdf`
  - 其他类型需要后端配置白名单
- 文件需要经过病毒扫描和敏感内容审查
- 超限或审查失败返回：
  - `413 Payload Too Large`: 单文件 >10MB 或 所有附件总大小 >50MB（统一：单文件 >10MB 或 总大小 >50MB 都返回 413）
  - `422 Unprocessable Entity`: MIME 类型不允许或内容审查失败

**错误码：**
- `413 Payload Too Large`: 单文件大小超过 10MB 或所有附件总大小超过 50MB（统一：单文件 >10MB 或 总大小 >50MB 都返回 413）
- `422 Unprocessable Entity`: 
  - MIME 类型不允许或内容审查失败
  - `meta` 字段格式错误（非法 JSON）或超限（>4KB）

**返回数据：**
```json
{
  "id": 123,
  "sender_id": "U1234567",
  "content": "消息内容",
  "task_id": 456,
  "created_at": "2024-01-01T12:00:00Z",
  "attachments": []  // 附件数组，如果没有附件则为空数组
}
```

#### 4.1.5 标记消息已读

```
POST /api/messages/task/{task_id}/read
```

**功能：** 批量标记消息为已读

**权限检查：**
- 必须是任务的参与者（发布者或接受者）
- 如果用户不是参与者，返回 403 Forbidden

**重要：** 所有已读标记操作统一排除 `sender_id = current_user_id` 的消息，与列表页未读数口径完全一致。

**请求体（二选一）：**
```json
{
  "upto_message_id": 123  // 标记到指定消息ID为止的所有消息为已读
}
```
或
```json
{
  "message_ids": [100, 101, 102, 123]  // 标记指定消息ID列表为已读
}
```

**功能：**
1. 如果使用 `upto_message_id`：
   - **防止与排序键不一致：** 服务端先查出 `upto_message_id` 对应的 `(created_at, id)`
   - 然后按 `(created_at < cutoff_created_at) OR (created_at = cutoff_created_at AND id <= cutoff_id)` 来批量标记
   - **同时排除自己发送的消息：** `sender_id <> current_user_id`
   - 批量写入 `message_reads` 表（忽略已存在的记录）
   - **注意：** 如果 ID 与时间不完全单调（跨分片或批量导入），仅按 `id <= upto_message_id` 可能与"到某条为止"的视觉含义不一致，因此需要结合 `created_at` 判断
2. 如果使用 `message_ids`：
   - 标记指定消息ID列表为已读
   - **同时排除自己发送的消息：** `sender_id <> current_user_id`
   - 批量写入 `message_reads` 表（忽略已存在的记录）
3. 幂等性：如果消息已标记为已读，直接跳过（不报错）

**返回数据：**
```json
{
  "marked_count": 5,  // 本次标记的消息数量
  "task_id": 456
}
```

**错误码：**
- `400 Bad Request`: 请求体格式错误（必须提供 `upto_message_id` 或 `message_ids` 之一）
- `403 Forbidden`: 无权限标记该任务的消息
- `404 Not Found`: 任务不存在

### 4.2 申请相关接口

#### 4.2.1 申请任务（修改现有接口）

```
POST /api/tasks/{task_id}/apply
```

**请求体：**
```json
{
  "message": "申请留言（可选）",
  "negotiated_price": 150.0  // 议价价格（可选）
}
```

**权限检查：**
- 检查用户是否已申请过此任务（通过 `TaskApplication` 表查询）
- 如果已存在申请记录（无论状态），返回 400 Bad Request（数据库唯一约束也会阻止）
- 检查任务状态：`status` 必须为 `"open"`，如果为 `"in_progress"` 或其他状态，返回 400 Bad Request
- **校验货币一致性：** 如果请求中包含 `currency`，必须与任务的 `currency` 一致，否则返回 400 Bad Request

**功能：**
1. 创建 `TaskApplication` 记录（唯一真相源）
2. 如果选择了议价，设置 `negotiated_price`（DECIMAL类型）
3. **不在 Message 表中创建申请消息**（申请信息从 TaskApplication 表实时查询）
4. 可选：创建系统消息（`message_type = "system"`）通知申请创建
5. 发送通知给发布者

**错误码：**
- `400 Bad Request`: 已申请过此任务 / 任务状态不允许申请
- `403 Forbidden`: 无权限申请
- `404 Not Found`: 任务不存在

#### 4.2.2 接受申请

```
POST /api/tasks/{task_id}/applications/{application_id}/accept
```

**权限检查：**
- 必须是任务发布者
- 如果用户不是发布者，返回 403 Forbidden
- 验证申请是否存在且属于该任务
- 如果申请不存在，返回 404 Not Found

**功能：**
1. 使用数据库事务 + `SELECT ... FOR UPDATE` 锁定任务行（防止并发）
2. 检查任务是否还有名额（`Task.taker_id` 是否为空）
3. 如果 `taker_id` 不为空，返回 400 Bad Request（任务已被接受）
4. 幂等性：如果再次接受同一申请（`TaskApplication.status = "approved"`），直接返回成功
5. 更新 `Task.taker_id` 为申请者的ID
6. 如果申请包含议价（`negotiated_price` 不为空）：
   - 更新任务的 `agreed_reward` 字段（不覆盖 `base_reward`）
   - **注意：** 不更新 `reward` 字段，前端显示统一使用：`display_reward = agreed_reward ?? base_reward`
7. 更新 `TaskApplication.status = "approved"`
8. 更新任务 `status = "in_progress"`
9. 自动拒绝所有其他待处理的申请（`TaskApplication.status = "rejected"`）
10. 发送通知给申请者

**错误码：**
- `400 Bad Request`: 任务已被接受 / 申请状态不允许接受
- `403 Forbidden`: 无权限接受申请
- `404 Not Found`: 任务或申请不存在
- `409 Conflict`: 并发冲突（理论上不应发生，因为使用了锁）

#### 4.2.3 拒绝申请

```
POST /api/tasks/{task_id}/applications/{application_id}/reject
```

**权限检查：**
- 必须是任务发布者
- 如果用户不是发布者，返回 403 Forbidden
- 验证申请是否存在且属于该任务
- 如果申请不存在，返回 404 Not Found

**功能：**
1. 更新 `TaskApplication.status = "rejected"`
2. 发送通知给申请者
3. 申请者在"我的任务"页面看不到此任务
4. 申请者不能再次申请此任务（数据库唯一约束保证）

**错误码：**
- `403 Forbidden`: 无权限拒绝申请
- `404 Not Found`: 任务或申请不存在

#### 4.2.4 撤回申请

```
POST /api/tasks/{task_id}/applications/{application_id}/withdraw
```

**功能：** 申请者主动撤回自己的申请

**权限检查：**
- 必须是申请者本人
- 如果用户不是申请者，返回 403 Forbidden
- 验证申请是否存在且属于该任务
- 如果申请不存在，返回 404 Not Found
- 申请状态必须为 `pending`，如果已接受或已拒绝，返回 400 Bad Request

**功能：**
1. 更新 `TaskApplication.status = "rejected"`（标记为已拒绝，等同于撤回）
2. **写入操作日志（可选增强）：** 在 `negotiation_response_logs` 表中记录操作
   - `action = "withdraw"`
   - `user_id`: 当前用户ID（申请者）
   - **审计区分（重要）：** 报表/埋点以 `negotiation_response_logs.action` 为准区分 `withdraw` 与 `reject`，避免数据分析混淆
   - 便于审计区分"撤回"和"被发布者拒绝"
   - **注意：** 如果未来要按状态渲染不同 UI，再考虑引入 `withdrawn` 状态
3. 发送通知给发布者（可选）
4. 申请者在"我的任务"页面看不到此任务
5. 申请者不能再次申请此任务（数据库唯一约束保证）

**审计说明：**
- **报表/埋点口径：** 报表/埋点一律以 `negotiation_response_logs.action` 区分 `withdraw` 与 `reject`，避免数据分析混淆
- 虽然状态都落在 `rejected`，但通过 `action` 字段可以准确区分"撤回"和"被发布者拒绝"

**返回数据：**
```json
{
  "application_id": 123,
  "status": "rejected",
  "withdrawn_at": "2024-01-01T12:00:00Z"
}
```

**错误码：**
- `400 Bad Request`: 申请状态不允许撤回（已接受或已拒绝）
- `403 Forbidden`: 无权限撤回申请（不是申请者本人）
- `404 Not Found`: 任务或申请不存在

#### 4.2.5 再次议价

```
POST /api/tasks/{task_id}/applications/{application_id}/negotiate
```

**请求体：**
```json
{
  "negotiated_price": 200.0,
  "message": "发布者的留言（可选）"
}
```

**权限检查：**
- 必须是任务发布者
- 如果用户不是发布者，返回 403 Forbidden
- 验证申请是否存在且属于该任务
- 如果申请不存在，返回 404 Not Found

**功能：**
1. 更新 `TaskApplication.negotiated_price`（DECIMAL类型）
2. **校验货币一致性：** 如果申请包含 `currency`，必须与任务的 `currency` 一致，否则返回 400 Bad Request
3. **生成两枚一次性签名 token（动作级）：**
   - 生成 `token_accept`（绑定用户+动作accept+申请ID+时间戳，有效期5分钟）
   - 生成 `token_reject`（绑定用户+动作reject+申请ID+时间戳，有效期5分钟）
4. **Token 存储（Redis）：**
   - **键名前缀：** 统一使用 `negotiation_token:{token}`，避免与其他模块冲突
   - 存储在 Redis 中，key 格式：
     - `negotiation_token:{token_accept}` → `{"user_id": "...", "action": "accept", "application_id": 123, "task_id": 456, "notification_id": 789, "nonce": "...", "exp": 1234567890, "expires_at": "..."}`
     - `negotiation_token:{token_reject}` → `{"user_id": "...", "action": "reject", "application_id": 123, "task_id": 456, "notification_id": 789, "nonce": "...", "exp": 1234567890, "expires_at": "..."}`
   - **Payload 建议：** 包含 `nonce`（随机数，防重放）与 `exp`（过期时间戳，虽然有 TTL，但 `exp` 便于服务端二次校验与审计回放）
   - 设置过期时间：5分钟（TTL：`EX 300`）
   - **原子消费：** 使用 `GETDEL`（Redis 6.2+）或 Lua 脚本一次性"取值+删除"，比"GET 后再 DEL"更原子，避免并发穿插
5. 创建系统通知（`Notification`）发送给申请者
   - `type = "negotiation_offer"`
   - `related_id = application_id`
   - `content` 包含 JSON 格式的通知数据（任务标题、议价价格、留言等）
6. 通知包含两个按钮：
   - "同意"按钮（携带 `token_accept`）
   - "拒绝"按钮（携带 `token_reject`）

**错误码：**
- `403 Forbidden`: 无权限发起议价
- `404 Not Found`: 任务或申请不存在

#### 4.2.6 处理再次议价（同意/拒绝）

```
POST /api/tasks/{task_id}/applications/{application_id}/respond-negotiation
```

**请求体：**
```json
{
  "action": "accept",  // 或 "reject"
  "token": "一次性签名token"  // 从通知链接中获取，用于防重放
}
```

**权限检查：**
- **Token 校验（Redis）：**
  - 使用 `GETDEL`（Redis 6.2+）或 Lua 脚本一次性"取值+删除"原子操作，比"GET 后再 DEL"更原子，避免并发穿插
  - 如果不存在，返回 403 Forbidden（token 无效或已使用）
  - 如果存在但已过期（Redis TTL 已过期），返回 403 Forbidden
  - **命中后校验：** 验证 token payload 中的 `exp`、`user_id`、`action`、`task_id`、`application_id` 是否匹配
  - 验证 token 绑定的用户ID是否匹配当前用户
  - 验证 token 绑定的申请ID和任务ID是否匹配请求参数
  - 验证 token 绑定的 action 是否匹配请求的 action
  - **二次校验权限：** 验证当前登录用户对该申请是否仍有权限（防止跨用户转发点击）
    - 申请者只能操作自己的申请
    - 如果申请状态已变更（如已被接受），返回 400 Bad Request
- **Token 侧限流/节流：**
  - 对"同一通知"在接口层再加幂等键（Idempotency-Key）或按 `(application_id, action)` 单窗口限次
  - 提升抗抖动能力，防止重复请求

**错误码（结构化响应）：**
- 除 HTTP 状态外，建议返回结构化错误信息：
```json
{
  "code": "APPLICATION_ALREADY_ACCEPTED",  // 业务错误码
  "message": "申请已被接受",  // 错误消息
  "details": {  // 详细信息（可选）
    "application_id": 123,
    "accepted_at": "2024-01-01T12:00:00Z"
  }
}
```
- 方便前端 i18n 与灰度埋点
- HTTP 状态码：
  - `400 Bad Request`: 申请状态已变更（如已被接受或拒绝），不允许操作
  - `403 Forbidden`: token 无效、已使用、过期或权限不足
  - `404 Not Found`: 任务或申请不存在

**功能：**
- 如果 `action = "accept"`：
  1. **业务操作（数据库事务）：**
     - 使用事务 + `SELECT ... FOR UPDATE` 锁定任务行
     - 检查任务是否还有名额（`Task.taker_id` 是否为空）
     - 如果 `taker_id` 不为空，返回明确错误码（任务已被接受）
     - 幂等性：如果再次接受同一申请（`TaskApplication.status = "approved"`），直接返回成功
     - 更新 `Task.taker_id` 为申请者的ID
     - 更新任务的 `agreed_reward` 字段为议价价格（不覆盖 `base_reward`）
     - 更新 `TaskApplication.status = "approved"`
     - 更新任务 `status = "in_progress"`
     - 自动拒绝所有其他待处理的申请
     - **写入操作日志：** 在 `negotiation_response_logs` 表中记录操作
       - `notification_id`: 从 token 中获取关联的通知ID（如果 token 中包含）
       - `task_id`: 任务ID
       - `application_id`: 申请ID
       - `user_id`: 当前用户ID
       - `action`: "accept"
       - `negotiated_price`: 议价价格
       - `responded_at`: 当前时间
  2. **Token 消费（Redis）：**
     - 从 Redis 删除 token：`DEL negotiation_token:{token}`（一次性消费，防重放）
  3. 发送通知给发布者
- 如果 `action = "reject"`：
  1. **业务操作（数据库事务）：**
     - 更新 `TaskApplication.status = "rejected"`
     - **写入操作日志：** 在 `negotiation_response_logs` 表中记录操作
       - `notification_id`: 从 token 中获取关联的通知ID（如果 token 中包含）
       - `task_id`: 任务ID
       - `application_id`: 申请ID
       - `user_id`: 当前用户ID
       - `action`: "reject"
       - `responded_at`: 当前时间
  2. **Token 消费（Redis）：**
     - 从 Redis 删除 token：`DEL negotiation_token:{token}`（一次性消费，防重放）
  3. 发送通知给发布者
  4. 申请者在"我的任务"页面看不到此任务
  5. 申请者不能再次申请此任务（数据库唯一约束保证）

### 4.3 任务相关接口修改

#### 4.3.1 创建任务（修改现有接口）

```
POST /api/tasks
```

**请求体：**
```json
{
  // 现有字段保持不变
}
```

**功能：**
- 创建单人任务，使用 `Task.taker_id` 存储接受者

#### 4.3.2 获取任务详情（修改现有接口）

```
GET /api/tasks/{task_id}
```

**返回数据新增字段：**
```json
{
  "taker_id": "U1234567",  // 接受者ID（如果有）
  "taker": {  // 接受者信息（如果有）
    "id": "U1234567",
    "name": "用户名",
    "avatar": "头像URL"
  },
  "can_apply": true,  // 是否可以申请（检查是否已申请或被拒绝）
  "application_status": "pending"  // 申请状态（如果有申请）
}
```

#### 4.3.3 获取任务申请列表

**注意：** 此接口与 4.1.3 节相同，请参考 [4.1.3 获取任务申请列表](#413-获取任务申请列表)。

## 五、前端实现

### 5.1 聊天页面改造

#### 5.1.1 左侧任务列表

- 替换原有的联系人列表
- 显示所有与当前用户相关的任务
- 每个任务项显示：
  - 任务图片（或默认类型图片）
  - 任务标题
  - 未读消息数（如果有）
  - 最后消息时间
  - 任务状态标识（进行中/待处理申请等）

#### 5.1.2 聊天框顶部

- 显示任务信息：
  - 任务图片（或默认类型图片）
  - 任务标题
  - 任务状态（可选）

#### 5.1.3 消息列表

- **普通消息：**
  - 显示发送者头像和名字（从 `users` 表 JOIN 得到）
  - 点击头像跳转到用户主页
  - 显示消息内容和时间
  - 显示消息附件（如果有）
  - 显示已读状态（基于 `message_reads` 表）
  - 需要让所有人知道此消息是谁发布的（显示发送者信息）
- **申请卡片区（独立于消息流）：**
  - 从 `TaskApplication` 表实时查询（唯一真相源）
  - 显示所有待处理的申请（`status = "pending"`）
  - 每个申请显示：
    - 申请者头像和名字
    - 申请留言
    - 议价价格（如果有，DECIMAL类型）
    - 申请时间
    - 发布者可以看到"接受"和"拒绝"按钮
  - 权限过滤：
    - 发布者：可以看到所有待处理的申请
    - 申请者：只能看到自己的待处理申请

#### 5.1.4 输入框权限控制

- **任务未开始（`status = "open"` 且 `taker_id` 为空）：**
  - **发布者：** 可以发送说明类消息（用于需求澄清，但限制频率）
  - **申请者：** 禁用输入框，显示提示："任务开始后才能发送消息"
- **任务进行中（`status = "in_progress"` 或 `taker_id` 不为空）：**
  - 所有参与者可以正常发送消息

### 5.2 申请弹窗

- 申请留言输入框（可选）
- 议价选项：
  - 复选框："我想议价"
  - 如果选中，显示价格输入框
- 默认申请按钮
- 提交按钮

### 5.3 任务详情页修改

**任务详情内容显示：**
- 显示任务描述
- 显示任务金额

**操作按钮：**
- **发布者：**
  - 如果任务还没有接受者（`taker_id` 为空），显示"查看申请"按钮（点击后弹出申请列表弹窗）
  - 如果任务已有接受者（`taker_id` 不为空），显示"进行中"状态
- **申请者：**
  - 如果已申请且状态为 `pending`，不显示"申请任务"按钮，显示"已申请"状态
  - 如果申请被拒绝，不显示"申请任务"按钮，显示"申请已拒绝"状态
  - 如果申请被接受（`Task.taker_id` 匹配），显示"进行中"状态
- **其他用户：**
  - 如果任务还没有接受者（`taker_id` 为空），显示"申请任务"按钮
  - 如果任务已有接受者（`taker_id` 不为空），显示"已被接受"状态

### 5.5 申请列表弹窗

- 显示所有待处理的申请
- 每个申请显示：
  - 申请者头像和名字
  - 申请留言
  - 议价价格（如果有）
  - 申请时间
  - "接受"和"拒绝"按钮
- 点击"接受"或"拒绝"后，直接执行操作并更新列表

### 5.4 通知中心

- 显示再次议价通知
- 通知中包含：
  - 任务标题
  - 新的议价价格（DECIMAL类型）
  - 申请者之前的留言
  - 发布者的留言
  - "同意"和"拒绝"按钮（分别携带 `token_accept` 和 `token_reject`，点击后直接执行操作，无需跳转）
- **安全要求（重要，请严格遵守）：**
  - **⚠️ 严禁使用 GET 请求，按钮操作必须使用 POST 请求，token 放在请求体中，避免 token 泄露到 URL/Referer/日志**
  - **CSRF 防护：** 同时别忘了同源策略/CSRF token（或 SameSite Cookie）以防"带着有效会话+外站诱导点击"的情况
  - 处理接口要二次校验当前登录用户是否为申请者本人，且申请仍处于允许状态
- 按钮点击后：
  - **Token 校验（前端调用接口）：** 后端使用 `GETDEL`（或 Lua 原子 GET+DEL）原子消费 token
  - 如果 token 无效或已使用（Redis 中不存在），显示错误提示
  - 如果 token 过期（Redis TTL 已过期），显示错误提示
  - 如果 token 有效，执行操作：
    - 业务操作写入数据库事务（包括操作日志写入 `negotiation_response_logs` 表）
    - Token 已通过 `GETDEL` 原子删除（一次性消费）

## 六、开发步骤

### 阶段一：数据库改动

**注意：由于数据库可以清除重建，可以直接使用新的表结构，无需考虑数据迁移。**

1. **清空相关表（如需要）：**
   - 在部署前，已通过应用启动时的自动清空功能清空了以下表：
     - `task_applications`
     - `reviews`
     - `task_history`
     - `task_cancel_requests`
     - `messages`
     - `notifications`
     - `tasks`
   - **保留的表：** `users`, `admin_users`, `system_settings`, `pending_users`, `customer_service*`, `admin_*`, `user_preferences`

2. 修改 `Task` 表（添加 `base_reward`、`agreed_reward`、`currency`）
3. 修改 `TaskApplication` 表（添加 `negotiated_price`、`currency`，添加唯一约束）
4. 修改 `Message` 表（添加 `task_id`、`message_type`、`conversation_type`、`meta`）
5. 创建 `Notifications` 表（系统通知，支持审计）
6. 创建 `MessageReads` 表（消息已读状态，外键使用 ON DELETE CASCADE）
7. 创建 `MessageAttachments` 表（消息附件，外键使用 ON DELETE CASCADE）
8. 创建 `NegotiationResponseLog` 表（议价响应操作日志，用于审计）
9. 创建 `MessageReadCursors` 表（默认必开：按任务维度的已读游标，降低写放大）
10. 创建必要的索引（包括游标分页索引）
11. 添加外键删除策略（ON DELETE CASCADE）
12. 添加 CHECK 约束（枚举值限制、任务消息必须关联 task_id 等）

### 阶段二：后端API开发
1. 实现任务聊天列表接口（包含未读计数和最后消息聚合）
2. 实现任务聊天消息接口（游标分页，JOIN用户信息）
3. 实现获取任务申请列表接口（独立接口，权限过滤）
4. 实现发送任务消息接口（支持附件数组）
5. 修改申请任务接口（添加权限检查和错误码）
6. 实现接受/拒绝申请接口（事务锁、幂等性、错误码）
7. 实现撤回申请接口（仅申请者可调用）
8. 实现再次议价接口（生成一次性签名 token）
9. 实现处理再次议价接口（验证 token、防重放、幂等性）
10. 修改任务创建和详情接口（返回价格字段）
11. 实现消息已读标记接口（`POST /api/messages/task/{task_id}/read`）

### 阶段三：业务逻辑实现
1. 实现任务状态判断逻辑（基于 `taker_id` 和 `status`，TaskApplication 仅作为候选）
2. **申请信息存储策略：** 以 TaskApplication 为唯一真相源，不在 Message 表存储
3. 实现接受申请时的并发控制（事务 + SELECT FOR UPDATE）
4. 实现接受申请时的幂等性检查
5. 实现接受申请后的自动拒绝逻辑
6. 实现议价价格处理逻辑（不覆盖 `base_reward`，使用 `agreed_reward`）
7. 实现对话权限控制逻辑（发布者可以发送说明类消息）
8. 实现一次性签名 token 生成和验证逻辑（使用 Redis 存储和校验，不存储在数据库）
9. 实现消息已读状态管理逻辑
10. 实现议价响应操作日志记录逻辑（写入 `negotiation_response_logs` 表，与业务事务一起提交）
11. 实现未读计数聚合逻辑（基于 message_reads 表）
12. 实现说明类消息频率限制逻辑（1条/分钟，日上限20条）

### 阶段四：前端开发
1. 改造聊天页面（任务列表替换联系人列表）
2. 实现申请弹窗
3. 实现申请卡片区（从 TaskApplication 表实时查询，独立于消息流）
4. 实现消息气泡头像显示（显示发送者信息）
5. 实现输入框权限控制（任务未开始时发布者可以发送说明类消息）
6. 修改任务详情页（显示价格字段）
7. 实现通知中心的议价通知显示（携带一次性签名 token）
8. 实现申请列表弹窗（调用独立接口）
9. 实现消息附件显示（支持多图/文件）
10. 实现游标分页（消息列表）
11. 实现消息已读状态显示

### 阶段五：测试和优化
1. 单元测试
2. 集成测试
3. 性能优化
4. 用户体验优化

## 七、技术问题修复说明

根据代码审查反馈，已修复以下技术问题：

### 7.1 申请信息存储策略

**问题：** 申请信息同时存储在 `TaskApplication` 和 `Message` 表中，产生双写一致性风险。

**修复：**
- 以 `TaskApplication` 表为唯一真相源
- 不在 `Message` 表中创建 `message_type = "application"` 的消息
- 聊天框中的申请信息从 `TaskApplication` 表实时查询
- 前端通过独立接口 `GET /api/tasks/{task_id}/applications` 获取申请列表

### 7.2 金额精度问题

**问题：** 使用 `FLOAT` 类型存储金额，存在精度问题。

**修复：**
- `TaskApplication.negotiated_price` 改为 `DECIMAL(12,2)`
- `Task.base_reward` 和 `Task.agreed_reward` 使用 `DECIMAL(12,2)`
- 添加 `currency` 字段（`CHAR(3)`）存储货币类型

### 7.3 接口拆分

**问题：** 消息和申请列表混在一个响应里，分页/权限边界复杂。

**修复：**
- `GET /api/messages/task/{task_id}` 只返回消息（游标分页）
- 新增 `GET /api/tasks/{task_id}/applications` 专门返回申请列表（独立分页）
- 后端根据用户角色自动过滤申请（发布者看全部，申请者只看自己的）


### 7.5 状态判定来源

**问题：** 状态判定来源不一致，有处说"通过 TaskApplication 判定任务状态"。

**修复：**
- 使用 `Task.taker_id` 和 `Task.status` 作为唯一来源判定任务状态
- `TaskApplication` 仅作为候选/历史，不用于主状态判定

### 7.6 议价价格覆盖原价

**问题：** 接受申请时把议价价格写回任务 `reward`，会抹去原价与谈判痕迹。

**修复：**
- 添加 `base_reward` 字段存储原始标价
- 添加 `agreed_reward` 字段存储最终成交价
- 接受议价时，更新 `agreed_reward`，不覆盖 `base_reward`
- **前端显示统一：** `display_reward = agreed_reward ?? base_reward`
- **不再写回 `reward` 字段**（仅保留历史兼容读取，避免三处价格口径分裂）

### 7.7 并发与幂等

**问题：** 接受申请时缺少并发控制和幂等性检查。

**修复：**
- 使用数据库事务 + `SELECT ... FOR UPDATE` 锁定任务行
- 幂等性：如果再次接受同一申请（`status = "approved"`），直接返回成功
- 如果 `taker_id` 不为空，返回明确错误码

### 7.8 消息已读状态

**问题：** `messages.is_read` 设计不合理，缺少按用户维度的已读表。

**修复：**
- 新增 `MessageReads` 表（`message_id`, `user_id`, `read_at`）
- 未读数基于 `message_reads` 表聚合计算
- 每条消息的已读状态按用户维度记录

### 7.9 task_id 关联规则

**问题：** "必须关联"与"客服消息可以为空"相互矛盾。

**修复：**
- 添加 `conversation_type` 字段区分会话类型（`task`/`customer_service`/`global`）
- 任务消息（`conversation_type = "task"`）：`task_id` 必须关联
- 客服消息（`conversation_type = "customer_service"`）：`task_id` 可以为空
- 新消息写入时强校验：任务消息必须有 `task_id`

### 7.10 唯一约束

**问题：** 缺少"一个用户对同一任务只能申请一次"的数据库唯一约束。

**修复：**
- 添加唯一约束：`UNIQUE(task_id, applicant_id)`
- 确保被拒绝后也不能再次申请

### 7.11 已读计数聚合

**问题：** 已读计数/最后消息的聚合口径未定义。

**修复：**
- 未读计数：基于 `message_reads` 表聚合计算
  - **明确口径：** 排除自己发送的消息（`sender_id <> current_user_id`）
  - SQL 逻辑：`COUNT(*) WHERE task_id = ? AND sender_id <> ? AND NOT EXISTS (SELECT 1 FROM message_reads WHERE message_id = messages.id AND user_id = ?)`
- 最后消息：基于 `messages` 表查询（按 `created_at DESC` 排序）
- 建议使用物化视图或缓存优化性能
- 建立相应索引：`(task_id, created_at DESC, id DESC)`

### 7.12 分页规范

**问题：** 分页只给 limit/offset，缺少时间序游标规范。

**修复：**
- 消息列表使用游标分页（详细规范请参考 [4.1.2 获取任务聊天消息](#412-获取任务聊天消息)）
- **排序固定：** `ORDER BY created_at DESC, id DESC`（最新→更旧）
- **游标格式：** `{ISO8601-UTC}_{id}`（如 `2024-01-01T12:00:00Z_123`）
- **时区约定：** 后端一律输出 UTC ISO8601（带 Z），客户端请求里的 cursor 也必须是 UTC 格式
- `next_cursor` = 本页最后一条（最旧）消息的 `{created_at}_{id}`
- 建立复合索引：`(task_id, created_at DESC, id DESC)` 支持此排序

### 7.13 权限规则

**问题：** 权限规则写在说明里，但接口未"硬编码"校验点。

**修复：**
- 每个接口增加"权限检查"小节
- 明确主体、可视范围、失败返回（403/404）
- 后端自动过滤（发布者看全部申请，申请者只看自己的）

### 7.14 通知按钮安全性

**问题：** 通知里的"同意/拒绝按钮直接执行"需要一次性签名与幂等。

**修复：**
- **生成两枚一次性签名 token（动作级）：** 一枚 `action=accept`，一枚 `action=reject`，分别绑定到两个按钮
- **Token 存储与校验：** 使用 Redis 存储和校验 token（不存储在数据库）
  - 存储：`SET negotiation_token:{token_accept} {json_data} EX 300`（5分钟过期）
  - 存储：`SET negotiation_token:{token_reject} {json_data} EX 300`（5分钟过期）
  - value 格式：`{"user_id": "...", "action": "accept" 或 "reject", "application_id": 123, "task_id": 456, "notification_id": 789, "nonce": "...", "exp": 1234567890, "expires_at": "..."}`
  - **Payload 字段统一：** `{user_id, action, application_id, task_id, notification_id, nonce, exp, expires_at}`
  - 校验与消费：使用 `GETDEL`（Redis 6.2+）或 Lua 脚本一次性"取值+删除"，比"GET 后再 DEL"更原子，避免并发穿插
  - 如果不存在或过期，返回 403
- **业务操作记录：** 在 `negotiation_response_logs` 表中记录操作日志
  - 与业务事务一起写入，保证数据一致性
  - 无需专门的 token 表，追溯依赖业务事件
  - 既快（Redis）又有追溯（业务表）
- **安全要求：** 按钮操作必须使用 POST 请求，token 放在请求体中，避免 token 出现在 URL/日志/Referer 中
- **二次校验权限：** 验证当前登录用户对该申请是否仍有权限（防止跨用户转发点击）
- 服务端校验 token、防重放、幂等

### 7.15 消息附件

**问题：** 消息附件模型过于简化，只支持单图。

**修复：**
- 新增 `MessageAttachments` 表（支持多图/文件）
- 发送接口改为 `attachments: []` 数组格式
- 支持多种附件类型（image/file/video等）

### 7.16 未开始阶段禁言

**问题：** 任务未开始阶段完全禁言，影响需求澄清。

**修复：**
- 发布者在未开始阶段可以发送"说明类消息"（用于需求澄清，但限制频率）
  - **频率限制量化：** 最多 1 条/分钟，日上限 20 条
  - 超限返回 `429 Too Many Requests`
  - 消息表 `meta` 字段中标记 `is_prestart_note: true` 便于审计
- 申请者在 pending 阶段仍通过申请卡片沟通，避免骚扰

### 7.17 字段一致性

**问题：** API 响应里大量返回 `sender_name/sender_avatar` 等，这些并非 messages 原表字段。

**修复：**
- 在接口说明中明确：这些字段源自 `users` 表 JOIN
- 确保 `Task.taker_id` 的类型与 `users.id` 对齐（VARCHAR(8)）
- 所有 JOIN 字段在返回数据说明中标注来源

## 八、注意事项

1. **数据库重建说明：**
   - **由于数据库可以清除重建，无需考虑数据迁移和向后兼容**
   - 可以直接使用新的表结构，所有字段都可以设置为 NOT NULL（如适用）
   - `Task.taker_id` 字段继续使用，存储唯一的接受者
   - 客服消息的 `task_id` 可以为空（`conversation_type = "customer_service"`）
   - 全局消息的 `task_id` 可以为空（`conversation_type = "global"`）
   - **ID 类型一致性：** 所有用户ID相关字段（如 `taker_id`, `poster_id`, `applicant_id`, `sender_id`, `user_id`）必须与 `users.id` 的类型完全一致。文档示例使用 `VARCHAR(8)`，实际开发时应确认类型

2. **数据清空说明：**
   - 在部署前，已通过应用启动时的自动清空功能清空了以下表：
     - `task_applications`（任务申请）
     - `reviews`（评价）
     - `task_history`（任务历史）
     - `task_cancel_requests`（任务取消请求）
     - `messages`（消息）
     - `notifications`（通知）
     - `tasks`（任务）
   - **保留的表：** 以下表的数据已保留，未清空：
     - `users`（用户基础信息）
     - `admin_users`（管理员账户）
     - `system_settings`（系统设置）
     - `pending_users`（待验证用户）
     - `customer_service*`（客服相关表）
     - `admin_*`（管理员相关表）
     - `user_preferences`（用户偏好）

3. **权限控制：**
   - 严格检查用户是否有权限查看/操作任务
   - 严格检查任务状态是否允许操作
   - 所有接口都要明确权限检查规则和错误码
   - 申请列表接口后端自动过滤（发布者看全部，申请者只看自己的）

4. **并发控制：**
   - 接受申请接口必须使用事务 + `SELECT ... FOR UPDATE`
   - 所有状态变更操作都要考虑并发安全
   - 实现幂等性检查

5. **安全性：**
   - 通知按钮操作必须使用一次性签名 token
   - **生成两枚 token（动作级）：** 一枚 `action=accept`，一枚 `action=reject`，分别绑定到两个按钮
   - **Token 存储与校验：** 使用 Redis 存储和校验 token（不存储在数据库）
     - 存储：`SET negotiation_token:{token_accept} {json_data} EX 300`（5分钟过期）
     - 存储：`SET negotiation_token:{token_reject} {json_data} EX 300`（5分钟过期）
     - 校验与消费：使用 `GETDEL`（Redis 6.2+）或 Lua 脚本一次性"取值+删除"，比"GET 后再 DEL"更原子，避免并发穿插
     - 如果不存在或过期，返回 403
   - **安全要求：** 按钮操作必须使用 POST 请求，token 放在请求体中，避免 token 出现在 URL/日志/Referer 中
   - **二次校验权限：** 验证当前登录用户对该申请是否仍有权限（防止跨用户转发点击）
   - **业务操作记录：** 在 `negotiation_response_logs` 表中记录操作日志
     - 与业务事务一起写入，保证数据一致性
     - 无需专门的 token 表，追溯依赖业务事件
     - 既快（Redis）又有追溯（业务表）
   - 防重放攻击

6. **性能优化：**
   - 任务聊天列表需要支持分页
   - 消息列表使用游标分页（详细规范请参考 [4.1.2 获取任务聊天消息](#412-获取任务聊天消息)）
   - 未读计数和最后消息建议使用物化视图或缓存
   - 建立必要的索引（包括游标分页索引：`(task_id, created_at DESC, id DESC)`）

7. **数据一致性：**
   - 以 `TaskApplication` 为唯一真相源，不在 `Message` 表存储申请信息
   - 所有金额字段使用 `DECIMAL(12,2)` 避免精度问题
   - 状态判定使用 `Task.taker_id` 和 `Task.status` 作为唯一来源
   - 数据库约束：任务消息必须关联 `task_id`（`CHECK (conversation_type <> 'task' OR task_id IS NOT NULL)`）

8. **未读计数口径：**
   - 明确排除自己发送的消息（`sender_id <> current_user_id`）
   - 避免"我刚发完还显示未读"的尴尬

9. **价格显示策略：**
   - 前端统一使用：`display_reward = agreed_reward ?? base_reward`
   - 不再写回 `reward` 字段（仅保留历史兼容读取）
   - 避免三处价格（base_reward/agreed_reward/reward）的口径分裂

10. **附件安全策略：**
    - 最大单文件：10MB，最大总大小：50MB
    - MIME 白名单：`image/jpeg`, `image/png`, `image/gif`, `image/webp`, `application/pdf`
    - 病毒扫描和敏感内容审查
    - 超限返回 413/422 错误码

11. **外键删除策略：**
    - `message_attachments.message_id` 使用 `ON DELETE CASCADE`
    - `message_reads.message_id` 使用 `ON DELETE CASCADE`
    - 删除消息时自动删除关联的附件和已读记录，避免孤儿记录

12. **任务删除策略：**
    - **建议禁止物理删除任务（或统一使用软删除）**
    - 如果采用软删除：
      - 在 `tasks` 表中添加 `deleted_at` 字段（DATETIME，可为空）
      - 删除任务时设置 `deleted_at = 当前时间`，不物理删除记录
      - **关联数据的可见性策略：**
        - 关联的消息（`messages`）：软删除后，消息对参与者仍可见（历史记录保留）
        - 关联的申请（`task_applications`）：软删除后，申请记录保留（用于审计）
        - 关联的通知（`notifications`）：软删除后，通知保留（用户仍可查看历史通知）
        - 关联的操作日志（`negotiation_response_logs`）：永久保留（审计需要）
    - 如果必须物理删除：
      - 需要级联处理所有关联数据
      - 删除消息、申请、通知、操作日志等所有关联记录
      - **注意：** 物理删除会丢失历史数据，建议仅在特殊场景下使用

13. **说明类消息频率限制：**
    - 发布者在任务未开始阶段发送说明类消息：最多 1 条/分钟，日上限 20 条
    - 超限返回 `429 Too Many Requests`
    - 消息表 `meta` 字段中标记 `is_prestart_note: true` 便于审计

14. **数据库兼容性（重要，避免 DBA 实施时卡住）：**
    - **CHECK 约束：** 如目标引擎不支持 CHECK（老 MySQL），改用应用层校验或触发器
      - 示例：`CHECK (conversation_type <> 'task' OR task_id IS NOT NULL)` 如果不支持，改用应用层校验或触发器实现
    - **降序索引：** 部分引擎/版本对降序索引支持不一，兼容写法：
      - 如果不支持降序索引，就建 `(task_id, created_at, id)` 联合索引
      - 查询使用 `ORDER BY created_at DESC, id DESC` 也可被同一索引覆盖
      - 多数引擎可用同一索引覆盖，无需专门的降序索引

15. **货币一致性：**
    - 申请/议价时，`TaskApplication.currency` 必须与 `Task.currency` 一致
    - 接口层必须校验，必要时在 DB 层用触发器或应用层强校验
    - 不一致时返回 400 Bad Request

16. **金额与币种处理（未来扩展）：**
    - 若未来存在 JPY/零小数或更细分币种，`DECIMAL(12,2)` 会与显示位数有落差
    - **建议：** 保留现状同时在服务层统一"最小货币单位换算"能力
    - 内部仍 `DECIMAL(12,2)` 存，出入参按币种转换（如 JPY 按最小单位存储，显示时除以100）
    - 避免大改，便于后续扩展

17. **撤回申请与拒绝申请的区分：**
    - 当前"撤回"和"被拒绝"都使用 `status = "rejected"`
    - 建议在 `negotiation_response_logs` 表中通过 `action = "withdraw"` 记录撤回操作，便于审计区分
    - **报表/埋点以 `negotiation_response_logs.action` 为准区分 `withdraw` 与 `reject`**
    - 或考虑新增 `withdrawn` 状态（可选增强）

17. **Token 安全细节：**
    - 通知里的"同意/拒绝"按钮应走 POST，token 放请求体，避免 token 出现在 URL/日志/Referer 中
    - 校验时除 user_id/action/task_id/application_id 外，再二次校验"当前登录用户对该申请是否仍有权限"，防止跨用户转发点击
    - 使用 `GETDEL`（Redis 6.2+）或 Lua 脚本一次性"取值+删除"，比"GET 后再 DEL"更原子，避免并发穿插

18. **业务边界与后续可扩展：**
    - **多承接者（capacity）演进位：** 当前单人任务（`taker_id`）在未来扩展为多承接者会牵动较多逻辑
      - 建议提前把"是否支持多承载"的领域开关与数据位（如 `capacity`）在模型层预留（不必立即启用）
      - 例如：`tasks` 表可预留 `capacity INTEGER DEFAULT 1` 字段，当前固定为 1
    - **任务重开/取消：** 当任务从 `in_progress` 回退为 `open`（取消或失败重开）时，申请可见性与历史消息如何处理要定口径
      - 例如：清退申请历史、禁止被拒者再次申请等规则是否保持
      - 建议：保留历史申请记录（用于审计），但允许被拒者重新申请（业务规则可配置）

## 九、已确认问题

1. ✅ Task.taker_id 用于单人任务，存储唯一的接受者
2. ✅ 每次接受申请后都检查并更新状态
3. ✅ 使用 `Task.taker_id` 和 `Task.status` 作为唯一来源判定任务状态（TaskApplication 仅作为候选/历史）
4. ✅ 申请信息从 TaskApplication 表实时查询（唯一真相源），如果申请被接受/拒绝，便不再显示
5. ✅ 申请信息需要存储 type, 申请者id, 任务id, 信息, 议价等
6. ✅ "同意"和"拒绝"按钮点击之后直接就有命令反应（同意后直接接收此任务，拒绝则拒绝接收此任务）
7. ✅ task_applications里要有拒绝状态，拒绝则在我的任务看不到此任务则不能再次申请此任务
8. ✅ 弹出申请列表弹窗
9. ✅ 消息显示发送者头像和名字，需要让所有人知道此消息是谁发布的
10. ✅ 历史消息需要关联到任务id
11. ✅ 通知中需要包含再议价的金额和申请者的留言，需要包含"同意"和"拒绝"按钮
12. ✅ 接受申请后，任务状态更新为 in_progress，自动拒绝其它所有申请者，并且此任务会从任务大厅移除

**文档已根据所有确认信息更新完成，可以开始开发。**

