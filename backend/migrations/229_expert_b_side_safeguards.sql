-- 迁移 229：达人团队 B 端风险拦截字段
-- 三块字段：
--   A. 协议接受记录（agreed_terms_version / agreed_terms_at）
--      落地 ExpertApplication 与 Expert，申请时由 owner 勾选记录，审核通过同步到团队。
--   B. 收款主体声明（payout_holder_user_id）
--      明确"团队收款实际进入哪个用户的 Stripe 个人账户"，初始 backfill 为当前 owner，
--      转让 owner 时由应用层同步刷新。
--   C. 流水阈值跟踪（volume_warning_level / volume_warning_at / last_30d_volume_pence）
--      由 scheduled_tasks 每日扫描结算交易写入；用于触发"建议升级对公"提示与 admin alert。
-- 全部为新增列，无破坏性变更；使用 IF NOT EXISTS 保证可重复执行。
-- 依赖：158（experts / expert_members / expert_applications 表）

-- ========== A. 协议接受版本 ==========
ALTER TABLE expert_applications
    ADD COLUMN IF NOT EXISTS agreed_terms_version VARCHAR(20),
    ADD COLUMN IF NOT EXISTS agreed_terms_at TIMESTAMPTZ;

ALTER TABLE experts
    ADD COLUMN IF NOT EXISTS agreed_terms_version VARCHAR(20),
    ADD COLUMN IF NOT EXISTS agreed_terms_at TIMESTAMPTZ;

-- ========== B. 收款主体声明 ==========
ALTER TABLE experts
    ADD COLUMN IF NOT EXISTS payout_holder_user_id VARCHAR(8)
        REFERENCES users(id) ON DELETE SET NULL;

-- Backfill：取当前 owner 成员；仅更新 NULL 行，可重复执行
UPDATE experts e
SET payout_holder_user_id = (
    SELECT m.user_id
    FROM expert_members m
    WHERE m.expert_id = e.id
      AND m.role = 'owner'
      AND m.status = 'active'
    ORDER BY m.joined_at ASC
    LIMIT 1
)
WHERE payout_holder_user_id IS NULL;

CREATE INDEX IF NOT EXISTS ix_experts_payout_holder ON experts(payout_holder_user_id);

-- ========== C. 流水阈值跟踪 ==========
ALTER TABLE experts
    ADD COLUMN IF NOT EXISTS volume_warning_level SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS volume_warning_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_30d_volume_pence BIGINT NOT NULL DEFAULT 0;

-- 部分索引：只索引已触发警告的团队（admin 列表过滤场景）
CREATE INDEX IF NOT EXISTS ix_experts_volume_warning_level
    ON experts(volume_warning_level) WHERE volume_warning_level > 0;

-- 验证
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE (table_name = 'experts' AND column_name IN (
--          'agreed_terms_version','agreed_terms_at','payout_holder_user_id',
--          'volume_warning_level','volume_warning_at','last_30d_volume_pence'))
--    OR (table_name = 'expert_applications' AND column_name IN (
--          'agreed_terms_version','agreed_terms_at'))
-- ORDER BY table_name, column_name;
-- 期望：8 行
--
-- SELECT COUNT(*) AS unbackfilled
-- FROM experts WHERE payout_holder_user_id IS NULL AND status = 'active';
-- 期望：0（全部活跃团队都已绑定 owner）
