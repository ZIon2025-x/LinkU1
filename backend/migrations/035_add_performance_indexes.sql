-- 性能优化：添加常用查询字段的索引
-- 创建时间：2024年

-- ==================== 任务表索引 ====================
-- 状态和截止日期的复合索引（用于查询开放任务）
CREATE INDEX IF NOT EXISTS idx_tasks_status_deadline ON tasks(status, deadline) WHERE status IN ('open', 'taken');

-- 位置索引（用于按城市筛选）
CREATE INDEX IF NOT EXISTS idx_tasks_location ON tasks(location) WHERE location IS NOT NULL;

-- 任务类型索引
CREATE INDEX IF NOT EXISTS idx_tasks_task_type ON tasks(task_type) WHERE task_type IS NOT NULL;

-- 创建时间索引（用于排序）
CREATE INDEX IF NOT EXISTS idx_tasks_created_at_desc ON tasks(created_at DESC);

-- 发布者ID索引（用于查询用户发布的任务）
CREATE INDEX IF NOT EXISTS idx_tasks_poster_created ON tasks(poster_id, created_at DESC);

-- 接受者ID索引（用于查询用户接受的任务）
CREATE INDEX IF NOT EXISTS idx_tasks_taker_created ON tasks(taker_id, created_at DESC);

-- ==================== 用户表索引 ====================
-- 邮箱索引（已存在，但确保存在）
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users(LOWER(email));

-- 创建时间索引（用于排序）
CREATE INDEX IF NOT EXISTS idx_users_created_at_desc ON users(created_at DESC);

-- 用户级别索引（用于筛选VIP用户等）
CREATE INDEX IF NOT EXISTS idx_users_level_created ON users(user_level, created_at DESC);

-- ==================== 消息表索引 ====================
-- 发送者和接收者的复合索引（用于查询对话）
CREATE INDEX IF NOT EXISTS idx_messages_sender_receiver_created ON messages(sender_id, receiver_id, created_at DESC);

-- 接收者ID和已读状态索引（用于查询未读消息）
CREATE INDEX IF NOT EXISTS idx_messages_receiver_unread ON messages(receiver_id, is_read, created_at DESC) WHERE is_read = 0;

-- 任务ID和创建时间索引（用于任务聊天）
CREATE INDEX IF NOT EXISTS idx_messages_task_created ON messages(task_id, created_at DESC) WHERE task_id IS NOT NULL;

-- ==================== 论坛帖子表索引 ====================
-- 板块ID和创建时间复合索引（用于查询板块帖子）
CREATE INDEX IF NOT EXISTS idx_forum_posts_category_created ON forum_posts(category_id, created_at DESC);

-- 作者ID索引（用于查询用户发布的帖子）
CREATE INDEX IF NOT EXISTS idx_forum_posts_author_created ON forum_posts(author_id, created_at DESC);

-- 状态索引（用于筛选可见帖子）
CREATE INDEX IF NOT EXISTS idx_forum_posts_status_created ON forum_posts(status, created_at DESC) WHERE status = 'published';

-- 最后回复时间索引（用于按最后回复排序）
CREATE INDEX IF NOT EXISTS idx_forum_posts_last_reply ON forum_posts(last_reply_at DESC) WHERE last_reply_at IS NOT NULL;

-- 点赞数索引（用于热门排序）
CREATE INDEX IF NOT EXISTS idx_forum_posts_likes ON forum_posts(likes_count DESC);

-- ==================== 论坛回复表索引 ====================
-- 帖子ID和创建时间索引（用于查询帖子回复）
CREATE INDEX IF NOT EXISTS idx_forum_replies_post_created ON forum_replies(post_id, created_at DESC);

-- 作者ID索引（用于查询用户的回复）
CREATE INDEX IF NOT EXISTS idx_forum_replies_author_created ON forum_replies(author_id, created_at DESC);

-- 父回复ID索引（用于查询嵌套回复）
CREATE INDEX IF NOT EXISTS idx_forum_replies_parent ON forum_replies(parent_reply_id) WHERE parent_reply_id IS NOT NULL;

-- ==================== 通知表索引 ====================
-- 用户ID和已读状态索引（用于查询未读通知）
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read, created_at DESC) WHERE is_read = 0;

-- 用户ID和创建时间索引（用于查询所有通知）
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);

-- ==================== 学生认证表索引 ====================
-- 用户ID和状态索引（用于查询用户的认证状态）
CREATE INDEX IF NOT EXISTS idx_student_verifications_user_status ON student_verifications(user_id, status);

-- 邮箱索引（用于邮箱唯一性检查）
CREATE INDEX IF NOT EXISTS idx_student_verifications_email ON student_verifications(LOWER(email));

-- 过期时间索引（用于查询即将过期的认证）
CREATE INDEX IF NOT EXISTS idx_student_verifications_expires ON student_verifications(expires_at) WHERE status = 'verified';

-- ==================== 任务申请表索引 ====================
-- 任务ID和状态索引（用于查询任务申请）
CREATE INDEX IF NOT EXISTS idx_task_applications_task_status ON task_applications(task_id, status, created_at DESC);

-- 申请者ID索引（用于查询用户的申请）
CREATE INDEX IF NOT EXISTS idx_task_applications_applicant_created ON task_applications(applicant_id, created_at DESC);

-- ==================== 评论表索引 ====================
-- 任务ID索引（用于查询任务评论）
CREATE INDEX IF NOT EXISTS idx_reviews_task_created ON reviews(task_id, created_at DESC);

-- 被评论用户ID索引（用于查询用户收到的评论）
CREATE INDEX IF NOT EXISTS idx_reviews_reviewed_user_created ON reviews(reviewed_user_id, created_at DESC);

-- ==================== 分析索引使用情况 ====================
-- 运行以下查询来检查索引使用情况：
-- SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
-- FROM pg_stat_user_indexes
-- WHERE schemaname = 'public'
-- ORDER BY idx_scan ASC;

