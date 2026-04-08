-- ===========================================
-- 迁移 182: 修复 expert FK 指向新 experts 表
--
-- 背景:
--   Phase 2a 引入新 experts 表后,以下 FK 仍指向旧 task_experts 表:
--     - expert_closed_dates.expert_id  → task_experts.id
--     - service_applications.new_expert_id → 无 FK (字符串列)
--
--   新路由 (expert_dashboard_routes / expert_consultation_routes) 用新
--   experts.id 写入这两个表,导致:
--     - 新建团队添加关门日期会触发 FK 违反
--     - service_applications.new_expert_id 可能成为孤立引用
--
-- 这个迁移:
--   1. 清理 expert_closed_dates 中无法对齐到新 experts 的孤立行
--   2. 把 expert_closed_dates.expert_id FK 切到 experts.id
--   3. 给 service_applications.new_expert_id 加 FK 到 experts.id
--   4. 给 service_applications.new_expert_id 加索引
-- ===========================================
BEGIN;

-- ---------- ExpertClosedDate ----------

-- 1) 先把不存在于 experts 表的孤立 expert_id 行删掉
--    (这些来自旧 task_experts,且没有对应的新 experts 行)
DELETE FROM expert_closed_dates
WHERE expert_id NOT IN (SELECT id FROM experts);

-- 2) 删除旧 FK 约束
ALTER TABLE expert_closed_dates
  DROP CONSTRAINT IF EXISTS expert_closed_dates_expert_id_fkey;

-- 3) 加新 FK 指向 experts.id
ALTER TABLE expert_closed_dates
  ADD CONSTRAINT expert_closed_dates_expert_id_fkey
  FOREIGN KEY (expert_id)
  REFERENCES experts(id)
  ON DELETE CASCADE;

COMMENT ON COLUMN expert_closed_dates.expert_id IS
  '团队 ID,指向 experts.id (Phase 2a 后)';

-- ---------- ServiceApplication ----------

-- 4) 清理 service_applications 中 new_expert_id 不存在于 experts 的孤立行
--    用 NULL 化而非删除,因为这些申请可能仍是合法的旧个人服务申请
UPDATE service_applications
SET new_expert_id = NULL
WHERE new_expert_id IS NOT NULL
  AND new_expert_id NOT IN (SELECT id FROM experts);

-- 5) 加 FK
ALTER TABLE service_applications
  ADD CONSTRAINT service_applications_new_expert_id_fkey
  FOREIGN KEY (new_expert_id)
  REFERENCES experts(id)
  ON DELETE CASCADE;

-- 6) 加索引(dashboard stats 高频查询字段)
CREATE INDEX IF NOT EXISTS ix_service_applications_new_expert_id
  ON service_applications(new_expert_id)
  WHERE new_expert_id IS NOT NULL;

COMMENT ON COLUMN service_applications.new_expert_id IS
  '团队服务申请的 expert 团队 ID,指向 experts.id (Phase 2a 后)';

COMMIT;
