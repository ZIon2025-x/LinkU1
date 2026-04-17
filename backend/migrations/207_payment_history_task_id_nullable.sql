-- 207_payment_history_task_id_nullable.sql
-- Make PaymentHistory.task_id nullable to support activity payments (no associated task)

ALTER TABLE payment_history ALTER COLUMN task_id DROP NOT NULL;
