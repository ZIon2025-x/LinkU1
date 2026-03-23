-- Composite index for follow feed: speeds up queries filtering by user_id + action + timestamp
CREATE INDEX IF NOT EXISTS ix_task_history_user_action_ts ON task_history(user_id, action, timestamp DESC);
