-- 添加 related_type 字段到 notifications 表
-- 用于明确标识 related_id 是 task_id 还是 application_id，避免误判

-- 添加 related_type 字段
ALTER TABLE notifications 
ADD COLUMN related_type VARCHAR(20) DEFAULT NULL;

-- 添加注释说明
COMMENT ON COLUMN notifications.related_type IS 'related_id 的类型：task_id, application_id, 或 NULL（旧数据）';

-- 为现有数据设置 related_type（根据通知类型推断）
-- task_application, task_approved, task_completed, task_confirmed, task_cancelled, task_reward_paid: related_id 是 task_id
UPDATE notifications 
SET related_type = 'task_id' 
WHERE type IN ('task_application', 'task_approved', 'task_completed', 'task_confirmed', 'task_cancelled', 'task_reward_paid')
  AND related_id IS NOT NULL
  AND related_type IS NULL;

-- application_message, negotiation_offer, application_rejected, application_withdrawn, negotiation_rejected: related_id 是 application_id
UPDATE notifications 
SET related_type = 'application_id' 
WHERE type IN ('application_message', 'negotiation_offer', 'application_rejected', 'application_withdrawn', 'negotiation_rejected')
  AND related_id IS NOT NULL
  AND related_type IS NULL;

-- application_accepted 类型：旧数据可能是 task_id 或 application_id，无法确定
-- 保持 related_type 为 NULL，让应用层验证是否是有效的 task_id，避免误判
-- 新数据会通过应用层自动设置正确的 related_type

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS ix_notifications_related_type ON notifications(related_type) WHERE related_type IS NOT NULL;
