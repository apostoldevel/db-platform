--------------------------------------------------------------------------------
-- SCHEDULER -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.scheduler ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.scheduler
AS
  SELECT * FROM ObjectScheduler;

GRANT SELECT ON api.scheduler TO administrator;

--------------------------------------------------------------------------------
-- api.add_scheduler -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new job scheduler via the API (defaults to 'job.scheduler' type).
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Scheduler type (NULL = job.scheduler)
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {interval} pPeriod - Execution interval
 * @param {timestamptz} pDateStart - Start of active window
 * @param {timestamptz} pDateStop - End of active window
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created scheduler
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_scheduler (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pPeriod       interval default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateScheduler(pParent, coalesce(pType, GetType('job.scheduler')), pCode, pName, pPeriod, pDateStart, pDateStop, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_scheduler --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing scheduler via the API.
 * @param {uuid} pId - Scheduler to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {interval} pPeriod - New interval (NULL keeps current)
 * @param {timestamptz} pDateStart - New start date (NULL keeps current)
 * @param {timestamptz} pDateStop - New stop date (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @throws ObjectNotFound - When scheduler with given ID does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_scheduler (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pPeriod       interval default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uScheduler    uuid;
BEGIN
  SELECT t.id INTO uScheduler FROM db.scheduler t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('планировщик', 'id', pId);
  END IF;

  PERFORM EditScheduler(uScheduler, pParent, pType, pCode, pName, pPeriod, pDateStart, pDateStop, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_scheduler -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a scheduler: create when pId is NULL, otherwise update. Return the row.
 * @param {uuid} pId - Scheduler ID (NULL = create new)
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Scheduler type
 * @param {text} pCode - Business code
 * @param {text} pName - Display name
 * @param {interval} pPeriod - Execution interval
 * @param {timestamptz} pDateStart - Start of active window
 * @param {timestamptz} pDateStop - End of active window
 * @param {text} pDescription - Optional description
 * @return {SETOF api.scheduler} - The created or updated scheduler row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_scheduler (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pPeriod       interval default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription  text default null
) RETURNS       SETOF api.scheduler
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_scheduler(pParent, pType, pCode, pName, pPeriod, pDateStart, pDateStop, pDescription);
  ELSE
    PERFORM api.update_scheduler(pId, pParent, pType, pCode, pName, pPeriod, pDateStart, pDateStop, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.scheduler WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_scheduler -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single scheduler by ID (with access check).
 * @param {uuid} pId - Scheduler ID
 * @return {SETOF api.scheduler} - Matching row or empty set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_scheduler (
  pId       uuid
) RETURNS   SETOF api.scheduler
AS $$
  SELECT * FROM api.scheduler WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_scheduler ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List schedulers with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Rows to skip
 * @param {jsonb} pOrderBy - Sort fields array
 * @return {SETOF api.scheduler} - Matching rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_scheduler (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.scheduler
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'scheduler', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_scheduler_id --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve a scheduler ID from a code or UUID string.
 * @param {text} pCode - Scheduler code or UUID
 * @return {uuid} - Scheduler ID
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_scheduler_id (
  pCode      text
) RETURNS    uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetScheduler(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
