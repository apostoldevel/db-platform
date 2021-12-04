--------------------------------------------------------------------------------
-- api.inbox -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.inbox
AS
  SELECT * FROM api.service_message(GetClass('inbox'));

GRANT SELECT ON api.inbox TO administrator;
GRANT SELECT ON api.inbox TO apibot;

--------------------------------------------------------------------------------
-- FUNCTION api.inbox ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.inbox (
  pState    uuid
) RETURNS	SETOF api.inbox
AS $$
  SELECT * FROM api.inbox WHERE state = pState;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.inbox ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.inbox (
  pState    text
) RETURNS	SETOF api.inbox
AS $$
  SELECT * FROM api.inbox(GetState(GetClass('inbox'), pState));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_inbox ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет входящее сообщение.
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
CREATE OR REPLACE FUNCTION api.add_inbox (
  pParent       uuid,
  pAgent        uuid,
  pCode         text,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent		text,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateMessage(pParent, GetType('message.inbox'), pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_inbox ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает входящее сообщение
 * @param {uuid} pId - Идентификатор
 * @return {api.inbox}
 */
CREATE OR REPLACE FUNCTION api.get_inbox (
  pId		uuid
) RETURNS	SETOF api.inbox
AS $$
  SELECT * FROM api.inbox WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_inbox --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список входящих сообщений.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.inbox}
 */
CREATE OR REPLACE FUNCTION api.list_inbox (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.inbox
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'inbox', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
