--------------------------------------------------------------------------------
-- FORM ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.form --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.form
AS
  SELECT * FROM ObjectForm;

GRANT SELECT ON api.form TO administrator;

--------------------------------------------------------------------------------
-- api.add_form ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new dynamic form via the API (defaults to 'none.form' type).
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Form type (NULL = none.form)
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created form
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_form (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateForm(pParent, coalesce(pType, GetType('none.form')), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_form -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing form definition via the API.
 * @param {uuid} pId - Form to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @throws ObjectNotFound - When form with given ID does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_form (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uForm        uuid;
BEGIN
  SELECT id INTO uForm FROM db.form WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('form', 'id', pId);
  END IF;

  PERFORM EditForm(pId, pParent, pType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_form ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a form: create when pId is NULL, otherwise update. Return the row.
 * @param {uuid} pId - Form ID (NULL = create new)
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Form type
 * @param {text} pCode - Business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {SETOF api.form} - The created or updated form row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_form (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       SETOF api.form
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_form(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_form(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.form WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_form ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single form by ID (with access check).
 * @param {uuid} pId - Form ID
 * @return {SETOF api.form} - Matching row or empty set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_form (
  pId       uuid
) RETURNS   SETOF api.form
AS $$
  SELECT * FROM api.form WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_form ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List forms with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Rows to skip
 * @param {jsonb} pOrderBy - Sort fields array
 * @return {SETOF api.form} - Matching rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_form (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.form
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'form', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.build_form --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Build a form's field layout as a JSON object with form ID and fields array.
 * @param {uuid} pId - Form ID
 * @param {json} pParams - Runtime parameters
 * @return {json} - JSON object {form, fields}
 * @throws NotFound - When form with given ID does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.build_form (
  pId       uuid,
  pParams   json
) RETURNS   json
AS $$
DECLARE
  uForm     uuid;
BEGIN
  SELECT id INTO uForm FROM db.form WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM NotFound();
  END IF;

  RETURN json_build_object('form', uForm, 'fields', BuildForm(uForm, pParams));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
