-- 迁移 171: 允许 forum_categories.type = 'expert'

ALTER TABLE forum_categories DROP CONSTRAINT IF EXISTS chk_forum_type;
ALTER TABLE forum_categories ADD CONSTRAINT chk_forum_type
    CHECK (type IN ('general', 'root', 'university', 'skill', 'expert'));
