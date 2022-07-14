--------------------------------------------------------------------------------
-- AGENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.agent -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.agent
AS
  SELECT * FROM ObjectAgent;

GRANT SELECT ON api.agent TO administrator;

--------------------------------------------------------------------------------
-- api.add_agent ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет агента.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pVendor - Производитель
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_agent (
  pParent       uuid,
  pType         uuid,
  pVendor       uuid,
  pCode         text,
  pName         text,
  pDescription	text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateAgent(pParent, coalesce(pType, GetType('system.agent')), pVendor, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_agent ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует агента.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pVendor - Производитель
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_agent (
  pId		    uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pVendor       uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  uAgent        uuid;
BEGIN
  SELECT t.id INTO uAgent FROM db.agent t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('агент', 'id', pId);
  END IF;

  PERFORM EditAgent(uAgent, pParent, pType, pVendor, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_agent ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_agent (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pVendor       uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       SETOF api.agent
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_agent(pParent, pType, pVendor, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_agent(pId, pParent, pType, pVendor, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.agent WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_agent ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает агента
 * @param {uuid} pId - Идентификатор
 * @return {api.agent}
 */
CREATE OR REPLACE FUNCTION api.get_agent (
  pId		uuid
) RETURNS	SETOF api.agent
AS $$
  SELECT * FROM api.agent WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_agent --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список агентов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.agent}
 */
CREATE OR REPLACE FUNCTION api.list_agent (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.agent
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'agent', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_agent_id ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает uuid по коду.
 * @param {text} pCode - Код агента
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.get_agent_id (
  pCode		text
) RETURNS	uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetAgent(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
