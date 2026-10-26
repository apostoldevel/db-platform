
--------------------------------------------------------------------------------
-- P00000039 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The channels `outbox` and `report` on notify (apostol-csms T1147, the SQL half of
-- stage E4 of T996): what the database must have before MessageServer and ReportServer
-- take their channels to `single`.
--
-- What arrives:
--   OutboxAbandon       `on_abandon` of the channel `outbox`: a closed row leaves the message it
--                       carried either failed as "outcome unknown" / "not sent" (`sending`: the mail
--                       may have left) or sent again (`prepared`: it never left)
--   ReportReadyAbandon  `on_abandon` of the channel `report`: `progress` -> `fail` as "outcome
--                       unknown" / "not started", `canceled` -> `abort` (nobody is left to say it)
--   notify.scrub        the payload of a row that is over, without the session code the channels
--                       `report` and `file` carry (notify.ack and notify.close call it; update.psql,
--                       run right after the patches, replaces those two)
--
-- notify.hold (the lock on the row a sender holds, taken at the head of its batch) is new in notify/routine.sql with
-- notify.scrub's callers; update.psql, run right after the patches, creates and grants it -- nothing here needs it.
--
-- A function named by on_abandon has to exist before the row names it (the trigger of
-- notify.channel checks), so the three functions are defined here as their modules define
-- them (the text below is the text of the modules, byte for byte). A value an operator already
-- set is not overwritten. The rows of the channels `report` and `file` that are over already (a
-- `single` channel kept the session code in them for retain_done / retain_closed) are cleaned.
-- Re-runnable.
--
-- A WINDOW. The old notify.ack and notify.close stay alive until update.psql replaces them, and the
-- cleaning below runs once. A row that ends in between, or on a base migrated with --no-update, keeps
-- the code until the last statement of this file (the UPDATE of the rows that are over) is run again
-- after update.psql; it is safe to run it as often as needed.
--
-- DML on notify.channel and notify.queue and three functions: kernel phase, no \connect.

\set ON_ERROR_STOP on

--------------------------------------------------------------------------------
-- notify.scrub ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief The payload of a row that is over: without the credential it carried while it was open.
 * @param {text} pChannel - Channel of the row
 * @param {text} pPayload - Payload of the row
 * @return {text} - The payload to keep. The channels `report` and `file` carry the session code of whoever asked
 *         (db.ft_notification_after_insert, db.ft_file_notify): a full credential, which the executor needs to act
 *         in that session and nobody needs afterwards. A row of the channel is kept for retain_done (confirmed) or
 *         retain_closed (closed), up to 90 days; the key `session` is taken out of it when the row ends, so the
 *         code lives in notify.queue as long as the delivery does. Only the key of the top level is taken: both
 *         triggers write it there, and a payload of another shape would keep what it holds deeper. A payload that
 *         is not JSON cannot be cleaned key by key and is dropped (NULL): nothing reads the payload of a row that
 *         is over. Any other channel: unchanged.
 * @since 1.2.39
 *
 * One place for the policy: notify.ack and notify.close call it, and a project that has another channel with a
 * credential in its payload overrides this function (the way it overrides the rest of the platform), not them.
 * The row is cleaned BEFORE on_abandon is called, so the callback does not see the code either.
 */
CREATE OR REPLACE FUNCTION notify.scrub (
  pChannel      text,
  pPayload      text
) RETURNS       text
AS $$
BEGIN
  IF pPayload IS NULL OR pChannel IS NULL OR pChannel NOT IN ('report', 'file') THEN
    RETURN pPayload;
  END IF;

  BEGIN
    RETURN (pPayload::jsonb - 'session')::text;
  EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
  END;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

-- internal, like every function of the schema: nothing is left to PUBLIC (routine.sql does the same for the whole schema)
REVOKE ALL ON FUNCTION notify.scrub(text, text) FROM PUBLIC;

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
 *    (notify.send, the way the trigger of db.notification does it);
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

  jContext := EnterSystemContext();

  BEGIN
    IF vState = 'sending' THEN
      vLabel := CASE WHEN starts_with(pReason, 'unsent:') THEN 'not sent' ELSE 'outcome unknown' END;

      PERFORM WriteToEventLog('W', 2026, 'workflow.outbox', 'abandon', left(vLabel || ': ' || pReason, 400), uMessage);
      PERFORM SetObjectLabel(uMessage, vLabel);
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
-- ReportReadyAbandon ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief `on_abandon` of the notify channel `report`: a delivery row was closed without a confirmation
 *        (the ReportServer that took it died and its lease ran out, or it refused the row for good).
 *
 * The state of the report says how far the build got:
 *  - `progress`: the build was taken and nobody knows how it ended -- it is NOT built again (the channel allows
 *    no repeat, and a build may leave a partial result): the report gets the label `outcome unknown` and the
 *    action `fail` (`failed` has the way back, `execute`). A row the executor itself refused (the reason starts with
 *    `unsent:`: the build never began, e.g. it waited for a free slot past half the lease) says `not started`;
 *  - `canceled`: the user cancelled a build, the ReportServer that was to stop it and say `abort` is gone, and
 *    nobody else will: the action `abort`;
 *  - anything else (`created`, `completed`, `failed`, `aborted`, `deleted`, an object that is no report): the report
 *    has moved on, the closed row is about an earlier build, nothing is touched.
 * If another row of the report is open, nothing is done: the report stands in THAT build (an administrator repeated
 * it while the old row was still open). The report is locked first (as an action locks it), the state is read under
 * the lock.
 *
 * The label is a fixed word of the class of the reason, never the reason itself (a reason can carry text of a
 * transport or a driver; the configuration reads labels). The reason goes to the event log only.
 *
 * The payload of the row has no session code by now (notify.scrub, when the row was closed): only `id` is read
 * from it, and nothing of it is written anywhere. The sweep that closes the row comes from a connection with no
 * session (the pool of ReportServer, role apibot); a transition is made in the system context
 * (EnterSystemContext), which is left on every path, as JobAbandon does it.
 * @param {bigint} pId - Row of notify.queue
 * @param {text} pKey - Key of the row (NULL for this channel)
 * @param {text} pPayload - Payload of the row: {"id": <report_ready>} (the session is gone)
 * @param {text} pReason - Why the row was closed
 * @return {void}
 * @since 1.2.39
 */
CREATE OR REPLACE FUNCTION ReportReadyAbandon (
  pId        bigint,
  pKey       text,
  pPayload   text,
  pReason    text
) RETURNS    void
AS $$
DECLARE
  uReport    uuid;
  vState     text;
  vEntity    text;
  vLabel     text;
  jContext   jsonb;
BEGIN
  BEGIN
    uReport := coalesce(pKey, pPayload::jsonb->>'id')::uuid;
  EXCEPTION WHEN others THEN
    RETURN;
  END;

  SELECT s.code, GetEntityCode(o.entity) INTO vState, vEntity
    FROM db.object o INNER JOIN db.state s ON s.id = o.state
   WHERE o.id = uReport
     FOR UPDATE OF o;

  IF NOT FOUND OR vEntity IS DISTINCT FROM 'report_ready' OR vState NOT IN ('progress', 'canceled') THEN
    RETURN;
  END IF;

  -- the row being closed is not "open" (state 3 already: notify.close wrote it first)
  PERFORM FROM notify.queue WHERE channel = 'report' AND state < 2 AND position(uReport::text IN payload) > 0;

  IF FOUND THEN
    RETURN;
  END IF;

  jContext := EnterSystemContext();

  BEGIN
    PERFORM WriteToEventLog('W', 2026, 'workflow.report', 'abandon', left(vState || ': ' || pReason, 400), uReport);

    IF vState = 'progress' THEN
      vLabel := CASE WHEN starts_with(pReason, 'unsent:') THEN 'not started' ELSE 'outcome unknown' END;

      PERFORM SetObjectLabel(uReport, vLabel);
      PERFORM DoFail(uReport);
    ELSE
      PERFORM DoAction(uReport, 'abort');
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

-- Called by notify.close, which runs as the owner: nobody else has a reason to call it (it changes a report).
REVOKE ALL ON FUNCTION ReportReadyAbandon(bigint, text, text, text) FROM PUBLIC;

--------------------------------------------------------------------------------
-- notify.channel `outbox` and `report` ----------------------------------------
--------------------------------------------------------------------------------

UPDATE notify.channel SET on_abandon = 'OutboxAbandon'
 WHERE code = 'outbox' AND on_abandon IS NULL;

UPDATE notify.channel SET on_abandon = 'ReportReadyAbandon'
 WHERE code = 'report' AND on_abandon IS NULL;

--------------------------------------------------------------------------------
-- rows of the channels `report` and `file` that are over ----------------------
--------------------------------------------------------------------------------

UPDATE notify.queue SET payload = notify.scrub(channel, payload)
 WHERE channel IN ('report', 'file') AND state >= 2 AND payload IS DISTINCT FROM notify.scrub(channel, payload);
