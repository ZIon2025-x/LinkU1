-- ===========================================
-- 迁移 010: 删除时间段表的旧列
-- ===========================================
-- 
-- 此迁移删除 service_time_slots 表中的旧列：
-- - slot_date (DATE)
-- - start_time (TIME)
-- - end_time (TIME)
-- 
-- 这些列已被 slot_start_datetime 和 slot_end_datetime 替代
--
-- 执行时间: 2025-11-23
-- ===========================================

DO $$
BEGIN
    -- 删除旧列（如果存在）
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_time_slots' 
        AND column_name = 'slot_date'
    ) THEN
        -- 先删除依赖这些字段的约束和索引（如果存在）
        ALTER TABLE service_time_slots DROP CONSTRAINT IF EXISTS uq_service_time_slot_old;
        DROP INDEX IF EXISTS ix_service_time_slots_slot_date;
        DROP INDEX IF EXISTS ix_service_time_slots_service_date;
        DROP INDEX IF EXISTS ix_service_time_slots_service_id_slot_date;
        
        ALTER TABLE service_time_slots DROP COLUMN slot_date;
        RAISE NOTICE '已删除字段: service_time_slots.slot_date';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_time_slots' 
        AND column_name = 'start_time'
    ) THEN
        ALTER TABLE service_time_slots DROP COLUMN start_time;
        RAISE NOTICE '已删除字段: service_time_slots.start_time';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_time_slots' 
        AND column_name = 'end_time'
    ) THEN
        ALTER TABLE service_time_slots DROP COLUMN end_time;
        RAISE NOTICE '已删除字段: service_time_slots.end_time';
    END IF;

    RAISE NOTICE '迁移 010 执行完成: 已删除时间段表的旧列';
END $$;

