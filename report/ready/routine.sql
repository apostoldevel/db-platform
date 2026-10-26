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
