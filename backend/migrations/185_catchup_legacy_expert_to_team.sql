-- ===========================================
-- 迁移 185: B1 — legacy 个人达人 → 1 人团队 catch-up 收口
--
-- 背景:
--   168/169/170 已把 2026-04-04 之前的 task_experts 全量迁移到 experts/
--   expert_members/_expert_id_migration_map。但之后通过
--   admin_official_routes.setup_official_account 新建的 task_experts
--   没有 mirror 到新表,导致这些"官方达人"在新模型下不可见。
--
--   本迁移做 catch-up: 对所有 task_experts.id NOT IN _expert_id_migration_map
--   的行,重跑 168 的核心逻辑(创建 experts + ExpertMember(owner) + map 条目
--   + forum_categories + 回填 service.owner_*)。
--
--   幂等: 已有映射的行会跳过(WHERE NOT EXISTS),可重复执行。
-- ===========================================
BEGIN;

-- 1. 临时映射表 — 仅生成新 id
CREATE TEMP TABLE _b1_new_map (
    old_id VARCHAR(8) PRIMARY KEY,
    new_id VARCHAR(8) NOT NULL UNIQUE
);

DO $$
DECLARE
    rec RECORD;
    v_new_id VARCHAR(8);
    v_id_exists BOOLEAN;
BEGIN
    FOR rec IN
        SELECT te.id
        FROM task_experts te
        WHERE NOT EXISTS (
            SELECT 1 FROM _expert_id_migration_map m WHERE m.old_id = te.id
        )
    LOOP
        LOOP
            v_new_id := LPAD(FLOOR(RANDOM() * 100000000)::TEXT, 8, '0');
            -- 确保新 id 不撞 _b1_new_map / experts / _expert_id_migration_map
            SELECT EXISTS(
                SELECT 1 FROM _b1_new_map WHERE new_id = v_new_id
                UNION ALL SELECT 1 FROM experts WHERE id = v_new_id
                UNION ALL SELECT 1 FROM _expert_id_migration_map WHERE new_id = v_new_id
            ) INTO v_id_exists;
            EXIT WHEN NOT v_id_exists;
        END LOOP;
        INSERT INTO _b1_new_map (old_id, new_id) VALUES (rec.id, v_new_id);
    END LOOP;
END $$;

-- 2. 创建 experts 行
INSERT INTO experts (
    id, name, bio, avatar, status,
    allow_applications, max_members, member_count,
    rating, total_services, completed_tasks, completion_rate,
    is_official, official_badge, stripe_onboarding_complete,
    created_at, updated_at
)
SELECT
    m.new_id,
    COALESCE(te.expert_name, u.name, 'Unnamed'),
    te.bio,
    te.avatar,
    COALESCE(te.status, 'active'),
    true,           -- allow_applications
    20,             -- max_members
    1,              -- member_count (owner)
    COALESCE(te.rating, 0.00),
    COALESCE(te.total_services, 0),
    COALESCE(te.completed_tasks, 0),
    COALESCE(te.completion_rate, 0.0),
    COALESCE(te.is_official, false),
    te.official_badge,
    false,
    COALESCE(te.created_at, NOW()),
    COALESCE(te.updated_at, NOW())
FROM task_experts te
JOIN _b1_new_map m ON m.old_id = te.id
LEFT JOIN users u ON u.id = te.id;

-- 3. 创建 ExpertMember(role='owner') 行
INSERT INTO expert_members (expert_id, user_id, role, status, joined_at)
SELECT
    m.new_id,
    te.id,
    'owner',
    'active',
    COALESCE(te.created_at, NOW())
FROM task_experts te
JOIN _b1_new_map m ON m.old_id = te.id;

-- 4. 持久化映射
INSERT INTO _expert_id_migration_map (old_id, new_id)
SELECT old_id, new_id FROM _b1_new_map
ON CONFLICT DO NOTHING;

-- 5. 回填 task_expert_services.owner_type/owner_id (catch-up,只补未填的)
UPDATE task_expert_services s
SET owner_type = 'expert', owner_id = m.new_id
FROM _expert_id_migration_map m
WHERE s.expert_id = m.old_id
  AND s.service_type = 'expert'
  AND (s.owner_type IS NULL OR s.owner_id IS NULL);

UPDATE task_expert_services
SET owner_type = 'user', owner_id = user_id
WHERE service_type = 'personal'
  AND (owner_type IS NULL OR owner_id IS NULL)
  AND user_id IS NOT NULL;

-- 6. 回填 service_applications.new_expert_id
UPDATE service_applications sa
SET new_expert_id = m.new_id
FROM _expert_id_migration_map m
WHERE sa.expert_id = m.old_id
  AND sa.new_expert_id IS NULL;

-- 7. 回填 featured_experts_v2 (从 featured_task_experts)
INSERT INTO featured_experts_v2 (
    expert_id, is_featured, display_order, category, created_by, created_at, updated_at
)
SELECT
    m.new_id,
    CASE WHEN COALESCE(fte.is_featured, 0) = 1 THEN true ELSE false END,
    COALESCE(fte.display_order, 0),
    fte.category,
    fte.created_by,
    COALESCE(fte.created_at, NOW()),
    COALESCE(fte.updated_at, NOW())
FROM featured_task_experts fte
JOIN _expert_id_migration_map m ON m.old_id = fte.user_id
WHERE NOT EXISTS (
    SELECT 1 FROM featured_experts_v2 fv2 WHERE fv2.expert_id = m.new_id
);

-- 8. 创建论坛板块 (如果还没有)
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
    SELECT 1 FROM forum_categories fc WHERE fc.expert_id = e.id AND fc.type = 'expert'
);

-- 9. 关联 forum_category_id 到 experts
UPDATE experts e
SET forum_category_id = fc.id
FROM forum_categories fc
WHERE fc.expert_id = e.id
  AND fc.type = 'expert'
  AND e.forum_category_id IS NULL;

-- 10. 验证
DO $$
DECLARE
    catchup_count INTEGER;
    total_experts INTEGER;
    total_task_experts INTEGER;
    unmapped_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO catchup_count FROM _b1_new_map;
    SELECT COUNT(*) INTO total_experts FROM experts;
    SELECT COUNT(*) INTO total_task_experts FROM task_experts;
    SELECT COUNT(*) INTO unmapped_count
    FROM task_experts te
    WHERE NOT EXISTS (
        SELECT 1 FROM _expert_id_migration_map m WHERE m.old_id = te.id
    );

    RAISE NOTICE 'B1 catch-up: % new mappings created', catchup_count;
    RAISE NOTICE 'experts table: % total rows', total_experts;
    RAISE NOTICE 'task_experts table: % total rows', total_task_experts;
    RAISE NOTICE 'unmapped task_experts after catch-up: %', unmapped_count;

    IF unmapped_count > 0 THEN
        RAISE WARNING 'B1: % task_experts 仍未映射,可能 DO 块逻辑有 bug,请人工检查', unmapped_count;
    END IF;
END $$;

COMMIT;
