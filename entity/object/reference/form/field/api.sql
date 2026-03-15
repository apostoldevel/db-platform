--------------------------------------------------------------------------------
-- FORM ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.form_field --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.form_field
AS
  SELECT * FROM FormField;

GRANT SELECT ON api.form_field TO administrator;

--------------------------------------------------------------------------------
-- api.set_form_field ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a form field and return the resulting row.
 * @param {uuid} pForm - Owning form
 * @param {text} pKey - Field key
 * @param {text} pType - Data type
 * @param {text} pLabel - UI label
 * @param {text} pFormat - Display format hint
 * @param {text} pValue - Default value
 * @param {jsonb} pData - Extra metadata
 * @param {boolean} pMutable - Mutability flag
 * @param {integer} pSequence - Display order
 * @return {SETOF api.form_field} - The upserted field row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_form_field (
  pForm         uuid,
  pKey          text,
  pType         text default null,
  pLabel        text default null,
  pFormat       text default null,
  pValue        text default null,
  pData         jsonb default null,
  pMutable      boolean default null,
  pSequence     integer default null
) RETURNS       SETOF api.form_field
AS $$
BEGIN
  PERFORM SetFormField(pForm, pKey, pType, pLabel, pFormat, pValue, pData, pMutable, pSequence);

  RETURN QUERY SELECT * FROM api.get_form_field(pForm, pKey);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_form_field ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single form field by form ID and key.
 * @param {uuid} pForm - Form ID
 * @param {text} pKey - Field key
 * @return {SETOF api.form_field} - Matching row or empty set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_form_field (
  pForm     uuid,
  pKey      text
) RETURNS   SETOF api.form_field
AS $$
  SELECT * FROM api.form_field WHERE form = pForm AND key = pKey;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_form_field -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a form field by form ID and key.
 * @param {uuid} pForm - Form owning the field
 * @param {text} pKey - Field key to delete
 * @return {boolean} - true if deleted
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_form_field (
  pForm         uuid,
  pKey          text
) RETURNS       boolean
AS $$
BEGIN
  RETURN DeleteFormField(pForm, pKey);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_form_field ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List form fields with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Rows to skip
 * @param {jsonb} pOrderBy - Sort fields array
 * @return {SETOF api.form_field} - Matching rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_form_field (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.form_field
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'form_field', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.clear_form_field --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete all fields from a form.
 * @param {uuid} pForm - Form to clear
 * @return {boolean} - true if any fields were deleted
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.clear_form_field (
  pForm     uuid
) RETURNS   boolean
AS $$
BEGIN
  RETURN DeleteFormField(pForm, null);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_form_field_json -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Replace all fields of a form from a JSON array (clears existing, then inserts).
 * @param {uuid} pForm - Form to populate
 * @param {json} pFields - JSON array of field objects
 * @return {SETOF api.form_field} - The inserted field rows
 * @throws ObjectNotFound - When form does not exist
 * @throws JsonIsEmpty - When pFields is NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_form_field_json (
  pForm        uuid,
  pFields      json
) RETURNS      SETOF api.form_field
AS $$
DECLARE
  r             record;

  arKeys        text[];
BEGIN
  PERFORM FROM db.form WHERE id = pForm;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('form field', 'id', pForm);
  END IF;

  IF pFields IS NULL THEN
    PERFORM JsonIsEmpty();
  END IF;

  arKeys := array_cat(arKeys, GetRoutines('set_form_field', 'api', false));
  PERFORM CheckJsonKeys('/form/field/set', arKeys, pFields);

  PERFORM api.clear_form_field(pForm);

  FOR r IN SELECT * FROM json_to_recordset(pFields) AS x(key text, type text, label text, format text, value text, data jsonb, mutable boolean, sequence integer)
  LOOP
    RETURN QUERY SELECT * FROM api.set_form_field(pForm, r.key, r.type, r.label, r.format, r.value, r.data, r.mutable, r.sequence);
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_form_field_jsonb ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Replace all fields of a form from a JSONB array (delegates to json variant).
 * @param {uuid} pForm - Form to populate
 * @param {jsonb} pFields - JSONB array of field objects
 * @return {SETOF api.form_field} - The inserted field rows
 * @see api.set_form_field_json
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_form_field_jsonb (
  pForm     uuid,
  pFields   jsonb
) RETURNS   SETOF api.form_field
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.set_form_field_json(pForm, pFields::json);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_form_field_json -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve all fields of a form as a JSON array, ordered by sequence.
 * @param {uuid} pForm - Form to read
 * @return {json} - JSON array of field objects
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_form_field_json (
  pForm     uuid
) RETURNS   json
AS $$
BEGIN
  RETURN GetFormFieldJson(pForm);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_form_field_jsonb ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve all fields of a form as a JSONB array (delegates to json variant).
 * @param {uuid} pForm - Form to read
 * @return {jsonb} - JSONB array of field objects
 * @see api.get_form_field_json
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_form_field_jsonb (
  pForm     uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN GetFormFieldJson(pForm);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
