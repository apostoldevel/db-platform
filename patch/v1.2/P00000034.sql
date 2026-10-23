--------------------------------------------------------------------------------
-- P00000034 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- db.recovery_ticket.type: a registration code is not a password reset
-- (ship-safety T330).
--
-- Registration codes and recovery codes share one table, and nothing told
-- them apart. api.registration_code_by_* issues the ticket to the caller when
-- the caller is not in group system; api.reset_password took any ticket that
-- passed CheckRecoveryTicket and set the password of its owner. So the holder
-- of someone's session asked for a registration code to a mailbox of their
-- own and then reset that person's password without knowing the old one.
--
-- From now on the registration wrappers mark their ticket V, and the three
-- consumers that act on the owner's account -- api.check_recovery_ticket,
-- api.reset_password, the ticket grant of daemon.token -- accept R only.
--
-- Tickets alive at the moment of the patch cannot be told apart by type, so the
-- short-lived ones are closed (marked used): a registration code lives 30 minutes
-- (email) or 5 (phone), and nothing else this platform issues lives that briefly
-- except a 5-minute phone recovery, whose owner asks for a new code. Longer
-- tickets -- a recovery by email (1 hour), a project's invitation or activation
-- (hours to days) -- are left alone. They are marked used rather than ended
-- early, which would collide with the unique index (userId, validFromDate,
-- validToDate) when two tickets of one user share a start.
--
-- The DDL is re-runnable; the closing UPDATE belongs to the first run (the
-- migrator applies a patch once) and would close a short ticket issued since.
--------------------------------------------------------------------------------

\set ON_ERROR_STOP on

ALTER TABLE db.recovery_ticket ADD COLUMN IF NOT EXISTS type char NOT NULL DEFAULT 'R';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_constraint
     WHERE conrelid = 'db.recovery_ticket'::regclass AND conname = 'recovery_ticket_type_check'
  ) THEN
    ALTER TABLE db.recovery_ticket ADD CONSTRAINT recovery_ticket_type_check CHECK (type IN ('R', 'V'));
  END IF;
END
$$;

COMMENT ON COLUMN db.recovery_ticket.type IS 'R = password recovery (resets the password, signs in), V = address verification (registration code). Set to V by api.registration_code_by_*.';

UPDATE db.recovery_ticket SET used = Now()
 WHERE used IS NULL AND type = 'R' AND validToDate > Now()
   AND validToDate - validFromDate <= interval '30 minutes';
