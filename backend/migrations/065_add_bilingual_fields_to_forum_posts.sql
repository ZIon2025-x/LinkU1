-- ===========================================
-- 迁移文件065：为论坛帖子添加双语字段
-- 创建时间: 2026-01-20
-- 说明: 为 forum_posts 表添加 title_en, title_zh, content_en, content_zh 字段
-- ===========================================

BEGIN;

-- 为论坛帖子表添加双语字段
ALTER TABLE forum_posts
    ADD COLUMN IF NOT EXISTS title_en VARCHAR(200) NULL,
    ADD COLUMN IF NOT EXISTS title_zh VARCHAR(200) NULL,
    ADD COLUMN IF NOT EXISTS content_en TEXT NULL,
    ADD COLUMN IF NOT EXISTS content_zh TEXT NULL;

-- 添加注释
COMMENT ON COLUMN forum_posts.title_en IS '帖子标题（英文）';
COMMENT ON COLUMN forum_posts.title_zh IS '帖子标题（中文）';
COMMENT ON COLUMN forum_posts.content_en IS '帖子内容（英文）';
COMMENT ON COLUMN forum_posts.content_zh IS '帖子内容（中文）';

COMMIT;
