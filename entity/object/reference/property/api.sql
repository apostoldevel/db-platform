--------------------------------------------------------------------------------
-- PROPERTY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.property ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.property
AS
  SELECT * FROM ObjectProperty;

GRANT SELECT ON api.property TO administrator;

--------------------------------------------------------------------------------
-- api.add_property ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет свойство.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_property (
  pParent       uuid,
  pType         text,
  pCode         text,
  pName         text,
  pDescription	text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateProperty(pParent, CodeToType(lower(coalesce(pType, 'string')), 'property'), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_property ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует свойство.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_property (
  pId		    uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  uType         uuid;
  nProperty		uuid;
BEGIN
  SELECT t.id INTO nProperty FROM db.property t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('свойство', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    uType := CodeToType(lower(pType), 'property');
  ELSE
    SELECT o.type INTO uType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditProperty(nProperty, pParent, uType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_property ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_property (
  pId           uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       SETOF api.property
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_property(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_property(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.property WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_property ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает свойство
 * @param {uuid} pId - Идентификатор
 * @return {api.property}
 */
CREATE OR REPLACE FUNCTION api.get_property (
  pId		uuid
) RETURNS	api.property
AS $$
  SELECT * FROM api.property WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_property -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список свойств.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.property}
 */
CREATE OR REPLACE FUNCTION api.list_property (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.property
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'property', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
