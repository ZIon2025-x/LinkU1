-- ===========================================
-- 迁移 018: 修复 parent_activity_id 外键约束并添加数据库约束
-- ===========================================
--
-- 此迁移修复以下问题：
-- 1. 将 parent_activity_id 外键从 ON DELETE SET NULL 改为 ON DELETE RESTRICT
-- 2. 添加固定时间段唯一约束（防止时间段冲突）
-- 3. 添加 TaskParticipant.activity_id 冗余字段（性能优化）
--
-- 执行时间: 2025-11-23
-- ===========================================

BEGIN;

-- 步骤1: 删除旧的外键约束
ALTER TABLE tasks 
DROP CONSTRAINT IF EXISTS fk_tasks_parent_activity_id;

ALTER TABLE tasks 
DROP CONSTRAINT IF EXISTS fk_parent_activity;

-- 步骤2: 添加新的外键约束（ON DELETE RESTRICT）
-- 先检查是否已存在（可能由016迁移创建）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_tasks_parent_activity_id'
    ) THEN
        ALTER TABLE tasks 
        ADD CONSTRAINT fk_tasks_parent_activity_id 
        FOREIGN KEY (parent_activity_id) REFERENCES activities(id) ON DELETE RESTRICT;
    ELSE
        -- 如果已存在，删除并重新创建（改为 RESTRICT）
        ALTER TABLE tasks 
        DROP CONSTRAINT fk_tasks_parent_activity_id;
        
        ALTER TABLE tasks 
        ADD CONSTRAINT fk_tasks_parent_activity_id 
        FOREIGN KEY (parent_activity_id) REFERENCES activities(id) ON DELETE RESTRICT;
    END IF;
END $$;

-- 步骤2.1: 为 activity_time_slot_relations 表添加外键约束（activities表已在015迁移中创建）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_activity_time_slot_relations_activity_id'
    ) THEN
        ALTER TABLE activity_time_slot_relations 
        ADD CONSTRAINT fk_activity_time_slot_relations_activity_id 
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 步骤3: 添加固定时间段唯一约束（防止时间段冲突）
-- 注意：PostgreSQL 的部分唯一索引语法
CREATE UNIQUE INDEX IF NOT EXISTS uq_activity_time_slot_fixed 
ON activity_time_slot_relations(time_slot_id) 
WHERE relation_mode = 'fixed' AND time_slot_id IS NOT NULL;

-- 步骤4: 添加 TaskParticipant.activity_id 冗余字段（性能优化）
ALTER TABLE task_participants 
ADD COLUMN IF NOT EXISTS activity_id INTEGER;

-- 添加外键约束
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_task_participants_activity_id'
    ) THEN
        ALTER TABLE task_participants 
        ADD CONSTRAINT fk_task_participants_activity_id 
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 添加索引
CREATE INDEX IF NOT EXISTS ix_task_participants_activity_id 
ON task_participants(activity_id);

-- 步骤5: 添加 tasks.originating_user_id 字段（记录实际申请人）
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS originating_user_id VARCHAR(8);

-- 添加外键约束
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_tasks_originating_user_id'
    ) THEN
        ALTER TABLE tasks 
        ADD CONSTRAINT fk_tasks_originating_user_id 
        FOREIGN KEY (originating_user_id) REFERENCES users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 添加索引
CREATE INDEX IF NOT EXISTS ix_tasks_originating_user_id 
ON tasks(originating_user_id);

-- 步骤6: 更新现有记录的 activity_id（从任务的 parent_activity_id 获取）
UPDATE task_participants tp
SET activity_id = t.parent_activity_id
FROM tasks t
WHERE tp.task_id = t.id 
AND t.parent_activity_id IS NOT NULL
AND tp.activity_id IS NULL;

-- 步骤7: 更新现有任务的 originating_user_id（从 taker_id 获取，因为任务方向已修复）
UPDATE tasks t
SET originating_user_id = t.taker_id
WHERE t.parent_activity_id IS NOT NULL
AND t.originating_user_id IS NULL
AND t.taker_id IS NOT NULL;

-- 添加注释
COMMENT ON COLUMN task_participants.activity_id IS '冗余字段：关联的活动ID（从任务的parent_activity_id获取，用于性能优化）';
COMMENT ON COLUMN tasks.originating_user_id IS '记录实际申请人（如果任务是从活动申请创建的）';

COMMIT;

DO $$
BEGIN
    RAISE NOTICE '迁移 018 执行完成: 已修复外键约束并添加数据库约束';
END $$;

