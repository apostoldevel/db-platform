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
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_version (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateVersion(pParent, coalesce(pType, GetType('api.version')), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_version ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует версию.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_version (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uVersion      uuid;
BEGIN
  SELECT t.id INTO uVersion FROM db.version t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('version', 'id', pId);
  END IF;

  PERFORM EditVersion(uVersion, pParent, pType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_version -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_version (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
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
 * @param {uuid} pId - Идентификатор
 * @return {api.version}
 */
CREATE OR REPLACE FUNCTION api.get_version (
  pId        uuid
) RETURNS    api.version
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
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.version
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'version', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_version_id ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает uuid по коду.
 * @param {text} pCode - Код версии
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.get_version_id (
  pCode      text
) RETURNS    uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetVersion(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
