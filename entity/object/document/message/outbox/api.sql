--------------------------------------------------------------------------------
-- api.outbox ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.outbox
AS
  SELECT * FROM ServiceMessage WHERE class = GetClass('outbox') AND scope = current_scope();

GRANT SELECT ON api.outbox TO administrator;
GRANT SELECT ON api.outbox TO apibot;

--------------------------------------------------------------------------------
-- FUNCTION api.outbox ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.outbox (
  pState    uuid
) RETURNS   SETOF api.outbox
AS $$
  SELECT * FROM api.outbox WHERE state = pState;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.outbox ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.outbox (
  pState    text
) RETURNS   SETOF api.outbox
AS $$
  SELECT * FROM api.outbox(GetState(GetClass('outbox'), pState));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_outbox --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет исходящее сообщение.
 * @param {uuid} pParent - Родительский объект
 * @param {uuid} pAgent - Агент
 * @param {text} pCode - Код (MsgId)
 * @param {text} pProfile - Профиль отправителя
 * @param {text} pAddress - Адрес получателя
 * @param {text} pSubject - Тема
 * @param {text} pContent - Содержимое
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_outbox (
  pParent       uuid,
  pAgent        uuid,
  pCode         text,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent        text,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateMessage(pParent, GetType('message.outbox'), pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_outbox --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает исходящее сообщение
 * @param {uuid} pId - Идентификатор
 * @return {api.outbox}
 */
CREATE OR REPLACE FUNCTION api.get_outbox (
  pId        uuid
) RETURNS    SETOF api.outbox
AS $$
  SELECT * FROM api.outbox WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_outbox -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список исходящих сообщений.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.outbox}
 */
CREATE OR REPLACE FUNCTION api.list_outbox (
  pSearch    jsonb DEFAULT null,
  pFilter    jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet    integer DEFAULT null,
  pOrderBy    jsonb DEFAULT null
) RETURNS    SETOF api.outbox
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'outbox', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

