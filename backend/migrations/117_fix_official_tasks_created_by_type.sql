-- Fix official_tasks.created_by column type: Integer -> VARCHAR(5)
-- AdminUser.id is String(5) format (e.g. 'A6688'), not Integer
ALTER TABLE official_tasks ALTER COLUMN created_by TYPE VARCHAR(5) USING created_by::VARCHAR(5);
