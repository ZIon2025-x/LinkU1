-- 补充两处真正缺失的外键索引
-- 审计依据：逐一检查 migrations/001-093 + models.py __table_args__，确认以下列无覆盖索引

-- task_audit_logs.user_id
-- Migration 007 建表时创建了 idx_audit_logs_task / idx_audit_logs_participant / idx_audit_logs_created_at
-- 未创建 user_id 索引，查询"某用户的操作日志"时需全表扫描
CREATE INDEX IF NOT EXISTS idx_audit_logs_user
    ON task_audit_logs(user_id)
    WHERE user_id IS NOT NULL;

-- oauth_refresh_token.user_id
-- Migration 081 建表时创建了 token / client_id / expires_at 索引
-- 未创建 user_id 索引，撤销某用户所有 token 时需全表扫描
CREATE INDEX IF NOT EXISTS idx_oauth_refresh_token_user_id
    ON oauth_refresh_token(user_id);
