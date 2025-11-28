-- 论坛功能数据库迁移
-- 创建时间: 2025-01-27
-- 说明: 创建论坛相关的所有表、索引和约束

-- 1. 创建论坛板块表
CREATE TABLE IF NOT EXISTS forum_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(200),
    sort_order INTEGER DEFAULT 0,
    is_visible BOOLEAN DEFAULT TRUE,
    post_count INTEGER DEFAULT 0,
    last_post_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_forum_categories_visible ON forum_categories(is_visible, sort_order);

-- 2. 创建主题帖表
CREATE TABLE IF NOT EXISTS forum_posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    category_id INTEGER NOT NULL REFERENCES forum_categories(id) ON DELETE CASCADE,
    author_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    view_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    favorite_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE,
    is_locked BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    is_visible BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_reply_at TIMESTAMP WITH TIME ZONE
);

-- 创建索引（注意：复杂索引使用 SQL 创建）
CREATE INDEX IF NOT EXISTS idx_forum_posts_category ON forum_posts(category_id, is_deleted, is_visible);
CREATE INDEX IF NOT EXISTS idx_forum_posts_author ON forum_posts(author_id, is_deleted, is_visible);
CREATE INDEX IF NOT EXISTS idx_forum_posts_pinned ON forum_posts(is_pinned, created_at);

-- 使用 SQL 创建带 DESC 的索引
CREATE INDEX IF NOT EXISTS idx_forum_posts_category_desc ON forum_posts(category_id, is_deleted, is_visible, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_posts_last_reply ON forum_posts(is_deleted, is_visible, last_reply_at DESC NULLS LAST);

-- 全文搜索索引（使用 simple 配置，后续可升级为 pg_bigm）
CREATE INDEX IF NOT EXISTS idx_forum_posts_search ON forum_posts USING GIN(to_tsvector('simple', title || ' ' || content));

-- 3. 创建回复表
CREATE TABLE IF NOT EXISTS forum_replies (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    post_id INTEGER NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
    parent_reply_id INTEGER REFERENCES forum_replies(id) ON DELETE CASCADE,
    reply_level INTEGER DEFAULT 1 CHECK (reply_level BETWEEN 1 AND 3),
    author_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    like_count INTEGER DEFAULT 0,
    is_deleted BOOLEAN DEFAULT FALSE,
    is_visible BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_forum_replies_post ON forum_replies(post_id, created_at);
CREATE INDEX IF NOT EXISTS idx_forum_replies_parent ON forum_replies(parent_reply_id);
CREATE INDEX IF NOT EXISTS idx_forum_replies_author ON forum_replies(author_id, is_deleted, is_visible);

-- 4. 创建点赞表
CREATE TABLE IF NOT EXISTS forum_likes (
    id SERIAL PRIMARY KEY,
    target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id INTEGER NOT NULL,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(target_type, target_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_forum_likes_target ON forum_likes(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_forum_likes_user ON forum_likes(user_id);

-- 5. 创建收藏表
CREATE TABLE IF NOT EXISTS forum_favorites (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_forum_favorites_user ON forum_favorites(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_forum_favorites_post ON forum_favorites(post_id);

-- 6. 创建通知表
CREATE TABLE IF NOT EXISTS forum_notifications (
    id SERIAL PRIMARY KEY,
    notification_type VARCHAR(20) NOT NULL CHECK (notification_type IN ('reply_post', 'reply_reply', 'like_post', 'feature_post', 'pin_post')),
    target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id INTEGER NOT NULL,
    from_user_id VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    to_user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_forum_notifications_user ON forum_notifications(to_user_id, is_read, created_at);
CREATE INDEX IF NOT EXISTS idx_forum_notifications_target ON forum_notifications(target_type, target_id);

-- 7. 创建举报表
CREATE TABLE IF NOT EXISTS forum_reports (
    id SERIAL PRIMARY KEY,
    target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id INTEGER NOT NULL,
    reporter_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason VARCHAR(50) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL CHECK (status IN ('pending', 'processed', 'rejected')),
    processor_id VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    processed_at TIMESTAMP WITH TIME ZONE,
    action VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_forum_reports_status ON forum_reports(status, created_at);
CREATE INDEX IF NOT EXISTS idx_forum_reports_target ON forum_reports(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_forum_reports_reporter ON forum_reports(reporter_id);

-- 部分唯一索引：防止同一用户对同一目标的 pending 举报重复
CREATE UNIQUE INDEX IF NOT EXISTS idx_forum_reports_unique_pending 
ON forum_reports(target_type, target_id, reporter_id) 
WHERE status = 'pending';

-- 8. 创建触发器：软删除帖子/回复时自动清理点赞记录
CREATE OR REPLACE FUNCTION cleanup_forum_likes_on_soft_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE THEN
        -- 删除帖子时清理点赞
        IF TG_TABLE_NAME = 'forum_posts' THEN
            DELETE FROM forum_likes 
            WHERE target_type = 'post' AND target_id = OLD.id;
        -- 删除回复时清理点赞
        ELSIF TG_TABLE_NAME = 'forum_replies' THEN
            DELETE FROM forum_likes 
            WHERE target_type = 'reply' AND target_id = OLD.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为帖子表创建触发器
DROP TRIGGER IF EXISTS trigger_cleanup_post_likes ON forum_posts;
CREATE TRIGGER trigger_cleanup_post_likes
    AFTER UPDATE ON forum_posts
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE)
    EXECUTE FUNCTION cleanup_forum_likes_on_soft_delete();

-- 为回复表创建触发器
DROP TRIGGER IF EXISTS trigger_cleanup_reply_likes ON forum_replies;
CREATE TRIGGER trigger_cleanup_reply_likes
    AFTER UPDATE ON forum_replies
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE)
    EXECUTE FUNCTION cleanup_forum_likes_on_soft_delete();

-- 9. 创建更新 updated_at 的触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为需要自动更新 updated_at 的表创建触发器
DROP TRIGGER IF EXISTS trigger_update_forum_categories_updated_at ON forum_categories;
CREATE TRIGGER trigger_update_forum_categories_updated_at
    BEFORE UPDATE ON forum_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_forum_posts_updated_at ON forum_posts;
CREATE TRIGGER trigger_update_forum_posts_updated_at
    BEFORE UPDATE ON forum_posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_forum_replies_updated_at ON forum_replies;
CREATE TRIGGER trigger_update_forum_replies_updated_at
    BEFORE UPDATE ON forum_replies
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 10. 创建管理员操作日志表
CREATE TABLE IF NOT EXISTS forum_admin_operation_logs (
    id SERIAL PRIMARY KEY,
    operator_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    operation_type VARCHAR(50) NOT NULL,
    target_type VARCHAR(20) NOT NULL,
    target_id INTEGER NOT NULL,
    target_title VARCHAR(500),
    action VARCHAR(50) NOT NULL,
    reason TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_logs_operator ON forum_admin_operation_logs(operator_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_target ON forum_admin_operation_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_operation ON forum_admin_operation_logs(operation_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created ON forum_admin_operation_logs(created_at DESC);

-- 11. 创建风控规则配置表
CREATE TABLE IF NOT EXISTS forum_risk_control_rules (
    id SERIAL PRIMARY KEY,
    rule_name VARCHAR(100) NOT NULL,
    target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('post', 'reply')),
    trigger_count INTEGER NOT NULL DEFAULT 3,
    trigger_time_window INTEGER NOT NULL DEFAULT 24,
    action_type VARCHAR(20) NOT NULL CHECK (action_type IN ('hide', 'lock', 'soft_delete', 'notify_admin')),
    is_enabled BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 12. 创建风控执行记录表
CREATE TABLE IF NOT EXISTS forum_risk_control_logs (
    id SERIAL PRIMARY KEY,
    target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id INTEGER NOT NULL,
    rule_id INTEGER REFERENCES forum_risk_control_rules(id) ON DELETE SET NULL,
    trigger_count INTEGER NOT NULL,
    action_type VARCHAR(20) NOT NULL CHECK (action_type IN ('hide', 'lock', 'soft_delete', 'notify_admin')),
    action_result VARCHAR(50),
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    executed_by VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    reverted_at TIMESTAMP WITH TIME ZONE,
    reverted_by VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_risk_control_logs_target ON forum_risk_control_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_risk_control_logs_executed ON forum_risk_control_logs(executed_at DESC);

-- 13. 插入默认风控规则（使用 NOT EXISTS 检查避免重复）
INSERT INTO forum_risk_control_rules (rule_name, target_type, trigger_count, trigger_time_window, action_type)
SELECT * FROM (VALUES
    ('帖子被举报3次自动隐藏', 'post', 3, 24, 'hide'),
    ('帖子被举报5次自动锁定', 'post', 5, 24, 'lock'),
    ('回复被举报3次自动隐藏', 'reply', 3, 24, 'hide'),
    ('回复被举报5次自动删除', 'reply', 5, 24, 'soft_delete')
) AS v(rule_name, target_type, trigger_count, trigger_time_window, action_type)
WHERE NOT EXISTS (
    SELECT 1 FROM forum_risk_control_rules 
    WHERE forum_risk_control_rules.rule_name = v.rule_name 
    AND forum_risk_control_rules.target_type = v.target_type
);

