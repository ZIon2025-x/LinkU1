-- ===========================================
-- 迁移 168: 重新执行达人数据迁移（修复 159 的变量冲突 bug）
-- ===========================================
--
-- 159 因 PL/pgSQL 变量名与列名冲突（new_id ambiguous）导致
-- expert_id_map 未生成数据，experts/expert_members 为空。
-- 本迁移重新执行完整的数据迁移。
--
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- 清理可能的残留数据（幂等）
DELETE FROM expert_members WHERE TRUE;
DELETE FROM featured_experts_v2 WHERE TRUE;
DELETE FROM experts WHERE TRUE;
DELETE FROM _expert_id_migration_map WHERE TRUE;

-- 1. 创建临时映射表
CREATE TEMP TABLE expert_id_map (
    old_id VARCHAR(8) PRIMARY KEY,
    new_id VARCHAR(8) NOT NULL UNIQUE
);

-- 2. 为每个现有达人生成新的 8 位 ID（修复后的变量名）
DO $$
DECLARE
    rec RECORD;
    v_new_id VARCHAR(8);
    v_id_exists BOOLEAN;
BEGIN
    FOR rec IN SELECT id FROM task_experts LOOP
        LOOP
            v_new_id := LPAD(FLOOR(RANDOM() * 100000000)::TEXT, 8, '0');
            SELECT EXISTS(SELECT 1 FROM expert_id_map WHERE expert_id_map.new_id = v_new_id) INTO v_id_exists;
            EXIT WHEN NOT v_id_exists;
        END LOOP;
        INSERT INTO expert_id_map (old_id, new_id) VALUES (rec.id, v_new_id);
    END LOOP;
END $$;

-- 3. 迁移 task_experts → experts
INSERT INTO experts (id, name, bio, avatar, status, rating, total_services, completed_tasks, is_official, official_badge, created_at, updated_at)
SELECT
    m.new_id,
    COALESCE(te.expert_name, u.name, 'Unnamed'),
    te.bio,
    te.avatar,
    te.status,
    te.rating,
    te.total_services,
    te.completed_tasks,
    te.is_official,
    te.official_badge,
    te.created_at,
    te.updated_at
FROM task_experts te
JOIN expert_id_map m ON m.old_id = te.id
LEFT JOIN users u ON u.id = te.id;

-- 4. 为每个达人创建 owner 成员记录
INSERT INTO expert_members (expert_id, user_id, role, status, joined_at)
SELECT
    m.new_id,
    te.id,
    'owner',
    'active',
    te.created_at
FROM task_experts te
JOIN expert_id_map m ON m.old_id = te.id;

-- 5. 迁移 featured_task_experts → featured_experts_v2
INSERT INTO featured_experts_v2 (expert_id, is_featured, display_order, category, created_by, created_at, updated_at)
SELECT
    m.new_id,
    CASE WHEN fte.is_featured = 1 THEN true ELSE false END,
    COALESCE(fte.display_order, 0),
    fte.category,
    fte.created_by,
    fte.created_at,
    fte.updated_at
FROM featured_task_experts fte
JOIN expert_id_map m ON m.old_id = fte.user_id;

-- 6. 保存映射表到永久表
INSERT INTO _expert_id_migration_map SELECT * FROM expert_id_map
ON CONFLICT DO NOTHING;

-- 7. 回填 task_expert_services 的 owner_type + owner_id（迁移 161 的逻辑）
UPDATE task_expert_services s
SET
    owner_type = 'expert',
    owner_id = m.new_id
FROM _expert_id_migration_map m
WHERE s.expert_id = m.old_id
  AND s.service_type = 'expert'
  AND (s.owner_type IS NULL OR s.owner_id IS NULL);

UPDATE task_expert_services
SET
    owner_type = 'user',
    owner_id = user_id
WHERE service_type = 'personal'
  AND (owner_type IS NULL OR owner_id IS NULL)
  AND user_id IS NOT NULL;

-- 8. 回填 service_applications.new_expert_id
UPDATE service_applications sa
SET new_expert_id = m.new_id
FROM _expert_id_migration_map m
WHERE sa.expert_id = m.old_id
  AND sa.new_expert_id IS NULL;

-- 9. 为每个迁移的达人创建论坛板块
INSERT INTO forum_categories (name, name_zh, name_en, type, expert_id, is_visible, is_admin_only)
SELECT
    'expert_' || e.id,
    e.name,
    e.name,
    'expert',
    e.id,
    true,
    false
FROM experts e
WHERE NOT EXISTS (
    SELECT 1 FROM forum_categories fc WHERE fc.expert_id = e.id
);

-- 10. 关联 forum_category_id 到 experts
UPDATE experts e
SET forum_category_id = fc.id
FROM forum_categories fc
WHERE fc.expert_id = e.id
  AND fc.type = 'expert'
  AND e.forum_category_id IS NULL;

-- 11. 验证
DO $$
DECLARE
    expert_count INTEGER;
    member_count INTEGER;
    map_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO expert_count FROM experts;
    SELECT COUNT(*) INTO member_count FROM expert_members;
    SELECT COUNT(*) INTO map_count FROM _expert_id_migration_map;
    RAISE NOTICE '迁移完成: % experts, % members, % mappings', expert_count, member_count, map_count;

    IF expert_count = 0 THEN
        RAISE WARNING '警告: experts 表为空，可能 task_experts 表也没有数据';
    END IF;
END $$;

COMMIT;
