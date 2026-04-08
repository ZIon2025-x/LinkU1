-- ===========================================
-- 迁移 183: backfill 历史 Review.expert_id + Expert.rating
--
-- 背景:
--   2026-04-08 修复 crud/review.py 写入 Review.expert_id 之前,
--   所有团队任务的评价 expert_id 都是 NULL,导致:
--     - GET /api/experts/{id}/reviews 团队评价列表恒空
--     - 团队 Owner/Admin 找不到评价回复
--     - Expert.rating 永远不更新
--
-- 这个迁移:
--   1. 把历史 Review.expert_id 从 task.taker_expert_id 反向填充
--   2. 重算所有受影响 Expert 的 rating / completed_tasks / completion_rate
-- ===========================================
BEGIN;

-- 1) 反向填充 Review.expert_id (仅 NULL 行)
UPDATE reviews r
SET expert_id = t.taker_expert_id
FROM tasks t
WHERE r.task_id = t.id
  AND t.taker_expert_id IS NOT NULL
  AND r.expert_id IS NULL;

-- 2) 重算 Expert.rating / completed_tasks / completion_rate
--    (一次性,与 crud.review.update_expert_team_statistics 逻辑一致)
WITH expert_stats AS (
    SELECT
        e.id AS expert_id,
        COALESCE(AVG(r.rating)::numeric(3,2), 0.00) AS avg_rating,
        COUNT(DISTINCT CASE WHEN t.status = 'completed' THEN t.id END) AS completed_count,
        COUNT(DISTINCT CASE
            WHEN t.status IN ('in_progress', 'completed', 'pending_confirmation', 'disputed')
            THEN t.id
        END) AS taken_count
    FROM experts e
    LEFT JOIN reviews r ON r.expert_id = e.id
    LEFT JOIN tasks t ON t.taker_expert_id = e.id
    GROUP BY e.id
)
UPDATE experts e
SET
    rating = es.avg_rating,
    completed_tasks = es.completed_count,
    completion_rate = CASE
        WHEN es.taken_count > 0 THEN (es.completed_count::float / es.taken_count * 100.0)
        ELSE 0.0
    END
FROM expert_stats es
WHERE e.id = es.expert_id;

COMMIT;
