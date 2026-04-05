-- ===========================================
-- 迁移 160: 给 task_expert_services 添加 owner_type + owner_id 列
-- ===========================================
--
-- 新增列：owner_type ('expert' | 'user')，owner_id (VARCHAR(8))
-- 不删除旧列（expert_id, service_type, user_id），保持向后兼容
-- 旧代码继续使用旧列，新代码使用新列
--
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- 添加新列
ALTER TABLE task_expert_services
    ADD COLUMN IF NOT EXISTS owner_type VARCHAR(20),
    ADD COLUMN IF NOT EXISTS owner_id VARCHAR(8);

-- 添加约束
ALTER TABLE task_expert_services
    DROP CONSTRAINT IF EXISTS chk_service_owner_type;
ALTER TABLE task_expert_services
    ADD CONSTRAINT chk_service_owner_type
    CHECK (owner_type IS NULL OR owner_type IN ('expert', 'user'));

-- 给 service_applications 添加 new_expert_id 列（指向新 experts 表）
ALTER TABLE service_applications
    ADD COLUMN IF NOT EXISTS new_expert_id VARCHAR(8);

-- 索引
CREATE INDEX IF NOT EXISTS ix_services_owner ON task_expert_services(owner_type, owner_id)
    WHERE owner_type IS NOT NULL;

COMMIT;
