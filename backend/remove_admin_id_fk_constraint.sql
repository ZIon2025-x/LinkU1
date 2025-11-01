-- 移除外键约束，允许 admin_id 字段存储客服ID
-- 执行此脚本后，admin_id 字段可以存储任何字符串ID（管理员ID或客服ID）

-- 1. 首先检查约束是否存在，如果存在则删除
DO $$
BEGIN
    -- 检查是否存在外键约束
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'task_cancel_requests_admin_id_fkey'
        AND table_name = 'task_cancel_requests'
    ) THEN
        -- 删除外键约束
        ALTER TABLE task_cancel_requests 
        DROP CONSTRAINT task_cancel_requests_admin_id_fkey;
        
        RAISE NOTICE '已删除外键约束: task_cancel_requests_admin_id_fkey';
    ELSE
        RAISE NOTICE '外键约束不存在，无需删除';
    END IF;
END $$;

