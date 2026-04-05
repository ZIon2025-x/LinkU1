-- 迁移 166: 补充 user_service_packages 唯一约束
BEGIN;
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_package_service_task
    ON user_service_packages(user_id, service_id, task_id)
    WHERE task_id IS NOT NULL;
COMMIT;
