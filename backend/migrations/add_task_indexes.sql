-- 任务表索引优化迁移脚本
-- 执行前请先备份数据库

-- 1. 创建复合索引（状态 + 截止日期 + 创建时间）
-- 用于任务列表查询：WHERE status = 'open' AND deadline > NOW() ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS ix_tasks_status_deadline_created 
ON tasks(status, deadline DESC, created_at DESC)
WHERE status IN ('open', 'taken');  -- 部分索引，只索引常用状态

-- 2. 创建发布者相关索引
-- 用于查询用户发布的任务：WHERE poster_id = ? AND status = ? ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS ix_tasks_poster_status_created 
ON tasks(poster_id, status, created_at DESC);

-- 3. 创建覆盖索引（包含常用查询字段，避免回表）
-- ⚠️ 注意：INCLUDE 子句需要 PostgreSQL ≥ 11
-- 如果版本低于 11，需要创建包含所有列的复合索引
CREATE INDEX IF NOT EXISTS ix_tasks_detail_covering 
ON tasks(id) 
INCLUDE (title, task_type, location, status, base_reward, deadline, created_at);

-- 索引说明：
-- 1. 覆盖索引可以支持 Index Only Scan，避免回表
-- 2. 但 Index Only Scan 需要可见性图（visibility map）支持
-- 3. 需要定期 VACUUM 维护可见性图，确保 all-visible 标记正确
-- 4. 如果可见性图不完整，仍会回表检查可见性

-- 4. 分析表，更新统计信息
ANALYZE tasks;

-- 5. 验证索引创建成功
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'tasks'
ORDER BY indexname;

