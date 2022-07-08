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
 * Возвращает форму
 * @param {uuid} pId - Идентификатор
 * @return {api.form_field}
 */
CREATE OR REPLACE FUNCTION api.get_form_field (
  pForm         uuid,
  pKey          text
) RETURNS       api.form_field
AS $$
  SELECT * FROM api.form_field WHERE form = pForm AND key = pKey;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_form_field -------------------------------------------------------
--------------------------------------------------------------------------------

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
 * Возвращает список форм.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.form_field}
 */
CREATE OR REPLACE FUNCTION api.list_form_field (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.form_field
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

CREATE OR REPLACE FUNCTION api.clear_form_field (
  pForm     uuid
) RETURNS	boolean
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

CREATE OR REPLACE FUNCTION api.set_form_field_json (
  pForm         uuid,
  pFields	    json
) RETURNS		SETOF api.form_field
AS $$
DECLARE
  r				record;

  arKeys		text[];
BEGIN
  PERFORM FROM db.form WHERE id = pForm;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('форма журнала', 'id', pForm);
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
