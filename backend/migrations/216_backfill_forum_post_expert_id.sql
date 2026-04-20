-- Backfill forum_posts.expert_id for posts published inside an expert board.
--
-- Context: forum_routes.create_post checked is_expert_board() to gate posting
-- permission, but never wrote the resulting expert_id to ForumPost.expert_id.
-- As a result, follow_feed_routes._fetch_followed_forum_posts (which matches
-- team-identity posts via ForumPost.expert_id IN following_expert_ids) returned
-- zero rows for every expert team — ExpertFollow users could not see team-board
-- posts in their follow feed, and those posts showed the author's personal
-- name/avatar instead of the team's in any list that prefers expert_id.
--
-- Fix going forward: forum_routes.py now sets expert_id at insert time when
-- the target category is an expert board. This migration closes the gap on
-- existing rows.

UPDATE forum_posts fp
SET expert_id = fc.expert_id
FROM forum_categories fc
WHERE fp.category_id = fc.id
  AND fc.type = 'expert'
  AND fc.expert_id IS NOT NULL
  AND fp.expert_id IS NULL;
