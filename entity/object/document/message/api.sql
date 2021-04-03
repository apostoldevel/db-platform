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
  pClass	uuid
) RETURNS	SETOF api.message
AS $$
  SELECT * FROM api.message WHERE class = pClass
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.inbox -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.inbox
AS
  SELECT * FROM api.message(GetClass('inbox'));

GRANT SELECT ON api.inbox TO administrator;

--------------------------------------------------------------------------------
-- api.outbox ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.outbox
AS
  SELECT * FROM api.message(GetClass('outbox'));

GRANT SELECT ON api.outbox TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.message --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.message (
  pType		uuid,
  pAgent    uuid,
  pState    uuid
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
  pType		text,
  pAgent    text,
  pState    text
) RETURNS	SETOF api.message
AS $$
  SELECT * FROM api.message(CodeToType(coalesce(pType, 'message.outbox'), 'message'), GetAgent(pAgent), GetState(GetClass(SubStr(pType, StrPos(pType, '.') + 1)), pState));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_message -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет сообщение.
 * @param {uuid} pParent - Родительский объект
 * @param {text} pType - Код типа
 * @param {uuid} pAgent - Агент
 * @param {text} pProfile - Профиль отправителя
 * @param {text} pAddress - Адрес получателя
 * @param {text} pSubject - Тема
 * @param {text} pContent - Содержимое
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_message (
  pParent       uuid,
  pType         text,
  pAgent        uuid,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent		text,
  pDescription  text default null
) RETURNS       uuid
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
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Родительский объект
 * @param {text} pType - Код типа
 * @param {uuid} pAgent - Агент
 * @param {text} pProfile - Профиль отправителя
 * @param {text} pAddress - Адрес получателя
 * @param {text} pSubject - Тема
 * @param {text} pContent - Содержимое
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_message (
  pId           uuid,
  pParent       uuid default null,
  pType         text default null,
  pAgent        uuid default null,
  pProfile      text default null,
  pAddress      text default null,
  pSubject      text default null,
  pContent		text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  nMessage      uuid;
  uType         uuid;
BEGIN
  SELECT a.id INTO nMessage FROM db.message a WHERE a.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('адрес', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    uType := CodeToType(lower(pType), 'message');
  ELSE
    SELECT o.type INTO uType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditMessage(nMessage, pParent, uType, pAgent, pProfile, pAddress, pSubject, pContent, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_message -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_message (
  pId           uuid,
  pParent       uuid default null,
  pType         text default null,
  pAgent        uuid default null,
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
 * Возвращает сообщение
 * @param {uuid} pId - Идентификатор
 * @return {api.message}
 */
CREATE OR REPLACE FUNCTION api.get_message (
  pId		uuid
) RETURNS	SETOF api.message
AS $$
  SELECT * FROM api.message WHERE id = pId
$$ LANGUAGE SQL
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
-- api.get_outbox --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает исходящее сообщение
 * @param {uuid} pId - Идентификатор
 * @return {api.outbox}
 */
CREATE OR REPLACE FUNCTION api.get_outbox (
  pId		uuid
) RETURNS	SETOF api.outbox
AS $$
  SELECT * FROM api.outbox WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_message ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список сообщений.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.message}
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
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.outbox
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'outbox', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
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
  nAgent		uuid;
  uMessageId	uuid;
BEGIN
  nAgent := GetAgent(pAgent);
  IF nAgent IS NULL THEN
    PERFORM ObjectNotFound('агент', 'code', pAgent);
  END IF;

  uMessageId := SendMessage(null, nAgent, pProfile, pAddress, pSubject, pContent, pDescription);

  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
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
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    SETOF api.message
AS $$
DECLARE
  uMessageId	uuid;
  vProject		text;
  vDomain		text;
  vProfile		text;
  vName			text;
  vEmail		text;
  vBody			text;
  bVerified		bool;
  vOAuthSecret	text;
BEGIN
  IF IsUserRole(GetGroup('system'), session_userid()) THEN
	SELECT secret INTO vOAuthSecret FROM oauth2.audience WHERE code = session_username();
	PERFORM SubstituteUser(GetUser('admin'), vOAuthSecret);
  END IF;

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

  uMessageId := SendMail(null, vProfile, vEmail, pSubject, vBody, pDescription);

  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
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
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    SETOF api.message
AS $$
DECLARE
  uMessageId	uuid;

  vCharSet      text;
  vName			text;
  vPhone        text;
  bVerified		bool;
  vOAuthSecret	text;
BEGIN
  IF IsUserRole(GetGroup('system'), session_userid()) THEN
	SELECT secret INTO vOAuthSecret FROM oauth2.audience WHERE code = session_username();
	PERFORM SubstituteUser(GetUser('admin'), vOAuthSecret);
  END IF;

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

  uMessageId := SendSMS(null, pProfile, pMessage, pUserId);

  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_push ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.send_push (
  pObject       uuid,
  pSubject		text,
  pData         json,
  pUserId       uuid DEFAULT current_userid()
) RETURNS	    SETOF api.message
AS $$
DECLARE
  uMessageId	uuid;
  vOAuthSecret	text;
BEGIN
  IF IsUserRole(GetGroup('system'), session_userid()) THEN
	SELECT secret INTO vOAuthSecret FROM oauth2.audience WHERE code = session_username();
	PERFORM SubstituteUser(GetUser('admin'), vOAuthSecret);
  END IF;

  uMessageId := SendPush(pObject, pSubject, pData, pUserId);

  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
