--------------------------------------------------------------------------------
-- P00000040 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The switch of a channel to `single` and the safety net of a callback that failed (apostol-csms T1165 and T1158,
-- E4 of T996): what the database must have before MessageServer and ReportServer take their channels to `single`.
--
-- What arrives:
--   notify.channel.on_release  a function (boolean, integer) RETURNING integer that the module owning the channel
--                       names, as it names on_abandon; checked by the trigger t_channel_check (that trigger now also
--                       fires on this column)
--   t_channel_switch    AFTER UPDATE OF mode, when the mode becomes `single`: notify.release(channel, true, NULL) in the
--                       transaction of the switch, whoever made it; an exception of the function refuses the switch
--   notify.release      calls the function the channel names (EXECUTE of a checked name); the sweep of a single channel
--                       calls it once a minute (update.psql, run right after the patches, replaces notify.sweep_channel)
--   ReleaseOutbox       `prepared` messages with no open row go to the queue through OutboxAbandon (older than the grace
--                       of the channel), `sending` ones older than the lease are failed as "outcome unknown"
--   ReleaseReportReady  `progress` / `canceled` reports with no open row and older than the lease are closed through
--                       ReportReadyAbandon; at the switch a younger one refuses it
--
-- A function named by on_release has to exist before the row names it (the trigger checks), so the functions are
-- defined here as their modules define them (the text below is the text of the modules, byte for byte). A value an
-- operator already set is not overwritten. Re-runnable: ADD COLUMN IF NOT EXISTS, CREATE OR REPLACE, both triggers
-- dropped and created, the UPDATE takes only a NULL.
--
-- On a base that comes from `v1.23.3` P00000035 installs the module notify from today's files and the column is
-- there already; on a base that has P00000035..P00000039 the column is added here. Nothing changes for a channel
-- in `legacy`: the column is empty, the trigger fires on a switch to `single` only, and the sweep of a `legacy`
-- channel does not call the function.
--
-- DDL on notify.channel, DML on it and functions: kernel phase, no \connect.

\set ON_ERROR_STOP on


--------------------------------------------------------------------------------
-- notify.channel.on_release ---------------------------------------------------
--------------------------------------------------------------------------------

ALTER TABLE notify.channel ADD COLUMN IF NOT EXISTS on_release text;

COMMENT ON COLUMN notify.channel.on_release IS 'Function (boolean, integer) RETURNING integer = (switch, limit): the owning module''s look at the objects that stand in the delivery of this channel and hold no open row of the queue. Called by the trigger that follows a switch to single (switch = true: it may refuse the switch) and by the sweep of a single channel (switch = false).';

--------------------------------------------------------------------------------
-- notify.ft_channel_check -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION notify.ft_channel_check()
RETURNS trigger
AS $$
DECLARE
  rFn           regprocedure;
BEGIN
  IF NEW.target_fn IS NOT NULL THEN
    rFn := to_regprocedure(NEW.target_fn || '(text)');

    IF rFn IS NULL OR (SELECT prorettype FROM pg_proc WHERE oid = rFn) <> 'integer'::regtype THEN
      RAISE EXCEPTION 'ERR-40000: Channel "%": target_fn "%" is not a function (text) RETURNING integer.', NEW.code, NEW.target_fn;
    END IF;
  END IF;

  IF NEW.on_abandon IS NOT NULL AND to_regprocedure(NEW.on_abandon || '(bigint,text,text,text)') IS NULL THEN
    RAISE EXCEPTION 'ERR-40000: Channel "%": on_abandon "%" is not a function (bigint, text, text, text).', NEW.code, NEW.on_abandon;
  END IF;

  IF NEW.on_release IS NOT NULL THEN
    rFn := to_regprocedure(NEW.on_release || '(boolean,integer)');

    IF rFn IS NULL OR (SELECT prorettype FROM pg_proc WHERE oid = rFn) <> 'integer'::regtype THEN
      RAISE EXCEPTION 'ERR-40000: Channel "%": on_release "%" is not a function (boolean, integer) RETURNING integer.', NEW.code, NEW.on_release;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

DROP TRIGGER IF EXISTS t_channel_check ON notify.channel;

CREATE TRIGGER t_channel_check
  BEFORE INSERT OR UPDATE OF target_fn, on_abandon, on_release ON notify.channel
  FOR EACH ROW EXECUTE FUNCTION notify.ft_channel_check();

--------------------------------------------------------------------------------
-- notify.ft_channel_switch, notify.release ------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION notify.ft_channel_switch()
RETURNS trigger
AS $$
BEGIN
  PERFORM notify.release(NEW.code, true, null);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

/**
 * @brief Call the function the channel names in on_release: the owning module's look at the objects that stand in
 *        the delivery of the channel and hold no open row of the queue (T1158, T1165). A channel with no such
 *        function: nothing to do.
 * @param {text} pChannel - Channel
 * @param {boolean} pSwitch - The channel has just been switched to single (the trigger): the function may refuse
 *        the switch with an exception. false: the sweep of a single channel
 * @param {integer} pLimit - Objects per call; NULL for all (the switch hands every object over at once)
 * @return {integer} - Objects the function acted on
 * @since 1.2.39
 *
 * The name is text that runs under EXECUTE, as on_abandon does: it is checked where it is written
 * (notify.ft_channel_check) and the function is closed to PUBLIC like the rest of the module.
 */
CREATE OR REPLACE FUNCTION notify.release (
  pChannel      text,
  pSwitch       boolean DEFAULT false,
  pLimit        integer DEFAULT 100
) RETURNS       integer
AS $$
DECLARE
  vFn           text;
  nCount        integer;
BEGIN
  SELECT on_release INTO vFn FROM notify.channel WHERE code = pChannel;

  IF vFn IS NULL THEN
    RETURN 0;
  END IF;

  EXECUTE format('SELECT %s($1, $2)', vFn) INTO nCount USING pSwitch, pLimit;

  RETURN coalesce(nCount, 0);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

-- nothing is left to PUBLIC in this schema (routine.sql): the two new functions are closed here, update.psql
-- does the same for the whole schema afterwards
REVOKE ALL ON FUNCTION notify.ft_channel_switch() FROM PUBLIC;
REVOKE ALL ON FUNCTION notify.release(text, boolean, integer) FROM PUBLIC;

DROP TRIGGER IF EXISTS t_channel_switch ON notify.channel;

CREATE TRIGGER t_channel_switch
  AFTER UPDATE OF mode ON notify.channel
  FOR EACH ROW
  WHEN (NEW.mode = 'single' AND OLD.mode IS DISTINCT FROM NEW.mode)
  EXECUTE FUNCTION notify.ft_channel_switch();

--------------------------------------------------------------------------------
-- ReleaseOutbox ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief `on_release` of the notify channel `outbox` (T1158, T1165): hand over the messages that stand in the delivery
 *        and hold no open row of the queue. The one procedure of the safety net of a failed callback and of the switch
 *        of the channel from `legacy` to `single`.
 *
 * Who such a message is. In `single` every `prepared` message has an open row (the trigger of db.notification puts it
 * in in the transaction of `submit`), and a `sending` one has the row its sender holds. One without a row is
 *  - `prepared`, put in while the channel was `legacy` (the old path polls `prepared` and sends it; once the channel is
 *    `single` that poll is empty by the mode, and nobody takes the message);
 *  - `prepared` or `sending` whose row was closed and whose callback then failed (`notify.close` keeps the row closed,
 *    writes `on_abandon failed: ...` to its `error` and leaves the message where it was: nobody restarts a callback);
 *  - `sending`, sent by a sender of the old path at the moment of the switch (a poller of `api.outbox` made the
 *    message `sending` and sends it with no row at all).
 * The last one is alive; the others are not, and the age of the state tells them apart, as it does for a job
 * (ReleaseJob): a `sending` message without a row is handed over only when its state is as old as the `lease` of the
 * channel -- a send of the old path that lasts that long is dead.
 * A `prepared` message is handed over when its state is as old as the `grace` of the channel (3 s): the time the old
 * path has to take it. Nothing of a `prepared` message has left, but on the path single `send` is committed before
 * anything leaves, and on the old path it runs BESIDE the delivery (MessageServer::do_send hands the mail over without
 * waiting for it): a message that a sender of the old path has in flight at the moment of the switch is `prepared` for
 * the round trips of its `send`, tens of milliseconds, and a row put in then would be a second sender on another
 * instance (the same process is told by its own memory). Younger than `grace` is left for the next look of the sweep.
 * The window that remains is a sender of the old path that stalls longer than `grace` between taking the message and
 * `send` -- the database stalls with it; there is no state to tell such a message from one that waits.
 *
 * It does not decide anything itself: every message goes through OutboxAbandon, the callback of the channel, which
 * reads the state under the lock and does what a closed row would have done -- `prepared` a new row (with the bound of
 * T1157: the rows that ended since the message entered `prepared` are counted), `sending` the label `outcome unknown`
 * and `fail`. One body for the two ways in, and a message with an open row is never given a second one.
 *
 * A failure of one message is a line in the event log (`workflow.outbox`, `release`) and the next message goes on.
 * With pSwitch the failures refuse the switch (an exception with their number and the first reason): a message that
 * could not be handed over must not be left behind in silence by a channel the old path no longer serves.
 * The messages are taken `FOR UPDATE SKIP LOCKED`: one that an action holds is somebody else's this minute.
 * @param {boolean} pSwitch - The channel has just been switched to single
 * @param {integer} pLimit - Messages per call; NULL for all
 * @return {integer} - Messages handed to OutboxAbandon
 * @since 1.2.39
 */
CREATE OR REPLACE FUNCTION ReleaseOutbox (
  pSwitch    boolean DEFAULT false,
  pLimit     integer DEFAULT 100
) RETURNS    integer
AS $$
DECLARE
  r          record;
  uClass     uuid;
  iLease     interval;
  iGrace     interval;
  dBound     timestamptz;
  nCount     integer := 0;
  nFailed    integer := 0;
  vIds       text := '';
  vError     text;
BEGIN
  uClass := GetClass('outbox');

  SELECT lease, grace INTO iLease, iGrace FROM notify.channel WHERE code = 'outbox';

  IF uClass IS NULL OR iLease IS NULL THEN
    RETURN 0;
  END IF;

  -- No system context of its own: OutboxAbandon opens one for every message it acts on, and a context opened here
  -- would leave a row in db.oauth2 and two lines in the log at every look of the sweep, minute after minute, with
  -- nothing to do.
  FOR r IN
    SELECT o.id, s.code AS state,
           (SELECT max(os.validFromDate) FROM db.object_state os WHERE os.object = o.id) AS since
      FROM db.object o INNER JOIN db.state s ON s.id = o.state
     WHERE s.class = uClass AND s.code IN ('prepared', 'sending')
       AND NOT EXISTS (SELECT FROM notify.queue q WHERE q.channel = 'outbox' AND q.state < 2 AND q.payload = o.id::text)
     ORDER BY o.pdate
     LIMIT pLimit
       FOR UPDATE OF o SKIP LOCKED
  LOOP
    -- younger than the time the old path has: a `sending` message may be a send of the old path in progress
    -- (the lease), a `prepared` one may be one the old path has just taken (the grace)
    -- (the bound is a variable: the THEN of a CASE inside the condition of an IF ends the condition for plpgsql)
    dBound := now() - CASE WHEN r.state = 'sending' THEN iLease ELSE iGrace END;

    IF coalesce(r.since, '-infinity') > dBound THEN
      CONTINUE;
    END IF;

    BEGIN
      PERFORM OutboxAbandon(0, NULL, r.id::text, 'orphaned: no open row of the channel');
      nCount := nCount + 1;
    EXCEPTION WHEN others THEN
      nFailed := nFailed + 1;
      vError := coalesce(vError, SQLERRM);

      IF nFailed <= 3 THEN
        vIds := vIds || ' ' || r.id::text;
      END IF;

      PERFORM WriteToEventLog('E', 2027, 'workflow.outbox', 'release', left('release failed: ' || SQLERRM, 400), r.id);
    END;
  END LOOP;

  IF pSwitch AND nFailed > 0 THEN
    -- the line of the log above is rolled back with the refused switch: the ids go into the text
    RAISE EXCEPTION 'ERR-40000: Channel "outbox": % message(s) could not be handed to the queue (first:%), the first reason: %', nFailed, vIds, vError;
  END IF;

  RETURN nCount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

-- Called by notify.release, which runs as the owner: nobody else has a reason to call it (it changes messages).
REVOKE ALL ON FUNCTION ReleaseOutbox(boolean, integer) FROM PUBLIC;

--------------------------------------------------------------------------------
-- ReleaseReportReady ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief `on_release` of the notify channel `report` (T1158, T1165): close the reports that stand in a build and hold
 *        no open row of the queue. The one procedure of the safety net of a failed callback and of the switch of the
 *        channel from `legacy` to `single`.
 *
 * Who such a report is. In `single` a `progress` report has an open row (the trigger of db.notification puts it in in
 * the transaction of `execute`) and one that is `canceled` is waiting for the ReportServer that holds the row to say
 * `abort`. One without a row is
 *  - `progress` whose row was closed and whose callback then failed (the row stays closed, the report stays `progress`);
 *  - a report of the old path: `execute` makes it `progress` and sends the NOTIFY in the same transaction, and the old
 *    path builds it in memory with no row at all -- or has not taken it yet, or never will (nobody listened).
 * The database cannot tell the last two apart: both are `progress` and no row. The age of the state tells the dead
 * from the living, as it does for a job (ReleaseJob): a report that is `progress` / `canceled` with no row and whose
 * state is as old as the `lease` of the channel (10 minutes) is closed the way ReportReadyAbandon closes a report
 * whose row was lost -- `progress` the label `outcome unknown` and `fail` (`failed` has the way back, `execute`),
 * `canceled` `abort`. A younger one may be a build of the old path in progress and is left alone.
 * A report whose row was CONFIRMED since it entered its state is not one of these either: a routine that hands the build
 * to an outside service (rpc_* with a callback that completes it) leaves the report `progress` after the sender has said
 * yes, and the callback may come later than the lease; failing it here would refuse the callback (`complete` from `failed`).
 *
 * A report is NOT put in the queue, as a message is. The row of the channel carries the session of whoever asked for
 * the report (db.ft_notification_after_insert: `current_session()` at `execute`), the build runs in it, with
 * the rights of that user. From SQL it cannot be restored; the session of the operator who switches the channel, or of
 * the bot (what ReportServer takes when the payload has none), would build the report with rights that are not the
 * asker's. The way back is `execute` by the asker, and a failed report offers it.
 *
 * With pSwitch (the trigger that follows a switch to single) the report that is left alone refuses the switch: if
 * any report is `progress` / `canceled` with no row and younger than the lease, the old path may be building it, and
 * a channel switched under it would leave it with nobody to say `abort` and with a build whose result the new
 * path does not know -- the exception names how many there are and how old the oldest is, the mode does not change
 * and nothing is lost in silence: the operator waits until they leave the state (a build of the old path ends) and
 * switches again. Reports older than the lease do not hold the switch: they are closed here, before the count.
 * A failure to close one is a line in the event log (`workflow.report`, `release`) and refuses the switch too.
 *
 * Every report goes through ReportReadyAbandon, the callback of the channel, which reads the state under the lock.
 * The reports are taken `FOR UPDATE SKIP LOCKED`.
 * @param {boolean} pSwitch - The channel has just been switched to single
 * @param {integer} pLimit - Reports per call; NULL for all
 * @return {integer} - Reports handed to ReportReadyAbandon
 * @since 1.2.39
 */
CREATE OR REPLACE FUNCTION ReleaseReportReady (
  pSwitch    boolean DEFAULT false,
  pLimit     integer DEFAULT 100
) RETURNS    integer
AS $$
DECLARE
  r          record;
  uEntity    uuid;
  iLease     interval;
  dOldest    timestamptz;
  nCount     integer := 0;
  nFailed    integer := 0;
  nYoung     integer := 0;
  vIds       text := '';
  vError     text;
BEGIN
  uEntity := GetEntity('report_ready');

  SELECT lease INTO iLease FROM notify.channel WHERE code = 'report';

  IF uEntity IS NULL OR iLease IS NULL THEN
    RETURN 0;
  END IF;

  -- No system context of its own (see ReleaseOutbox): ReportReadyAbandon opens one for every report it acts on.
  -- A report whose row was CONFIRMED since it entered its state is not one of these: a routine that hands the build
  -- to an outside service (rpc_* with a callback that completes it) leaves the report `progress` after the sender has
  -- said yes, and the callback may come later than the lease.
  FOR r IN
    SELECT o.id, s.code AS state, st.since
      FROM db.object o INNER JOIN db.state s ON s.id = o.state
     CROSS JOIN LATERAL (SELECT max(os.validFromDate) AS since FROM db.object_state os WHERE os.object = o.id) st
     WHERE s.class IN (SELECT t.id FROM db.class_tree t WHERE t.entity = uEntity) AND s.code IN ('progress', 'canceled')
       AND NOT EXISTS (SELECT FROM notify.queue q WHERE q.channel = 'report' AND q.state < 2 AND position(o.id::text IN q.payload) > 0)
       AND NOT EXISTS (SELECT FROM notify.queue q WHERE q.channel = 'report' AND q.state = 2 AND q.done >= coalesce(st.since, '-infinity') AND position(o.id::text IN q.payload) > 0)
     ORDER BY o.pdate
     LIMIT pLimit
       FOR UPDATE OF o SKIP LOCKED
  LOOP
    -- younger than the lease: may be a build of the old path in progress
    IF coalesce(r.since, '-infinity') > now() - iLease THEN
      CONTINUE;
    END IF;

    BEGIN
      PERFORM ReportReadyAbandon(0, NULL, jsonb_build_object('id', r.id)::text, 'orphaned: no open row of the channel');
      nCount := nCount + 1;
    EXCEPTION WHEN others THEN
      nFailed := nFailed + 1;
      vError := coalesce(vError, SQLERRM);

      IF nFailed <= 3 THEN
        vIds := vIds || ' ' || r.id::text;
      END IF;

      PERFORM WriteToEventLog('E', 2027, 'workflow.report', 'release', left('release failed: ' || SQLERRM, 400), r.id);
    END;
  END LOOP;

  IF pSwitch THEN
    -- the count that refuses the switch does not skip what another transaction holds: a report an action holds
    -- is one the old path is working on
    SELECT count(*), min(y.since) INTO nYoung, dOldest
      FROM (SELECT st.since
              FROM db.object o INNER JOIN db.state s ON s.id = o.state
             CROSS JOIN LATERAL (SELECT max(os.validFromDate) AS since FROM db.object_state os WHERE os.object = o.id) st
             WHERE s.class IN (SELECT t.id FROM db.class_tree t WHERE t.entity = uEntity) AND s.code IN ('progress', 'canceled')
               AND NOT EXISTS (SELECT FROM notify.queue q WHERE q.channel = 'report' AND q.state < 2 AND position(o.id::text IN q.payload) > 0)
               AND NOT EXISTS (SELECT FROM notify.queue q WHERE q.channel = 'report' AND q.state = 2 AND q.done >= coalesce(st.since, '-infinity') AND position(o.id::text IN q.payload) > 0)
           ) y
     WHERE coalesce(y.since, '-infinity') > now() - iLease;
  END IF;

  IF pSwitch AND nYoung > 0 THEN
    RAISE EXCEPTION 'ERR-40000: Channel "report" is not switched to single: % report(s) stand in progress or canceled with no row of the queue and younger than the lease (%): the old path may be building them; the oldest began % ago. Wait until they leave the state and switch again.',
      nYoung, iLease, date_trunc('second', now() - dOldest);
  END IF;

  IF pSwitch AND nFailed > 0 THEN
    RAISE EXCEPTION 'ERR-40000: Channel "report" is not switched to single: % report(s) could not be closed (first:%), the first reason: %', nFailed, vIds, vError;
  END IF;

  RETURN nCount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

-- Called by notify.release, which runs as the owner: nobody else has a reason to call it (it changes reports).
REVOKE ALL ON FUNCTION ReleaseReportReady(boolean, integer) FROM PUBLIC;

--------------------------------------------------------------------------------
-- notify.channel `outbox` and `report` ----------------------------------------
--------------------------------------------------------------------------------

UPDATE notify.channel SET on_release = 'ReleaseOutbox'
 WHERE code = 'outbox' AND on_release IS NULL;

UPDATE notify.channel SET on_release = 'ReleaseReportReady'
 WHERE code = 'report' AND on_release IS NULL;
