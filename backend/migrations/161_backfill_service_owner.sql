-- ===========================================
-- 迁移 161: 回填 task_expert_services 的 owner_type + owner_id
-- ===========================================
--
-- 利用 _expert_id_migration_map（Phase 1a 创建）将旧 expert_id → 新 experts.id
-- 个人服务的 owner_id 直接用 user_id
--
-- 依赖：迁移 158（experts 表）、迁移 159（_expert_id_migration_map）、迁移 160（新列）
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- 1. 回填达人服务：service_type = 'expert'
-- owner_type = 'expert', owner_id = 新 experts.id（通过映射表）
UPDATE task_expert_services s
SET
    owner_type = 'expert',
    owner_id = m.new_id
FROM _expert_id_migration_map m
WHERE s.expert_id = m.old_id
  AND s.service_type = 'expert'
  AND s.owner_type IS NULL;

-- 2. 回填个人服务：service_type = 'personal'
-- owner_type = 'user', owner_id = user_id
UPDATE task_expert_services
SET
    owner_type = 'user',
    owner_id = user_id
WHERE service_type = 'personal'
  AND owner_type IS NULL
  AND user_id IS NOT NULL;

-- 3. 回填 service_applications.new_expert_id
UPDATE service_applications sa
SET new_expert_id = m.new_id
FROM _expert_id_migration_map m
WHERE sa.expert_id = m.old_id
  AND sa.new_expert_id IS NULL;

-- 4. 验证回填结果
DO $$
DECLARE
    unfilled_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unfilled_count
    FROM task_expert_services
    WHERE owner_type IS NULL;

    IF unfilled_count > 0 THEN
        RAISE WARNING '% services still have NULL owner_type after backfill', unfilled_count;
    END IF;
END $$;

-- 5. 设置 NOT NULL 约束（仅当所有行都已回填时）
DO $$
DECLARE
    unfilled_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unfilled_count
    FROM task_expert_services
    WHERE owner_type IS NULL;

    IF unfilled_count = 0 THEN
        EXECUTE 'ALTER TABLE task_expert_services ALTER COLUMN owner_type SET NOT NULL';
        EXECUTE 'ALTER TABLE task_expert_services ALTER COLUMN owner_id SET NOT NULL';
        RAISE NOTICE 'owner_type and owner_id set to NOT NULL';
    ELSE
        RAISE NOTICE 'Skipping NOT NULL — % rows still unfilled', unfilled_count;
    END IF;
END $$;

COMMIT;
