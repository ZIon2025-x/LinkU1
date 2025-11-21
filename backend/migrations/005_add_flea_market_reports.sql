-- 迁移文件5：创建商品举报表

DO $body$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'flea_market_reports') THEN
        CREATE TABLE flea_market_reports (
            id SERIAL PRIMARY KEY,
            item_id INTEGER NOT NULL REFERENCES flea_market_items(id) ON DELETE CASCADE,
            reporter_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            reason VARCHAR(100) NOT NULL,  -- 举报原因：spam, fraud, inappropriate, other
            description TEXT,  -- 详细描述
            status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'resolved', 'rejected')),
            admin_comment TEXT,  -- 管理员处理意见
            handled_by VARCHAR(5) REFERENCES admin_users(id),  -- 处理管理员
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            handled_at TIMESTAMPTZ  -- 处理时间
        );

        -- 索引
        CREATE INDEX idx_flea_market_reports_item_id ON flea_market_reports(item_id);
        CREATE INDEX idx_flea_market_reports_reporter_id ON flea_market_reports(reporter_id);
        CREATE INDEX idx_flea_market_reports_status ON flea_market_reports(status);
        CREATE INDEX idx_flea_market_reports_created_at ON flea_market_reports(created_at);
        
        -- 唯一约束：一个用户对同一个商品只能举报一次（pending状态）
        CREATE UNIQUE INDEX idx_flea_market_reports_unique_pending 
            ON flea_market_reports(item_id, reporter_id) 
            WHERE status = 'pending';

        -- 更新时间触发器
        CREATE OR REPLACE FUNCTION update_flea_market_reports_updated_at()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;

        CREATE TRIGGER trigger_update_flea_market_reports_updated_at
            BEFORE UPDATE ON flea_market_reports
            FOR EACH ROW
            EXECUTE FUNCTION update_flea_market_reports_updated_at();
    END IF;
END $body$;

