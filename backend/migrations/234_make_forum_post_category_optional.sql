-- Migration 234: make forum_posts.category_id nullable
-- Background: 板块从必选改为可选话题（spec 2026-05-15-forum-category-optional-design.md）
-- 必须先在 staging DB 跑完，再 push backend 代码

BEGIN;

ALTER TABLE forum_posts ALTER COLUMN category_id DROP NOT NULL;

COMMIT;
