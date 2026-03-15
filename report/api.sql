--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- VIEW api.report -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.report
AS
  SELECT * FROM ObjectReport;

GRANT SELECT ON api.report TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.report_object --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all reports bound to a class and its ancestors in the class hierarchy.
 * @param {uuid} pClass - Class identifier to resolve reports for
 * @return {SETOF api.report} - Matching report rows ordered by hierarchy depth (most specific first)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.report_object (
  pClass    uuid
) RETURNS   SETOF api.report
AS $$
  WITH RECURSIVE classtree(id, parent, level) AS (
    SELECT id, parent, level FROM db.class_tree WHERE id = pClass
     UNION
    SELECT c.id, c.parent, c.level
      FROM db.class_tree c INNER JOIN classtree ct ON ct.parent = c.id
  )
  SELECT r.*
    FROM api.report r INNER JOIN classtree c ON r.binding = c.id
   ORDER BY c.level DESC
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.add_report -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Add a new report via the API layer.
 * @param {uuid} pParent - Parent object identifier or NULL
 * @param {uuid} pType - Type identifier (defaults to 'report.report')
 * @param {uuid} pTree - Report tree node
 * @param {uuid} pForm - Input form for report parameters
 * @param {uuid} pBinding - Class binding for object-scoped reports
 * @param {text} pCode - Unique string code
 * @param {text} pName - Human-readable name
 * @param {text} pDescription - Detailed description
 * @param {jsonb} pInfo - Extra metadata (JSON)
 * @return {uuid} - Identifier of the created report
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_report (
  pParent       uuid,
  pType         uuid,
  pTree         uuid default null,
  pForm         uuid default null,
  pBinding      uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null,
  pInfo         jsonb default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateReport(pParent, coalesce(pType, GetType('report.report')), pTree, pForm, pBinding, pCode, pName, pDescription, pInfo);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.update_report --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing report via the API layer.
 * @param {uuid} pId - Report identifier
 * @param {uuid} pParent - New parent or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {uuid} pTree - New tree node or NULL to keep
 * @param {uuid} pForm - New input form or NULL to keep
 * @param {uuid} pBinding - New class binding or NULL to keep
 * @param {text} pCode - New code or NULL to keep
 * @param {text} pName - New name or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @param {jsonb} pInfo - New metadata or NULL to keep
 * @return {void}
 * @throws ObjectNotFound - When no report exists with the given id
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_report (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pTree         uuid default null,
  pForm         uuid default null,
  pBinding      uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null,
  pInfo         jsonb default null
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
BEGIN
  SELECT r.id INTO uId FROM db.report r WHERE r.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('report', 'id', pId);
  END IF;

  PERFORM EditReport(uId, pParent, pType, pTree, pForm, pBinding, pCode, pName, pDescription, pInfo);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.set_report -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a report — create if pId is NULL, otherwise update.
 * @param {uuid} pId - Report identifier (NULL to create)
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier
 * @param {uuid} pTree - Report tree node
 * @param {uuid} pForm - Input form
 * @param {uuid} pBinding - Class binding
 * @param {text} pCode - Unique code
 * @param {text} pName - Name
 * @param {text} pDescription - Description
 * @param {jsonb} pInfo - Extra metadata
 * @return {SETOF api.report} - The created or updated report row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_report (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pTree         uuid default null,
  pForm         uuid default null,
  pBinding      uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null,
  pInfo         jsonb default null
) RETURNS       SETOF api.report
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_report(pParent, pType, pTree, pForm, pBinding, pCode, pName, pDescription, pInfo);
  ELSE
    PERFORM api.update_report(pId, pParent, pType, pTree, pForm, pBinding, pCode, pName, pDescription, pInfo);
  END IF;

  RETURN QUERY SELECT * FROM api.report WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_report --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single report by identifier (access-checked).
 * @param {uuid} pId - Report identifier
 * @return {SETOF api.report} - Report row if accessible
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_report (
  pId       uuid
) RETURNS   SETOF api.report
AS $$
  SELECT * FROM api.report WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_report ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count report records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_report (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_report -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List reports with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-level filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification array
 * @return {SETOF api.report} - Matching report rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_report (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.report
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_report_object -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count reports bound to a specific object class matching search/filter criteria.
 * @param {uuid} pClass - Object class identifier
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_report_object (
  pClass     uuid,
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', format('report_object(%L::uuid)', pClass), pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_report_object ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List reports bound to a specific object class with optional search/filter/pagination.
 * @param {uuid} pClass - Object class identifier
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-level filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification array
 * @return {SETOF api.report} - Matching report rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_report_object (
  pClass        uuid,
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.report
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', format('report_object(%L::uuid)', pClass), pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_report_form_files ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve files attached to a report's input form.
 * @param {uuid} pReport - Report identifier
 * @return {SETOF api.object_file} - File records belonging to the report form
 * @throws NotFound - When the report does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_report_form_files (
  pReport   uuid
) RETURNS   SETOF api.object_file
AS $$
DECLARE
  r         record;
  uForm     uuid;
BEGIN
  SELECT form INTO uForm FROM db.report WHERE id = pReport;

  IF NOT FOUND THEN
    PERFORM NotFound();
  END IF;

  FOR r IN SELECT * FROM api.object_file WHERE object = uForm
  LOOP
    RETURN NEXT r;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
