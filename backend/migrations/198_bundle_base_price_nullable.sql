-- 198: 允许 task_expert_services.base_price 为 NULL
--
-- 背景:
--   base_price 是"单次课时价" — multi 套餐需要(单次课时价),普通单次服务需要
--   (服务单价),但 bundle 套餐没有"单价"概念,它是"把几个子服务打包,各按子
--   服务的 base_price 结算"。
--
--   之前为了绕开 NOT NULL 约束,前端 bundle 提交时把 package_price 占位塞给
--   base_price,导致 DB 里 bundle 行的 base_price 语义脏乱。
--
-- 变更:
--   DROP NOT NULL — bundle 类型可写 NULL;multi/null 类型仍由 schema validator
--   在应用层强制 > 0。
--
-- 迁移后语义:
--   - NULL → 此服务是 bundle 套餐,不存在"单价"
--   - > 0  → 单次服务或 multi 套餐的单价
ALTER TABLE task_expert_services
  ALTER COLUMN base_price DROP NOT NULL;
