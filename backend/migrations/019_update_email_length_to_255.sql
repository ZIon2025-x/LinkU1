-- 迁移：更新邮箱字段长度从120到255
-- 原因：验证器允许最多254字符（RFC 5321标准），但数据库字段只有120字符
-- 这会导致验证通过但数据库插入失败的问题

DO $$
BEGIN
    -- 更新 users 表的 email 字段
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'email' 
        AND character_maximum_length = 120
    ) THEN
        ALTER TABLE users 
        ALTER COLUMN email TYPE VARCHAR(255);
        RAISE NOTICE 'Updated users.email from VARCHAR(120) to VARCHAR(255)';
    ELSE
        RAISE NOTICE 'users.email is already VARCHAR(255) or does not exist';
    END IF;

    -- 更新 customer_service 表的 email 字段
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service' 
        AND column_name = 'email' 
        AND character_maximum_length = 120
    ) THEN
        ALTER TABLE customer_service 
        ALTER COLUMN email TYPE VARCHAR(255);
        RAISE NOTICE 'Updated customer_service.email from VARCHAR(120) to VARCHAR(255)';
    ELSE
        RAISE NOTICE 'customer_service.email is already VARCHAR(255) or does not exist';
    END IF;

    -- 更新 admin_users 表的 email 字段
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'admin_users' 
        AND column_name = 'email' 
        AND character_maximum_length = 120
    ) THEN
        ALTER TABLE admin_users 
        ALTER COLUMN email TYPE VARCHAR(255);
        RAISE NOTICE 'Updated admin_users.email from VARCHAR(120) to VARCHAR(255)';
    ELSE
        RAISE NOTICE 'admin_users.email is already VARCHAR(255) or does not exist';
    END IF;

    -- 更新 pending_users 表的 email 字段
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pending_users' 
        AND column_name = 'email' 
        AND character_maximum_length = 120
    ) THEN
        ALTER TABLE pending_users 
        ALTER COLUMN email TYPE VARCHAR(255);
        RAISE NOTICE 'Updated pending_users.email from VARCHAR(120) to VARCHAR(255)';
    ELSE
        RAISE NOTICE 'pending_users.email is already VARCHAR(255) or does not exist';
    END IF;

END $$;

