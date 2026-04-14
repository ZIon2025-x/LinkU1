-- 197: 清理 task_expert_services.package_type 的 'single' 枚举值
--
-- 背景:
--   _VALID_PACKAGE_TYPES 原本是 ('single', 'multi', 'bundle'),但整个系统里
--   'single' 没有任何独占行为 — 套餐购买入口 /services/{id}/purchase-package
--   显式拒绝 single; 前端套餐管理页也把 single/null 都当"普通服务"过滤掉;
--   实际的"套餐"只有 multi / bundle 两种。
--
-- 变更:
--   1. 把历史 package_type='single' 的行统一刷成 NULL (如果有的话)
--   2. 去掉 NOT NULL 约束 + server_default='single',让普通服务用 NULL 表达
--
-- 迁移后语义:
--   - package_type IS NULL   → 普通单次服务 (走 /apply 申请 + Task 流程)
--   - package_type = 'multi' → 多课时套餐
--   - package_type = 'bundle'→ 服务包

-- 1. single → NULL (幂等,没有 single 数据也不会报错)
UPDATE task_expert_services
SET package_type = NULL
WHERE package_type = 'single';

-- 2. 允许 NULL + 去掉 server default
ALTER TABLE task_expert_services
  ALTER COLUMN package_type DROP DEFAULT,
  ALTER COLUMN package_type DROP NOT NULL;
