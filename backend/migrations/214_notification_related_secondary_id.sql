-- Migration 214: Notification 加 related_secondary_id 列 + 调整唯一约束为 4 列
--
-- 目的:
--   1) 解决"同一 task 下多个申请者议价时,后者通知覆盖前者"的 bug
--      (老约束 UNIQUE(user_id, type, related_id) 对 task_id 相同但 application
--       不同的场景会误合并,导致发布者丢失其他申请者的通知)
--   2) 为 Flutter 通知点击能正确跳到咨询会话提供数据:咨询类通知的
--      related_id=task_id,related_secondary_id=application_id
--
-- 后向兼容:
--   - 老通知 related_secondary_id=NULL。Postgres UNIQUE 约束里 NULL != NULL,
--     老通知之间不会因新约束冲突;历史数据不变。
--   - 现有 create_notification 调用没传 related_secondary_id 的继续 NULL 行为,
--     合并逻辑(user_id + type + related_id + NULL)与老约束等价。

BEGIN;

-- 1. 加列
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS related_secondary_id INTEGER;

-- 2. DROP 老约束(若存在)
ALTER TABLE notifications
    DROP CONSTRAINT IF EXISTS uix_user_type_related;

-- 3. 建新 4 列唯一约束
ALTER TABLE notifications
    ADD CONSTRAINT uix_user_type_related_secondary
    UNIQUE (user_id, type, related_id, related_secondary_id);

-- 4. 辅助索引:按 related_secondary_id 定位咨询通知
CREATE INDEX IF NOT EXISTS ix_notifications_related_secondary_id
    ON notifications(related_secondary_id)
    WHERE related_secondary_id IS NOT NULL;

COMMIT;
