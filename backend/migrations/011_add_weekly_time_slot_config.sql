-- ===========================================
-- 迁移 011: 添加按周几设置时间段配置
-- ===========================================
-- 
-- 此迁移添加以下内容：
-- 1. 为 task_expert_services 表添加 weekly_time_slot_config 字段（JSONB）
--    用于存储按周几设置的时间段配置，例如：
--    {
--      "monday": {"start_time": "09:00:00", "end_time": "17:00:00", "enabled": true},
--      "tuesday": {"start_time": "09:00:00", "end_time": "17:00:00", "enabled": true},
--      ...
--      "sunday": {"start_time": "12:00:00", "end_time": "17:00:00", "enabled": true}
--    }
-- 2. 为 service_time_slots 表添加 is_manually_deleted 字段
--    用于标记手动删除的时间段（避免自动重新生成）
--
-- 执行时间: 2025-11-23
-- ===========================================

DO $$
BEGIN
    -- 1. 添加按周几设置时间段配置字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_expert_services' 
        AND column_name = 'weekly_time_slot_config'
    ) THEN
        ALTER TABLE task_expert_services 
        ADD COLUMN weekly_time_slot_config JSONB;
        
        RAISE NOTICE '已添加字段: task_expert_services.weekly_time_slot_config';
    END IF;

    -- 2. 添加手动删除标记字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_time_slots' 
        AND column_name = 'is_manually_deleted'
    ) THEN
        ALTER TABLE service_time_slots 
        ADD COLUMN is_manually_deleted BOOLEAN NOT NULL DEFAULT FALSE;
        
        -- 创建索引
        CREATE INDEX IF NOT EXISTS ix_service_time_slots_manually_deleted 
        ON service_time_slots(service_id, is_manually_deleted) 
        WHERE is_manually_deleted = TRUE;
        
        RAISE NOTICE '已添加字段: service_time_slots.is_manually_deleted';
    END IF;

    RAISE NOTICE '迁移 011 执行完成: 按周几设置时间段配置已添加';
END $$;

