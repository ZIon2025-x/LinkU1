# 任务聊天功能数据库迁移说明

## 迁移文件
- 文件路径：`backend/alembic/versions/2025_01_27_0000_add_task_chat_features.py`
- 版本号：`task_chat_features_001`
- 基于版本：`make_task_history_nullable`

## 迁移内容

本次迁移包含以下数据库改动：

### 1. 修改 Task 表
- 添加 `base_reward` (DECIMAL(12,2)) - 原始标价
- 添加 `agreed_reward` (DECIMAL(12,2)) - 最终成交价
- 添加 `currency` (CHAR(3), 默认 'GBP') - 货币类型

### 2. 修改 TaskApplication 表
- 添加 `negotiated_price` (DECIMAL(12,2)) - 议价价格
- 添加 `currency` (CHAR(3), 默认 'GBP') - 货币类型

### 3. 修改 Message 表
- 修改 `receiver_id` 为可空（用于任务消息）
- 添加 `task_id` (INTEGER) - 关联的任务ID
- 添加 `message_type` (VARCHAR(20), 默认 'normal') - 消息类型
- 添加 `conversation_type` (VARCHAR(20), 默认 'task') - 会话类型
- 添加 `meta` (TEXT) - JSON格式元数据
- 创建外键约束和索引
- 创建 CHECK 约束（如果数据库支持）

### 4. 修改 Notification 表
- 修改 `type` 字段长度（从50改为32）
- 修改 `title` 为可空（向后兼容）
- 添加 `read_at` (DATETIME) - 已读时间
- 创建新索引

### 5. 创建 MessageReads 表
- 消息已读状态表
- 外键使用 ON DELETE CASCADE

### 6. 创建 MessageAttachments 表
- 消息附件表
- 支持多图/文件
- 外键使用 ON DELETE CASCADE

### 7. 创建 NegotiationResponseLog 表
- 议价响应操作日志表
- 用于审计

### 8. 创建 MessageReadCursors 表
- 消息已读游标表
- 按任务维度记录已读游标，降低写放大

## 运行迁移

### 本地开发环境

```bash
# 进入 backend 目录
cd backend

# 查看当前迁移版本
alembic current

# 查看迁移历史
alembic history

# 运行迁移（升级到最新版本）
alembic upgrade head

# 如果需要回滚（降级一个版本）
alembic downgrade -1
```

### 使用 migrate.py 脚本

```bash
# 进入 backend 目录
cd backend

# 查看迁移状态
python migrate.py status

# 运行迁移
python migrate.py upgrade

# 查看迁移历史
python migrate.py history
```

### Railway 部署环境

在 Railway 部署时，迁移会自动运行（如果配置了启动脚本）。

或者手动运行：

```bash
# 在 Railway 控制台或通过 CLI
cd backend
alembic upgrade head
```

## 注意事项

1. **CHECK 约束兼容性**：
   - 某些数据库（如旧版 MySQL）可能不支持 CHECK 约束
   - 迁移脚本会尝试创建 CHECK 约束，如果失败会跳过（应用层会进行校验）
   - PostgreSQL 和 SQLite 支持 CHECK 约束

2. **数据兼容性**：
   - 所有新字段都设置为可空（nullable=True），不会影响现有数据
   - `receiver_id` 字段改为可空，不会影响现有消息记录
   - `Notification.title` 改为可空，向后兼容

3. **索引创建**：
   - 所有索引都会自动创建
   - 如果索引已存在，迁移会失败（需要先手动删除）

4. **外键约束**：
   - `MessageReads` 和 `MessageAttachments` 使用 `ON DELETE CASCADE`
   - 删除消息时会自动删除关联的已读记录和附件

5. **回滚（downgrade）**：
   - 如果迁移失败，可以使用 `alembic downgrade -1` 回滚
   - 回滚会删除所有新创建的表和字段
   - **注意：回滚会丢失数据，请谨慎操作**

## 验证迁移

迁移完成后，可以验证：

```sql
-- 检查新表是否存在
SELECT table_name FROM information_schema.tables 
WHERE table_name IN (
    'message_reads', 
    'message_attachments', 
    'negotiation_response_logs', 
    'message_read_cursors'
);

-- 检查新字段是否存在
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'tasks' 
AND column_name IN ('base_reward', 'agreed_reward', 'currency');

-- 检查索引是否存在
SELECT indexname FROM pg_indexes 
WHERE tablename = 'messages' 
AND indexname LIKE 'ix_messages_%';
```

## 故障排查

### 问题1：迁移失败，提示约束已存在
**解决方案**：检查数据库中是否已有相关约束，手动删除后重试

### 问题2：迁移失败，提示字段已存在
**解决方案**：检查数据库中是否已有相关字段，可能需要手动清理

### 问题3：CHECK 约束创建失败
**解决方案**：这是正常的，某些数据库不支持 CHECK 约束。应用层会进行校验。

### 问题4：外键约束失败
**解决方案**：检查关联的表是否存在，确保外键引用的表已创建

## 联系支持

如果遇到问题，请：
1. 查看迁移日志
2. 检查数据库连接
3. 验证数据库版本兼容性
4. 联系开发团队

