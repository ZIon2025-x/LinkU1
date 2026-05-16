-- Migration 235: change forum_posts.category_id FK ondelete to SET NULL
-- After migration 234 made category_id nullable, CASCADE no longer matches intent.
-- Deleting a board should now demote its posts to "no topic", not erase them.

BEGIN;

ALTER TABLE forum_posts DROP CONSTRAINT IF EXISTS forum_posts_category_id_fkey;
ALTER TABLE forum_posts ADD CONSTRAINT forum_posts_category_id_fkey
    FOREIGN KEY (category_id) REFERENCES forum_categories(id) ON DELETE SET NULL;

COMMIT;
