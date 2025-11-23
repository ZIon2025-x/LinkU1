-- ===========================================
-- 迁移 009: 将时间段改为UTC时间存储
-- ===========================================
-- 
-- 此迁移将 service_time_slots 表的时间段字段从 DATE + TIME 改为 DateTime(timezone=True)
-- 存储UTC时间，前端显示为英国时间
--
-- 执行时间: 2024-11-25
-- ===========================================

DO $$
DECLARE
    rec RECORD;
    slot_start_utc TIMESTAMPTZ;
    slot_end_utc TIMESTAMPTZ;
    london_tz TEXT := 'Europe/London';
BEGIN
    -- 1. 添加新字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_time_slots' 
        AND column_name = 'slot_start_datetime'
    ) THEN
        ALTER TABLE service_time_slots 
        ADD COLUMN slot_start_datetime TIMESTAMPTZ;
        
        RAISE NOTICE '已添加字段: service_time_slots.slot_start_datetime';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_time_slots' 
        AND column_name = 'slot_end_datetime'
    ) THEN
        ALTER TABLE service_time_slots 
        ADD COLUMN slot_end_datetime TIMESTAMPTZ;
        
        RAISE NOTICE '已添加字段: service_time_slots.slot_end_datetime';
    END IF;

    -- 2. 迁移现有数据：将DATE + TIME转换为UTC时间
    -- 假设现有的日期和时间是英国时间，需要转换为UTC
    FOR rec IN 
        SELECT id, slot_date, start_time, end_time 
        FROM service_time_slots 
        WHERE slot_start_datetime IS NULL OR slot_end_datetime IS NULL
    LOOP
        -- 将英国时间的日期+时间组合，然后转换为UTC
        -- 使用英国时区创建datetime，然后转换为UTC
        slot_start_utc := (rec.slot_date + rec.start_time)::TIMESTAMP AT TIME ZONE london_tz AT TIME ZONE 'UTC';
        slot_end_utc := (rec.slot_date + rec.end_time)::TIMESTAMP AT TIME ZONE london_tz AT TIME ZONE 'UTC';
        
        UPDATE service_time_slots
        SET 
            slot_start_datetime = slot_start_utc,
            slot_end_datetime = slot_end_utc
        WHERE id = rec.id;
        
        RAISE NOTICE '已迁移时间段 ID: %, 开始: %, 结束: %', rec.id, slot_start_utc, slot_end_utc;
    END LOOP;

    -- 3. 设置新字段为NOT NULL（在数据迁移完成后）
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_time_slots' 
        AND column_name = 'slot_start_datetime'
        AND is_nullable = 'YES'
    ) THEN
        -- 检查是否所有记录都已迁移
        IF NOT EXISTS (
            SELECT 1 FROM service_time_slots 
            WHERE slot_start_datetime IS NULL OR slot_end_datetime IS NULL
        ) THEN
            ALTER TABLE service_time_slots 
            ALTER COLUMN slot_start_datetime SET NOT NULL;
            
            ALTER TABLE service_time_slots 
            ALTER COLUMN slot_end_datetime SET NOT NULL;
            
            RAISE NOTICE '已设置新字段为NOT NULL';
        ELSE
            RAISE WARNING '存在未迁移的数据，请先完成数据迁移';
        END IF;
    END IF;

    -- 4. 删除旧字段
    -- 注意：删除前确保所有代码都已更新
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

    -- 5. 更新索引和约束
    -- 删除旧索引
    DROP INDEX IF EXISTS ix_service_time_slots_slot_date;
    DROP INDEX IF EXISTS ix_service_time_slots_service_date;
    DROP INDEX IF EXISTS ix_service_time_slots_service_id_slot_date;
    
    -- 创建新索引
    CREATE INDEX IF NOT EXISTS ix_service_time_slots_slot_start_datetime 
        ON service_time_slots(slot_start_datetime);
    CREATE INDEX IF NOT EXISTS ix_service_time_slots_service_start 
        ON service_time_slots(service_id, slot_start_datetime);
    
    -- 删除旧唯一约束
    ALTER TABLE service_time_slots DROP CONSTRAINT IF EXISTS uq_service_time_slot;
    
    -- 创建新唯一约束
    ALTER TABLE service_time_slots 
    ADD CONSTRAINT uq_service_time_slot 
        UNIQUE (service_id, slot_start_datetime, slot_end_datetime);
    
    RAISE NOTICE '已更新索引和约束';

    RAISE NOTICE '迁移 009 执行完成: 时间段已转换为UTC时间存储';
END $$;

