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
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {uuid} pVendor - Производитель
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_model (
  pParent       uuid,
  pType         text,
  pCode         text,
  pName         text,
  pVendor       uuid,
  pDescription	text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateModel(pParent, CodeToType(lower(coalesce(pType, 'device')), 'model'), pCode, pName, pVendor, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_model ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует модель.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {uuid} pVendor - Производитель
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_model (
  pId		    uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pVendor       uuid default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nType         uuid;
  nModel        uuid;
BEGIN
  SELECT t.id INTO nModel FROM db.model t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('модель', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'model');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditModel(nModel, pParent, nType, pCode, pName, pVendor, pDescription);
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
  pCode         text default null,
  pName         text default null,
  pVendor       uuid default null,
  pDescription	text default null
) RETURNS       SETOF api.model
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_model(pParent, pType, pCode, pName, pVendor, pDescription);
  ELSE
    PERFORM api.update_model(pId, pParent, pType, pCode, pName, pVendor, pDescription);
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
