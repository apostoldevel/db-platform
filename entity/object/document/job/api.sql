--------------------------------------------------------------------------------
-- JOB -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.job ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.job
AS
  SELECT t.* FROM ObjectJob t INNER JOIN AccessJob a ON t.id = a.object;

GRANT SELECT ON api.job TO administrator;

--------------------------------------------------------------------------------
-- api.service_job -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.service_job
AS
  SELECT * FROM ObjectJob WHERE scope = current_scope();

GRANT SELECT ON api.service_job TO administrator;
GRANT SELECT ON api.service_job TO apibot;

--------------------------------------------------------------------------------
-- FUNCTION api.job ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve jobs by state type, filtered by execution date within the current scope.
 *
 * The TaskScheduler's feed: it runs each body as raw SQL under the system's
 * bot session. Only a job and a program both owned by a platform
 * administrator are handed out (T848) — the second line behind the gates of
 * api.add_/update_job and api.add_/update_program, for an object put into the
 * base past them (CreateJob/CreateProgram called directly) by a non-admin.
 * It reads the owner only: it does not catch an object whose owner was
 * rewritten to the administrator — DeleteUser re-owns every object of the
 * deleted user — nor an admin-owned program whose body a non-admin edited
 * before the gates existed.
 *
 * @param {uuid} pStateType - State type identifier (e.g., enabled, disabled)
 * @param {timestamptz} pDateFrom - Return jobs scheduled on or before this timestamp
 * @return {SETOF record} - Job records with id, typecode, statecode, created, daterun, body
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.job (
  pStateType    uuid,
  pDateFrom     timestamptz DEFAULT Now(),
  OUT id        uuid,
  OUT typecode  text,
  OUT statecode text,
  OUT created   timestamptz,
  OUT daterun   timestamptz,
  OUT body      text
) RETURNS       SETOF record
AS $$
  SELECT j.id, t.code, s.code, o.pdate, j.daterun, p.body
    FROM db.job j INNER JOIN db.object  o ON j.document = o.id
                  INNER JOIN db.type    t ON o.type = t.id
                  INNER JOIN db.state   s ON o.state = s.id
                  INNER JOIN db.program p ON j.program = p.id
                  INNER JOIN db.object po ON p.id = po.id
     WHERE j.dateRun <= pDateFrom
       AND o.state_type = pStateType
       AND o.scope = current_scope()
       AND IsAdmin(o.owner)
       AND IsAdmin(po.owner);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.job ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve jobs by state type code, with optional epoch-based date filter.
 * @param {text} pStateType - State type code (e.g., 'enabled')
 * @param {double precision} pDateFrom - Unix epoch timestamp (NULL defaults to now)
 * @return {SETOF record} - Job records with id, typecode, statecode, created, daterun, body
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.job (
  pStateType    text DEFAULT 'enabled',
  pDateFrom     double precision DEFAULT null,
  OUT id        uuid,
  OUT typecode  text,
  OUT statecode text,
  OUT created   timestamptz,
  OUT daterun   timestamptz,
  OUT body      text
) RETURNS       SETOF record
AS $$
  SELECT * FROM api.job(GetStateType(pStateType), coalesce(to_timestamp(pDateFrom), Now()));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.job_due --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Hand the jobs that are due to the notify channel `job`: the feed of a
 *        TaskScheduler that runs on notify instead of polling api.job. Every
 *        instance calls it about once a second under each scope's session.
 *
 * Same filters as the feed api.job (SCH02.FR.01–02): the session's scope, a job and
 * a program both owned by an administrator (T848). Offered: a job that can be
 * STARTED (`enabled`, `aborted`, `failed`) and is due (`dateRun` at or before now),
 * and an `executed` job whose run has no row at all (nobody holds it, nothing else
 * will find it: its api.job_claim hands the body out without a transition).
 * It makes no transition for those. `SELECT … FOR UPDATE SKIP LOCKED` keeps a
 * second caller away from a row this one is handing out and from a row whose
 * `done` has not committed; the channel's `dedupe` on JobRunKey is the second line
 * — a job that is still waiting for its executor, or whose run is kept, is offered
 * again every second and the same row comes back. The payload is the job and its
 * scope (the executor needs the scope's session); it never carries the body: the
 * executor asks api.job_claim, which applies the gates again.
 *
 * Before it offers, it frees what nobody holds (ReleaseJob): a `canceled` job is
 * aborted, an `executed` one whose run was closed without a confirmation is failed.
 *
 * Does nothing unless the channel `job` is `single` (a binary that still polls
 * api.job shares the base: N−1), and refuses to work (an error) when it is `single`
 * without `on_abandon` -- the patch that sets it was not applied, and a row closed
 * without a confirmation would leave its job stuck.
 * @return {SETOF record} - The jobs offered: id, key, and the row of notify.queue
 * @since 1.2.38
 */
CREATE OR REPLACE FUNCTION api.job_due (
  OUT id        uuid,
  OUT key       text,
  OUT queue     bigint
) RETURNS       SETOF record
AS $$
DECLARE
  r             record;
  vAbandon      text;
BEGIN
  SELECT c.on_abandon INTO vAbandon FROM notify.channel c WHERE c.code = 'job' AND c.mode = 'single';

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF vAbandon IS NULL THEN
    RAISE EXCEPTION 'api.job_due: the channel job is single but has no on_abandon (the patch that sets it, P00000037, was not applied)';
  END IF;

  FOR r IN
    SELECT j.id AS job
      FROM db.job j INNER JOIN db.object  o ON j.document = o.id
                    INNER JOIN db.state   s ON o.state = s.id
                    INNER JOIN db.program p ON j.program = p.id
                    INNER JOIN db.object po ON p.id = po.id
     WHERE s.code IN ('executed', 'canceled')
       AND o.scope = current_scope()
       AND IsAdmin(o.owner)
       AND IsAdmin(po.owner)
       AND NOT EXISTS (SELECT FROM notify.queue q WHERE q.channel = 'job' AND q.key = JobRunKey(j.id, j.daterun) AND q.state IN (0, 1))
     ORDER BY j.daterun, j.id
  LOOP
    PERFORM ReleaseJob(r.job);
  END LOOP;

  FOR r IN
    SELECT j.id AS job, j.daterun AS dr, o.scope AS sc
      FROM db.job j INNER JOIN db.object  o ON j.document = o.id
                    INNER JOIN db.state   s ON o.state = s.id
                    INNER JOIN db.program p ON j.program = p.id
                    INNER JOIN db.object po ON p.id = po.id
     WHERE o.scope = current_scope()
       AND IsAdmin(o.owner)
       AND IsAdmin(po.owner)
       AND ((j.daterun <= Now() AND s.code IN ('enabled', 'aborted', 'failed'))
         OR (s.code = 'executed' AND NOT EXISTS (SELECT FROM notify.queue q WHERE q.channel = 'job' AND q.key = JobRunKey(j.id, j.daterun))))
     ORDER BY j.daterun, j.id
       FOR UPDATE OF j SKIP LOCKED
  LOOP
    id    := r.job;
    key   := JobRunKey(r.job, r.dr);
    queue := notify.send('job', jsonb_build_object('id', r.job, 'scope', r.sc)::text, key);

    RETURN NEXT;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

REVOKE ALL ON FUNCTION api.job_due() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.job_due() TO apibot;

--------------------------------------------------------------------------------
-- FUNCTION api.job_claim ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief The executor's first step after it took a row of the channel `job`: its
 *        own committed transaction that makes the job `executed` and hands back
 *        what to run. The second step — the body, `done` / `fail` and
 *        `notify.ack` — is one more transaction (the executor's).
 *
 * The job is found again by the filters of the feed (the session's scope, a job and
 * a program owned by an administrator, T848): the body is read here, never taken
 * from the payload of the row. Nothing is returned (the executor acknowledges the
 * row and runs nothing) when the job is gone, is not in this scope, is not an
 * administrator's, has another planned time than the key (it was edited or moved
 * on since), is not due yet, or is in a state that cannot be started. Otherwise:
 *   `enabled`, `aborted`, `failed`  - `execute`, the body is returned;
 *   `executed`                      - a repeat after the previous executor died: no
 *                                     transition, the body is returned (its transaction
 *                                     rolled back, so the work was not done; a late
 *                                     ack of that executor is refused by the token);
 *   `canceled`                      - `abort` (the event re-arms the job), nothing returned.
 * @param {uuid} pId - Job identifier (from the payload of the row)
 * @param {text} pKey - Key of the row (JobRunKey)
 * @return {SETOF record} - id, typecode (`periodic.job`: `done`, else `complete`), statecode, daterun, body
 * @since 1.2.38
 */
CREATE OR REPLACE FUNCTION api.job_claim (
  pId           uuid,
  pKey          text,
  OUT id        uuid,
  OUT typecode  text,
  OUT statecode text,
  OUT daterun   timestamptz,
  OUT body      text
) RETURNS       SETOF record
AS $$
DECLARE
  r             record;
  vState        text;
BEGIN
  -- the object first, then the job: the order the actions take (see JobAbandon)
  PERFORM FROM db.job j INNER JOIN db.object o ON o.id = j.document WHERE j.id = pId FOR UPDATE OF o;

  SELECT j.daterun AS dr, y.code AS tc, s.code AS sc, p.body AS bd INTO r
    FROM db.job j INNER JOIN db.object  o ON j.document = o.id
                  INNER JOIN db.type    y ON o.type = y.id
                  INNER JOIN db.state   s ON o.state = s.id
                  INNER JOIN db.program p ON j.program = p.id
                  INNER JOIN db.object po ON p.id = po.id
   WHERE j.id = pId
     AND o.scope = current_scope()
     AND IsAdmin(o.owner)
     AND IsAdmin(po.owner)
     FOR UPDATE OF j;

  IF NOT FOUND OR pKey IS DISTINCT FROM JobRunKey(pId, r.dr) THEN
    RETURN;
  END IF;

  vState := r.sc;

  IF vState IN ('enabled', 'aborted', 'failed') THEN
    IF r.dr > Now() THEN
      RETURN;
    END IF;
    PERFORM DoAction(pId, 'execute');
    vState := 'executed';
  ELSIF vState = 'canceled' THEN
    PERFORM DoAction(pId, 'abort');
    RETURN;
  ELSIF vState <> 'executed' THEN
    RETURN;
  END IF;

  id        := pId;
  typecode  := r.tc;
  statecode := vState;
  daterun   := r.dr;
  body      := r.bd;

  RETURN NEXT;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

REVOKE ALL ON FUNCTION api.job_claim(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.job_claim(uuid, text) TO apibot;

--------------------------------------------------------------------------------
-- api.add_job -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new job via the API layer.
 * @param {uuid} pParent - Parent object reference
 * @param {uuid} pType - Job type identifier (defaults to 'periodic.job')
 * @param {uuid} pScheduler - Scheduler reference
 * @param {uuid} pProgram - Program to execute
 * @param {timestamptz} pDateRun - First execution timestamp
 * @param {text} pCode - Unique job code
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Job description
 * @return {uuid} - Identifier of the created job
 * @throws AccessDenied - When the caller is not a platform administrator (T848)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_job (
  pParent           uuid,
  pType             uuid,
  pScheduler        uuid,
  pProgram          uuid,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           uuid
AS $$
BEGIN
  -- T848: a job makes the TaskScheduler run a program body — raw SQL — as the
  -- system (role apibot, a bot session); its REST routes are open to any session. Writing one
  -- is the platform administrator's alone — not the system group: the OAuth2
  -- client accounts are members of it, and client_credentials with a public
  -- client's secret (web, mobile) signs in as one. The kernel installs.
  IF session_user <> 'kernel' AND NOT IsAdmin() THEN
    PERFORM AccessDenied();
  END IF;

  RETURN CreateJob(pParent, coalesce(pType, GetType('periodic.job')), pScheduler, pProgram, pDateRun, pCode, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_job --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing job via the API layer.
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
 * @throws ObjectNotFound - When no job matches pId
 * @throws AccessDenied - When the caller is not a platform administrator (T848)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_job (
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
BEGIN
  -- T848: a job makes the TaskScheduler run a program body — raw SQL — as the
  -- system (role apibot, a bot session); its REST routes are open to any session. Writing one
  -- is the platform administrator's alone — not the system group: the OAuth2
  -- client accounts are members of it, and client_credentials with a public
  -- client's secret (web, mobile) signs in as one. The kernel installs.
  IF session_user <> 'kernel' AND NOT IsAdmin() THEN
    PERFORM AccessDenied();
  END IF;

  PERFORM FROM db.job WHERE id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('job', 'id', pId);
  END IF;

  PERFORM EditJob(pId, pParent, pType, pScheduler, pProgram, pDateRun, pCode, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_job -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a job (upsert). Routes to add or update based on pId.
 * @param {uuid} pId - Job identifier (NULL to create)
 * @param {uuid} pParent - Parent object reference
 * @param {uuid} pType - Job type identifier
 * @param {uuid} pScheduler - Scheduler reference
 * @param {uuid} pProgram - Program to execute
 * @param {timestamptz} pDateRun - Execution timestamp
 * @param {text} pCode - Unique job code
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Job description
 * @return {SETOF api.job} - The created or updated job
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_job (
  pId               uuid,
  pParent           uuid default null,
  pType             uuid default null,
  pScheduler        uuid default null,
  pProgram          uuid default null,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           SETOF api.job
AS $$
BEGIN
  pId := coalesce(pId, GetJob(pCode));

  IF pId IS NULL THEN
    pId := api.add_job(pParent, pType, pScheduler, pProgram, pDateRun, pCode, pLabel, pDescription);
  ELSE
    PERFORM api.update_job(pId, pParent, pType, pScheduler, pProgram, pDateRun, pCode, pLabel, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.job WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_job -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single job by identifier with access check.
 * @param {uuid} pId - Job identifier
 * @return {SETOF api.job} - Matching job record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_job (
  pId       uuid
) RETURNS   SETOF api.job
AS $$
  SELECT * FROM api.job WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_job ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count job records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_job (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('kernel', 'ObjectJob', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_job ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List jobs matching search, filter, and sort criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-level equality filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.job} - Matching job records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_job (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.job
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('kernel', 'ObjectJob', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_job_id --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve a job code (or UUID string) to its identifier.
 * @param {text} pCode - Job code or UUID string
 * @return {uuid} - Job identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_job_id (
  pCode     text
) RETURNS   uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetJob(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
