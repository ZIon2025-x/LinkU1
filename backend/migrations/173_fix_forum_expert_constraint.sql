-- 迁移 173: 更新 forum_categories 的 university_code 约束以允许 expert 类型

ALTER TABLE forum_categories DROP CONSTRAINT IF EXISTS chk_forum_type_university_code;
ALTER TABLE forum_categories ADD CONSTRAINT chk_forum_type_university_code
    CHECK (
        (type = 'university' AND university_code IS NOT NULL) OR
        (type IN ('general', 'root', 'skill', 'expert') AND university_code IS NULL)
    );

-- 重新创建论坛板块（上次因约束失败）
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
