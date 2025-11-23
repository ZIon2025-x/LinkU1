-- ===========================================
-- 迁移 016: 添加 parent_activity_id 外键约束
-- ===========================================
-- 
-- 此迁移在activities表创建后，为tasks表的parent_activity_id添加外键约束
--
-- 执行时间: 2025-11-23
-- ===========================================

-- 添加外键约束
ALTER TABLE tasks 
ADD CONSTRAINT IF NOT EXISTS fk_tasks_parent_activity_id 
FOREIGN KEY (parent_activity_id) REFERENCES activities(id) ON DELETE SET NULL;

-- 添加索引（如果还没有）
CREATE INDEX IF NOT EXISTS ix_tasks_parent_activity_id ON tasks(parent_activity_id);

RAISE NOTICE '迁移 016 执行完成: 已添加 parent_activity_id 外键约束';

