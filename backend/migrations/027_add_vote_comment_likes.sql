-- 迁移文件027：添加留言点赞功能
-- 包括：在leaderboard_votes表中添加like_count字段，创建vote_comment_likes表

DO $body$
BEGIN
    -- 在 leaderboard_votes 表中添加 like_count 字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'leaderboard_votes' AND column_name = 'like_count'
    ) THEN
        ALTER TABLE leaderboard_votes 
        ADD COLUMN like_count INTEGER NOT NULL DEFAULT 0;
        
        -- 添加非负约束
        ALTER TABLE leaderboard_votes 
        ADD CONSTRAINT ck_vote_like_count_non_negative 
        CHECK (like_count >= 0);
        
        -- 创建索引（可选，如果经常按点赞数排序）
        CREATE INDEX idx_vote_like_count ON leaderboard_votes(like_count DESC);
        
        RAISE NOTICE '字段 like_count 已添加到 leaderboard_votes 表';
    ELSE
        RAISE NOTICE '字段 like_count 已存在，跳过添加';
    END IF;

    -- 创建 vote_comment_likes 表
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vote_comment_likes') THEN
        CREATE TABLE vote_comment_likes (
            id SERIAL PRIMARY KEY,
            vote_id INTEGER NOT NULL REFERENCES leaderboard_votes(id) ON DELETE CASCADE,
            user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_vote_comment_like UNIQUE (vote_id, user_id)
        );

        -- 创建索引
        CREATE INDEX idx_comment_like_vote_user ON vote_comment_likes(vote_id, user_id);
        CREATE INDEX idx_comment_like_vote_id ON vote_comment_likes(vote_id);
        CREATE INDEX idx_comment_like_user_id ON vote_comment_likes(user_id);
        CREATE INDEX idx_comment_like_created_at ON vote_comment_likes(created_at DESC);

        RAISE NOTICE '表 vote_comment_likes 创建成功';
    ELSE
        RAISE NOTICE '表 vote_comment_likes 已存在，跳过创建';
    END IF;
END;
$body$;

