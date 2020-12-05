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
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pVendor - Производитель
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_model (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pName         varchar,
  pVendor       numeric,
  pDescription	text default null
) RETURNS       numeric
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
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pVendor - Производитель
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_model (
  pId		    numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pName         varchar default null,
  pVendor       numeric default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nType         numeric;
  nModel        numeric;
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
  pId           numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pName         varchar default null,
  pVendor       numeric default null,
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
 * @param {numeric} pId - Идентификатор
 * @return {api.model}
 */
CREATE OR REPLACE FUNCTION api.get_model (
  pId		numeric
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
