-- 优化支付过期相关查询的索引
-- 用于提升定时任务查询性能

-- 1. 优化支付过期任务查询的复合索引
-- 用于 check_expired_payment_tasks 函数
CREATE INDEX IF NOT EXISTS ix_tasks_payment_expires_status_paid 
ON tasks(status, is_paid, payment_expires_at) 
WHERE status = 'pending_payment' 
  AND is_paid = 0 
  AND payment_expires_at IS NOT NULL;

-- 2. 优化支付提醒查询的复合索引
-- 用于 send_payment_reminders 函数（查询即将过期的任务）
CREATE INDEX IF NOT EXISTS ix_tasks_payment_reminder_query 
ON tasks(status, is_paid, payment_expires_at) 
WHERE status = 'pending_payment' 
  AND is_paid = 0 
  AND payment_expires_at IS NOT NULL;

-- 3. 添加支付提醒通知的查询索引（避免重复发送）
-- 用于检查是否已发送过提醒
CREATE INDEX IF NOT EXISTS ix_notifications_payment_reminder_check 
ON notifications(user_id, type, related_id, created_at) 
WHERE type = 'payment_reminder';

-- 添加注释
COMMENT ON INDEX ix_tasks_payment_expires_status_paid IS '支付过期任务查询索引（用于定时任务检查过期任务）';
COMMENT ON INDEX ix_tasks_payment_reminder_query IS '支付提醒查询索引（用于定时任务发送提醒）';
COMMENT ON INDEX ix_notifications_payment_reminder_check IS '支付提醒通知检查索引（用于避免重复发送提醒）';
