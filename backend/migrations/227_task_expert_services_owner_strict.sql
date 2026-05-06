-- ===========================================
-- 迁移 227: 收紧 task_expert_services.owner_type / owner_id 约束
-- ===========================================
--
-- 背景: migration 160 加了 owner_type + owner_id 列 (allow NULL) 加 CHECK
-- (owner_type IS NULL OR owner_type IN ('expert', 'user'))。migration 161
-- 条件性设 NOT NULL: 仅当 owner_type IS NULL 计数为 0 时才 ALTER。
-- 由于不确定 161 跑的时候是否真的应用了 NOT NULL,本 migration 兜底:
--   1. 验证当前 DB 无 NULL
--   2. 重新设 NOT NULL (idempotent)
--   3. 替换 CHECK 为不允许 NULL 的严格版本
--
-- 体检结果:
--   linktest: expert=11, personal=4, new_null=0, new_id_null=0
--   prod:     expert=7,  personal=29, new_null=0, new_id_null=0
--
-- 执行时间: 2026-05-06
-- 部署节奏: 可任意顺序 (DB 加 NOT NULL 不影响现有代码运行,
--          代码层 nullable=False 不影响 DB)。建议 migration 先跑。
-- ===========================================

BEGIN;

-- 防御性检查
DO $$
DECLARE
    null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_count
    FROM task_expert_services
    WHERE owner_type IS NULL OR owner_id IS NULL;

    IF null_count > 0 THEN
        RAISE EXCEPTION 'Migration 227 aborted: % rows have NULL owner_type/owner_id, backfill before adding NOT NULL', null_count;
    END IF;
END $$;

-- 兜底设 NOT NULL (idempotent)
ALTER TABLE task_expert_services ALTER COLUMN owner_type SET NOT NULL;
ALTER TABLE task_expert_services ALTER COLUMN owner_id SET NOT NULL;

-- 替换 CHECK: 旧版允许 NULL,新版严格
ALTER TABLE task_expert_services DROP CONSTRAINT IF EXISTS chk_service_owner_type;
ALTER TABLE task_expert_services
    ADD CONSTRAINT chk_service_owner_type
    CHECK (owner_type IN ('expert', 'user'));

COMMIT;
