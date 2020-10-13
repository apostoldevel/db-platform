--------------------------------------------------------------------------------
-- MESSAGE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.message -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.message
AS
  SELECT * FROM ObjectMessage;

GRANT SELECT ON api.message TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.message --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.message (
  pType		numeric,
  pAgent    numeric,
  pState    numeric
) RETURNS	SETOF api.message
AS $$
  SELECT * FROM api.message WHERE type = pType AND agent = pAgent AND state = pState ORDER BY addressfrom;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.message --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.message (
  pType		varchar,
  pAgent    varchar,
  pState    varchar
) RETURNS	SETOF api.message
AS $$
  SELECT * FROM api.message(CodeToType(coalesce(pType, 'message'), ARRAY['outbox', 'inbox']), GetAgent(pAgent), GetState(GetClass(SubStr(pType, StrPos(pType, '.') + 1)), pState));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_message -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет сообщение.
 * @param {numeric} pParent - Родительский объект
 * @param {varchar} pType - Код типа
 * @param {varchar} pAgent - Код агента
 * @param {text} pFrom - От
 * @param {text} pTo - Кому
 * @param {text} pSubject - Тема
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_message (
  pParent       numeric,
  pType         varchar,
  pAgent        varchar,
  pFrom         text,
  pTo           text,
  pSubject      text,
  pBody         text,
  pDescription  text default null
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateMessage(pParent, CodeToType(coalesce(lower(pType), 'message'), ARRAY['outbox', 'inbox']), GetAgent(coalesce(pAgent, 'system')), pFrom, pTo, pSubject, pBody, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_message ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет сообщение.
 * @param {numeric} pId - Идентификатор
 * @param {numeric} pParent - Родительский объект
 * @param {varchar} pType - Код типа
 * @param {varchar} pAgent - Код агента
 * @param {text} pFrom - От
 * @param {text} pTo - Кому
 * @param {text} pSubject - Тема
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_message (
  pId           numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pAgent        varchar default null,
  pFrom         text default null,
  pTo           text default null,
  pSubject      text default null,
  pBody         text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  nMessage      numeric;
  nType         numeric;
BEGIN
  SELECT a.id INTO nMessage FROM db.message a WHERE a.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('адрес', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), ARRAY['outbox', 'inbox']);
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditMessage(nMessage, pParent, nType, GetAgent(coalesce(pAgent, 'system')), pFrom, pTo, pSubject, pBody, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_message -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_message (
  pId           numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pAgent        varchar default null,
  pAddressFrom  text default null,
  pAddressTo    text default null,
  pSubject      text default null,
  pBody         text default null,
  pDescription  text default null
) RETURNS       SETOF api.message
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_message(pParent, pType, pAgent, pAddressFrom, pAddressTo, pSubject, pBody, pDescription);
  ELSE
    PERFORM api.update_message(pId, pParent, pType, pAgent, pAddressFrom, pAddressTo, pSubject, pBody, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.message WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_message -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает клиента
 * @param {numeric} pId - Идентификатор адреса
 * @return {api.message} - Адрес
 */
CREATE OR REPLACE FUNCTION api.get_message (
  pId		numeric
) RETURNS	SETOF api.message
AS $$
  SELECT * FROM api.message WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_message ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список клиентов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.message} - Адреса
 */
CREATE OR REPLACE FUNCTION api.list_message (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.message
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'message', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_message ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Отправляет сообщение.
 * @param {numeric} pId - Идентификатор
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.send_message (
  pId           numeric
) RETURNS       void
AS $$
BEGIN
  PERFORM SendMessage(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
