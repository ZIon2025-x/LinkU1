-- Migration 097: Performance optimization indexes
-- Adds indexes for high-frequency query patterns identified in routers.py and forum_routes.py
-- These cover N+1 query hotspots, unindexed filters, and aggregate queries

-- ===================== reviews table =====================
-- GET /profile/me calculates avg_rating by scanning all reviews for a user
-- This index makes the aggregation efficient
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reviews_user_id
  ON reviews (user_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reviews_user_id_rating
  ON reviews (user_id, rating);

-- ===================== admin_requests table =====================
-- GET /admin/customer-service-requests orders by created_at desc, filters by status/priority
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_admin_requests_created_at_desc
  ON admin_requests (created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_admin_requests_status
  ON admin_requests (status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_admin_requests_requester_id
  ON admin_requests (requester_id);

-- ===================== admin_chat_messages table =====================
-- GET /admin/customer-service-chat orders by created_at asc, fetches all
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_admin_chat_messages_created_at
  ON admin_chat_messages (created_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_admin_chat_messages_sender
  ON admin_chat_messages (sender_type, sender_id);

-- ===================== refund_requests table =====================
-- Task timeline queries filter by task_id and order by created_at
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_refund_requests_task_id_created_at
  ON refund_requests (task_id, created_at ASC);

-- ===================== task_disputes table =====================
-- Task timeline queries filter by task_id and order by created_at
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_disputes_task_id_created_at
  ON task_disputes (task_id, created_at ASC);

-- ===================== message_attachments table =====================
-- Evidence file lookups use blob_id
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_message_attachments_blob_id
  ON message_attachments (blob_id);

-- ===================== task_participants table =====================
-- Multi-participant lookups: filter by task_id + status, or user_id + status
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_participants_task_status
  ON task_participants (task_id, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_participants_user_status
  ON task_participants (user_id, status);

-- ===================== tasks table =====================
-- Profile page: count in-progress tasks by poster/taker + status
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_poster_status
  ON tasks (poster_id, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_taker_status
  ON tasks (taker_id, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_expert_creator_status
  ON tasks (expert_creator_id, status)
  WHERE expert_creator_id IS NOT NULL;

-- ===================== admin_users table =====================
-- Stripe dispute notification queries active admins
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_admin_users_is_active
  ON admin_users (is_active)
  WHERE is_active = true;
