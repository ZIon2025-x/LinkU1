-- ===========================================
-- 迁移 177: activities 多态所有权
-- spec §1.2
-- ===========================================
BEGIN;

ALTER TABLE activities
  ADD COLUMN owner_type VARCHAR(20) NOT NULL DEFAULT 'user'
    CHECK (owner_type IN ('user', 'expert')),
  ADD COLUMN owner_id VARCHAR(8) NULL;

UPDATE activities SET owner_id = expert_id WHERE owner_id IS NULL;

ALTER TABLE activities ALTER COLUMN owner_id SET NOT NULL;

CREATE INDEX ix_activities_owner ON activities(owner_type, owner_id);

COMMENT ON COLUMN activities.owner_type IS '所有权: user=个人, expert=达人团队';
COMMENT ON COLUMN activities.owner_id IS 'user 时指 users.id; expert 时指 experts.id';
COMMENT ON COLUMN activities.expert_id IS '[legacy] 原 user_id 字段,团队活动时填 owner.user_id';

COMMIT;
