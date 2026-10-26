--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CreateReportReady -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new generated report document and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object identifier or NULL
 * @param {uuid} pType - Type identifier (must belong to entity 'report_ready')
 * @param {uuid} pReport - Source report definition that produces this output
 * @param {jsonb} pForm - Input parameters snapshot (JSON)
 * @param {text} pLabel - Display label for the document
 * @param {text} pDescription - Detailed description
 * @return {uuid} - Identifier of the newly created report_ready document
 * @throws IncorrectClassType - When pType does not belong to the 'report_ready' entity
 * @throws ObjectNotFound - When pReport does not reference an existing report
 * @see EditReportReady, ExecuteReportReady
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateReportReady (
  pParent       uuid,
  pType         uuid,
  pReport       uuid default null,
  pForm         jsonb default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  uReportReady  uuid;
  uDocument     uuid;

  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'report_ready' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO uId FROM db.report WHERE id = pReport;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('report', 'id', pReport);
  END IF;

  uDocument := CreateDocument(pParent, pType, pLabel, pDescription);

  INSERT INTO db.report_ready (id, document, report, form)
  VALUES (uDocument, uDocument, pReport, pForm)
  RETURNING id INTO uReportReady;

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReportReady, uMethod);

  RETURN uReportReady;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReportReady -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing generated report document (NULL parameters keep current values).
 * @param {uuid} pId - Report ready document identifier
 * @param {uuid} pParent - New parent object or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {uuid} pReport - New source report or NULL to keep
 * @param {text} pForm - New input parameters or NULL to keep
 * @param {text} pLabel - New display label or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @return {void}
 * @throws ObjectNotFound - When pReport does not reference an existing report
 * @see CreateReportReady
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditReportReady (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pForm         text default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  IF pReport IS NOT NULL THEN
    SELECT id INTO uId FROM db.report WHERE id = pReport;
    IF NOT FOUND THEN
      PERFORM ObjectNotFound('report', 'id', pReport);
    END IF;
  END IF;

  PERFORM EditDocument(pId, pParent, pType, pLabel, pDescription, pDescription, current_locale());

  UPDATE db.report_ready
     SET report = coalesce(pReport, report),
         form = coalesce(pForm, form)
   WHERE id = pId;

  uClass := GetObjectClass(pId);
  uMethod := GetMethod(uClass, GetAction('edit'));

  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetReportReadyForm ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the input parameters snapshot for a generated report.
 * @param {uuid} pId - Report ready document identifier
 * @return {jsonb} - Input form parameters (JSON) or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReportReadyForm (
  pId       uuid
) RETURNS   jsonb
AS $$
  SELECT form FROM db.report_ready WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ExecuteReportReady ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute all generation routines for a report_ready document in sequence order.
 * @param {uuid} pId - Report ready document identifier
 * @return {void}
 * @see BuildReport, CreateReportReady
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ExecuteReportReady (
  pId       uuid
) RETURNS   void
AS $$
DECLARE
  r         record;

  uReport   uuid;
  jForm     jsonb;
BEGIN
  SELECT report, form INTO uReport, jForm FROM db.report_ready WHERE id = pId;

  FOR r IN SELECT definition FROM db.report_routine WHERE report = uReport ORDER BY sequence
  LOOP
    EXECUTE format('SELECT report.%I($1, $2);', r.definition) USING pId, jForm;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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
