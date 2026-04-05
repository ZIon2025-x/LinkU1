-- 167: 为 tasks 表和 reviews 表添加缺失的索引
-- 解决全表扫描问题，预计查询性能提升 50-100 倍
-- 所有索引使用 IF NOT EXISTS，可安全重复执行

-- ========== Phase 1: Task 表单列索引（高频过滤字段）==========

-- poster_id: 用户发布的任务统计、个人主页
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_poster_id
    ON tasks (poster_id);

-- taker_id: 用户接单的任务统计
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_taker_id
    ON tasks (taker_id);

-- status: 几乎所有任务列表查询都按状态过滤
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_status
    ON tasks (status);

-- task_type: 按分类筛选任务
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_task_type
    ON tasks (task_type);

-- created_at: 排序分页（DESC 优化 ORDER BY ... DESC）
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_created_at
    ON tasks (created_at DESC);

-- deadline: 过期任务查询、定时任务扫描
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_deadline
    ON tasks (deadline);

-- ========== Phase 2: Task 表复合索引（常见组合查询）==========

-- 任务列表核心查询：status + is_visible（最高频组合）
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_status_is_visible
    ON tasks (status, is_visible);

-- 推荐系统 + 任务列表：is_visible + status + created_at 排序
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_visible_status_created
    ON tasks (is_visible, status, created_at DESC);

-- 用户接单统计：taker_id + status（如 completed 数量统计）
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_taker_status
    ON tasks (taker_id, status);

-- 用户发布任务按时间查：poster_id + created_at
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_poster_created
    ON tasks (poster_id, created_at DESC);

-- ========== Phase 3: Review 表补充索引 ==========

-- 按用户查评价
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reviews_user_id
    ON reviews (user_id);

-- 用户评价历史（按时间倒序）
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reviews_user_created
    ON reviews (user_id, created_at DESC);

-- ========== Phase 4: 删除无用索引（0 次使用，浪费存储和写入性能）==========

DROP INDEX IF EXISTS idx_forum_posts_content_trgm;
DROP INDEX IF EXISTS idx_forum_posts_search;
DROP INDEX IF EXISTS idx_tasks_description_trgm;
