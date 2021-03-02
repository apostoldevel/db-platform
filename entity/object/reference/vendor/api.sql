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
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_vendor (
  pParent       uuid,
  pType         text,
  pCode         text,
  pName         text,
  pDescription	text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateVendor(pParent, CodeToType(lower(coalesce(pType, 'device')), 'vendor'), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_vendor -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует производителя.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_vendor (
  pId		    uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nType         uuid;
  nVendor       uuid;
BEGIN
  SELECT t.id INTO nVendor FROM db.vendor t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('производитель', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'vendor');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditVendor(nVendor, pParent, nType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_vendor --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_vendor (
  pId           uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
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
 * Возвращает производителя
 * @param {uuid} pId - Идентификатор
 * @return {api.vendor}
 */
CREATE OR REPLACE FUNCTION api.get_vendor (
  pId		uuid
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
