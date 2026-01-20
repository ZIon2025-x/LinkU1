-- 迁移文件59：创建论坛板块和排行榜收藏表

-- 创建论坛板块收藏表
DO $body$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'forum_category_favorites') THEN
        CREATE TABLE forum_category_favorites (
            id SERIAL PRIMARY KEY,
            category_id INTEGER NOT NULL REFERENCES forum_categories(id) ON DELETE CASCADE,
            user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_forum_category_favorites_category_user UNIQUE (category_id, user_id)
        );

        -- 索引
        CREATE INDEX idx_forum_category_favorites_user ON forum_category_favorites(user_id, created_at);
        CREATE INDEX idx_forum_category_favorites_category ON forum_category_favorites(category_id);
        
        -- 添加注释
        COMMENT ON TABLE forum_category_favorites IS '论坛板块收藏表';
        COMMENT ON COLUMN forum_category_favorites.id IS '收藏ID';
        COMMENT ON COLUMN forum_category_favorites.category_id IS '板块ID';
        COMMENT ON COLUMN forum_category_favorites.user_id IS '用户ID';
        COMMENT ON COLUMN forum_category_favorites.created_at IS '收藏时间';
    END IF;
END $body$;

-- 创建自定义排行榜收藏表
DO $body$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'custom_leaderboard_favorites') THEN
        CREATE TABLE custom_leaderboard_favorites (
            id SERIAL PRIMARY KEY,
            leaderboard_id INTEGER NOT NULL REFERENCES custom_leaderboards(id) ON DELETE CASCADE,
            user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_custom_leaderboard_favorites_leaderboard_user UNIQUE (leaderboard_id, user_id)
        );

        -- 索引
        CREATE INDEX idx_custom_leaderboard_favorites_user ON custom_leaderboard_favorites(user_id, created_at);
        CREATE INDEX idx_custom_leaderboard_favorites_leaderboard ON custom_leaderboard_favorites(leaderboard_id);
        
        -- 添加注释
        COMMENT ON TABLE custom_leaderboard_favorites IS '自定义排行榜收藏表';
        COMMENT ON COLUMN custom_leaderboard_favorites.id IS '收藏ID';
        COMMENT ON COLUMN custom_leaderboard_favorites.leaderboard_id IS '排行榜ID';
        COMMENT ON COLUMN custom_leaderboard_favorites.user_id IS '用户ID';
        COMMENT ON COLUMN custom_leaderboard_favorites.created_at IS '收藏时间';
    END IF;
END $body$;
