-- 迁移文件3：创建购买申请表（必建，用于议价购买流程）

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'flea_market_purchase_requests') THEN
        CREATE TABLE flea_market_purchase_requests (
            id SERIAL PRIMARY KEY,
            item_id INTEGER NOT NULL REFERENCES flea_market_items(id) ON DELETE CASCADE,
            buyer_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            proposed_price DECIMAL(12, 2),  -- 议价金额（如果买家议价）
            message TEXT,  -- 购买留言
            status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        -- 索引
        CREATE INDEX idx_flea_market_purchase_requests_item_id ON flea_market_purchase_requests(item_id);
        CREATE INDEX idx_flea_market_purchase_requests_buyer_id ON flea_market_purchase_requests(buyer_id);
        CREATE INDEX idx_flea_market_purchase_requests_status ON flea_market_purchase_requests(status);
        CREATE INDEX idx_flea_market_purchase_requests_created_at ON flea_market_purchase_requests(created_at);

        -- 唯一约束：一个买家对同一个商品只能有一个pending状态的申请
        CREATE UNIQUE INDEX idx_flea_market_purchase_requests_unique_pending 
            ON flea_market_purchase_requests(item_id, buyer_id) 
            WHERE status = 'pending';

        -- 更新时间触发器
        CREATE OR REPLACE FUNCTION update_flea_market_purchase_requests_updated_at()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;

        CREATE TRIGGER trigger_update_flea_market_purchase_requests_updated_at
            BEFORE UPDATE ON flea_market_purchase_requests
            FOR EACH ROW
            EXECUTE FUNCTION update_flea_market_purchase_requests_updated_at();
    END IF;
END $$;

