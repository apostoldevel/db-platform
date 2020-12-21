--------------------------------------------------------------------------------
-- CATEGORY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.category ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.category
AS
  SELECT * FROM ObjectCategory;

GRANT SELECT ON api.category TO administrator;

--------------------------------------------------------------------------------
-- api.add_category ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет категорию.
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_category (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pName         varchar,
  pDescription	text default null
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateCategory(pParent, CodeToType(lower(coalesce(pType, 'service')), 'category'), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_category ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует категорию.
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_category (
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
  nCategory        numeric;
BEGIN
  SELECT t.id INTO nCategory FROM db.category t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('категория', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'category');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditCategory(nCategory, pParent, nType,pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_category ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_category (
  pId           numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pName         varchar default null,
  pDescription	text default null
) RETURNS       SETOF api.category
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_category(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_category(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.category WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_category ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает категорию
 * @param {numeric} pId - Идентификатор
 * @return {api.category}
 */
CREATE OR REPLACE FUNCTION api.get_category (
  pId		numeric
) RETURNS	api.category
AS $$
  SELECT * FROM api.category WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_category -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список категорий.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.category}
 */
CREATE OR REPLACE FUNCTION api.list_category (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.category
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'category', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
