-- ===========================================
-- 迁移 226: 删除 service_applications.expert_id (legacy → task_experts.id)
-- ===========================================
--
-- 背景: Phase 2a (2026-04) 引入 new_expert_id (FK → experts.id)。从那以后所有
-- 新写入显式 expert_id=NULL,所有查询 filter 改用 new_expert_id。expert_id
-- 列在代码层零 filter 读 (见 commit 4a8d4a9c3 删除 ServiceApplication.expert
-- relationship 后的 grep 验证)。
--
-- 执行时间: 2026-05-06
-- 部署节奏: 此 migration 必须在代码先部署 (删除 Column 定义 + Index 定义 +
--          expert_consultation_routes 写入点) 之后再跑,否则不会破坏 DB 但
--          代码部署期间会报"列不存在"。
--
-- 体检结果:
--   linktest: total=20, legacy_set=7, legacy_only_orphan=0, dual_set=7
--   prod:     total=12, legacy_set=5, legacy_only_orphan=0, dual_set=5
--   两边都无孤儿,可安全 DROP。
-- ===========================================

BEGIN;

-- 防御性检查: 若有 expert_id 设置但 new_expert_id 为 NULL 的孤儿,中止 migration
DO $$
DECLARE
    orphan_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO orphan_count
    FROM service_applications
    WHERE expert_id IS NOT NULL AND new_expert_id IS NULL;

    IF orphan_count > 0 THEN
        RAISE EXCEPTION 'Migration 226 aborted: % rows have legacy expert_id without new_expert_id, backfill before dropping column', orphan_count;
    END IF;
END $$;

-- 删 index (若存在)
DROP INDEX IF EXISTS ix_service_applications_expert_id;

-- 删 column (CASCADE 不需要,因为 FK 约束自带,relationship 已在代码层删除)
ALTER TABLE service_applications DROP COLUMN IF EXISTS expert_id;

COMMIT;
