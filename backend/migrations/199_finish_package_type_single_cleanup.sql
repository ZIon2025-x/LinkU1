-- 199: 补跑 197 未完成的 'single' → NULL 数据清理
--
-- 背景:
--   197 里 UPDATE 语句先于 ALTER DROP NOT NULL 执行 (语句分割器顺序),
--   导致旧行改 NULL 时撞 NOT NULL 约束失败。fallback 的 psycopg2 把 ALTER
--   跑通了但 UPDATE 没补,数据库里仍残留 package_type='single' 的行。
--
--   197 已被标记为"已执行",需要独立 migration 把残留 'single' 刷成 NULL。
--
-- 幂等: 没有残留数据时是无操作。
UPDATE task_expert_services
SET package_type = NULL
WHERE package_type = 'single';
