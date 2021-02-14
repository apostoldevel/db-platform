--------------------------------------------------------------------------------
-- VERSION ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.version -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.version
AS
  SELECT * FROM ObjectVersion;

GRANT SELECT ON api.version TO administrator;

--------------------------------------------------------------------------------
-- api.add_version -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет версию.
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_version (
  pParent       numeric,
  pType         text,
  pCode         text,
  pName         text,
  pDescription	text default null
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateVersion(pParent, CodeToType(lower(coalesce(pType, 'api')), 'version'), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_version ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует версию.
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_version (
  pId		    numeric,
  pParent       numeric default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nType         numeric;
  nVersion      numeric;
BEGIN
  SELECT t.id INTO nVersion FROM db.version t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('версия', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'version');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditVersion(nVersion, pParent, nType,pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_version -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_version (
  pId           numeric,
  pParent       numeric default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       SETOF api.version
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_version(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_version(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.version WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_version -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает версию
 * @param {numeric} pId - Идентификатор
 * @return {api.version}
 */
CREATE OR REPLACE FUNCTION api.get_version (
  pId		numeric
) RETURNS	api.version
AS $$
  SELECT * FROM api.version WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_version ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает версию в виде списка.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.version}
 */
CREATE OR REPLACE FUNCTION api.list_version (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.version
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'version', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
