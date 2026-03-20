-- P00000004.sql — Add attempts counter to recovery_ticket
--
-- Prevents brute-force of 6-digit verification codes.
-- CheckRecoveryTicket() enforces max 5 attempts per ticket.

\set ON_ERROR_STOP on

ALTER TABLE db.recovery_ticket ADD COLUMN IF NOT EXISTS attempts int NOT NULL DEFAULT 0;
