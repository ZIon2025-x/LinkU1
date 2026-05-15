-- 给 tasks / task_expert_services / experts / activities 四表加 city_canonical 列。
--
-- 目标：把 location 自由文本规范化为 UK 主要城市的 canonical 名（如 'London'），
-- 让"同城"查询从 ILIKE 多 pattern 扫表 → 索引等值匹配，并消除 borough 漏检
-- （Camden/Soho/Croydon 等都规范化为 'London'）。
--
-- 写入路径：SQLAlchemy before_insert / before_update 事件钩子（app/event_listeners.py）
-- 调用 resolve_city_canonical(location) 自动维护此列。
--
-- 历史数据：由 backend/scripts/backfill_city_canonical.py 一次性回填。
--
-- 索引：city_canonical 是查询主入口，必须索引；location 已是字符串无 unique 约束。

ALTER TABLE tasks
ADD COLUMN city_canonical VARCHAR(50) NULL;
CREATE INDEX idx_tasks_city_canonical ON tasks(city_canonical);
COMMENT ON COLUMN tasks.city_canonical IS '由 location 规范化得到的 canonical UK 城市名（London/Birmingham/...），NULL 表示无法识别';

ALTER TABLE task_expert_services
ADD COLUMN city_canonical VARCHAR(50) NULL;
CREATE INDEX idx_task_expert_services_city_canonical ON task_expert_services(city_canonical);
COMMENT ON COLUMN task_expert_services.city_canonical IS '由 location 规范化得到的 canonical UK 城市名，personal 服务用 service.location，expert 服务可由 expert.location 兜底';

ALTER TABLE experts
ADD COLUMN city_canonical VARCHAR(50) NULL;
CREATE INDEX idx_experts_city_canonical ON experts(city_canonical);
COMMENT ON COLUMN experts.city_canonical IS '由 location 规范化得到的 canonical UK 城市名，达人团队服务在 service.city_canonical 缺失时回退此列';

ALTER TABLE activities
ADD COLUMN city_canonical VARCHAR(50) NULL;
CREATE INDEX idx_activities_city_canonical ON activities(city_canonical);
COMMENT ON COLUMN activities.city_canonical IS '由 location 规范化得到的 canonical UK 城市名，活动列表 city 过滤走此索引';
