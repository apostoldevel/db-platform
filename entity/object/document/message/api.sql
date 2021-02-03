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
  SELECT * FROM api.message WHERE type = pType AND agent = pAgent AND state = pState;
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
  SELECT * FROM api.message(CodeToType(coalesce(pType, 'message.outbox'), 'message'), GetAgent(pAgent), GetState(GetClass(SubStr(pType, StrPos(pType, '.') + 1)), pState));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.outbox ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.outbox (
  pState    numeric,
  pType		numeric DEFAULT GetType('message.outbox')
) RETURNS	SETOF api.message
AS $$
  SELECT * FROM api.message WHERE type = pType AND state = pState;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.outbox ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.outbox (
  pState    varchar
) RETURNS	SETOF api.message
AS $$
  SELECT * FROM api.outbox(GetState(GetClass('outbox'), pState));
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
 * @param {numeric} pAgent - Агент
 * @param {text} pProfile - Профиль отправителя
 * @param {text} pAddress - Адрес получателя
 * @param {text} pSubject - Тема
 * @param {text} pContent - Содержимое
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_message (
  pParent       numeric,
  pType         varchar,
  pAgent        numeric,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent		text,
  pDescription  text default null
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateMessage(pParent, CodeToType(coalesce(lower(pType), 'message.outbox'), 'message'), pAgent, pProfile, pAddress, pSubject, pContent, pDescription);
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
 * @param {numeric} pAgent - Агент
 * @param {text} pProfile - Профиль отправителя
 * @param {text} pAddress - Адрес получателя
 * @param {text} pSubject - Тема
 * @param {text} pContent - Содержимое
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_message (
  pId           numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pAgent        numeric default null,
  pProfile      text default null,
  pAddress      text default null,
  pSubject      text default null,
  pContent		text default null,
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
    nType := CodeToType(lower(pType), 'message');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditMessage(nMessage, pParent, nType, pAgent, pProfile, pAddress, pSubject, pContent, pDescription);
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
  pAgent        numeric default null,
  pProfile      text default null,
  pAddress      text default null,
  pSubject      text default null,
  pContent      text default null,
  pDescription  text default null
) RETURNS       SETOF api.message
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_message(pParent, pType, pAgent, pProfile, pAddress, pSubject, pContent, pDescription);
  ELSE
    PERFORM api.update_message(pId, pParent, pType, pAgent, pProfile, pAddress, pSubject, pContent, pDescription);
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

CREATE OR REPLACE FUNCTION api.send_message (
  pAgent        text,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pDescription  text default null
) RETURNS       SETOF api.message
AS $$
DECLARE
  nAgent		numeric;
  nMessageId	numeric;
BEGIN
  nAgent := GetAgent(pAgent);
  IF nAgent IS NULL THEN
    PERFORM ObjectNotFound('агент', 'code', pAgent);
  END IF;

  nMessageId := SendMessage(null, nAgent, pProfile, pAddress, pSubject, pContent, pDescription);

  RETURN QUERY SELECT * FROM api.message WHERE id = nMessageId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_mail ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.send_mail (
  pSubject      text,
  pText			text,
  pHTML			text,
  pDescription  text DEFAULT null,
  pUserId		numeric DEFAULT current_userid()
) RETURNS	    SETOF api.message
AS $$
DECLARE
  vProject		text;
  vDomain		text;
  vProfile		text;
  vName			text;
  vEmail		text;
  vBody			text;
  bVerified		bool;
  nMessageId	numeric;
BEGIN
  SELECT name, email, email_verified, locale INTO vName, vEmail, bVerified
	FROM db.user u INNER JOIN db.profile p ON u.id = p.userid
   WHERE id = pUserId;

  IF vEmail IS NULL THEN
    PERFORM EmailAddressNotSet();
  END IF;

  IF NOT bVerified THEN
    PERFORM EmailAddressNotVerified(vEmail);
  END IF;

  vProject := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Name', pUserId);
  vDomain := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Domain', pUserId);

  vProfile := format('info@%s', vDomain);

  vBody := CreateMailBody(vProject, vProfile, vName, vEmail, pSubject, pText, pHTML);

  nMessageId := SendMail(null, vProfile, vEmail, pSubject, vBody, pDescription);

  RETURN QUERY SELECT * FROM api.message WHERE id = nMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_sms ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.send_sms (
  pProfile      text,
  pMessage      text,
  pUserId		numeric DEFAULT current_userid()
) RETURNS	    SETOF api.message
AS $$
DECLARE
  vCharSet      text;
  vName			text;
  vPhone        text;
  bVerified		bool;
  nMessageId	numeric;
BEGIN
  vCharSet := coalesce(nullif(pg_client_encoding(), 'UTF8'), 'utf-8');

  SELECT name, phone, phone_verified, locale INTO vName, vPhone, bVerified
	FROM db.user u INNER JOIN db.profile p ON u.id = p.userid
   WHERE id = pUserId;

  IF vPhone IS NULL THEN
    PERFORM PhoneNumberNotSet();
  END IF;

  IF NOT bVerified THEN
    PERFORM PhoneNumberNotVerified(vPhone);
  END IF;

  nMessageId := SendSMS(null, pProfile, pMessage, pUserId);

  RETURN QUERY SELECT * FROM api.message WHERE id = nMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_push ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.send_push (
  pObject       numeric,
  pSubject		text,
  pData         json,
  pUserId       numeric DEFAULT current_userid()
) RETURNS	    SETOF api.message
AS $$
DECLARE
  nMessageId	numeric;
BEGIN
  nMessageId := SendPush(pObject, pSubject, pData, pUserId);

  RETURN QUERY SELECT * FROM api.message WHERE id = nMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
