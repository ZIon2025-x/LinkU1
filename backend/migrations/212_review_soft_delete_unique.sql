-- Migration 212: Review 软删除 + 唯一约束
--
-- 目的:
--   1) 在 reviews 表加 is_deleted / deleted_at 字段,为未来"改评"功能预留软删除能力
--   2) 加 partial UNIQUE 约束,防止同一用户对同一 task 或同一 package 生成多条有效评价
--   3) Partial index(WHERE is_deleted = false)留出逃生阀:改评时先 soft-delete 旧记录再新建
--
-- 背景:
--   之前只在应用层 (crud/review.py::create_review) 做 "already_reviewed" 检查,
--   并发下不可靠。Review 表既能挂 task_id 也能挂 package_id(两选一),因此两条
--   partial UNIQUE 各自守住一个维度。
--
-- 风险:
--   去重步骤会物理删除历史重复 Review。执行前请确认 reviews 表是否有合法重复
--   (可能的业务场景: 用户改评被错误地新建一条新记录)。当前代码逻辑不允许改评,
--   理论上应无重复,保留最新 id 的策略是安全的。

BEGIN;

-- 1. 加字段
ALTER TABLE reviews
    ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 2. 去重:同一 (task_id, user_id) 组合只保留 id 最大的一条(最新)
--    WHERE 条件过滤 task_id NULL 的行(这些行属于 package 评价维度,单独处理)
DELETE FROM reviews a
USING reviews b
WHERE a.id < b.id
  AND a.task_id IS NOT NULL
  AND a.task_id = b.task_id
  AND a.user_id = b.user_id;

-- 3. 去重:同一 (package_id, user_id) 组合只保留 id 最大的一条
DELETE FROM reviews a
USING reviews b
WHERE a.id < b.id
  AND a.package_id IS NOT NULL
  AND a.package_id = b.package_id
  AND a.user_id = b.user_id;

-- 4. Partial UNIQUE: task 维度(只对有效 + 有 task_id 的行生效)
CREATE UNIQUE INDEX IF NOT EXISTS uq_reviews_task_user_active
    ON reviews (task_id, user_id)
    WHERE is_deleted = FALSE AND task_id IS NOT NULL;

-- 5. Partial UNIQUE: package 维度
CREATE UNIQUE INDEX IF NOT EXISTS uq_reviews_package_user_active
    ON reviews (package_id, user_id)
    WHERE is_deleted = FALSE AND package_id IS NOT NULL;

-- 6. 辅助索引:按 is_deleted 快速过滤(大多数查询都需要)
CREATE INDEX IF NOT EXISTS ix_reviews_is_deleted
    ON reviews (is_deleted)
    WHERE is_deleted = FALSE;

COMMIT;
