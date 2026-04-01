-- 149_migrate_old_task_types.sql
-- Migrate old task_type values to new standardized types.
-- Old types: Housekeeping, Campus Life, Second-hand & Rental, Errand Running,
--            Skill Service, Social Help, Transportation, Pet Care, Life Convenience, Other

-- One-to-one mappings (clear correspondence)
UPDATE tasks SET task_type = 'cleaning'       WHERE task_type = 'Housekeeping';
UPDATE tasks SET task_type = 'campus_life'    WHERE task_type = 'Campus Life';
UPDATE tasks SET task_type = 'second_hand'    WHERE task_type = 'Second-hand & Rental';
UPDATE tasks SET task_type = 'errand'         WHERE task_type = 'Errand Running';
UPDATE tasks SET task_type = 'accompany'      WHERE task_type = 'Social Help';
UPDATE tasks SET task_type = 'pickup_dropoff' WHERE task_type = 'Transportation';
UPDATE tasks SET task_type = 'pet_care'       WHERE task_type = 'Pet Care';
UPDATE tasks SET task_type = 'other'          WHERE task_type = 'Other';

-- Ambiguous mappings (old broad categories → best-fit new type)
-- "Skill Service" covered tutoring/translation/design/programming/writing — cannot distinguish, map to 'other'
UPDATE tasks SET task_type = 'other'          WHERE task_type = 'Skill Service';
-- "Life Convenience" covered cooking/repair/misc — cannot distinguish, map to 'other'
UPDATE tasks SET task_type = 'other'          WHERE task_type = 'Life Convenience';

-- Also update ai_tools old type references to prevent future mismatches
-- (code change needed separately — this migration only handles data)
