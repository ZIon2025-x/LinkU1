-- 确保 featured_task_experts 表的 id 和 user_id 字段保持同步
-- 添加触发器和索引

-- 步骤1: 添加 user_id 字段的索引（如果不存在）
-- 首先检查 user_id 列是否存在
DO $$
DECLARE
    user_id_exists BOOLEAN;
BEGIN
    -- 检查 user_id 列是否存在
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' AND column_name = 'user_id'
    ) INTO user_id_exists;
    
    IF NOT user_id_exists THEN
        RAISE NOTICE 'user_id column does not exist, skipping index creation';
        RETURN;
    END IF;
    
    -- 如果列存在，检查索引是否存在
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'featured_task_experts' 
        AND indexname = 'ix_featured_task_experts_user_id'
    ) THEN
        CREATE INDEX ix_featured_task_experts_user_id ON featured_task_experts(user_id);
        RAISE NOTICE 'Created index on user_id column';
    ELSE
        RAISE NOTICE 'Index on user_id column already exists, skipping';
    END IF;
END $$;

-- 步骤2: 创建或替换触发器函数（使用不同的分隔符避免冲突）
CREATE OR REPLACE FUNCTION sync_featured_task_experts_id_user_id()
RETURNS TRIGGER AS $function$
BEGIN
    -- 在 INSERT 时，如果 id 和 user_id 不一致，将 id 设置为 user_id
    IF NEW.id IS DISTINCT FROM NEW.user_id THEN
        NEW.id := NEW.user_id;
    END IF;
    
    -- 在 UPDATE 时，如果 user_id 被修改，同步更新 id
    IF TG_OP = 'UPDATE' AND NEW.user_id IS DISTINCT FROM OLD.user_id THEN
        NEW.id := NEW.user_id;
    ELSIF TG_OP = 'UPDATE' AND NEW.id IS DISTINCT FROM NEW.user_id THEN
        -- 如果 id 和 user_id 不一致，将 id 设置为 user_id
        NEW.id := NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$function$ LANGUAGE plpgsql;

-- 步骤3: 删除旧的触发器（如果存在）
DROP TRIGGER IF EXISTS trigger_sync_featured_task_experts_id_user_id ON featured_task_experts;

-- 步骤4: 创建触发器（只有在 user_id 列存在时才创建）
DO $$
DECLARE
    user_id_exists BOOLEAN;
BEGIN
    -- 检查 user_id 列是否存在
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' AND column_name = 'user_id'
    ) INTO user_id_exists;
    
    IF user_id_exists THEN
        CREATE TRIGGER trigger_sync_featured_task_experts_id_user_id
            BEFORE INSERT OR UPDATE ON featured_task_experts
            FOR EACH ROW
            EXECUTE FUNCTION sync_featured_task_experts_id_user_id();
        RAISE NOTICE 'Created trigger to keep id and user_id in sync';
    ELSE
        RAISE NOTICE 'user_id column does not exist, skipping trigger creation';
    END IF;
END $$;

-- 步骤5: 修复现有数据中 id 和 user_id 不一致的记录（如果 user_id 列存在）
DO $$
DECLARE
    user_id_exists BOOLEAN;
BEGIN
    -- 检查 user_id 列是否存在
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' AND column_name = 'user_id'
    ) INTO user_id_exists;
    
    IF user_id_exists THEN
        UPDATE featured_task_experts 
        SET id = user_id 
        WHERE id IS DISTINCT FROM user_id;
        RAISE NOTICE 'Fixed records where id and user_id were inconsistent';
    ELSE
        RAISE NOTICE 'user_id column does not exist, skipping data sync';
    END IF;
END $$;

-- 步骤6: 添加注释（如果对象存在）
DO $$
DECLARE
    func_exists BOOLEAN;
    index_exists BOOLEAN;
BEGIN
    -- 检查函数是否存在
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'sync_featured_task_experts_id_user_id'
    ) INTO func_exists;
    
    IF func_exists THEN
        COMMENT ON FUNCTION sync_featured_task_experts_id_user_id() IS 'Ensures id and user_id columns in featured_task_experts table are always in sync';
    END IF;
    
    -- 检查索引是否存在
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'featured_task_experts' 
        AND indexname = 'ix_featured_task_experts_user_id'
    ) INTO index_exists;
    
    IF index_exists THEN
        COMMENT ON INDEX ix_featured_task_experts_user_id IS 'Index on user_id column in featured_task_experts table for query optimization';
    END IF;
END $$;
