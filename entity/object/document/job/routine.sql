--------------------------------------------------------------------------------
-- CreateJob -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new scheduled job linked to a scheduler and program.
 * @param {uuid} pParent - Parent object reference
 * @param {uuid} pType - Job type identifier (must belong to entity 'job')
 * @param {uuid} pScheduler - Scheduler that owns this job
 * @param {uuid} pProgram - Program to execute
 * @param {timestamptz} pDateRun - First execution timestamp (NULL defaults via scheduler period)
 * @param {text} pCode - Unique job code within scope (auto-generated if NULL)
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Job description
 * @return {uuid} - Identifier of the created job
 * @throws IncorrectClassType - When pType does not belong to the 'job' entity
 * @throws JobExists - When a job with the same code already exists in this scope
 * @see EditJob
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateJob (
  pParent           uuid,
  pType             uuid,
  pScheduler        uuid default null,
  pProgram          uuid default null,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           uuid
AS $$
DECLARE
  uDocument         uuid;
  uClass            uuid;
  uMethod           uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'job' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO uDocument FROM db.job WHERE scope = current_scope() AND code = pCode;

  IF FOUND THEN
    PERFORM JobExists(pCode);
  END IF;

  uDocument := CreateDocument(pParent, pType, pLabel, pDescription);

  INSERT INTO db.job (id, document, scope, code, scheduler, program, daterun)
  VALUES (uDocument, uDocument, current_scope(), pCode, pScheduler, pProgram, pDateRun);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uDocument, uMethod);

  RETURN uDocument;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditJob ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing job and trigger the "edit" workflow method.
 * @param {uuid} pId - Job identifier
 * @param {uuid} pParent - New parent object (NULL keeps current)
 * @param {uuid} pType - New job type (NULL keeps current)
 * @param {uuid} pScheduler - New scheduler (NULL keeps current)
 * @param {uuid} pProgram - New program (NULL keeps current)
 * @param {timestamptz} pDateRun - New execution timestamp (NULL keeps current)
 * @param {text} pCode - New job code (NULL keeps current)
 * @param {text} pLabel - New display label (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @throws JobExists - When the new code conflicts with an existing job in this scope
 * @see CreateJob
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditJob (
  pId               uuid,
  pParent           uuid default null,
  pType             uuid default null,
  pScheduler        uuid default null,
  pProgram          uuid default null,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           void
AS $$
DECLARE
  uDocument         uuid;
  vCode             text;

  old               db.job%rowtype;
  new               db.job%rowtype;

  uClass            uuid;
  uMethod           uuid;
BEGIN
  SELECT code INTO vCode FROM db.job WHERE id = pId;

  IF vCode <> coalesce(pCode, vCode) THEN
    SELECT id INTO uDocument FROM db.job WHERE scope = current_scope() AND code = pCode;
    IF FOUND THEN
      PERFORM JobExists(pCode);
    END IF;
  END IF;

  PERFORM EditDocument(pId, pParent, pType, pLabel, pDescription, pDescription, current_locale());

  SELECT * INTO old FROM db.job WHERE id = pId;

  UPDATE db.job
     SET code = coalesce(pCode, code),
         scheduler = coalesce(pScheduler, scheduler),
         program = coalesce(pProgram, program),
         dateRun = coalesce(pDateRun, dateRun)
   WHERE id = pId;

  SELECT * INTO new FROM db.job WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod, jsonb_build_object('old', row_to_json(old), 'new', row_to_json(new)));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetJob ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a job identifier by its unique code.
 * @param {text} pCode - Job code
 * @return {uuid} - Job identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetJob (
  pCode     text
) RETURNS   uuid
AS $$
  SELECT id FROM db.job WHERE code = pCode
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RescheduleJob ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Move a job's next run one scheduler period forward from its current
 *        daterun. Clamped to Now() on both sides: a daterun in the future is
 *        first pulled back to Now() so a period is never added twice, and a
 *        result in the past is raised to Now() so the job runs at the next pass
 *        rather than "as soon as possible, repeatedly". A scheduler without a
 *        period counts as 0 seconds. Shared by the done and fail handlers.
 * @param {uuid} pObject - Job identifier
 * @return {timestamptz} - The new daterun
 * @since 1.2.20
 */
CREATE OR REPLACE FUNCTION RescheduleJob (
  pObject    uuid
) RETURNS    timestamptz
AS $$
DECLARE
  uScheduler uuid;
  dtDateRun  timestamptz;

  iPeriod    interval;
BEGIN
  SELECT scheduler, daterun INTO uScheduler, dtDateRun FROM db.job WHERE id = pObject;
  SELECT period INTO iPeriod FROM db.scheduler WHERE id = uScheduler;

  iPeriod := coalesce(iPeriod, '0 seconds'::interval);

  IF dtDateRun > Now() THEN
    dtDateRun := Now();
  END IF;

  dtDateRun := dtDateRun + iPeriod;

  IF dtDateRun < Now() THEN
    dtDateRun := Now();
  END IF;

  UPDATE db.job SET daterun = dtDateRun WHERE id = pObject;

  RETURN dtDateRun;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JobRunKey -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief The key of one planned run of a job on the notify channel `job`: the job
 *        and its planned time (`dateRun`) as stored, in UTC, to the microsecond.
 *        `done` and `fail` move `dateRun` (RescheduleJob), so the next run has
 *        another key; while it is the same run the key is the same and the channel
 *        (`dedupe`) hands it out once.
 * @param {uuid} pJob - Job identifier
 * @param {timestamptz} pDateRun - Planned time of the run
 * @return {text} - '<job>:<YYYYMMDD"T"HH24MISS.US>'
 * @since 1.2.38
 */
CREATE OR REPLACE FUNCTION JobRunKey (
  pJob       uuid,
  pDateRun   timestamptz
) RETURNS    text
AS $$
  SELECT pJob::text || ':' || to_char(pDateRun AT TIME ZONE 'UTC', 'YYYYMMDD"T"HH24MISS.US');
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RearmJob --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief A job that becomes runnable again is a NEW planned run: when its
 *        `dateRun` is already past it is set to now, which gives it a new
 *        JobRunKey. Without it a re-armed job keeps the key of the run that
 *        already happened, and the channel's `dedupe` would not hand it out for as
 *        long as that row is kept. A `dateRun` in the future is left alone: the job
 *        waits for it. Called by the `enable` and `abort` events.
 * @param {uuid} pObject - Job identifier
 * @return {void}
 * @since 1.2.38
 */
CREATE OR REPLACE FUNCTION RearmJob (
  pObject    uuid
) RETURNS    void
AS $$
BEGIN
  -- only a job that is runnable now: `enable` of a completed job has a method and no
  -- transition, the state stays `completed` and its planned time is not touched
  UPDATE db.job SET daterun = Now()
   WHERE id = pObject AND daterun < Now()
     AND GetObjectStateCode(pObject) IN ('enabled', 'aborted', 'failed');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JobAbandon ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief `on_abandon` of the notify channel `job`: a row was closed without a
 *        confirmation (the executor died twice, or the row expired).
 *
 * The closed row keeps its key (`dedupe`), so the job MUST leave it, or it would
 * never be handed out again: `executed` (died inside the body) -> `fail`, which
 * postpones a periodic job by a period and disables a one-time one; `canceled` ->
 * `abort` (the event re-arms it); due but not yet executed (died before `execute`,
 * or never handed out) -> RescheduleJob. A job that already moved on -- another planned
 * time, another state -- is not touched: the closed row is about an earlier run.
 *
 * The sweep that closes the row comes from a connection with no session (the
 * TaskScheduler's pool, role apibot), and a change of a state of an object asks for
 * one -- the trigger of db.object refuses a user that is not there -- so the work is
 * done in the system context (EnterSystemContext: kernel, daemon and apibot may
 * enter), which is left on every path. The reason goes to the event log.
 * @param {bigint} pId - Row of notify.queue
 * @param {text} pKey - Key of the row (JobRunKey)
 * @param {text} pPayload - Payload of the row
 * @param {text} pReason - Why the row was closed
 * @return {void}
 * @since 1.2.38
 */
CREATE OR REPLACE FUNCTION JobAbandon (
  pId        bigint,
  pKey       text,
  pPayload   text,
  pReason    text
) RETURNS    void
AS $$
DECLARE
  uJob       uuid;
  dtDateRun  timestamptz;
  vState     text;
  jContext   jsonb;
BEGIN
  BEGIN
    uJob := split_part(pKey, ':', 1)::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN;
  END;

  -- the object first, then the job: the order the actions take (a workflow action updates the
  -- object, and RescheduleJob then the job), so that a `done` still in flight cannot deadlock with this
  PERFORM FROM db.job j INNER JOIN db.object o ON o.id = j.document WHERE j.id = uJob FOR UPDATE OF o;

  SELECT j.daterun, s.code INTO dtDateRun, vState
    FROM db.job j INNER JOIN db.object o ON o.id = j.document
                  INNER JOIN db.state  s ON s.id = o.state
   WHERE j.id = uJob
     FOR UPDATE OF j;

  IF NOT FOUND OR pKey IS DISTINCT FROM JobRunKey(uJob, dtDateRun) THEN
    RETURN;
  END IF;

  IF vState NOT IN ('executed', 'canceled', 'enabled', 'aborted', 'failed') THEN
    RETURN;
  END IF;

  jContext := EnterSystemContext();

  BEGIN
    PERFORM WriteToEventLog('W', 2026, 'workflow.job', 'abandon', left(pReason, 400), uJob);

    IF vState = 'executed' THEN
      PERFORM DoFail(uJob);
    ELSIF vState = 'canceled' THEN
      PERFORM DoAction(uJob, 'abort');
    ELSE
      PERFORM RescheduleJob(uJob);
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

--------------------------------------------------------------------------------
-- ReleaseJob ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief A job that is `executed` or `canceled` and has no live row of the notify
 *        channel `job` (a row waiting or taken) on its current run: nobody holds it
 *        and nothing will find it -- an administrator pressed `execute`, the key was
 *        edited under a run, `on_abandon` failed, the binary was switched with a job
 *        running. The poller this replaces cancelled and aborted such a job on its
 *        next pass (TSK02.FR.02, SCH02.FR.04); api.job_due calls this for it.
 *
 *   `canceled`                          -> `abort` (the event re-arms it, so it starts again);
 *   `executed`, its run has a CLOSED row -> `fail` (the row keeps the key, so it cannot be
 *                                          offered again: a periodic job waits a period,
 *                                          a one-time one is disabled -- what JobAbandon does);
 *   `executed`, its run has no row at all -> nothing: api.job_due offers it (the executor's
 *                                          api.job_claim hands the body out without a transition).
 *
 * The object is locked first, then the job (as the actions do); a row somebody else holds
 * is skipped. Everything is checked again under the lock.
 * @param {uuid} pJob - Job identifier
 * @return {text} - 'abort', 'fail', or NULL when nothing was done
 * @since 1.2.38
 */
CREATE OR REPLACE FUNCTION ReleaseJob (
  pJob       uuid
) RETURNS    text
AS $$
DECLARE
  dtDateRun  timestamptz;
  vState     text;
  vKey       text;
BEGIN
  PERFORM FROM db.job j INNER JOIN db.object o ON o.id = j.document WHERE j.id = pJob FOR UPDATE OF o SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT j.daterun, s.code INTO dtDateRun, vState
    FROM db.job j INNER JOIN db.object o ON o.id = j.document
                  INNER JOIN db.state  s ON s.id = o.state
   WHERE j.id = pJob
     FOR UPDATE OF j;

  IF NOT FOUND OR vState NOT IN ('executed', 'canceled') THEN
    RETURN NULL;
  END IF;

  vKey := JobRunKey(pJob, dtDateRun);

  IF EXISTS (SELECT FROM notify.queue q WHERE q.channel = 'job' AND q.key = vKey AND q.state IN (0, 1)) THEN
    RETURN NULL;
  END IF;

  IF vState = 'canceled' THEN
    PERFORM WriteToEventLog('W', 2026, 'workflow.job', 'release', 'A canceled job nobody holds is aborted.', pJob);
    PERFORM DoAction(pJob, 'abort');
    RETURN 'abort';
  END IF;

  IF NOT EXISTS (SELECT FROM notify.queue q WHERE q.channel = 'job' AND q.key = vKey) THEN
    RETURN NULL;
  END IF;

  PERFORM WriteToEventLog('W', 2026, 'workflow.job', 'release', 'An executed job whose run was closed without a confirmation is failed.', pJob);
  PERFORM DoFail(pJob);
  RETURN 'fail';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
