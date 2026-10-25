--------------------------------------------------------------------------------
-- P00000038 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The channel `http` on notify (apostol-csms T1102, stage E3 of T996): what the
-- database must have before a sender can take the channel to `single`.
--
-- What arrives:
--   http.try_create_response  the response of an open request, stored and the row closed
--                             under its lock; false when the row is not open
--   http.retake               the row of a REPEAT; a lifetime that ended closes it as
--                             "outcome unknown" and calls the producer, not quietly
--   http.fail_unknown         the closing both of them and http.abandon share
--   http.abandon              `on_abandon` of the channel http: the request a delivery
--                             row carries is closed when notify closes the row
--   http.sweep                leaves alone a row that has a delivery row in notify.queue
--
-- What changes: the trigger function http.ft_request_after_insert hands `max_attempts`
-- to notify.send only with `expire` (a request without a lifetime is outside the
-- resend contract; notify would take its repeat for one without a limit). The trigger
-- itself is untouched. `update.psql` never re-runs table.sql, which is why the
-- function is here, as a copy of the body in http/table.sql.
--
-- The index queue_channel_key (notify.queue, every state): http.sweep asks whether a request has a delivery row,
-- and the partial index of the open rows cannot answer for a closed one -- 62 ms a statement on 500 000 closed
-- rows with fresh statistics, seconds with stale ones.
--
-- The channel row: on_abandon = http.abandon and on_expire = true where nobody set an
-- abandon function; lease 2 minutes where the 5 minutes of the first seed stand (the
-- longest a sender is in flight is its timeout + 10 s of the task + 20 s of the
-- transaction, 60 s at the 30 s of the shipped configuration). The channel is
-- `legacy` on every installation, so none of this is in force until it is switched.
--
-- ORDER. A function named by on_abandon has to exist before the row names it (the
-- trigger of notify.channel checks), so http/notify.sql is included first -- the
-- reasoning of P00000016 and P00000035: a second copy of the functions is a second
-- copy that drifts. The file holds the four new functions and nothing else on purpose:
-- http/routine.sql also has http.get and http.post, which a configuration overrides,
-- and running it here would put the platform's copies in their place for as long as
-- the patches after this one take (update.psql restores the override, later). The file
-- is CREATE OR REPLACE only and ends with the REVOKE/GRANT of the new functions;
-- `update.psql` runs it again right after the patches. http.sweep (routine.sql) is
-- replaced by that run, not here: the channel is `legacy` until it is switched, and
-- the new exclusion changes nothing while there are no delivery rows.
--
-- Single phase, kernel: DDL and DML on notify.channel, no session. Re-runnable.
--------------------------------------------------------------------------------

\ir '../../http/notify.sql'

--------------------------------------------------------------------------------
-- http.ft_request_after_insert -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION http.ft_request_after_insert()
RETURNS     trigger
AS $$
BEGIN
  PERFORM notify.send('http', NEW.id::text, NEW.id::text, NEW.expire,
                      CASE WHEN NEW.expire IS NOT NULL THEN NEW.max_attempts ELSE 0 END);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- notify.queue: the lookup of http.sweep ---------------------------------------
--------------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS queue_channel_key ON notify.queue (channel, key) WHERE key IS NOT NULL;

--------------------------------------------------------------------------------
-- notify.channel `http` ---------------------------------------------------------
--------------------------------------------------------------------------------

UPDATE notify.channel SET on_abandon = 'http.abandon', on_expire = true
 WHERE code = 'http' AND on_abandon IS NULL;

UPDATE notify.channel SET lease = interval '2 minutes'
 WHERE code = 'http' AND lease = interval '5 minutes';
