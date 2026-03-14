--------------------------------------------------------------------------------
-- JOB -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.job ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.job
AS
  SELECT * FROM ObjectJob;

GRANT SELECT ON api.job TO administrator;

--------------------------------------------------------------------------------
-- api.service_job -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.service_job
AS
  SELECT * FROM ServiceJob WHERE scope = current_scope();

GRANT SELECT ON api.service_job TO administrator;
GRANT SELECT ON api.service_job TO apibot;

--------------------------------------------------------------------------------
-- FUNCTION api.job ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve jobs by state type, filtered by execution date within the current scope.
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
     WHERE j.dateRun <= pDateFrom
       AND o.state_type = pStateType
       AND o.scope = current_scope();
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
DECLARE
  uJob              uuid;
BEGIN
  SELECT c.id INTO uJob FROM db.job c WHERE c.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('job', 'id', pId);
  END IF;

  PERFORM EditJob(uJob, pParent, pType, pScheduler, pProgram, pDateRun, pCode, pLabel, pDescription);
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
  SELECT * FROM api.job WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
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
  RETURN QUERY EXECUTE api.sql('api', 'job', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
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
