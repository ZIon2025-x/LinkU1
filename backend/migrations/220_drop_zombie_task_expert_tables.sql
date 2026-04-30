-- Migration 220: drop zombie task_expert tables
--
-- Spec: docs/superpowers/specs/2026-04-30-zombie-cleanup-and-scheduler-fix-design.md §3.A1
-- Plan: docs/superpowers/plans/2026-04-30-zombie-cleanup-and-scheduler-fix.md Task 1
--
-- 删除 2026-04-09 task_expert_routes.py 移除后留下的两张 zombie 表。
-- 模型 TaskExpertApplication / TaskExpertProfileUpdateRequest 已从 app/models.py 删除；
-- 全 backend 零读写。
--
-- CASCADE 系 spec §3.A1 deliberate choice（兜底清理这两张表自身的索引/序列）；
-- linktest 执行前 plan Task 2 会先 `\d+` 验证无外部依赖，再正式执行此 migration。
-- 备份见 /tmp/zombie_tables_backup_2026-04-30.sql（由执行人在 plan Task 1 Step 1 生成）。

BEGIN;

DROP TABLE IF EXISTS task_expert_profile_update_requests CASCADE;
DROP TABLE IF EXISTS task_expert_applications CASCADE;

COMMIT;
