-- 迁移文件026：创建自定义排行榜相关表
-- 包括：custom_leaderboards, leaderboard_items, leaderboard_votes

DO $body$
BEGIN
    -- 创建 custom_leaderboards 表
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'custom_leaderboards') THEN
        CREATE TABLE custom_leaderboards (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            location VARCHAR(100) NOT NULL,
            description TEXT,
            cover_image VARCHAR(500),
            applicant_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            application_reason TEXT,
            status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'rejected')),
            reviewed_by VARCHAR(5) REFERENCES admin_users(id) ON DELETE SET NULL,
            reviewed_at TIMESTAMPTZ,
            review_comment TEXT,
            item_count INTEGER NOT NULL DEFAULT 0,
            vote_count INTEGER NOT NULL DEFAULT 0,
            view_count INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_leaderboard_name_location UNIQUE (name, location)
        );

        -- 创建索引
        CREATE INDEX idx_leaderboard_status ON custom_leaderboards(status);
        CREATE INDEX idx_leaderboard_location ON custom_leaderboards(location);
        CREATE INDEX idx_leaderboard_vote_count ON custom_leaderboards(vote_count);
        CREATE INDEX idx_leaderboard_created_at ON custom_leaderboards(created_at DESC);
        
        -- 复合索引：优化筛选和排序查询
        CREATE INDEX idx_leaderboard_status_location ON custom_leaderboards(status, location);
        CREATE INDEX idx_leaderboard_status_created ON custom_leaderboards(status, created_at DESC);
        CREATE INDEX idx_leaderboard_status_hot ON custom_leaderboards(status, vote_count DESC, item_count DESC);

        -- 更新时间触发器
        CREATE OR REPLACE FUNCTION update_custom_leaderboards_updated_at()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;

        CREATE TRIGGER trigger_update_custom_leaderboards_updated_at
        BEFORE UPDATE ON custom_leaderboards
        FOR EACH ROW
        EXECUTE FUNCTION update_custom_leaderboards_updated_at();

        RAISE NOTICE '表 custom_leaderboards 创建成功';
    ELSE
        RAISE NOTICE '表 custom_leaderboards 已存在，跳过创建';
    END IF;

    -- 创建 leaderboard_items 表
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'leaderboard_items') THEN
        CREATE TABLE leaderboard_items (
            id SERIAL PRIMARY KEY,
            leaderboard_id INTEGER NOT NULL REFERENCES custom_leaderboards(id) ON DELETE CASCADE,
            name VARCHAR(200) NOT NULL,
            description TEXT,
            address VARCHAR(500),
            phone VARCHAR(50),
            website VARCHAR(500),
            images TEXT,  -- JSON字符串，存储为List[str]的序列化结果
            submitted_by VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            status VARCHAR(20) NOT NULL DEFAULT 'approved' CHECK (status IN ('approved', 'pending', 'rejected')),
            upvotes INTEGER NOT NULL DEFAULT 0 CHECK (upvotes >= 0),
            downvotes INTEGER NOT NULL DEFAULT 0 CHECK (downvotes >= 0),
            net_votes INTEGER NOT NULL DEFAULT 0,
            vote_score FLOAT NOT NULL DEFAULT 0.0,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_item_leaderboard_name UNIQUE (leaderboard_id, name)
        );

        -- 创建索引
        CREATE INDEX idx_item_leaderboard ON leaderboard_items(leaderboard_id);
        CREATE INDEX idx_item_vote_score ON leaderboard_items(vote_score DESC);
        CREATE INDEX idx_item_status ON leaderboard_items(status);
        CREATE INDEX idx_item_created_at ON leaderboard_items(created_at DESC);
        
        -- 复合索引：优化榜单内竞品查询
        CREATE INDEX idx_item_leaderboard_status_score ON leaderboard_items(leaderboard_id, status, vote_score DESC);
        CREATE INDEX idx_item_leaderboard_status_created ON leaderboard_items(leaderboard_id, status, created_at DESC);

        -- 更新时间触发器
        CREATE OR REPLACE FUNCTION update_leaderboard_items_updated_at()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;

        CREATE TRIGGER trigger_update_leaderboard_items_updated_at
        BEFORE UPDATE ON leaderboard_items
        FOR EACH ROW
        EXECUTE FUNCTION update_leaderboard_items_updated_at();

        RAISE NOTICE '表 leaderboard_items 创建成功';
    ELSE
        RAISE NOTICE '表 leaderboard_items 已存在，跳过创建';
    END IF;

    -- 创建 leaderboard_votes 表
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'leaderboard_votes') THEN
        CREATE TABLE leaderboard_votes (
            id SERIAL PRIMARY KEY,
            item_id INTEGER NOT NULL REFERENCES leaderboard_items(id) ON DELETE CASCADE,
            user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            vote_type VARCHAR(10) NOT NULL CHECK (vote_type IN ('upvote', 'downvote')),
            comment TEXT CHECK (LENGTH(comment) <= 500),
            is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_item_user_vote UNIQUE (item_id, user_id)
        );

        -- 创建索引
        CREATE INDEX idx_vote_item_user ON leaderboard_votes(item_id, user_id);
        CREATE INDEX idx_vote_created_at ON leaderboard_votes(created_at DESC);
        CREATE INDEX idx_vote_item_id ON leaderboard_votes(item_id);

        -- 更新时间触发器
        CREATE OR REPLACE FUNCTION update_leaderboard_votes_updated_at()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;

        CREATE TRIGGER trigger_update_leaderboard_votes_updated_at
        BEFORE UPDATE ON leaderboard_votes
        FOR EACH ROW
        EXECUTE FUNCTION update_leaderboard_votes_updated_at();

        RAISE NOTICE '表 leaderboard_votes 创建成功';
    ELSE
        RAISE NOTICE '表 leaderboard_votes 已存在，跳过创建';
    END IF;
END;
$body$;

