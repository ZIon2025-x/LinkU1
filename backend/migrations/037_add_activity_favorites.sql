-- 创建活动收藏表
CREATE TABLE IF NOT EXISTS activity_favorites (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    activity_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uix_user_activity_favorite UNIQUE (user_id, activity_id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_activity_favorites_user_id ON activity_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_favorites_activity_id ON activity_favorites(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_favorites_created_at ON activity_favorites(created_at);

-- 添加注释
COMMENT ON TABLE activity_favorites IS '活动收藏表';
COMMENT ON COLUMN activity_favorites.id IS '收藏ID';
COMMENT ON COLUMN activity_favorites.user_id IS '用户ID';
COMMENT ON COLUMN activity_favorites.activity_id IS '活动ID';
COMMENT ON COLUMN activity_favorites.created_at IS '收藏时间';

