--------------------------------------------------------------------------------
-- MODEL -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.model -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.model
AS
  SELECT * FROM ObjectModel;

GRANT SELECT ON api.model TO administrator;

--------------------------------------------------------------------------------
-- api.add_model ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет модель.
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {text} pType - Код или идентификатор типа
 * @param {uuid} pVendor - Производитель
 * @param {uuid} pCategory - Категория
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_model (
  pParent       uuid,
  pType         text,
  pVendor       uuid,
  pCategory		uuid,
  pCode         text,
  pName         text,
  pDescription	text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateModel(pParent, CodeToType(lower(coalesce(pType, 'device')), 'model'), pVendor, pCategory, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_model ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует модель.
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {text} pType - Код или идентификатор типа
 * @param {uuid} pVendor - Производитель
 * @param {uuid} pCategory - Категория
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_model (
  pId		    uuid,
  pParent       uuid default null,
  pType         text default null,
  pVendor       uuid default null,
  pCategory		uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  uType         uuid;
  nModel        uuid;
BEGIN
  SELECT t.id INTO nModel FROM db.model t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('модель', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    uType := CodeToType(lower(pType), 'model');
  ELSE
    SELECT o.type INTO uType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditModel(nModel, pParent, uType, pVendor, pCategory, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_model ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_model (
  pId           uuid,
  pParent       uuid default null,
  pType         text default null,
  pVendor       uuid default null,
  pCategory		uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       SETOF api.model
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_model(pParent, pType, pVendor, pCategory, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_model(pId, pParent, pType, pVendor, pCategory, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.model WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_model ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает модель
 * @param {uuid} pId - Идентификатор
 * @return {api.model}
 */
CREATE OR REPLACE FUNCTION api.get_model (
  pId		uuid
) RETURNS	api.model
AS $$
  SELECT * FROM api.model WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_model --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список моделей.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.model}
 */
CREATE OR REPLACE FUNCTION api.list_model (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.model
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'model', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- MODEL PROPERTY --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.model_property ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.model_property
AS
  SELECT * FROM ModelPropertyJson;

GRANT SELECT ON api.model_property TO administrator;

--------------------------------------------------------------------------------
-- api.set_model_property_json -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_model_property_json (
  pModel		uuid,
  pProperties	json
) RETURNS		SETOF api.model_property
AS $$
DECLARE
  r				record;
  e				record;

  uId			uuid;
  uProperty		uuid;
  uMeasure		uuid;

  arKeys		text[];
BEGIN
  SELECT id INTO uId FROM db.model WHERE id = pModel;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('модель', 'id', pModel);
  END IF;

  IF pProperties IS NULL THEN
    PERFORM JsonIsEmpty();
  END IF;

  arKeys := array_cat(arKeys, ARRAY['modelid', 'propertyid', 'measureid', 'property', 'measure', 'typevalue', 'value', 'format', 'sequence']);
  PERFORM CheckJsonKeys('/model/property/set', arKeys, pProperties);

  PERFORM api.clear_model_property(pModel);

  FOR r IN SELECT * FROM json_to_recordset(pProperties) AS x(propertyid uuid, measureid uuid, property json, measure json, typevalue integer, value text, format text, sequence integer)
  LOOP
    uProperty := null_uuid();
    uMeasure := null_uuid();

    IF r.property IS NOT NULL THEN
      FOR e IN SELECT * FROM json_to_record(r.property) AS x(id uuid, parent uuid, type uuid, typecode text, code text, name text, description text)
      LOOP
	    SELECT id INTO uProperty FROM api.set_property(e.id, e.parent, coalesce(e.typecode, GetTypeCode(e.type)), e.code, e.name, e.description);
      END LOOP;
	END IF;

    IF r.measure IS NOT NULL THEN
      FOR e IN SELECT * FROM json_to_record(r.measure) AS x(id uuid, parent uuid, type uuid, typecode text, code text, name text, description text)
      LOOP
	    SELECT id INTO uMeasure FROM api.set_measure(e.id, e.parent, coalesce(e.typecode, GetTypeCode(e.type)), e.code, e.name, e.description);
      END LOOP;
	END IF;

	RETURN QUERY SELECT * FROM api.set_model_property(pModel, coalesce(r.propertyId, uProperty), coalesce(r.measureId, uMeasure), r.typeValue, r.value, r.format, r.sequence);
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_model_property_jsonb ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_model_property_jsonb (
  pModel		uuid,
  pProperties	jsonb
) RETURNS		SETOF api.model_property
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.set_model_property_json(pModel, pProperties::json);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_model_property_json -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_model_property_json (
  pModel  		uuid
) RETURNS		json
AS $$
BEGIN
  RETURN GetModelPropertyJson(pModel);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_model_property_jsonb ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_model_property_jsonb (
  pModel		uuid
) RETURNS		jsonb
AS $$
BEGIN
  RETURN GetModelPropertyJsonb(pModel);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_model_property ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает свойство модели
 * @param {uuid} pModel - Идентификатор модели
 * @param {uuid} pProperty - Идентификатор свойства
 * @return {SETOF api.model_property}
 */
CREATE OR REPLACE FUNCTION api.set_model_property (
  pModel		uuid,
  pProperty		uuid,
  pMeasure		uuid,
  pTypeValue    integer,
  pValue		text,
  pFormat		text,
  pSequence		integer DEFAULT null
) RETURNS       SETOF api.model_property
AS $$
DECLARE
  vValue		Variant;
BEGIN
  vValue.vType := coalesce(pTypeValue, 3);

  CASE vValue.vType
  WHEN 0 THEN vValue.vInteger := StrToInt(pValue, coalesce(pFormat, 'FM999999999990'));
  WHEN 1 THEN vValue.vNumeric := StrToInt(pValue, coalesce(pFormat, 'FM999999999990.00'));
  WHEN 2 THEN vValue.vDateTime := StrToTimeStamp(pValue, coalesce(pFormat, 'DD.MM.YYYY HH24:MI:SS'));
  WHEN 3 THEN vValue.vString := pValue;
  WHEN 4 THEN vValue.vBoolean := pValue::boolean;
  END CASE;

  PERFORM SetModelProperty(pModel, pProperty, pMeasure, vValue, pFormat, pSequence);

  RETURN QUERY SELECT * FROM api.get_model_property(pModel, pProperty);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_model_property ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает свойтво модели
 * @param {uuid} pModel - Идентификатор модели
 * @param {uuid} pProperty - Идентификатор свойства
 * @return {SETOF api.model_property}
 */
CREATE OR REPLACE FUNCTION api.get_model_property (
  pModel		uuid,
  pProperty		uuid
) RETURNS       SETOF api.model_property
AS $$
  SELECT *
    FROM api.model_property
   WHERE modelId = pModel
     AND propertyId = pProperty
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_model_property ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет свойство модели
 * @param {uuid} pModel - Идентификатор модели
 * @param {uuid} pProperty - Идентификатор свойства
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION api.delete_model_property (
  pModel  		uuid,
  pProperty		uuid
) RETURNS       boolean
AS $$
BEGIN
  RETURN DeleteModelProperty(pModel, pProperty);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.clear_model_property ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет все свойства модели
 * @param {uuid} pModel - Идентификатор модели
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.clear_model_property (
  pModel  	uuid
) RETURNS	boolean
AS $$
BEGIN
  RETURN DeleteModelProperty(pModel);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_model_property -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает свойства модели.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.model_property}
 */
CREATE OR REPLACE FUNCTION api.list_model_property (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.model_property
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'model_property', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
