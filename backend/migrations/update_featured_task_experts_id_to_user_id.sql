-- 修改 featured_task_experts 表的 id 字段为 user_id
-- 执行前请先备份数据库
-- 注意：此迁移假设表已存在，并且有 user_id 列

-- 步骤1: 检查表是否存在，如果不存在则跳过
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'featured_task_experts') THEN
        RAISE NOTICE '表 featured_task_experts 不存在，跳过迁移';
        RETURN;
    END IF;
END $$;

-- 步骤2: 检查 id 列的类型，如果是 INTEGER 则需要迁移
DO $$
DECLARE
    id_type TEXT;
    id_exists BOOLEAN;
    user_id_exists BOOLEAN;
BEGIN
    -- 检查 id 列是否存在
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' AND column_name = 'id'
    ) INTO id_exists;
    
    -- 检查 user_id 列是否存在
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' AND column_name = 'user_id'
    ) INTO user_id_exists;
    
    IF NOT id_exists THEN
        RAISE NOTICE 'id 列不存在，可能表结构已更新，跳过迁移';
        RETURN;
    END IF;
    
    -- 获取 id 列的类型
    SELECT data_type INTO id_type
    FROM information_schema.columns
    WHERE table_name = 'featured_task_experts' AND column_name = 'id';
    
    IF id_type = 'integer' THEN
        RAISE NOTICE '检测到 id 列为 INTEGER 类型，开始迁移...';
    ELSIF id_type = 'character varying' OR id_type = 'varchar' THEN
        RAISE NOTICE 'id 列已经是 VARCHAR 类型，可能已迁移过';
        -- 即使已迁移，如果 user_id 列不存在，也需要添加它
        IF NOT user_id_exists THEN
            RAISE NOTICE '但 user_id 列不存在，将添加 user_id 列';
        END IF;
    ELSE
        RAISE NOTICE 'id 列类型为 %，跳过迁移', id_type;
        RETURN;
    END IF;
END $$;

-- 步骤3: 如果 user_id 列存在，删除所有 user_id 为 NULL 的记录（这些记录无法迁移）
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' AND column_name = 'user_id'
    ) THEN
        DELETE FROM featured_task_experts WHERE user_id IS NULL;
        RAISE NOTICE '已删除 user_id 为 NULL 的记录';
    END IF;
END $$;

-- 步骤4: 删除外键约束（如果存在）
ALTER TABLE featured_task_experts 
    DROP CONSTRAINT IF EXISTS featured_task_experts_pkey CASCADE,
    DROP CONSTRAINT IF EXISTS featured_task_experts_user_id_fkey CASCADE;

-- 步骤4.1: 删除索引（如果存在）- 必须单独执行，不能在 ALTER TABLE 中使用
DROP INDEX IF EXISTS ix_task_experts_user_id;
DROP INDEX IF EXISTS ix_featured_task_experts_user_id;

-- 步骤5: 删除旧的 INTEGER 类型的 id 列
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' 
        AND column_name = 'id' 
        AND data_type = 'integer'
    ) THEN
        ALTER TABLE featured_task_experts DROP COLUMN id;
        RAISE NOTICE '已删除旧的 INTEGER 类型的 id 列';
    END IF;
END $$;

-- 步骤6: 如果 user_id 列存在且 id 列不存在，将 user_id 重命名为 id
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' 
        AND column_name = 'user_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' 
        AND column_name = 'id'
    ) THEN
        ALTER TABLE featured_task_experts RENAME COLUMN user_id TO id;
        RAISE NOTICE '已将 user_id 列重命名为 id';
    END IF;
END $$;

-- 步骤7: 设置 id 为主键和外键（如果还不是）
DO $$
BEGIN
    -- 检查是否已有主键
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'featured_task_experts' 
        AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE featured_task_experts ADD PRIMARY KEY (id);
        RAISE NOTICE '已设置 id 为主键';
    END IF;
    
    -- 检查是否已有外键
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'featured_task_experts' 
        AND constraint_name = 'featured_task_experts_id_fkey'
    ) THEN
        ALTER TABLE featured_task_experts
            ADD CONSTRAINT featured_task_experts_id_fkey 
            FOREIGN KEY (id) REFERENCES users(id) ON DELETE CASCADE;
        RAISE NOTICE '已添加 id 的外键约束';
    END IF;
END $$;

-- 步骤8: 重新添加 user_id 列（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE featured_task_experts
            ADD COLUMN user_id VARCHAR(8) NOT NULL DEFAULT '';
        RAISE NOTICE '已添加 user_id 列';
        
        -- 将 id 的值复制到 user_id
        UPDATE featured_task_experts SET user_id = id;
        RAISE NOTICE '已将 id 的值复制到 user_id';
        
        -- 移除默认值
        ALTER TABLE featured_task_experts ALTER COLUMN user_id DROP DEFAULT;
        
        -- 添加 user_id 的外键约束
        ALTER TABLE featured_task_experts
            ADD CONSTRAINT featured_task_experts_user_id_fkey 
            FOREIGN KEY (user_id) REFERENCES users(id);
        RAISE NOTICE '已添加 user_id 的外键约束';
        
        -- 添加唯一约束
        ALTER TABLE featured_task_experts
            ADD CONSTRAINT featured_task_experts_user_id_unique UNIQUE (user_id);
        RAISE NOTICE '已添加 user_id 的唯一约束';
    END IF;
END $$;

-- 完成：添加注释（如果列存在）
DO $$
BEGIN
    -- 添加 id 列的注释
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' AND column_name = 'id'
    ) THEN
        COMMENT ON COLUMN featured_task_experts.id IS '主键，使用用户ID';
    END IF;
    
    -- 添加 user_id 列的注释（如果列存在）
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' AND column_name = 'user_id'
    ) THEN
        COMMENT ON COLUMN featured_task_experts.user_id IS '用户ID（与id相同，保留字段以保持兼容性）';
    END IF;
END $$;
