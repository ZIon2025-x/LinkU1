-- 迁移文件1：添加用户表字段
-- 为用户表添加跳蚤市场须知同意时间字段

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'flea_market_notice_agreed_at'
    ) THEN
        ALTER TABLE users 
        ADD COLUMN flea_market_notice_agreed_at TIMESTAMPTZ NULL;
        
        -- 添加索引（可选，如果需要按同意时间查询）
        CREATE INDEX IF NOT EXISTS idx_users_flea_market_notice_agreed_at 
        ON users(flea_market_notice_agreed_at);
    END IF;
END $$;

