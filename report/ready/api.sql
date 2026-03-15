--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.report_ready ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.report_ready
AS
  SELECT * FROM ObjectReportReady;

GRANT SELECT ON api.report_ready TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.report_ready ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List generated reports filtered by workflow state type (uuid overload).
 * @param {uuid} pStateType - State type identifier to filter by
 * @return {SETOF record} - Rows with id, typecode, statecode, created
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.report_ready (
  pStateType    uuid,
  OUT id        uuid,
  OUT typecode  text,
  OUT statecode text,
  OUT created   timestamptz
) RETURNS       SETOF record
AS $$
  SELECT r.id, t.code, s.code, o.pdate
    FROM db.report_ready r INNER JOIN db.object  o ON r.document = o.id
                           INNER JOIN db.type    t ON o.type = t.id
                           INNER JOIN db.state   s ON o.state = s.id
     WHERE o.state_type = pStateType
       AND o.scope = current_scope();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.report_ready ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List generated reports filtered by workflow state type name (text overload).
 * @param {text} pStateType - State type code (default 'enabled')
 * @return {SETOF record} - Rows with id, typecode, statecode, created
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.report_ready (
  pStateType    text DEFAULT 'enabled',
  OUT id        uuid,
  OUT typecode  text,
  OUT statecode text,
  OUT created   timestamptz
) RETURNS       SETOF record
AS $$
  SELECT * FROM api.report_ready(GetStateType(pStateType));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_report_ready --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Add a new generated report document via the API layer.
 * @param {uuid} pParent - Parent object identifier or NULL
 * @param {uuid} pType - Type identifier (defaults to 'sync.report_ready')
 * @param {uuid} pReport - Source report definition
 * @param {jsonb} pForm - Input parameters snapshot (JSON)
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Detailed description
 * @return {uuid} - Identifier of the created report_ready document
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_report_ready (
  pParent       uuid,
  pType         uuid,
  pReport       uuid,
  pForm         jsonb default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateReportReady(pParent, coalesce(pType, GetType('sync.report_ready')), pReport, pForm, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_report_ready -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing generated report document via the API layer.
 * @param {uuid} pId - Report ready document identifier
 * @param {uuid} pParent - New parent object or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {uuid} pReport - New source report or NULL to keep
 * @param {jsonb} pForm - New input parameters or NULL to keep
 * @param {text} pLabel - New display label or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @return {void}
 * @throws ObjectNotFound - When no report_ready document exists with the given id
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_report_ready (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pForm         jsonb default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
BEGIN
  SELECT c.id INTO uId FROM db.report_ready c WHERE c.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('report ready', 'id', pId);
  END IF;

  PERFORM EditReportReady(uId, pParent, pType, pReport, pForm, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_report_ready --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a generated report — create if pId is NULL, otherwise update.
 * @param {uuid} pId - Report ready identifier (NULL to create)
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier
 * @param {uuid} pReport - Source report definition
 * @param {jsonb} pForm - Input parameters
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Description
 * @return {SETOF api.report_ready} - The created or updated row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_report_ready (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pForm         jsonb default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       SETOF api.report_ready
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_report_ready(pParent, pType, pReport, pForm, pLabel, pDescription);
  ELSE
    PERFORM api.update_report_ready(pId, pParent, pType, pReport, pForm, pLabel, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.report_ready WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_report_ready --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single generated report by identifier (access-checked).
 * @param {uuid} pId - Report ready document identifier
 * @return {SETOF api.report_ready} - Report ready row if accessible
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_report_ready (
  pId       uuid
) RETURNS   SETOF api.report_ready
AS $$
  SELECT * FROM api.report_ready WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_report_ready -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List generated reports with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-level filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification array
 * @return {SETOF api.report_ready} - Matching report ready rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_report_ready (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.report_ready
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report_ready', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.build_report ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Build a report — create and return a report_ready document from a report definition.
 * @param {uuid} pReport - Report definition identifier
 * @param {jsonb} pForm - Input form parameters (JSON)
 * @return {SETOF api.report_ready} - The newly generated report_ready row
 * @see BuildReport
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.build_report (
  pReport   uuid,
  pForm     jsonb
) RETURNS   SETOF api.report_ready
AS $$
DECLARE
  uId       uuid;
BEGIN
  uId := BuildReport(pReport, GetType('sync.report_ready'), pForm);
  RETURN QUERY SELECT * FROM api.report_ready WHERE id = uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.execute_report_ready ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute all generation routines for an existing report_ready document.
 * @param {uuid} pId - Report ready document identifier
 * @return {void}
 * @see ExecuteReportReady
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.execute_report_ready (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM ExecuteReportReady(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

