-- ===========================================
-- 迁移 016: 添加 parent_activity_id 外键约束
-- ===========================================
-- 
-- 此迁移在activities表创建后，为tasks表的parent_activity_id添加外键约束
--
-- 执行时间: 2025-11-23
-- ===========================================

-- 添加外键约束（先检查是否存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_tasks_parent_activity_id'
    ) THEN
        ALTER TABLE tasks 
        ADD CONSTRAINT fk_tasks_parent_activity_id 
        FOREIGN KEY (parent_activity_id) REFERENCES activities(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 添加索引（如果还没有）
CREATE INDEX IF NOT EXISTS ix_tasks_parent_activity_id ON tasks(parent_activity_id);

DO $$
BEGIN
    RAISE NOTICE '迁移 016 执行完成: 已添加 parent_activity_id 外键约束';
END $$;

