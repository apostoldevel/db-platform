--------------------------------------------------------------------------------
-- VENDOR ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.vendor ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.vendor
AS
  SELECT * FROM ObjectVendor;

GRANT SELECT ON api.vendor TO administrator;

--------------------------------------------------------------------------------
-- api.add_vendor --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет производителя.
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_vendor (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pName         varchar,
  pDescription	text default null
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateVendor(pParent, CodeToType(lower(coalesce(pType, 'device')), 'vendor'), format('%s.vendor', pCode), pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_vendor -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет тариф.
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_vendor (
  pId		    numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pName         varchar default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nType         numeric;
  nVendor       numeric;
BEGIN
  SELECT t.id INTO nVendor FROM db.vendor t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('тариф', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'vendor');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditVendor(nVendor, pParent, nType,pCode, pName, pCost, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_vendor --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_vendor (
  pId           numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pName         varchar default null,
  pDescription	text default null
) RETURNS       SETOF api.vendor
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_vendor(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_vendor(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.vendor WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_vendor --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тариф
 * @param {numeric} pId - Идентификатор
 * @return {api.vendor}
 */
CREATE OR REPLACE FUNCTION api.get_vendor (
  pId		numeric
) RETURNS	api.vendor
AS $$
  SELECT * FROM api.vendor WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_vendor -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список производителей.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.vendor}
 */
CREATE OR REPLACE FUNCTION api.list_vendor (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.vendor
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'vendor', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
