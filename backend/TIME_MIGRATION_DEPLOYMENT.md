# 时间字段迁移部署指南

## 概述

本指南说明如何在部署时自动执行时间字段迁移，将数据库中的 `TIMESTAMP` 字段转换为 `TIMESTAMPTZ` 字段。

## 自动迁移配置

### 环境变量

通过 `AUTO_MIGRATE` 环境变量控制是否启用自动迁移：

- `AUTO_MIGRATE=true`（默认）：启用自动迁移，应用启动时自动执行
- `AUTO_MIGRATE=false`：禁用自动迁移

### 部署时自动执行

**默认情况下，应用启动时会自动执行所有迁移脚本**，包括时间字段迁移。

迁移脚本执行顺序：
1. 创建优惠券和积分系统表
2. 创建任务表索引
3. 创建任务达人功能表
4. ...（其他迁移）
5. **时间字段迁移**（`migrate_time_fields_to_timestamptz.sql`）

## 迁移脚本说明

### 迁移策略

迁移脚本 `migrate_time_fields_to_timestamptz.sql` 执行以下操作：

1. **检查字段类型**：如果字段已经是 `TIMESTAMPTZ`，则跳过
2. **添加新列**：创建 `TIMESTAMPTZ` 类型的新列
3. **转换数据**：
   - 假设所有旧数据是欧洲/伦敦时区（Europe/London）的墙钟时间
   - 将旧数据解释为伦敦时间，然后转换为 UTC
   - 使用 PostgreSQL 的 `AT TIME ZONE` 语法进行转换
4. **回填NULL值**：使用 `NOW()` 回填 NULL 值（保持 TIMESTAMPTZ 语义）
5. **替换旧列**：删除旧列，重命名新列
6. **添加约束**：为必需字段添加 NOT NULL 约束

### 幂等性

迁移脚本具有幂等性，可以安全地多次执行：
- 如果字段已经是 `TIMESTAMPTZ`，会自动跳过
- 使用 `IF NOT EXISTS` 和 `DO $$ ... END $$` 块确保幂等性

### 迁移的表和字段

迁移脚本会处理以下表的时间字段：

- `users`: created_at, suspend_until, terms_agreed_at, name_updated_at
- `tasks`: deadline, created_at, accepted_at, completed_at
- `task_reviews`: created_at
- `task_history`: timestamp
- `messages`: created_at
- `notifications`: created_at, read_at
- `task_cancel_requests`: created_at, reviewed_at
- `customer_service`: created_at
- `admin_requests`: created_at, updated_at
- `admin_users`: created_at, last_login
- `staff_notifications`: created_at, read_at
- `system_settings`: created_at, updated_at
- `customer_service_chats`: created_at, ended_at, last_message_at, rated_at
- `customer_service_messages`: created_at
- `pending_users`: created_at, expires_at, terms_agreed_at
- `task_applications`: created_at
- `job_positions`: created_at, updated_at
- `featured_task_experts`: created_at, updated_at
- `user_preferences`: created_at, updated_at
- `message_read`: read_at
- `message_attachments`: created_at
- `negotiation_response_log`: responded_at
- `message_read_cursor`: updated_at

## 部署流程

### 生产环境部署

1. **设置环境变量**（可选，默认已启用）：
   ```bash
   export AUTO_MIGRATE=true
   ```

2. **启动应用**：
   ```bash
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```

3. **查看日志**：
   应用启动时会自动执行迁移，日志中会显示：
   ```
   🚀 开始执行自动数据库迁移...
   🚀 开始执行 migrate_time_fields_to_timestamptz.sql...
   ✅ users.created_at 迁移完成
   ✅ tasks.created_at 迁移完成
   ...
   ✅ 所有时间字段迁移完成！
   ```

### Railway 部署

Railway 部署时，应用会自动执行迁移：

1. **环境变量**：确保 `AUTO_MIGRATE=true`（或留空，默认启用）
2. **部署**：推送代码到 Railway，应用启动时会自动执行迁移
3. **监控日志**：在 Railway 控制台查看迁移执行日志

## 注意事项

### ⚠️ 重要提示

1. **数据源假设**：
   - 迁移脚本假设所有旧数据都是欧洲/伦敦时区（Europe/London）
   - 如果数据来源不是伦敦时区，需要修改迁移脚本的转换策略

2. **迁移时间**：
   - 迁移在应用启动时执行，可能会稍微延长启动时间
   - 大型表迁移可能需要几分钟时间

3. **错误处理**：
   - 迁移失败不会阻止应用启动，但会记录错误日志
   - 如果迁移失败，请检查日志并手动修复

4. **回滚**：
   - 迁移脚本不包含自动回滚功能
   - 如需回滚，需要手动执行回滚 SQL 或从备份恢复

### 验证迁移结果

迁移完成后，可以执行以下 SQL 验证：

```sql
-- 检查字段类型
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name IN ('users', 'tasks', 'messages', 'notifications')
AND column_name LIKE '%_at' OR column_name = 'timestamp'
ORDER BY table_name, column_name;

-- 应该看到所有时间字段都是 timestamp with time zone
```

## 故障排查

### 迁移未执行

1. 检查 `AUTO_MIGRATE` 环境变量设置
2. 查看启动日志，确认是否输出了迁移相关信息
3. 检查 `backend/migrations/migrate_time_fields_to_timestamptz.sql` 文件是否存在

### 迁移失败

1. 查看应用日志，找到具体的错误信息
2. 检查数据库连接是否正常
3. 确认数据库用户是否有足够的权限（需要 ALTER TABLE 权限）
4. 检查是否有其他进程正在锁定表

### 数据转换错误

如果发现数据转换不正确：

1. 检查旧数据是否真的是伦敦时区
2. 验证转换逻辑是否正确
3. 考虑手动修正数据或使用不同的转换策略

## 相关文件

- `backend/migrations/migrate_time_fields_to_timestamptz.sql` - 时间字段迁移脚本
- `backend/app/db_migrations.py` - 自动迁移执行模块
- `backend/app/main.py` - 应用启动事件（调用自动迁移）
- `backend/app/utils/time_utils.py` - 时间工具模块

## 更新日志

- 2024-12-28: 创建时间字段迁移脚本，集成到自动迁移系统

