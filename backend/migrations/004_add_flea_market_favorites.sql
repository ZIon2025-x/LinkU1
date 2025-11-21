-- 迁移文件4：创建商品收藏表

DO $body$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'flea_market_favorites') THEN
        CREATE TABLE flea_market_favorites (
            id SERIAL PRIMARY KEY,
            user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            item_id INTEGER NOT NULL REFERENCES flea_market_items(id) ON DELETE CASCADE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE(user_id, item_id)  -- 一个用户只能收藏一次同一个商品
        );

        -- 索引
        CREATE INDEX idx_flea_market_favorites_user_id ON flea_market_favorites(user_id);
        CREATE INDEX idx_flea_market_favorites_item_id ON flea_market_favorites(item_id);
        CREATE INDEX idx_flea_market_favorites_created_at ON flea_market_favorites(created_at);
    END IF;
END $body$;

