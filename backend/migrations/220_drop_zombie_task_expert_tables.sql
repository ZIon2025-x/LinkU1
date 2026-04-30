-- 删除 2026-04-09 task_expert_routes.py 移除后留下的两张 zombie 表。
-- 模型已删（见 models.py:1549, 1596 注释）；全 backend 零读写。
-- 备份见 /tmp/zombie_tables_backup_2026-04-30.sql。

DROP TABLE IF EXISTS task_expert_profile_update_requests CASCADE;
DROP TABLE IF EXISTS task_expert_applications CASCADE;
