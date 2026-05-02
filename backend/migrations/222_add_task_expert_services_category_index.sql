-- 222_add_task_expert_services_category_index.sql
-- 为 task_expert_services.category 加索引，优化技能板块"按 category 列服务"查询.
--
-- 背景: 2026-05-01 把 expert/service category 字典从 13 扩到 30 keys。
-- GET /api/services?category=X 跨达人列服务（用于 SkillLeaderboardView 的
-- "本类别下的服务" section），每次切 tab 都跑:
--     WHERE status='active' AND owner_type='expert' AND category=?
--     ORDER BY display_order, created_at
--
-- 现有索引（models.py:1693-1697）只有 expert_id / status / owner. 没有 category.
-- 上千个 active 服务时 category 过滤需要全表扫. 加索引消除这个 hot path.
--
-- 用 CONCURRENTLY 不锁写入；NOT EXISTS 让重复跑安全.
-- 单语句执行（CREATE INDEX CONCURRENTLY 不能在事务里）.

CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_task_expert_services_category
ON task_expert_services(category);
