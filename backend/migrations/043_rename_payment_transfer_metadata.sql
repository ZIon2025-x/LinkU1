-- 重命名 payment_transfers 表的 metadata 列为 extra_metadata
-- 迁移文件：043_rename_payment_transfer_metadata.sql
-- 原因：SQLAlchemy 的 Declarative API 中 metadata 是保留字

-- 检查列是否存在，如果存在则重命名
DO $$
BEGIN
    -- 检查 metadata 列是否存在
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'payment_transfers' 
        AND column_name = 'metadata'
    ) THEN
        -- 重命名列
        ALTER TABLE payment_transfers 
        RENAME COLUMN metadata TO extra_metadata;
        
        RAISE NOTICE '已重命名 payment_transfers.metadata 为 extra_metadata';
    ELSE
        RAISE NOTICE 'payment_transfers.metadata 列不存在，跳过重命名';
    END IF;
END $$;

-- 更新注释
COMMENT ON COLUMN payment_transfers.extra_metadata IS '额外元数据（JSON格式，使用 extra_metadata 避免与 SQLAlchemy 的 metadata 属性冲突）';

