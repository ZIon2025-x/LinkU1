-- 201: Add linked_service_id to task_expert_services
--
-- 背景:
--   multi 套餐（多次套餐）原本是独立的 service 行，与其他 service 无关。
--   现在允许 multi 套餐关联一个现有的单次服务（package_type IS NULL），
--   语义: "此套餐用于消耗 N 次 {关联服务}"。
--
-- 字段语义:
--   NULL             → 老行为，multi 套餐自包含（不关联服务）
--   INTEGER          → 关联到某个同 owner 的单次服务（package_type IS NULL）
--
-- 约束:
--   - 仅在 package_type = 'multi' 时有意义
--   - 不能自引用（应用层校验，DB 层用 CHECK 兜底）
--   - ON DELETE SET NULL：被关联的服务删除时，套餐不消失，字段置 NULL
--
-- 注意: 同 owner 校验和 package_type 校验放在应用层（路由 validator），
--       因为 SQL CHECK 无法跨行验证 owner_id/package_type。

ALTER TABLE task_expert_services
    ADD COLUMN IF NOT EXISTS linked_service_id INTEGER
        REFERENCES task_expert_services(id) ON DELETE SET NULL;

-- 自引用禁止
ALTER TABLE task_expert_services
    ADD CONSTRAINT ck_task_expert_services_linked_not_self
        CHECK (linked_service_id IS NULL OR linked_service_id <> id);

-- 查询常用模式: 给定一个单次服务，列出所有关联它的 multi 套餐
CREATE INDEX IF NOT EXISTS ix_task_expert_services_linked_service_id
    ON task_expert_services (linked_service_id)
    WHERE linked_service_id IS NOT NULL;
