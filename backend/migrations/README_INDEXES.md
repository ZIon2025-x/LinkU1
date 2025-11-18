# 数据库索引迁移说明

## 📋 概述

本目录包含数据库性能优化所需的索引迁移脚本。

## 🚀 使用方法

### 1. 执行迁移脚本

```bash
# 使用 psql 执行
psql -U postgres -d linku_db -f add_performance_indexes.sql

# 或使用数据库管理工具执行 SQL 文件
```

### 2. 验证索引创建

执行脚本后，会自动显示所有创建的索引信息。

### 3. 验证索引使用情况

```sql
-- 查看索引使用统计
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE tablename IN ('tasks', 'task_applications', 'messages', 'notifications')
ORDER BY idx_scan DESC;
```

## ⚠️ 重要说明

### 1. conversation_key 字段

- `conversation_key` 字段由数据库触发器自动维护
- 应用层**不需要**手动设置此字段
- 触发器会在 INSERT/UPDATE 时自动生成 `conversation_key`

### 2. 部分索引的 WHERE 条件

- `ix_tasks_status_created_id` 和 `ix_tasks_type_location_status` 使用了部分索引
- 这些索引只覆盖 `status IN ('open', 'taken')` 的查询
- 查询时尽量使用 `status = 'open'` 或 `status IN ('open', 'taken')`
- 避免使用 `status != 'closed'` 这种形式（不走部分索引）

### 3. pg_trgm 扩展

- 如果使用 `USE_PG_TRGM=true`，需要确保已启用 `pg_trgm` 扩展
- 脚本会自动创建扩展（如果不存在）

### 4. 索引创建时间

- 索引创建可能需要一些时间，取决于表的大小
- 建议在低峰期执行迁移

## 📊 索引列表

### 任务表索引
- `ix_tasks_status_created_id` - 游标分页索引
- `ix_tasks_type_location_status` - 组合查询索引
- `ix_tasks_poster_status_created` - 用户发布任务索引
- `ix_tasks_taker_status_created` - 用户接受任务索引
- `idx_tasks_title_trgm` - 标题相似度搜索索引
- `idx_tasks_description_trgm` - 描述相似度搜索索引
- `idx_tasks_search` - 全文搜索索引

### 申请表索引
- `ix_applications_applicant_created` - 申请者查询索引
- `ix_applications_task_status` - 任务申请状态索引

### 消息表索引
- `ix_messages_conversation_created` - 对话查询索引（使用 conversation_key）
- `ix_messages_receiver_created` - 接收者查询索引

### 通知表索引
- `ix_notifications_user_read_created` - 用户通知查询索引

## 🔍 性能验证

执行以下 SQL 验证索引是否被使用：

```sql
-- 任务列表查询
EXPLAIN ANALYZE
SELECT * FROM tasks 
WHERE status = 'open' 
  AND task_type = 'delivery'
ORDER BY created_at DESC 
LIMIT 20;

-- 对话消息查询
EXPLAIN ANALYZE
SELECT * FROM messages 
WHERE conversation_key = 'user1-user2'
ORDER BY created_at ASC
LIMIT 50;
```

预期结果应该看到 "Index Scan" 而不是 "Seq Scan"（全表扫描）。

