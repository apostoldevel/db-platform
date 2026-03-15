--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.report_routine ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.report_routine
AS
  SELECT * FROM ObjectReportRoutine;

GRANT SELECT ON api.report_routine TO administrator;

--------------------------------------------------------------------------------
-- api.add_report_routine ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Add a new report generation routine via the API layer.
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier (defaults to 'plpgsql.report_routine')
 * @param {uuid} pReport - Report this routine belongs to
 * @param {text} pCode - Unique string code
 * @param {text} pName - Human-readable name
 * @param {text} pDefinition - PL/pgSQL function name for report generation
 * @param {text} pDescription - Detailed description
 * @param {integer} pSequence - Execution order
 * @return {uuid} - Identifier of the created routine
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_report_routine (
  pParent       uuid,
  pType         uuid,
  pReport       uuid,
  pCode         text,
  pName         text,
  pDefinition   text,
  pDescription  text DEFAULT null,
  pSequence     integer default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateReportRoutine(pParent, coalesce(pType, GetType('plpgsql.report_routine')), pReport, pCode, pName, pDefinition, pDescription, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_report_routine ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing report generation routine via the API layer.
 * @param {uuid} pId - Routine identifier
 * @param {uuid} pParent - New parent object or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {uuid} pReport - New report association or NULL to keep
 * @param {text} pCode - New code or NULL to keep
 * @param {text} pName - New name or NULL to keep
 * @param {text} pDefinition - New function name or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @param {integer} pSequence - New execution order or NULL to keep
 * @return {void}
 * @throws ObjectNotFound - When no report routine exists with the given id
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_report_routine (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pCode         text default null,
  pName         text default null,
  pDefinition   text default null,
  pDescription  text default null,
  pSequence     integer default null
) RETURNS       void
AS $$
DECLARE
  uRoutine        uuid;
BEGIN
  SELECT id INTO uRoutine FROM db.report_routine WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('report routine', 'id', pId);
  END IF;

  PERFORM EditReportRoutine(pId, pParent, pType, pReport, pCode, pName, pDefinition, pDescription, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_report_routine ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a report routine — create if pId is NULL, otherwise update.
 * @param {uuid} pId - Routine identifier (NULL to create)
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier
 * @param {uuid} pReport - Report association
 * @param {text} pCode - Unique code
 * @param {text} pName - Name
 * @param {text} pDefinition - Function name
 * @param {text} pDescription - Description
 * @param {integer} pSequence - Execution order
 * @return {SETOF api.report_routine} - The created or updated routine row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_report_routine (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pCode         text default null,
  pName         text default null,
  pDefinition   text default null,
  pDescription  text default null,
  pSequence     integer default null
) RETURNS       SETOF api.report_routine
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_report_routine(pParent, pType, pReport, pCode, pName, pDefinition, pDescription, pSequence);
  ELSE
    PERFORM api.update_report_routine(pId, pParent, pType, pReport, pCode, pName, pDefinition, pDescription, pSequence);
  END IF;

  RETURN QUERY SELECT * FROM api.report_routine WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_report_routine ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single report routine by identifier (access-checked).
 * @param {uuid} pId - Routine identifier
 * @return {SETOF api.report_routine} - Routine row if accessible
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_report_routine (
  pId       uuid
) RETURNS   SETOF api.report_routine
AS $$
  SELECT * FROM api.report_routine WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_report_routine -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List report routines with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-level filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification array
 * @return {SETOF api.report_routine} - Matching routine rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_report_routine (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.report_routine
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report_routine', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.call_report_routine -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Invoke a report generation routine directly with the given form data.
 * @param {uuid} pId - Report routine identifier
 * @param {json} pForm - Input form parameters (JSON)
 * @return {SETOF json} - Generated report data as JSON
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.call_report_routine (
  pId       uuid,
  pForm     json
) RETURNS   SETOF json
AS $$
BEGIN
  RETURN QUERY SELECT * FROM CallReportRoutine(pId, pForm);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
