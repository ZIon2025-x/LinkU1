-- backend/migrations/238_add_user_profile_preference_city_source.sql
-- user_profile_preferences 新增 city_source 字段
-- 'gps'    : 由 POST /api/profile/location 自动写入，可被新 GPS 城市覆盖
-- 'manual' : 用户在偏好页手动改过 city，GPS 自动同步不再覆盖

BEGIN;

ALTER TABLE user_profile_preferences
    ADD COLUMN IF NOT EXISTS city_source VARCHAR(16) NOT NULL DEFAULT 'gps';

-- 历史数据：已经存在 city 值的行，视为用户曾手动设置，保留 manual 语义防止本次新逻辑把它们的 city 改掉
UPDATE user_profile_preferences
SET city_source = 'manual'
WHERE city IS NOT NULL AND city <> '';

COMMIT;
