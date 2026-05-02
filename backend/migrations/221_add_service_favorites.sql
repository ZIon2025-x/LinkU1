-- Migration 221: add service_favorites table
--
-- 技能服务收藏表 (task_expert_services 维度, 含 personal + expert 服务)
-- 模型: app/models.py ServiceFavorite
-- 模板对照: flea_market_favorites / activity_favorites

BEGIN;

CREATE TABLE IF NOT EXISTS service_favorites (
    id          SERIAL PRIMARY KEY,
    user_id     VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    service_id  INTEGER    NOT NULL REFERENCES task_expert_services(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uix_user_service_favorite UNIQUE (user_id, service_id)
);

CREATE INDEX IF NOT EXISTS idx_service_favorites_user_id     ON service_favorites (user_id);
CREATE INDEX IF NOT EXISTS idx_service_favorites_service_id  ON service_favorites (service_id);
CREATE INDEX IF NOT EXISTS idx_service_favorites_created_at  ON service_favorites (created_at);

COMMIT;
