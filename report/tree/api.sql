--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.report_tree -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.report_tree
AS
  SELECT * FROM ObjectReportTree;

GRANT SELECT ON api.report_tree TO administrator;

--------------------------------------------------------------------------------
-- api.add_report_tree ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Add a new report tree node via the API layer.
 * @param {uuid} pParent - Parent object identifier or NULL
 * @param {uuid} pType - Type identifier (defaults to 'report.report_tree')
 * @param {uuid} pRoot - Root node (pass null_uuid() to create a root node)
 * @param {uuid} pNode - Parent node in the hierarchy
 * @param {text} pCode - Unique string code
 * @param {text} pName - Human-readable name
 * @param {text} pDescription - Detailed description
 * @param {integer} pSequence - Display order among siblings
 * @return {uuid} - Identifier of the created tree node
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_report_tree (
  pParent       uuid,
  pType         uuid,
  pRoot         uuid,
  pNode         uuid,
  pCode         text,
  pName         text,
  pDescription  text default null,
  pSequence     integer default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateReportTree(pParent, coalesce(pType, GetType('report.report_tree')), pRoot, pNode, pCode, pName, pDescription, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_report_tree ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing report tree node via the API layer.
 * @param {uuid} pId - Tree node identifier
 * @param {uuid} pParent - New parent object or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {uuid} pRoot - New root node or NULL to keep
 * @param {uuid} pNode - New parent node or NULL to keep
 * @param {text} pCode - New code or NULL to keep
 * @param {text} pName - New name or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @param {integer} pSequence - New display order or NULL to keep
 * @return {void}
 * @throws ObjectNotFound - When no report tree node exists with the given id
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_report_tree (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pRoot         uuid default null,
  pNode         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null,
  pSequence     integer default null
) RETURNS       void
AS $$
DECLARE
  uReportTree   uuid;
BEGIN
  SELECT t.id INTO uReportTree FROM db.report_tree t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('report tree', 'id', pId);
  END IF;

  PERFORM EditReportTree(uReportTree, pParent, pType,pRoot, pNode, pCode, pName, pDescription, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_report_tree ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a report tree node — create if pId is NULL, otherwise update.
 * @param {uuid} pId - Tree node identifier (NULL to create)
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier
 * @param {uuid} pRoot - Root node identifier
 * @param {uuid} pNode - Parent node in the hierarchy
 * @param {text} pCode - Unique code
 * @param {text} pName - Name
 * @param {text} pDescription - Description
 * @param {integer} pSequence - Display order
 * @return {SETOF api.report_tree} - The created or updated tree node row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_report_tree (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pRoot         uuid default null,
  pNode         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null,
  pSequence     integer default null
) RETURNS       SETOF api.report_tree
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_report_tree(pParent, pType, pRoot, pNode, pCode, pName, pDescription, pSequence);
  ELSE
    PERFORM api.update_report_tree(pId, pParent, pType, pRoot, pNode, pCode, pName, pDescription, pSequence);
  END IF;

  RETURN QUERY SELECT * FROM api.report_tree WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_report_tree ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single report tree node by identifier (access-checked).
 * @param {uuid} pId - Tree node identifier
 * @return {SETOF api.report_tree} - Tree node row if accessible
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_report_tree (
  pId       uuid
) RETURNS   SETOF api.report_tree
AS $$
  SELECT * FROM api.report_tree WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_report_tree -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count report tree node records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_report_tree (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report_tree', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_report_tree --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List report tree nodes with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-level filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification array
 * @return {SETOF api.report_tree} - Matching tree node rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_report_tree (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.report_tree
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report_tree', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
