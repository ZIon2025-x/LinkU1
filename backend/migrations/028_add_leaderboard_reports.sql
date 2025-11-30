-- 迁移文件028：添加排行榜举报功能
-- 包括：leaderboard_reports表（榜单举报）和item_reports表（竞品举报）

DO $body$
BEGIN
    -- 创建 leaderboard_reports 表（榜单举报表）
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'leaderboard_reports') THEN
        CREATE TABLE leaderboard_reports (
            id SERIAL PRIMARY KEY,
            leaderboard_id INTEGER NOT NULL REFERENCES custom_leaderboards(id) ON DELETE CASCADE,
            reporter_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            reason VARCHAR(500) NOT NULL,
            description TEXT,
            status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
            reviewed_by VARCHAR(5) REFERENCES admin_users(id) ON DELETE SET NULL,
            reviewed_at TIMESTAMPTZ,
            admin_comment TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_leaderboard_report UNIQUE (leaderboard_id, reporter_id)
        );

        -- 创建索引
        CREATE INDEX idx_leaderboard_report_status ON leaderboard_reports(status);
        CREATE INDEX idx_leaderboard_report_created_at ON leaderboard_reports(created_at DESC);
        CREATE INDEX idx_leaderboard_report_leaderboard_id ON leaderboard_reports(leaderboard_id);
        CREATE INDEX idx_leaderboard_report_reporter_id ON leaderboard_reports(reporter_id);

        -- 更新时间触发器
        CREATE OR REPLACE FUNCTION update_leaderboard_reports_updated_at()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;

        CREATE TRIGGER trigger_update_leaderboard_reports_updated_at
        BEFORE UPDATE ON leaderboard_reports
        FOR EACH ROW
        EXECUTE FUNCTION update_leaderboard_reports_updated_at();

        RAISE NOTICE '表 leaderboard_reports 创建成功';
    ELSE
        RAISE NOTICE '表 leaderboard_reports 已存在，跳过创建';
    END IF;

    -- 创建 item_reports 表（竞品举报表）
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'item_reports') THEN
        CREATE TABLE item_reports (
            id SERIAL PRIMARY KEY,
            item_id INTEGER NOT NULL REFERENCES leaderboard_items(id) ON DELETE CASCADE,
            reporter_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            reason VARCHAR(500) NOT NULL,
            description TEXT,
            status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
            reviewed_by VARCHAR(5) REFERENCES admin_users(id) ON DELETE SET NULL,
            reviewed_at TIMESTAMPTZ,
            admin_comment TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_item_report UNIQUE (item_id, reporter_id)
        );

        -- 创建索引
        CREATE INDEX idx_item_report_status ON item_reports(status);
        CREATE INDEX idx_item_report_created_at ON item_reports(created_at DESC);
        CREATE INDEX idx_item_report_item_id ON item_reports(item_id);
        CREATE INDEX idx_item_report_reporter_id ON item_reports(reporter_id);

        -- 更新时间触发器
        CREATE OR REPLACE FUNCTION update_item_reports_updated_at()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;

        CREATE TRIGGER trigger_update_item_reports_updated_at
        BEFORE UPDATE ON item_reports
        FOR EACH ROW
        EXECUTE FUNCTION update_item_reports_updated_at();

        RAISE NOTICE '表 item_reports 创建成功';
    ELSE
        RAISE NOTICE '表 item_reports 已存在，跳过创建';
    END IF;
END;
$body$;

