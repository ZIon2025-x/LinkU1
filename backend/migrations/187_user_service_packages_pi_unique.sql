-- 187: 给 user_service_packages.payment_intent_id 加 partial unique 索引
-- 背景: 套餐购买 webhook (routers.py:7741) 用 query-then-add 模式做幂等,
--       并发同一 PI 的两次 webhook 调用可创建多条 UserServicePackage 行。
-- 修复: DB 层 unique 约束兜底 + webhook 端用 IntegrityError 捕获(等价 ON CONFLICT DO NOTHING)。
-- payment_intent_id 是 nullable(历史数据可能为 NULL),所以用 partial index 仅约束非 NULL 值。

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_service_packages_pi
  ON user_service_packages(payment_intent_id)
  WHERE payment_intent_id IS NOT NULL;
