-- 迁移文件2：创建跳蚤市场商品表

DO $body$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'flea_market_items') THEN
        CREATE TABLE flea_market_items (
            id SERIAL PRIMARY KEY,
            title VARCHAR(200) NOT NULL,
            description TEXT NOT NULL,
            price DECIMAL(12, 2) NOT NULL CHECK (price >= 0),
            currency VARCHAR(3) NOT NULL DEFAULT 'GBP' CHECK (currency = 'GBP'),
            images TEXT,  -- JSON数组，例如：'["url1", "url2"]'
            location VARCHAR(100),  -- 线下交易地点或"Online"
            category VARCHAR(100),
            contact VARCHAR(200),  -- 预留字段，本期不使用
            status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'sold', 'deleted')),
            seller_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- 卖家ID
            sold_task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,  -- 售出后关联的任务ID
            view_count INTEGER NOT NULL DEFAULT 0,  -- 浏览量
            refreshed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- 刷新时间，用于自动删除机制
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        -- 单列索引
        CREATE INDEX idx_flea_market_items_seller_id ON flea_market_items(seller_id);
        CREATE INDEX idx_flea_market_items_status ON flea_market_items(status);
        CREATE INDEX idx_flea_market_items_category ON flea_market_items(category);
        CREATE INDEX idx_flea_market_items_created_at ON flea_market_items(created_at);
        CREATE INDEX idx_flea_market_items_price ON flea_market_items(price);
        CREATE INDEX idx_flea_market_items_refreshed_at ON flea_market_items(refreshed_at);  -- 用于自动删除查询
        CREATE INDEX idx_flea_market_items_view_count ON flea_market_items(view_count);  -- 用于按浏览量排序

        -- 复合索引（性能优化，必做）
        CREATE INDEX idx_flea_market_items_status_refreshed ON flea_market_items(status, refreshed_at DESC);  -- 最重要：用于列表查询和排序
        CREATE INDEX idx_flea_market_items_status_category_refreshed ON flea_market_items(status, category, refreshed_at DESC);  -- 用于分类筛选
        CREATE INDEX idx_flea_market_items_status_location_refreshed ON flea_market_items(status, location, refreshed_at DESC);  -- 用于城市筛选（可选）

        -- 全文搜索索引（如果使用PostgreSQL）
        CREATE INDEX idx_flea_market_items_title_search ON flea_market_items USING gin(to_tsvector('simple', title));
        CREATE INDEX idx_flea_market_items_description_search ON flea_market_items USING gin(to_tsvector('simple', description));

        -- 更新时间触发器（自动更新updated_at）
        CREATE OR REPLACE FUNCTION update_flea_market_items_updated_at()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;

        CREATE TRIGGER trigger_update_flea_market_items_updated_at
            BEFORE UPDATE ON flea_market_items
            FOR EACH ROW
            EXECUTE FUNCTION update_flea_market_items_updated_at();
    END IF;
END $body$;

