-- 为搜索字段添加 pg_trgm GIN 索引
-- 加速 ILIKE + similarity() 查询
-- 创建时间: 2026-04-03

-- ==================== 任务表 ====================
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_title_trgm
ON tasks USING gin(title gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_description_trgm
ON tasks USING gin(description gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_title_zh_trgm
ON tasks USING gin(title_zh gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_title_en_trgm
ON tasks USING gin(title_en gin_trgm_ops);

-- ==================== 活动表 ====================
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_title_trgm
ON activities USING gin(title gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_description_trgm
ON activities USING gin(description gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_title_zh_trgm
ON activities USING gin(title_zh gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_title_en_trgm
ON activities USING gin(title_en gin_trgm_ops);

-- ==================== 跳蚤市场 ====================
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_flea_market_items_title_trgm
ON flea_market_items USING gin(title gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_flea_market_items_description_trgm
ON flea_market_items USING gin(description gin_trgm_ops);

-- ==================== 达人服务 ====================
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_expert_services_name_trgm
ON task_expert_services USING gin(service_name gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_expert_services_desc_trgm
ON task_expert_services USING gin(description gin_trgm_ops);

-- ==================== 排行榜 ====================
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_custom_leaderboards_name_trgm
ON custom_leaderboards USING gin(name gin_trgm_ops);

-- ==================== 论坛帖子（已有 title/content 索引，补充双语字段）====================
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_forum_posts_title_zh_trgm
ON forum_posts USING gin(title_zh gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_forum_posts_title_en_trgm
ON forum_posts USING gin(title_en gin_trgm_ops);
