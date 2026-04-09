-- P00000007.sql: Add scope column to db.log
-- Part of: Logging system redesign (2026-04-09)

ALTER TABLE db.log ADD COLUMN IF NOT EXISTS scope text;

COMMENT ON COLUMN db.log.scope IS 'Event subsystem: lifecycle, workflow, payment.stripe, ocpp.status, etc.';

CREATE INDEX IF NOT EXISTS log_scope_idx ON db.log (scope);
CREATE INDEX IF NOT EXISTS log_scope_event_idx ON db.log (scope, event);
CREATE INDEX IF NOT EXISTS log_type_datetime_idx ON db.log (type, datetime);
CREATE INDEX IF NOT EXISTS log_type_scope_datetime_idx ON db.log (type, scope, datetime);
