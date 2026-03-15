--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.report_form -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.report_form
AS
  SELECT * FROM ObjectReportForm;

GRANT SELECT ON api.report_form TO administrator;

--------------------------------------------------------------------------------
-- api.add_report_form ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Add a new report input form via the API layer.
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier (defaults to 'json.report_form')
 * @param {text} pCode - Unique string code
 * @param {text} pName - Human-readable name
 * @param {text} pDefinition - PL/pgSQL function name that builds the form
 * @param {text} pDescription - Detailed description
 * @return {uuid} - Identifier of the created form
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_report_form (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDefinition   text,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateReportForm(pParent, coalesce(pType, GetType('json.report_form')), pCode, pName, pDefinition, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_report_form ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing report input form via the API layer.
 * @param {uuid} pId - Form identifier
 * @param {uuid} pParent - New parent object or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {text} pCode - New code or NULL to keep
 * @param {text} pName - New name or NULL to keep
 * @param {text} pDefinition - New function name or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @return {void}
 * @throws ObjectNotFound - When no report form exists with the given id
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_report_form (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDefinition   text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uForm        uuid;
BEGIN
  SELECT id INTO uForm FROM db.report_form WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('report form', 'id', pId);
  END IF;

  PERFORM EditReportForm(pId, pParent, pType, pCode, pName, pDefinition, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_report_form ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a report form — create if pId is NULL, otherwise update.
 * @param {uuid} pId - Form identifier (NULL to create)
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier
 * @param {text} pCode - Unique code
 * @param {text} pName - Name
 * @param {text} pDefinition - Function name
 * @param {text} pDescription - Description
 * @return {SETOF api.report_form} - The created or updated form row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_report_form (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDefinition   text default null,
  pDescription  text default null
) RETURNS       SETOF api.report_form
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_report_form(pParent, pType, pCode, pName, pDefinition, pDescription);
  ELSE
    PERFORM api.update_report_form(pId, pParent, pType, pCode, pName, pDefinition, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.report_form WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_report_form ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single report form by identifier (access-checked).
 * @param {uuid} pId - Form identifier
 * @return {SETOF api.report_form} - Form row if accessible
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_report_form (
  pId       uuid
) RETURNS   SETOF api.report_form
AS $$
  SELECT * FROM api.report_form WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_report_form -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count report form records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_report_form (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report_form', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_report_form --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List report forms with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-level filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification array
 * @return {SETOF api.report_form} - Matching form rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_report_form (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.report_form
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report_form', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.build_report_form -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Build a report form by executing its definition function, resolving from form or report id.
 * @param {uuid} pId - Report form or report identifier
 * @param {json} pParams - Input parameters passed to the form builder
 * @return {json} - Generated form definition as JSON
 * @throws NotFound - When neither a form nor a report exists with the given id
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.build_report_form (
  pId       uuid,
  pParams   json
) RETURNS   json
AS $$
DECLARE
  uForm     uuid;
BEGIN
  SELECT id INTO uForm FROM db.report_form WHERE id = pId;

  IF NOT FOUND THEN
    SELECT form INTO uForm FROM db.report WHERE id = pId;
    IF NOT FOUND THEN
      PERFORM NotFound();
    END IF;
  END IF;

  RETURN BuildReportForm(uForm, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
