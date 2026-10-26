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
