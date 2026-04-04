-- ===========================================
-- 迁移 159: 迁移现有达人数据到新表
-- ===========================================
--
-- 将 task_experts → experts + expert_members
-- 将 featured_task_experts → featured_experts_v2
-- 保留旧表不删除
--
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- 1. 创建临时映射表：old_expert_id (= user_id) → new_expert_id
CREATE TEMP TABLE expert_id_map (
    old_id VARCHAR(8) PRIMARY KEY,
    new_id VARCHAR(8) NOT NULL UNIQUE
);

-- 2. 为每个现有达人生成新的 8 位 ID 并插入映射表
DO $$
DECLARE
    rec RECORD;
    new_id VARCHAR(8);
    id_exists BOOLEAN;
BEGIN
    FOR rec IN SELECT id FROM task_experts LOOP
        LOOP
            new_id := LPAD(FLOOR(RANDOM() * 100000000)::TEXT, 8, '0');
            SELECT EXISTS(SELECT 1 FROM expert_id_map WHERE expert_id_map.new_id = new_id) INTO id_exists;
            EXIT WHEN NOT id_exists;
        END LOOP;
        INSERT INTO expert_id_map (old_id, new_id) VALUES (rec.id, new_id);
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

-- 6. 保存映射表到永久表（供后续 Phase 2 服务迁移使用）
CREATE TABLE IF NOT EXISTS _expert_id_migration_map (
    old_id VARCHAR(8) PRIMARY KEY,
    new_id VARCHAR(8) NOT NULL UNIQUE
);
INSERT INTO _expert_id_migration_map SELECT * FROM expert_id_map
ON CONFLICT DO NOTHING;

COMMIT;
