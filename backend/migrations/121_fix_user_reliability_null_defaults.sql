-- 修复 user_reliability 表中的 NULL 值和缺失的 SQL DEFAULT
-- 原因: SQLAlchemy 的 default=0.0 只在 Python 层生效，迁移120通过 raw SQL INSERT 创建的记录某些列为 NULL

-- 1. 将已有 NULL 值更新为 0.0
UPDATE user_reliability SET response_speed_avg = 0.0 WHERE response_speed_avg IS NULL;
UPDATE user_reliability SET completion_rate = 0.0 WHERE completion_rate IS NULL;
UPDATE user_reliability SET on_time_rate = 0.0 WHERE on_time_rate IS NULL;
UPDATE user_reliability SET complaint_rate = 0.0 WHERE complaint_rate IS NULL;
UPDATE user_reliability SET communication_score = 0.0 WHERE communication_score IS NULL;
UPDATE user_reliability SET repeat_rate = 0.0 WHERE repeat_rate IS NULL;
UPDATE user_reliability SET cancellation_rate = 0.0 WHERE cancellation_rate IS NULL;
UPDATE user_reliability SET total_tasks_taken = 0 WHERE total_tasks_taken IS NULL;

-- 2. 添加 SQL 层面的 DEFAULT 约束，防止未来 raw SQL 插入产生 NULL
ALTER TABLE user_reliability ALTER COLUMN response_speed_avg SET DEFAULT 0.0;
ALTER TABLE user_reliability ALTER COLUMN completion_rate SET DEFAULT 0.0;
ALTER TABLE user_reliability ALTER COLUMN on_time_rate SET DEFAULT 0.0;
ALTER TABLE user_reliability ALTER COLUMN complaint_rate SET DEFAULT 0.0;
ALTER TABLE user_reliability ALTER COLUMN communication_score SET DEFAULT 0.0;
ALTER TABLE user_reliability ALTER COLUMN repeat_rate SET DEFAULT 0.0;
ALTER TABLE user_reliability ALTER COLUMN cancellation_rate SET DEFAULT 0.0;
ALTER TABLE user_reliability ALTER COLUMN total_tasks_taken SET DEFAULT 0;
