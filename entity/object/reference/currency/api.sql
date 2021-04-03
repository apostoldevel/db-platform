--------------------------------------------------------------------------------
-- CURRENCY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.currency ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.currency
AS
  SELECT * FROM ObjectCurrency;

GRANT SELECT ON api.currency TO administrator;

--------------------------------------------------------------------------------
-- api.add_currency ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет валюту.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {integer} pDigital - Цифровой код
 * @param {integer} pDecimal - Количество знаков после запятой
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_currency (
  pParent       uuid,
  pType         text,
  pCode         text,
  pName         text,
  pDescription	text default null,
  pDigital		integer default null,
  pDecimal		integer default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateCurrency(pParent, CodeToType(lower(coalesce(pType, 'time')), 'currency'), pCode, pName, pDescription, pDigital, pDecimal);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_currency ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует валюту.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {integer} pDigital - Цифровой код
 * @param {integer} pDecimal - Количество знаков после запятой
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_currency (
  pId		    uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null,
  pDigital		integer default null,
  pDecimal		integer default null
) RETURNS       void
AS $$
DECLARE
  uType         uuid;
  nCurrency        uuid;
BEGIN
  SELECT t.id INTO nCurrency FROM db.currency t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('мера', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    uType := CodeToType(lower(pType), 'currency');
  ELSE
    SELECT o.type INTO uType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditCurrency(nCurrency, pParent, uType, pCode, pName, pDescription, pDigital, pDecimal);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_currency ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_currency (
  pId           uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null,
  pDigital		integer default null,
  pDecimal		integer default null
) RETURNS       SETOF api.currency
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_currency(pParent, pType, pCode, pName, pDescription, pDigital, pDecimal);
  ELSE
    PERFORM api.update_currency(pId, pParent, pType, pCode, pName, pDescription, pDigital, pDecimal);
  END IF;

  RETURN QUERY SELECT * FROM api.currency WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_currency ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает валюту
 * @param {uuid} pId - Идентификатор
 * @return {api.currency}
 */
CREATE OR REPLACE FUNCTION api.get_currency (
  pId		uuid
) RETURNS	api.currency
AS $$
  SELECT * FROM api.currency WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_currency -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список валют.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.currency}
 */
CREATE OR REPLACE FUNCTION api.list_currency (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.currency
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'currency', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
