-- 推荐系统性能优化索引
-- 创建时间：2025-01-27
-- 说明：为推荐系统相关查询添加索引，提升性能

-- ==================== 任务表推荐相关索引 ====================
-- 状态、创建时间、发布者ID复合索引（用于推荐查询）
CREATE INDEX IF NOT EXISTS idx_tasks_recommendation_status_created 
ON tasks(status, created_at DESC, poster_id) 
WHERE status = 'open';

-- 任务类型、状态、创建时间复合索引（用于类型筛选推荐）
CREATE INDEX IF NOT EXISTS idx_tasks_recommendation_type_status_created 
ON tasks(task_type, status, created_at DESC) 
WHERE status = 'open';

-- 位置、状态、创建时间复合索引（用于位置筛选推荐）
CREATE INDEX IF NOT EXISTS idx_tasks_recommendation_location_status_created 
ON tasks(location, status, created_at DESC) 
WHERE status = 'open' AND location IS NOT NULL;

-- 截止日期、状态索引（用于时间匹配推荐）
CREATE INDEX IF NOT EXISTS idx_tasks_recommendation_deadline_status 
ON tasks(deadline, status) 
WHERE status = 'open' AND deadline IS NOT NULL;

-- ==================== 任务申请表索引优化 ====================
-- 申请者ID、任务ID复合索引（用于快速查询用户申请的任务）
CREATE INDEX IF NOT EXISTS idx_task_applications_applicant_task 
ON task_applications(applicant_id, task_id);

-- ==================== 任务历史表索引优化 ====================
-- 用户ID、动作、任务ID复合索引（用于查询用户完成的任务）
CREATE INDEX IF NOT EXISTS idx_task_history_user_action_task 
ON task_history(user_id, action, task_id) 
WHERE action IN ('accepted', 'completed');

-- 用户ID、时间戳索引（用于查询用户最近的历史）
CREATE INDEX IF NOT EXISTS idx_task_history_user_timestamp 
ON task_history(user_id, timestamp DESC);

-- ==================== 任务参与者表索引优化 ====================
-- 用户ID、状态、任务ID复合索引（用于查询用户参与的任务）
CREATE INDEX IF NOT EXISTS idx_task_participants_user_status_task 
ON task_participants(user_id, status, task_id) 
WHERE status IN ('accepted', 'in_progress', 'completed');

-- ==================== 用户任务交互表索引优化 ====================
-- 用户ID、交互类型、任务ID复合索引（用于协同过滤）
CREATE INDEX IF NOT EXISTS idx_user_task_interactions_user_type_task 
ON user_task_interactions(user_id, interaction_type, task_id);

-- 任务ID、交互类型、时间索引（用于查询任务交互）
CREATE INDEX IF NOT EXISTS idx_user_task_interactions_task_type_time 
ON user_task_interactions(task_id, interaction_type, interaction_time DESC);

-- 用户ID、时间索引（用于查询用户最近的交互）
CREATE INDEX IF NOT EXISTS idx_user_task_interactions_user_time 
ON user_task_interactions(user_id, interaction_time DESC);

-- ==================== 用户偏好表索引优化 ====================
-- 用户ID索引（用于查询用户偏好）
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id 
ON user_preferences(user_id);

-- ==================== 推荐反馈表索引优化 ====================
-- 用户ID、反馈类型索引（用于分析推荐效果）
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_user_type 
ON recommendation_feedback(user_id, feedback_type);

-- 任务ID、反馈类型索引（用于分析任务推荐效果）
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_task_type 
ON recommendation_feedback(task_id, feedback_type);

-- ==================== 分析索引使用情况 ====================
-- 运行以下查询来检查推荐系统相关索引的使用情况：
-- SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
-- FROM pg_stat_user_indexes
-- WHERE schemaname = 'public'
--   AND (indexname LIKE '%recommendation%' 
--        OR indexname LIKE '%task_applications%'
--        OR indexname LIKE '%task_history%'
--        OR indexname LIKE '%task_participants%'
--        OR indexname LIKE '%user_task_interactions%')
-- ORDER BY idx_scan ASC;
