DROP FUNCTION IF EXISTS kernel.RecoveryPasswordByPhone(uuid, text);
DROP FUNCTION IF EXISTS kernel.AddRecoveryTicket(uuid, text, timestamp with time zone, timestamp with time zone);
DROP FUNCTION IF EXISTS kernel.NewRecoveryTicket(uuid, text, timestamp with time zone, timestamp with time zone);

ALTER TABLE db.recovery_ticket
  ADD COLUMN initiator text;

COMMENT ON COLUMN db.recovery_ticket.initiator IS 'Инициатор';

CREATE INDEX ON db.recovery_ticket (initiator, validFromDate, validToDate);

UPDATE db.recovery_ticket SET initiator = encode(digest(ticket::text, 'sha1'), 'hex');

ALTER TABLE db.recovery_ticket
	ALTER COLUMN initiator SET NOT NULL;
