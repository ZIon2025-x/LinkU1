-- 允许 tasks 表的 deadline 字段为 NULL（支持灵活模式任务）
-- 灵活模式任务没有截止日期，deadline 应该为 NULL

-- 修改 deadline 字段，允许为 NULL（如果当前不允许为 NULL）
DO $$
BEGIN
    -- 检查 deadline 字段是否允许为 NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' 
        AND column_name = 'deadline'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE tasks 
        ALTER COLUMN deadline DROP NOT NULL;
        RAISE NOTICE '已修改 deadline 字段，允许为 NULL';
    ELSE
        RAISE NOTICE 'deadline 字段已允许为 NULL，跳过';
    END IF;
END $$;

-- 添加注释说明
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' 
        AND column_name = 'deadline'
    ) THEN
        COMMENT ON COLUMN tasks.deadline IS '任务截止日期。NULL 表示灵活模式，没有截止日期。';
        RAISE NOTICE '已添加 deadline 字段注释';
    END IF;
END $$;

