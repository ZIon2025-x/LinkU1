-- backend/migrations/194_payment_transfers_taker_id_nullable.sql
-- Make payment_transfers.taker_id nullable so package transfers (which have
-- no individual taker, only an expert team) can be inserted.
--
-- For task transfers, taker_id is still set to the worker's user_id.
-- For package transfers, taker_id IS NULL and taker_expert_id holds the team.

BEGIN;

ALTER TABLE payment_transfers
  ALTER COLUMN taker_id DROP NOT NULL;

COMMIT;
