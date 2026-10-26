--------------------------------------------------------------------------------
-- OUTBOX ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- OutboxAbandon ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief `on_abandon` of the notify channel `outbox`: a delivery row was closed without a confirmation
 *        (the MessageServer that took it died and its lease ran out, or it refused the row for good).
 *
 * What the message is to become depends on how far the sender got -- the state says it:
 *  - `sending`: the action `send` was committed, so the mail may have left, and nobody knows. It is NOT sent
 *    again: the message gets the label `outcome unknown` and the action `fail` (the description of the channel:
 *    "an unknown outcome is not repeated"; a person repeats it, the action `repeat`). A row the sender itself
 *    refused (the reason starts with `unsent:`: the message was never handed to the transport) says `not sent`;
 *  - `prepared`: `send` was never committed, nothing left, a repeat is safe: a new row on the channel
 *    (notify.send, the way the trigger of db.notification does it) -- but not for ever (T1157): the new row is woken
 *    at once, so a sender that keeps refusing the message, or keeps dying before `send`, sends the rows round with
 *    no pause but the speed of its own take (measured: 200 deliveries, 101 rows, the message still `prepared`).
 *    The rows that ended since the message entered `prepared` are counted (the one just closed is among them);
 *    when they reach nMaxRows the message gets the label `not sent` and the action `fail` instead of one more row
 *    (the action `repeat` is the way back; it enters `prepared` again and the count starts anew);
 *  - anything else (`created`, `submitted`, `failed`, `deleted`, a message of another class): the message has moved
 *    on, the closed row is about an earlier delivery, nothing is touched.
 * In both live states, if another row of the message is open, nothing is done: the message stands in THAT delivery
 * (an administrator repeated it while the old row was still open), and a second row would be a second sender.
 * The message is locked first (as an action locks it), the state is read under the lock.
 *
 * The label is a fixed word of the class of the reason, never the reason itself: a reason can carry text of a
 * transport, and the configuration reads the label of a failed message (EventOutboxFail of CSMS disables a device
 * whose label says `[404] NOT_FOUND`). The reason goes to the event log only.
 *
 * The sweep that closes the row comes from a connection with no session (the pool of MessageServer, role apibot);
 * a change of the state of an object asks for one -- the trigger of db.object refuses a user that is not there --
 * so a transition is made in the system context (EnterSystemContext), which is left on every path
 * (the way JobAbandon does it).
 * @param {bigint} pId - Row of notify.queue
 * @param {text} pKey - Key of the row (NULL for this channel)
 * @param {text} pPayload - Payload of the row: the message identifier
 * @param {text} pReason - Why the row was closed
 * @return {void}
 * @since 1.2.39
 */
CREATE OR REPLACE FUNCTION OutboxAbandon (
  pId        bigint,
  pKey       text,
  pPayload   text,
  pReason    text
) RETURNS    void
AS $$
DECLARE
  uMessage   uuid;
  vState     text;
  vClass     text;
  vLabel     text;
  jContext   jsonb;
  dSince     timestamptz;
  nRows      integer := 0;
  -- the rows one stay in `prepared` may use (a row is up to two deliveries: `unsent:` goes back once)
  nMaxRows   constant integer := 5;
BEGIN
  BEGIN
    uMessage := coalesce(pKey, pPayload)::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN;
  END;

  SELECT s.code, GetClassCode(o.class) INTO vState, vClass
    FROM db.object o INNER JOIN db.state s ON s.id = o.state
   WHERE o.id = uMessage
     FOR UPDATE OF o;

  IF NOT FOUND OR vClass IS DISTINCT FROM 'outbox' OR vState NOT IN ('prepared', 'sending') THEN
    RETURN;
  END IF;

  -- the row being closed is not "open" (state 3 already: notify.close wrote it first)
  PERFORM FROM notify.queue WHERE channel = 'outbox' AND payload = uMessage::text AND state < 2;

  IF FOUND THEN
    RETURN;
  END IF;

  IF vState = 'prepared' THEN
    -- this stay in `prepared`: it began with the latest period of the history (an administrator's `repeat` opens a
    -- new one). A row of the stay ended after it began, so `done` (indexed with the channel, for the rows that are
    -- over) finds them without reading the retention of 90 days.
    SELECT max(validFromDate) INTO dSince FROM db.object_state WHERE object = uMessage;

    SELECT count(*) INTO nRows
      FROM notify.queue
     WHERE channel = 'outbox' AND state >= 2 AND done >= coalesce(dSince, '-infinity') AND payload = uMessage::text;
  END IF;

  jContext := EnterSystemContext();

  BEGIN
    IF vState = 'sending' THEN
      vLabel := CASE WHEN starts_with(pReason, 'unsent:') THEN 'not sent' ELSE 'outcome unknown' END;

      PERFORM WriteToEventLog('W', 2026, 'workflow.outbox', 'abandon', left(vLabel || ': ' || pReason, 400), uMessage);
      PERFORM SetObjectLabel(uMessage, vLabel);
      PERFORM DoFail(uMessage);
    ELSIF nRows >= nMaxRows THEN
      PERFORM WriteToEventLog('W', 2026, 'workflow.outbox', 'abandon', left(format('not sent, given up after %s rows: ', nRows) || pReason, 400), uMessage);
      PERFORM SetObjectLabel(uMessage, 'not sent');
      PERFORM DoFail(uMessage);
    ELSE
      PERFORM WriteToEventLog('W', 2026, 'workflow.outbox', 'abandon', left('not sent, sent again: ' || pReason, 400), uMessage);
      PERFORM notify.send('outbox', uMessage::text);
    END IF;
  EXCEPTION WHEN others THEN
    PERFORM LeaveSystemContext(jContext);
    RAISE;
  END;

  PERFORM LeaveSystemContext(jContext);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

-- Called by notify.close, which runs as the owner: nobody else has a reason to call it (it changes a message).
REVOKE ALL ON FUNCTION OutboxAbandon(bigint, text, text, text) FROM PUBLIC;

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
