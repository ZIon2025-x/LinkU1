-- 219_drop_forum_reply_level.sql
-- 删除 forum_replies.reply_level 列与 check_reply_level 约束
-- 关联设计文档: docs/superpowers/specs/2026-04-26-forum-flat-replies-design.md
-- 关联实施计划: docs/superpowers/plans/2026-04-26-forum-flat-replies.md

BEGIN;

-- 1) 删除 CheckConstraint
ALTER TABLE forum_replies DROP CONSTRAINT IF EXISTS check_reply_level;

-- 2) 删除 reply_level 列
ALTER TABLE forum_replies DROP COLUMN IF EXISTS reply_level;

COMMIT;
