-- 217: 重跑 204 的三个 B-tree 索引
--
-- 背景:
--   204 里用了 CREATE INDEX CONCURRENTLY,但旧版 db_migrations.py 在 psycopg2
--   raw_conn 上默认有隐式事务,CONCURRENTLY 不能在事务内执行,三个索引全部
--   创建失败 (日志里三条 "cannot run inside a transaction block" warning)。
--   db_migrations.py 已修:遇到含 CONCURRENTLY 的语句会临时切 autocommit=True。
--
-- 幂等: IF NOT EXISTS,重复执行安全。

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_lat_lng_btree
  ON tasks (latitude, longitude)
  WHERE latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND status IN ('open', 'in_progress')
    AND is_visible = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_services_lat_lng_btree
  ON task_expert_services (latitude, longitude)
  WHERE latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND status = 'active'
    AND location_type IN ('in_person', 'both');

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_experts_lat_lng_btree
  ON experts (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
