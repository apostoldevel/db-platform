--------------------------------------------------------------------------------
-- P00000037 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- T1104 (apostol-csms), stage E5 of T996: the notify channel `job` closes a row
-- that nobody confirmed by calling JobAbandon, which moves the job off the key of
-- the closed row (a closed row of a `dedupe` channel keeps its key, and a job that
-- stayed on it would never be handed out again).
--
-- The row of the channel exists since P00000035 (`legacy`, nothing changes for a
-- binary that still polls api.job). A function named by on_abandon has to exist
-- before the row names it (the trigger of notify.channel checks), so the two
-- functions are defined here, as routine.sql defines them; update.psql replaces
-- them in the same run, right after the patches, together with api.job_due,
-- api.job_claim and the events enable / abort. A value an operator already set is
-- not overwritten. Re-runnable.
--
-- DML on notify.channel and two functions: kernel phase, no \connect.

\set ON_ERROR_STOP on

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
-- notify.channel `job` --------------------------------------------------------
--------------------------------------------------------------------------------

UPDATE notify.channel SET on_abandon = 'JobAbandon', on_expire = true
 WHERE code = 'job' AND on_abandon IS NULL;
