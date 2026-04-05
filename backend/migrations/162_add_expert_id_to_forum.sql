-- ===========================================
-- 迁移 162: 给论坛表添加 expert_id 字段
-- ===========================================
--
-- forum_categories.expert_id — 达人板块关联达人团队
-- forum_posts.expert_id — 以达人身份发帖
--
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- forum_categories 添加 expert_id
ALTER TABLE forum_categories
    ADD COLUMN IF NOT EXISTS expert_id VARCHAR(8) REFERENCES experts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_forum_categories_expert_id
    ON forum_categories(expert_id) WHERE expert_id IS NOT NULL;

-- forum_posts 添加 expert_id
ALTER TABLE forum_posts
    ADD COLUMN IF NOT EXISTS expert_id VARCHAR(8) REFERENCES experts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_forum_posts_expert_id
    ON forum_posts(expert_id) WHERE expert_id IS NOT NULL;

COMMIT;
