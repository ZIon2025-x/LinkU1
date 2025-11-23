-- ===========================================
-- 迁移 008: 添加服务时间段功能
-- ===========================================
-- 
-- 此迁移添加以下内容：
-- 1. 为 task_expert_services 表添加时间段相关字段
-- 2. 创建 service_time_slots 表
-- 3. 为 service_applications 表添加 time_slot_id 字段
--
-- 执行时间: 2024-10-01
-- ===========================================

DO $$
BEGIN
    -- 1. 为 task_expert_services 表添加时间段相关字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_expert_services' 
        AND column_name = 'has_time_slots'
    ) THEN
        ALTER TABLE task_expert_services 
        ADD COLUMN has_time_slots BOOLEAN NOT NULL DEFAULT FALSE;
        
        RAISE NOTICE '已添加字段: task_expert_services.has_time_slots';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_expert_services' 
        AND column_name = 'time_slot_duration_minutes'
    ) THEN
        ALTER TABLE task_expert_services 
        ADD COLUMN time_slot_duration_minutes INTEGER;
        
        RAISE NOTICE '已添加字段: task_expert_services.time_slot_duration_minutes';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_expert_services' 
        AND column_name = 'time_slot_start_time'
    ) THEN
        ALTER TABLE task_expert_services 
        ADD COLUMN time_slot_start_time TIME;
        
        RAISE NOTICE '已添加字段: task_expert_services.time_slot_start_time';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_expert_services' 
        AND column_name = 'time_slot_end_time'
    ) THEN
        ALTER TABLE task_expert_services 
        ADD COLUMN time_slot_end_time TIME;
        
        RAISE NOTICE '已添加字段: task_expert_services.time_slot_end_time';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_expert_services' 
        AND column_name = 'participants_per_slot'
    ) THEN
        ALTER TABLE task_expert_services 
        ADD COLUMN participants_per_slot INTEGER;
        
        RAISE NOTICE '已添加字段: task_expert_services.participants_per_slot';
    END IF;

    -- 2. 创建 service_time_slots 表
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'service_time_slots'
    ) THEN
        CREATE TABLE service_time_slots (
            id SERIAL PRIMARY KEY,
            service_id INTEGER NOT NULL REFERENCES task_expert_services(id) ON DELETE CASCADE,
            slot_date DATE NOT NULL,
            start_time TIME NOT NULL,
            end_time TIME NOT NULL,
            price_per_participant DECIMAL(12, 2) NOT NULL,
            max_participants INTEGER NOT NULL,
            current_participants INTEGER NOT NULL DEFAULT 0,
            is_available BOOLEAN NOT NULL DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT uq_service_time_slot UNIQUE (service_id, slot_date, start_time, end_time)
        );
        
        -- 创建索引
        CREATE INDEX IF NOT EXISTS ix_service_time_slots_service_id ON service_time_slots(service_id);
        CREATE INDEX IF NOT EXISTS ix_service_time_slots_slot_date ON service_time_slots(slot_date);
        CREATE INDEX IF NOT EXISTS ix_service_time_slots_service_date ON service_time_slots(service_id, slot_date);
        
        RAISE NOTICE '已创建表: service_time_slots';
    END IF;

    -- 3. 为 service_applications 表添加 time_slot_id 字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_applications' 
        AND column_name = 'time_slot_id'
    ) THEN
        ALTER TABLE service_applications 
        ADD COLUMN time_slot_id INTEGER REFERENCES service_time_slots(id) ON DELETE SET NULL;
        
        -- 创建索引
        CREATE INDEX IF NOT EXISTS ix_service_applications_time_slot_id ON service_applications(time_slot_id);
        
        RAISE NOTICE '已添加字段: service_applications.time_slot_id';
    END IF;

    RAISE NOTICE '迁移 008 执行完成: 服务时间段功能已添加';
END $$;

