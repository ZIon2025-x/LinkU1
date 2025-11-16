-- 为 service_applications 表添加 deadline 和 is_flexible 字段
-- 用于支持用户申请服务时设置任务截至日期或选择灵活模式

-- 检查表是否存在
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'service_applications') THEN
        RAISE NOTICE '表 service_applications 不存在，跳过迁移';
        RETURN;
    END IF;
END $$;

-- 添加 deadline 字段（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_applications' 
        AND column_name = 'deadline'
    ) THEN
        ALTER TABLE service_applications
            ADD COLUMN deadline TIMESTAMPTZ;
        RAISE NOTICE '已添加 deadline 字段';
    ELSE
        RAISE NOTICE 'deadline 字段已存在，跳过';
    END IF;
END $$;

-- 添加 is_flexible 字段（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_applications' 
        AND column_name = 'is_flexible'
    ) THEN
        ALTER TABLE service_applications
            ADD COLUMN is_flexible INTEGER DEFAULT 0 CHECK (is_flexible IN (0, 1));
        RAISE NOTICE '已添加 is_flexible 字段';
    ELSE
        RAISE NOTICE 'is_flexible 字段已存在，跳过';
    END IF;
END $$;

-- 添加注释
COMMENT ON COLUMN service_applications.deadline IS '任务截至日期（如果is_flexible为0）';
COMMENT ON COLUMN service_applications.is_flexible IS '是否灵活（1=灵活，无截至日期；0=有截至日期）';

