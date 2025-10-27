-- ========================================
-- 创建 pg_trgm 索引以优化搜索性能
-- 在 Railway 数据库控制台执行此文件
-- ========================================

-- 1. 确保 pg_trgm 扩展已安装
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. 为任务表创建 GIN 索引
-- 这些索引将大幅提升任务搜索的性能

-- 任务标题索引
CREATE INDEX IF NOT EXISTS idx_tasks_title_trgm 
ON tasks USING gin(title gin_trgm_ops);

-- 任务描述索引
CREATE INDEX IF NOT EXISTS idx_tasks_description_trgm 
ON tasks USING gin(description gin_trgm_ops);

-- 任务类型索引
CREATE INDEX IF NOT EXISTS idx_tasks_type_trgm 
ON tasks USING gin(task_type gin_trgm_ops);

-- 任务地点索引
CREATE INDEX IF NOT EXISTS idx_tasks_location_trgm 
ON tasks USING gin(location gin_trgm_ops);

-- 3. 为用户表创建 GIN 索引
-- 优化用户名和邮箱搜索

-- 用户名索引
CREATE INDEX IF NOT EXISTS idx_users_name_trgm 
ON users USING gin(name gin_trgm_ops);

-- 邮箱索引
CREATE INDEX IF NOT EXISTS idx_users_email_trgm 
ON users USING gin(email gin_trgm_ops);

-- 4. 查看创建的索引
-- 验证索引是否成功创建
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes
WHERE indexname LIKE '%_trgm'
ORDER BY pg_size_pretty(pg_relation_size(indexname::regclass)) DESC;

-- ========================================
-- 性能监控查询（可选）
-- ========================================

-- 查看最慢的查询
SELECT 
    left(query, 100) as query_snippet,
    calls,
    round(total_exec_time::numeric, 2) as total_time_ms,
    round(mean_exec_time::numeric, 2) as mean_time_ms,
    round(max_exec_time::numeric, 2) as max_time_ms
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC
LIMIT 20;

-- 查看索引使用统计
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
AND indexname LIKE '%_trgm'
ORDER BY idx_scan DESC;

-- 查看表统计和大小
SELECT 
    schemaname,
    relname as table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    n_live_tup as row_count,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(relid) DESC;

