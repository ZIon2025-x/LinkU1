-- 兜底回填(防止 208a 到 208b 之间有旧代码漏写 flag 的行)
UPDATE tasks
SET is_consultation_placeholder = TRUE
WHERE task_source IN ('consultation', 'task_consultation', 'flea_market_consultation')
  AND is_consultation_placeholder = FALSE;

-- 双保险 ASSERT:若仍有违反行(新代码漏改的 / 兜底 UPDATE 未覆盖的边界),中止 migration 并报告,
-- 避免 ADD CONSTRAINT 崩溃在"扫描表时发现违反"的模糊错误信息上
-- ⚠️ 要求 migration runner 用 ON_ERROR_STOP=on(psql -v ON_ERROR_STOP=1 / --single-transaction)或等效设置,
--    否则 RAISE EXCEPTION 触发后 runner 可能仍继续执行下面的 ADD CONSTRAINT,失去双保险意义
DO $$
DECLARE
  violation_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO violation_count
  FROM tasks
  WHERE (is_consultation_placeholder = TRUE
          AND task_source NOT IN ('consultation', 'task_consultation', 'flea_market_consultation'))
     OR (is_consultation_placeholder = FALSE
          AND task_source IN ('consultation', 'task_consultation', 'flea_market_consultation'));
  IF violation_count > 0 THEN
    RAISE EXCEPTION
      'Cannot add ck_tasks_consultation_placeholder_matches_source: % rows still inconsistent. '
      'Check: SELECT id, task_source, is_consultation_placeholder FROM tasks WHERE (...same predicate...). '
      'Fix data before retry (probably old code still writing to prod).', violation_count;
  END IF;
END $$;

-- 强约束两个字段一致,避免 source-of-truth 漂移
-- 新代码已全部通过 create_placeholder_task helper 同时写两字段,此时加约束不会破坏任何写入
ALTER TABLE tasks
  ADD CONSTRAINT ck_tasks_consultation_placeholder_matches_source
  CHECK (
    (is_consultation_placeholder = TRUE
      AND task_source IN ('consultation', 'task_consultation', 'flea_market_consultation'))
    OR
    (is_consultation_placeholder = FALSE
      AND task_source NOT IN ('consultation', 'task_consultation', 'flea_market_consultation'))
  );
