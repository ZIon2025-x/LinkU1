-- 迁移 020: 为 task_time_slot_relations 和 activity_time_slot_relations 表添加时间段字段
-- 目的：在关联表中冗余存储时间段信息，避免关联查询 service_time_slots 表，提高查询性能

DO $$
BEGIN
    -- 1. 为 task_time_slot_relations 表添加时间段字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_time_slot_relations' 
        AND column_name = 'slot_start_datetime'
    ) THEN
        ALTER TABLE task_time_slot_relations 
        ADD COLUMN slot_start_datetime TIMESTAMPTZ NULL,
        ADD COLUMN slot_end_datetime TIMESTAMPTZ NULL;
        
        -- 从 service_time_slots 表迁移现有数据
        UPDATE task_time_slot_relations ttsr
        SET 
            slot_start_datetime = sts.slot_start_datetime,
            slot_end_datetime = sts.slot_end_datetime
        FROM service_time_slots sts
        WHERE ttsr.time_slot_id = sts.id 
        AND ttsr.slot_start_datetime IS NULL;
        
        -- 创建索引
        CREATE INDEX IF NOT EXISTS ix_task_time_slot_relations_start_datetime 
        ON task_time_slot_relations(slot_start_datetime);
        
        CREATE INDEX IF NOT EXISTS ix_task_time_slot_relations_end_datetime 
        ON task_time_slot_relations(slot_end_datetime);
        
        RAISE NOTICE '已为 task_time_slot_relations 表添加时间段字段';
    END IF;

    -- 2. 为 activity_time_slot_relations 表添加时间段字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_time_slot_relations' 
        AND column_name = 'slot_start_datetime'
    ) THEN
        ALTER TABLE activity_time_slot_relations 
        ADD COLUMN slot_start_datetime TIMESTAMPTZ NULL,
        ADD COLUMN slot_end_datetime TIMESTAMPTZ NULL;
        
        -- 从 service_time_slots 表迁移现有数据
        UPDATE activity_time_slot_relations atsr
        SET 
            slot_start_datetime = sts.slot_start_datetime,
            slot_end_datetime = sts.slot_end_datetime
        FROM service_time_slots sts
        WHERE atsr.time_slot_id = sts.id 
        AND atsr.slot_start_datetime IS NULL;
        
        -- 创建索引
        CREATE INDEX IF NOT EXISTS ix_activity_time_slot_relations_start_datetime 
        ON activity_time_slot_relations(slot_start_datetime);
        
        CREATE INDEX IF NOT EXISTS ix_activity_time_slot_relations_end_datetime 
        ON activity_time_slot_relations(slot_end_datetime);
        
        RAISE NOTICE '已为 activity_time_slot_relations 表添加时间段字段';
    END IF;

    RAISE NOTICE '迁移 020 执行完成: 时间段字段已添加到关联表';
END $$;

