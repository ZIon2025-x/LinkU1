-- backend/migrations/240_ai_qa_fix_system_settings_seed.sql
-- Fix: migration 237 INSERT INTO system_settings 缺 created_at 字段 → 全 fail
-- (linktest deploy 2026-05-18 18:25 抓到):
--   null value in column "created_at" of relation "system_settings" violates not-null constraint
-- 根因: system_settings.created_at 是 Column(default=get_utc_time) Python-side default,
--   无 server_default;纯 SQL INSERT 没传 → NOT NULL violation → 整条 INSERT 跳过 → 3 个
--   ai_qa_* settings 没插进 DB → 上线 admin 建 Expert 后 UPDATE 不到行 (no-op)。
-- 本 migration 显式带 created_at + updated_at 重新 INSERT,ON CONFLICT 跳过已存在的。

BEGIN;

INSERT INTO system_settings (setting_key, setting_value, description, created_at, updated_at) VALUES
    ('ai_qa_weekly_settle_cap_pence', '20000',
     'AI 限时问答周度发奖总额上限 (pence)，默认 £200/周', NOW(), NOW()),
    ('ai_qa_settle_alert_threshold_pence', '10000',
     'AI 限时问答周度发奖告警阈值 (pence)，超过发邮件给 admin', NOW(), NOW()),
    ('ai_qa_default_expert_id', '',
     'AI 限时问答 draft 路径默认 posed_by_expert_id (留空则 admin 提交时必填)', NOW(), NOW())
ON CONFLICT (setting_key) DO NOTHING;

COMMIT;
