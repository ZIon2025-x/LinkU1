-- ===========================================
-- 迁移 088: 为 task_time_slot_relations 表的 task_id 添加唯一约束
-- ===========================================
--
-- 目的：确保一个任务（task_id）最多只能关联一个时间段
-- 即 task 和 time_slot 是一对一关系（从 task 方向看）
-- 注意：一个 time_slot 仍然可以被多个 task 关联（多人活动场景）
--
-- 约束仅对 fixed 模式且 time_slot_id 不为空的记录生效
-- 执行时间: 2026-02-09
-- ===========================================

-- 先检查是否已存在该约束，避免重复创建
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'uq_task_time_slot_task_id'
    ) THEN
        -- 创建部分唯一索引：一个任务只能关联一个固定时间段
        CREATE UNIQUE INDEX uq_task_time_slot_task_id
            ON task_time_slot_relations(task_id)
            WHERE relation_mode = 'fixed' AND time_slot_id IS NOT NULL;
        
        RAISE NOTICE '迁移 088 执行完成: 已为 task_time_slot_relations 表的 task_id 添加唯一约束 (uq_task_time_slot_task_id)';
    ELSE
        RAISE NOTICE '迁移 088 跳过: 约束 uq_task_time_slot_task_id 已存在';
    END IF;
END $$;
