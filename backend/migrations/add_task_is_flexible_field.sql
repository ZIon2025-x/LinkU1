-- 在 tasks 表中添加 is_flexible 字段
-- 用于标识任务是否是灵活时间模式（1=灵活，无截止日期；0=有截止日期）

-- 添加 is_flexible 字段（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' 
        AND column_name = 'is_flexible'
    ) THEN
        ALTER TABLE tasks 
        ADD COLUMN is_flexible INTEGER DEFAULT 0;
        RAISE NOTICE '已添加 is_flexible 字段';
    ELSE
        RAISE NOTICE 'is_flexible 字段已存在，跳过';
    END IF;
END $$;

-- 添加注释说明（如果字段存在）
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' 
        AND column_name = 'is_flexible'
    ) THEN
        COMMENT ON COLUMN tasks.is_flexible IS '是否灵活时间（1=灵活，无截止日期；0=有截止日期）。如果 is_flexible=1，则 deadline 应该为 NULL。';
        RAISE NOTICE '已添加 is_flexible 字段注释';
    END IF;
END $$;

-- 添加检查约束，确保数据一致性：如果 is_flexible=1，则 deadline 必须为 NULL
-- 如果 is_flexible=0，则 deadline 应该不为 NULL（但为了向后兼容，暂时不强制）
-- 注意：使用 IF NOT EXISTS 避免重复添加约束
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_flexible_deadline_consistency'
        AND conrelid = 'tasks'::regclass
    ) THEN
        -- 先确保所有现有数据符合约束条件
        -- 如果 is_flexible 为 NULL，设置为 0
        UPDATE tasks SET is_flexible = 0 WHERE is_flexible IS NULL;
        
        -- 添加约束
        ALTER TABLE tasks 
        ADD CONSTRAINT check_flexible_deadline_consistency 
        CHECK (
            (is_flexible = 1 AND deadline IS NULL) OR 
            (is_flexible = 0)
        );
        RAISE NOTICE '已添加 check_flexible_deadline_consistency 约束';
    ELSE
        RAISE NOTICE 'check_flexible_deadline_consistency 约束已存在，跳过';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '添加约束时出错: %', SQLERRM;
        -- 不抛出异常，允许迁移继续
END $$;

