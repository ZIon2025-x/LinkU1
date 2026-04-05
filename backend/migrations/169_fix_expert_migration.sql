-- ===========================================
-- 迁移 169: 修复达人数据迁移
-- ===========================================
-- 168 因事务回滚导致 experts 为空但 _expert_id_migration_map 有数据
-- 本迁移利用已有的映射表重新插入数据，不依赖临时表
-- ===========================================

-- 步骤 1: 插入 experts（利用已有映射）
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
JOIN _expert_id_migration_map m ON m.old_id = te.id
LEFT JOIN users u ON u.id = te.id
WHERE NOT EXISTS (SELECT 1 FROM experts e WHERE e.id = m.new_id)
ON CONFLICT (id) DO NOTHING;

-- 步骤 2: 插入 expert_members
INSERT INTO expert_members (expert_id, user_id, role, status, joined_at)
SELECT
    m.new_id,
    te.id,
    'owner',
    'active',
    te.created_at
FROM task_experts te
JOIN _expert_id_migration_map m ON m.old_id = te.id
WHERE EXISTS (SELECT 1 FROM experts e WHERE e.id = m.new_id)
  AND NOT EXISTS (SELECT 1 FROM expert_members em WHERE em.expert_id = m.new_id AND em.user_id = te.id)
ON CONFLICT (expert_id, user_id) DO NOTHING;

-- 步骤 3: 插入 featured_experts_v2
INSERT INTO featured_experts_v2 (expert_id, is_featured, display_order, category, created_by, created_at, updated_at)
SELECT
    m.new_id,
    CASE WHEN fte.is_featured = 1 THEN true WHEN fte.is_featured = 0 THEN false ELSE COALESCE(fte.is_featured::boolean, true) END,
    COALESCE(fte.display_order, 0),
    fte.category,
    fte.created_by,
    fte.created_at,
    fte.updated_at
FROM featured_task_experts fte
JOIN _expert_id_migration_map m ON m.old_id = fte.user_id
WHERE EXISTS (SELECT 1 FROM experts e WHERE e.id = m.new_id)
  AND NOT EXISTS (SELECT 1 FROM featured_experts_v2 fv WHERE fv.expert_id = m.new_id)
ON CONFLICT (expert_id) DO NOTHING;

-- 步骤 4: 回填 services owner_type/owner_id
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

-- 步骤 5: 回填 service_applications.new_expert_id
UPDATE service_applications sa
SET new_expert_id = m.new_id
FROM _expert_id_migration_map m
WHERE sa.expert_id = m.old_id
  AND sa.new_expert_id IS NULL;

-- 步骤 6: 创建达人板块
INSERT INTO forum_categories (name, name_zh, name_en, type, expert_id, is_visible, is_admin_only, sort_order)
SELECT
    'expert_' || e.id,
    e.name,
    e.name,
    'expert',
    e.id,
    true,
    false,
    0
FROM experts e
WHERE NOT EXISTS (
    SELECT 1 FROM forum_categories fc WHERE fc.expert_id = e.id
);

-- 步骤 7: 关联 forum_category_id
UPDATE experts e
SET forum_category_id = fc.id
FROM forum_categories fc
WHERE fc.expert_id = e.id
  AND fc.type = 'expert'
  AND e.forum_category_id IS NULL;
