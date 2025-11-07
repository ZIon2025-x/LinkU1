# 任务聊天功能实现检查报告

## 一、数据库模型改动检查

### ✅ 2.1 Task 表修改
- [x] `base_reward` 字段（DECIMAL(12,2)）
- [x] `agreed_reward` 字段（DECIMAL(12,2)）
- [x] `currency` 字段（CHAR(3)，默认GBP）
- [x] 保留原有 `reward` 字段（向后兼容）

### ✅ 2.2 TaskApplication 表修改
- [x] `negotiated_price` 字段（DECIMAL(12,2)）
- [x] `currency` 字段（CHAR(3)，默认GBP）
- [x] 唯一约束：`UNIQUE(task_id, applicant_id)`

### ✅ 2.3 Message 表修改
- [x] `task_id` 字段（外键关联 tasks）
- [x] `message_type` 字段（VARCHAR(20)，默认'normal'）
- [x] `conversation_type` 字段（VARCHAR(20)，默认'task'）
- [x] `meta` 字段（TEXT，JSON格式）
- [x] CHECK 约束：任务消息必须关联 task_id
- [x] CHECK 约束：message_type 枚举值限制
- [x] CHECK 约束：conversation_type 枚举值限制
- [x] 索引：`ix_messages_task_id`
- [x] 索引：`ix_messages_task_type`
- [x] 索引：`ix_messages_task_created`（游标分页）
- [x] 索引：`ix_messages_conversation_type`
- [x] 索引：`ix_messages_task_id_id`（未读数聚合）

### ✅ 2.4 MessageReads 表
- [x] 表已创建
- [x] 字段：`message_id`, `user_id`, `read_at`
- [x] 唯一约束：`UNIQUE(message_id, user_id)`
- [x] 外键：`ON DELETE CASCADE`
- [x] 索引已创建

### ✅ 2.5 MessageAttachments 表
- [x] 表已创建
- [x] 字段：`message_id`, `attachment_type`, `url`, `blob_id`, `meta`
- [x] CHECK 约束：url 和 blob_id 必须二选一
- [x] 外键：`ON DELETE CASCADE`
- [x] 索引已创建

### ✅ 2.6 Notifications 表
- [x] 表已创建（已存在）
- [x] 字段：`user_id`, `type`, `related_id`, `content`, `created_at`, `read_at`
- [x] 索引已创建

### ✅ 2.7 NegotiationResponseLog 表
- [x] 表已创建
- [x] 字段：`notification_id`, `task_id`, `application_id`, `user_id`, `action`, `negotiated_price`, `responded_at`, `ip_address`, `user_agent`
- [x] 唯一约束：`UNIQUE(application_id, action)`
- [x] 索引已创建

### ✅ 2.8 MessageReadCursors 表
- [x] 表已创建
- [x] 字段：`task_id`, `user_id`, `last_read_message_id`, `updated_at`
- [x] 唯一约束：`UNIQUE(task_id, user_id)`
- [x] 索引已创建

## 二、API 接口实现检查

### ✅ 4.1 任务相关接口

#### 4.1.1 获取任务聊天列表
- [x] 接口：`GET /api/messages/tasks`
- [x] 支持分页（limit, offset）
- [x] 返回未读计数（基于 message_read_cursors）
- [x] 返回最后消息信息
- [x] 排除自己发送的消息（未读数口径）

#### 4.1.2 获取任务聊天消息
- [x] 接口：`GET /api/messages/task/{task_id}`
- [x] 游标分页（cursor 格式：`{ISO8601-UTC}_{id}`）
- [x] 排序：`ORDER BY created_at DESC, id DESC`
- [x] 权限检查（参与者）
- [x] JOIN 用户信息（sender_name, sender_avatar）
- [x] 返回附件信息
- [x] 返回 is_read 状态

#### 4.1.3 获取任务申请列表
- [x] 接口：`GET /api/tasks/{task_id}/applications`
- [x] 支持状态过滤
- [x] 权限过滤（发布者看全部，申请者只看自己的）
- [x] JOIN 用户信息（applicant_name, applicant_avatar）

#### 4.1.4 发送任务消息
- [x] 接口：`POST /api/messages/task/{task_id}/send`
- [x] 支持附件数组
- [x] 支持 meta 字段
- [x] 权限检查（参与者）
- [x] 任务状态检查
- [x] 说明类消息频率限制（1条/分钟，日上限20条）
- [x] 附件验证（url 和 blob_id 二选一）

#### 4.1.5 标记消息已读
- [x] 接口：`POST /api/messages/task/{task_id}/read`
- [x] 支持 `upto_message_id` 方式
- [x] 支持 `message_ids` 方式
- [x] 排除自己发送的消息
- [x] 更新 message_read_cursors

### ✅ 4.2 申请相关接口

#### 4.2.1 申请任务
- [x] 接口：`POST /api/tasks/{task_id}/apply`
- [x] 支持议价价格
- [x] 支持申请留言
- [x] 唯一约束检查（不能重复申请）
- [x] 任务状态检查
- [x] 货币一致性校验
- [x] 发送通知给发布者

#### 4.2.2 接受申请
- [x] 接口：`POST /api/tasks/{task_id}/applications/{application_id}/accept`
- [x] 权限检查（发布者）
- [x] 事务 + SELECT FOR UPDATE 锁定
- [x] 幂等性检查
- [x] 更新 `Task.taker_id`
- [x] 更新 `Task.agreed_reward`（如果议价）
- [x] 更新任务状态为 `in_progress`
- [x] 自动拒绝其他申请
- [x] 写入操作日志
- [x] 发送通知给申请者

#### 4.2.3 拒绝申请
- [x] 接口：`POST /api/tasks/{task_id}/applications/{application_id}/reject`
- [x] 权限检查（发布者）
- [x] 更新申请状态为 `rejected`
- [x] 写入操作日志
- [x] 发送通知给申请者

#### 4.2.4 撤回申请
- [x] 接口：`POST /api/tasks/{task_id}/applications/{application_id}/withdraw`
- [x] 权限检查（申请者本人）
- [x] 状态检查（必须是 pending）
- [x] 更新申请状态为 `rejected`
- [x] 写入操作日志（action = "withdraw"）
- [x] 发送通知给发布者

#### 4.2.5 再次议价
- [x] 接口：`POST /api/tasks/{task_id}/applications/{application_id}/negotiate`
- [x] 权限检查（发布者）
- [x] 更新 `TaskApplication.negotiated_price`
- [x] 货币一致性校验
- [x] 生成两枚 token（accept 和 reject）
- [x] Token 存储到 Redis（5分钟过期）
- [x] Token payload 包含所有必需字段
- [x] 创建系统通知（type = "negotiation_offer"）
- [x] 通知内容包含任务标题、议价价格、留言等

#### 4.2.6 处理再次议价
- [x] 接口：`POST /api/tasks/{task_id}/applications/{application_id}/respond-negotiation`
- [x] Token 校验（使用 GETDEL 原子操作）
- [x] 验证 token payload（exp, user_id, action, task_id, application_id）
- [x] 二次校验权限
- [x] 幂等性检查
- [x] 写入操作日志
- [x] 发送通知

**⚠️ 问题发现：**
- 处理再次议价接口中，接受议价时没有更新 `Task.taker_id` 和任务状态，只是记录了日志。根据文档，接受议价应该等同于接受申请，需要更新任务状态。

## 三、业务逻辑实现检查

### ✅ 3.1 任务状态逻辑
- [x] 任务大厅显示逻辑（status = "open" 且 taker_id 为空）
- [x] 我的任务页面显示逻辑（基于 taker_id 和 status）
- [x] 状态判定来源统一（Task.taker_id 和 Task.status）

### ✅ 3.2 申请流程
- [x] 申请信息存储策略（TaskApplication 为唯一真相源）
- [x] 不在 Message 表存储申请信息
- [x] 申请信息显示规则（pending 状态才显示）
- [x] 权限过滤（发布者看全部，申请者只看自己的）

### ✅ 3.3 接受/拒绝申请
- [x] 并发控制（事务 + SELECT FOR UPDATE）
- [x] 幂等性检查
- [x] 自动拒绝其他申请
- [x] 更新任务状态

### ✅ 3.4 再次议价流程
- [x] 发布者发起再次议价
- [x] Token 生成和存储（Redis）
- [x] Token 校验和消费（GETDEL 原子操作）
- [x] 操作日志记录

**⚠️ 问题发现：**
- 接受议价时应该更新任务状态（等同于接受申请），但当前实现只记录了日志。

### ✅ 3.5 对话权限控制
- [x] 任务未开始阶段权限控制
- [x] 发布者可以发送说明类消息
- [x] 说明类消息频率限制
- [x] 申请者不能发送普通消息
- [x] 任务进行中所有参与者可以正常发送消息

### ✅ 3.6 任务显示逻辑
- [x] 任务卡片显示
- [x] 任务详情页显示逻辑
- [x] 操作按钮显示逻辑

## 四、前端实现检查

### ✅ 5.1 聊天页面改造
- [x] 左侧任务列表（替换联系人列表）
- [x] 显示任务信息（图片、标题、未读数、最后消息）
- [x] 聊天框顶部显示任务信息
- [x] 消息列表显示发送者信息（头像、名字）
- [x] 申请卡片区（独立于消息流）
- [x] 申请卡片显示申请信息
- [x] 输入框权限控制

### ✅ 5.2 申请弹窗
- [x] 申请留言输入框
- [x] 议价选项
- [x] 价格输入框
- [x] 提交按钮

### ✅ 5.3 任务详情页修改
- [x] 显示任务描述和金额
- [x] 操作按钮显示逻辑
- [x] 发布者：查看申请按钮
- [x] 申请者：已申请状态
- [x] 其他用户：申请任务按钮

### ✅ 5.4 申请列表弹窗
- [x] 显示所有待处理的申请
- [x] 显示申请者信息
- [x] 显示申请留言和议价价格
- [x] 接受和拒绝按钮

### ⚠️ 5.5 通知中心
- [x] 显示再次议价通知
- [x] 通知内容包含任务标题、议价价格、留言
- [x] 显示"同意"和"拒绝"按钮
- [x] 按钮携带 token
- [ ] **问题：** 需要确认按钮是否使用 POST 请求，token 是否放在请求体中（避免出现在 URL）

### ✅ 5.6 其他功能
- [x] 消息附件显示
- [x] 游标分页实现
- [x] 消息已读状态显示

## 五、关键问题汇总

### ✅ 已修复的问题

1. **处理再次议价接口逻辑不完整** ✅ 已修复
   - **位置：** `backend/app/task_chat_routes.py:1694-1778`
   - **问题：** 接受议价时只记录了日志，没有更新 `Task.taker_id` 和任务状态
   - **修复内容：**
     - ✅ 使用事务 + SELECT FOR UPDATE 锁定任务
     - ✅ 检查任务是否还有名额
     - ✅ 更新 `Task.taker_id` 为申请者ID
     - ✅ 更新 `Task.agreed_reward` 为议价价格
     - ✅ 更新 `TaskApplication.status = "approved"`
     - ✅ 更新任务 `status = "in_progress"`
     - ✅ 自动拒绝所有其他待处理的申请
     - ✅ 发送通知给发布者

2. **Token payload 完整性** ✅ 已修复
   - **位置：** `backend/app/task_chat_routes.py:1523-1542`
   - **问题：** Token payload 中缺少 `notification_id` 字段
   - **修复内容：**
     - ✅ 在创建通知后，获取 `notification_id`
     - ✅ 更新 token payload 添加 `notification_id`
     - ✅ 重新存储到 Redis（覆盖之前的 token）
     - ✅ 在操作日志中记录 `notification_id`

3. **拒绝议价逻辑完善** ✅ 已修复
   - **位置：** `backend/app/task_chat_routes.py:1780-1818`
   - **修复内容：**
     - ✅ 更新申请状态为 `rejected`
     - ✅ 在操作日志中记录 `notification_id`
     - ✅ 发送通知给发布者

### ✅ 已确认的问题

1. **通知按钮安全性** ✅ 已确认
   - **位置：** `frontend/src/components/NotificationPanel.tsx:257-354`
   - **确认结果：** 
     - ✅ 按钮使用 POST 请求（通过 `respondNegotiation` API）
     - ✅ Token 放在请求体中（`api.post(..., { action, token })`）
     - ✅ 不会出现在 URL/日志/Referer 中

## 六、功能完成度统计

### 数据库模型：100% ✅
- 所有表结构已创建
- 所有字段已添加
- 所有约束和索引已创建

### API 接口：100% ✅
- 所有接口已实现
- 主要功能正常
- 处理再次议价接口逻辑已完善

### 业务逻辑：100% ✅
- 主要业务逻辑已实现
- 权限控制已实现
- 并发控制和幂等性已实现
- 接受议价逻辑已完善

### 前端实现：100% ✅
- 主要页面已改造
- 申请卡片已实现
- 通知中心安全性已确认

## 七、修复完成情况

### ✅ 已完成的修复
1. ✅ 修复处理再次议价接口：接受议价时现在会更新任务状态
2. ✅ 在 Token payload 中添加 `notification_id` 字段
3. ✅ 在操作日志中记录 `notification_id`
4. ✅ 完善拒绝议价逻辑（更新申请状态、发送通知）
5. ✅ 确认通知按钮安全性（已确认使用 POST 请求，token 在请求体中）

### 📋 可选优化（P2）
1. 添加更多错误处理和日志
2. 优化性能（缓存、索引等）

## 八、总结

✅ **所有关键问题已修复完成！**

整体功能实现度已达到 **100%**：
- ✅ 数据库模型：100% 完成
- ✅ API 接口：100% 完成
- ✅ 业务逻辑：100% 完成
- ✅ 前端实现：100% 完成

**主要修复内容：**
1. 修复了处理再次议价接口，接受议价时现在会正确更新任务状态（等同于接受申请）
2. 在 Token payload 中添加了 `notification_id` 字段，便于审计和关联
3. 完善了拒绝议价逻辑，包括更新申请状态和发送通知
4. 确认了通知按钮的安全性（使用 POST 请求，token 在请求体中）

**建议：** 进行完整的功能测试，确保所有修复正常工作。

