# 数据库索引建议

## 概述
本文档列出了建议添加的数据库索引，以优化查询性能。

## 已存在的索引

根据代码分析，以下表已经有索引：

### PaymentTransfer 表
- `ix_payment_transfer_task` (task_id)
- `ix_payment_transfer_taker` (taker_id)
- `ix_payment_transfer_status` (status)
- `ix_payment_transfer_retry` (next_retry_at)
- `ix_payment_transfer_created` (created_at)

### PaymentHistory 表
- `ix_payment_history_created` (created_at)

## 建议添加的索引

### 1. Task 表

#### 高优先级索引

```sql
-- 任务状态查询（非常频繁）
CREATE INDEX IF NOT EXISTS ix_tasks_status ON tasks(status);

-- 任务发布者查询
CREATE INDEX IF NOT EXISTS ix_tasks_poster ON tasks(poster_id);

-- 任务接受者查询
CREATE INDEX IF NOT EXISTS ix_tasks_taker ON tasks(taker_id);

-- 任务状态+发布者组合查询（用于用户任务列表）
CREATE INDEX IF NOT EXISTS ix_tasks_status_poster ON tasks(status, poster_id);

-- 任务状态+接受者组合查询（用于用户任务列表）
CREATE INDEX IF NOT EXISTS ix_tasks_status_taker ON tasks(status, taker_id);

-- 任务截止日期查询（用于过期任务检查）
CREATE INDEX IF NOT EXISTS ix_tasks_deadline ON tasks(deadline) WHERE deadline IS NOT NULL;

-- 任务创建时间查询（用于排序）
CREATE INDEX IF NOT EXISTS ix_tasks_created ON tasks(created_at);

-- 任务类型查询
CREATE INDEX IF NOT EXISTS ix_tasks_type ON tasks(task_type);
```

#### 中优先级索引

```sql
-- 任务位置查询（如果经常按位置筛选）
CREATE INDEX IF NOT EXISTS ix_tasks_location ON tasks(location);

-- 任务支付状态查询
CREATE INDEX IF NOT EXISTS ix_tasks_payment ON tasks(is_paid, is_confirmed);

-- 任务支付过期时间查询
CREATE INDEX IF NOT EXISTS ix_tasks_payment_expires ON tasks(payment_expires_at) WHERE payment_expires_at IS NOT NULL;
```

### 2. User 表

```sql
-- 用户邮箱查询（登录、验证）
CREATE INDEX IF NOT EXISTS ix_users_email ON users(email);

-- 用户手机号查询（登录、验证）
CREATE INDEX IF NOT EXISTS ix_users_phone ON users(phone) WHERE phone IS NOT NULL;

-- 用户等级查询
CREATE INDEX IF NOT EXISTS ix_users_level ON users(user_level);

-- 用户创建时间查询
CREATE INDEX IF NOT EXISTS ix_users_created ON users(created_at);
```

### 3. TaskApplication 表

```sql
-- 申请任务查询
CREATE INDEX IF NOT EXISTS ix_task_applications_task ON task_applications(task_id);

-- 申请用户查询
CREATE INDEX IF NOT EXISTS ix_task_applications_user ON task_applications(applicant_id);

-- 申请状态查询
CREATE INDEX IF NOT EXISTS ix_task_applications_status ON task_applications(status);

-- 任务+用户组合查询（检查用户是否已申请）
CREATE INDEX IF NOT EXISTS ix_task_applications_task_user ON task_applications(task_id, applicant_id);

-- 任务+状态组合查询（获取任务的申请列表）
CREATE INDEX IF NOT EXISTS ix_task_applications_task_status ON task_applications(task_id, status);
```

### 4. Review 表

```sql
-- 用户评价查询
CREATE INDEX IF NOT EXISTS ix_reviews_user ON reviews(user_id);

-- 任务评价查询
CREATE INDEX IF NOT EXISTS ix_reviews_task ON reviews(task_id);

-- 用户+任务组合查询
CREATE INDEX IF NOT EXISTS ix_reviews_user_task ON reviews(user_id, task_id);
```

### 5. Notification 表

```sql
-- 用户通知查询
CREATE INDEX IF NOT EXISTS ix_notifications_user ON notifications(user_id);

-- 用户+已读状态查询
CREATE INDEX IF NOT EXISTS ix_notifications_user_read ON notifications(user_id, is_read);

-- 通知创建时间查询（用于排序）
CREATE INDEX IF NOT EXISTS ix_notifications_created ON notifications(created_at);
```

### 6. PointsAccount 表

```sql
-- 用户积分账户查询
CREATE INDEX IF NOT EXISTS ix_points_accounts_user ON points_accounts(user_id);
```

### 7. PointsTransaction 表

```sql
-- 用户积分交易查询
CREATE INDEX IF NOT EXISTS ix_points_transactions_user ON points_transactions(user_id);

-- 用户+类型组合查询
CREATE INDEX IF NOT EXISTS ix_points_transactions_user_type ON points_transactions(user_id, type);

-- 积分交易创建时间查询（用于排序）
CREATE INDEX IF NOT EXISTS ix_points_transactions_created ON points_transactions(created_at);

-- 幂等性键查询（如果使用）
CREATE INDEX IF NOT EXISTS ix_points_transactions_idempotency ON points_transactions(idempotency_key) WHERE idempotency_key IS NOT NULL;
```

### 8. TaskParticipant 表（多人任务）

```sql
-- 任务参与者查询
CREATE INDEX IF NOT EXISTS ix_task_participants_task ON task_participants(task_id);

-- 用户参与任务查询
CREATE INDEX IF NOT EXISTS ix_task_participants_user ON task_participants(user_id);

-- 任务+用户组合查询
CREATE INDEX IF NOT EXISTS ix_task_participants_task_user ON task_participants(task_id, user_id);

-- 任务+状态组合查询
CREATE INDEX IF NOT EXISTS ix_task_participants_task_status ON task_participants(task_id, status);
```

## 复合索引说明

### 何时使用复合索引

1. **WHERE 子句包含多个条件**：如果查询经常同时使用多个字段过滤，创建复合索引
2. **排序和过滤**：如果查询需要按某个字段排序并过滤另一个字段，考虑复合索引
3. **覆盖索引**：如果索引包含查询所需的所有字段，可以避免回表查询

### 索引顺序

复合索引的字段顺序很重要：
- **最常用的过滤字段放在前面**
- **选择性高的字段放在前面**（唯一值多的字段）
- **排序字段放在最后**

## 索引维护

### 定期检查

```sql
-- 查看未使用的索引
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY schemaname, tablename;

-- 查看索引大小
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;
```

### 索引重建

如果索引碎片化严重，可以重建：

```sql
-- 重建索引（PostgreSQL 12+）
REINDEX INDEX CONCURRENTLY ix_tasks_status;

-- 或者重建整个表的所有索引
REINDEX TABLE CONCURRENTLY tasks;
```

## 注意事项

1. **索引会增加写入开销**：每次 INSERT/UPDATE/DELETE 都需要更新索引
2. **索引占用存储空间**：大表的索引可能占用大量空间
3. **不要过度索引**：只为经常查询的字段创建索引
4. **监控索引使用情况**：定期检查哪些索引实际被使用

## 实施建议

1. **分阶段实施**：先添加高优先级索引，观察性能改进
2. **在低峰期创建**：使用 `CONCURRENTLY` 选项避免锁表
3. **监控性能**：创建索引后监控查询性能变化
4. **定期审查**：根据实际查询模式调整索引策略

## 示例迁移脚本

```sql
-- 创建索引（使用 CONCURRENTLY 避免锁表）
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_tasks_status ON tasks(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_tasks_poster ON tasks(poster_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_tasks_taker ON tasks(taker_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_tasks_status_poster ON tasks(status, poster_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_tasks_status_taker ON tasks(status, taker_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_tasks_deadline ON tasks(deadline) WHERE deadline IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_tasks_created ON tasks(created_at);

-- 用户表索引
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_users_email ON users(email);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_users_phone ON users(phone) WHERE phone IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_users_level ON users(user_level);

-- 申请表索引
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_task_applications_task ON task_applications(task_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_task_applications_user ON task_applications(applicant_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_task_applications_status ON task_applications(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_task_applications_task_user ON task_applications(task_id, applicant_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_task_applications_task_status ON task_applications(task_id, status);

-- 评价表索引
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_reviews_user ON reviews(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_reviews_task ON reviews(task_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_reviews_user_task ON reviews(user_id, task_id);

-- 通知表索引
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_notifications_user ON notifications(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_notifications_user_read ON notifications(user_id, is_read);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_notifications_created ON notifications(created_at);
```
