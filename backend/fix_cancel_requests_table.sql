-- 修复 task_cancel_requests 表的外键约束
-- 执行此脚本来立即修复数据库结构

-- 1. 移除所有旧的 admin_id 外键约束（可能指向 users 表）
DO $$
DECLARE
    constraint_name_var TEXT;
BEGIN
    -- 查找所有相关的约束
    FOR constraint_name_var IN
        SELECT constraint_name 
        FROM information_schema.table_constraints 
        WHERE constraint_name LIKE 'task_cancel_requests_admin_id%'
        AND table_name = 'task_cancel_requests'
        AND constraint_type = 'FOREIGN KEY'
    LOOP
        EXECUTE format('ALTER TABLE task_cancel_requests DROP CONSTRAINT IF EXISTS %I', constraint_name_var);
        RAISE NOTICE '已移除约束: %', constraint_name_var;
    END LOOP;
END $$;

-- 2. 添加 service_id 字段（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'task_cancel_requests'
        AND column_name = 'service_id'
    ) THEN
        ALTER TABLE task_cancel_requests 
        ADD COLUMN service_id VARCHAR(6);
        
        ALTER TABLE task_cancel_requests 
        ADD CONSTRAINT task_cancel_requests_service_id_fkey 
        FOREIGN KEY (service_id) REFERENCES customer_service(id);
        
        RAISE NOTICE '已添加 service_id 字段';
    ELSE
        RAISE NOTICE 'service_id 字段已存在';
    END IF;
END $$;

-- 3. 修改 admin_id 字段类型为 VARCHAR(5)（如果还不是）
DO $$
BEGIN
    -- 检查字段类型
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'task_cancel_requests'
        AND column_name = 'admin_id'
        AND (data_type != 'character varying' OR character_maximum_length != 5)
    ) THEN
        ALTER TABLE task_cancel_requests 
        ALTER COLUMN admin_id TYPE VARCHAR(5) USING admin_id::VARCHAR(5);
        RAISE NOTICE '已修改 admin_id 字段类型为 VARCHAR(5)';
    ELSE
        RAISE NOTICE 'admin_id 字段类型已正确';
    END IF;
END $$;

-- 4. 添加新的外键约束（指向 admin_users 表）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'task_cancel_requests_admin_id_fkey'
        AND table_name = 'task_cancel_requests'
    ) THEN
        ALTER TABLE task_cancel_requests 
        ADD CONSTRAINT task_cancel_requests_admin_id_fkey 
        FOREIGN KEY (admin_id) REFERENCES admin_users(id);
        RAISE NOTICE '已添加 admin_id 外键约束（指向 admin_users）';
    ELSE
        RAISE NOTICE 'admin_id 外键约束已存在';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '添加外键约束时出错（可能已存在）: %', SQLERRM;
END $$;

