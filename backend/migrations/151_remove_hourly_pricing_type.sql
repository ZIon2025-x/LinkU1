-- Migration 151: Remove hourly pricing type
-- Convert all existing 'hourly' pricing_type records to 'fixed'

UPDATE tasks SET pricing_type = 'fixed' WHERE pricing_type = 'hourly';
UPDATE task_expert_services SET pricing_type = 'fixed' WHERE pricing_type = 'hourly';
