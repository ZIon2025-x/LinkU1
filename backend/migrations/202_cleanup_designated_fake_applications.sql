-- 清理 designated-task-refactor 前遗留的伪造 TaskApplication
-- 规则：task.status='pending_acceptance' 且 application.applicant_id=task.taker_id
--       且 application.message='来自用户资料页的任务请求' 且 status='pending'
-- 这些是 crud/task.py 老版本创建的伪造申请，重构后不再需要

BEGIN;

DELETE FROM task_applications
WHERE id IN (
  SELECT ta.id
  FROM task_applications ta
  JOIN tasks t ON ta.task_id = t.id
  WHERE t.status = 'pending_acceptance'
    AND ta.status = 'pending'
    AND ta.message = '来自用户资料页的任务请求'
    AND ta.applicant_id = t.taker_id
);

COMMIT;
