-- 迁移 172: 为已有达人创建论坛板块（171 更新约束后）

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

UPDATE experts e
SET forum_category_id = fc.id
FROM forum_categories fc
WHERE fc.expert_id = e.id
  AND fc.type = 'expert'
  AND e.forum_category_id IS NULL;
