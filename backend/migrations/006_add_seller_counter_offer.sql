-- 迁移文件6：添加卖家议价功能
-- 添加seller_counter_price字段和seller_negotiating状态

DO $body$
BEGIN
    -- 添加seller_counter_price字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flea_market_purchase_requests' 
        AND column_name = 'seller_counter_price'
    ) THEN
        ALTER TABLE flea_market_purchase_requests 
        ADD COLUMN seller_counter_price DECIMAL(12, 2);
    END IF;

    -- 修改status约束，添加seller_negotiating状态
    -- 先删除旧的约束
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'check_status_valid' 
        AND table_name = 'flea_market_purchase_requests'
    ) THEN
        ALTER TABLE flea_market_purchase_requests 
        DROP CONSTRAINT check_status_valid;
    END IF;

    -- 添加新的约束，包含seller_negotiating状态
    ALTER TABLE flea_market_purchase_requests 
    ADD CONSTRAINT check_status_valid 
    CHECK (status IN ('pending', 'seller_negotiating', 'accepted', 'rejected'));
END $body$;

