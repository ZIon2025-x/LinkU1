-- ===========================================
-- 迁移 014: 添加 parent_activity_id 字段到 tasks 表
-- ===========================================
-- 
-- 此迁移添加 parent_activity_id 字段，用于关联任务到活动
-- 当用户申请非时间段服务的多人活动时，会创建一个新任务，该任务关联到活动
--
-- 执行时间: 2025-11-23
-- ===========================================

-- 添加 parent_activity_id 字段（注意：activities表在015迁移中创建，所以这里先不添加外键约束）
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS parent_activity_id INTEGER;

-- 在015迁移后，需要添加外键约束：
-- ALTER TABLE tasks 
-- ADD CONSTRAINT fk_tasks_parent_activity_id 
-- FOREIGN KEY (parent_activity_id) REFERENCES activities(id) ON DELETE SET NULL;

-- 创建索引
CREATE INDEX IF NOT EXISTS ix_tasks_parent_activity_id ON tasks(parent_activity_id);

-- 添加注释
COMMENT ON COLUMN tasks.parent_activity_id IS '关联的多人活动ID（如果此任务是从活动申请创建的）';

DO $$
BEGIN
    RAISE NOTICE '迁移 014 执行完成: 已添加 parent_activity_id 字段到 tasks 表';
END $$;

