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
-- api.service_message ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.service_message
AS
  SELECT * FROM ServiceMessage;

GRANT SELECT ON api.service_message TO administrator;
GRANT SELECT ON api.service_message TO apibot;

--------------------------------------------------------------------------------
-- FUNCTION api.service_message ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.service_message (
  pClass	uuid
) RETURNS	SETOF api.service_message
AS $$
  SELECT * FROM api.service_message WHERE class = pClass
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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
-- api.outbox ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.outbox
AS
  SELECT * FROM api.service_message(GetClass('outbox'));

GRANT SELECT ON api.outbox TO administrator;
GRANT SELECT ON api.outbox TO apibot;

--------------------------------------------------------------------------------
-- FUNCTION api.outbox ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.outbox (
  pState    uuid
) RETURNS	SETOF api.outbox
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
) RETURNS	SETOF api.outbox
AS $$
  SELECT * FROM api.outbox(GetState(GetClass('outbox'), pState));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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
  SELECT * FROM api.message(CodeToType(pType, 'message'), GetAgent(pAgent), GetState(GetClass(SubStr(pType, StrPos(pType, '.') + 1)), pState));
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
  pContent		text,
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
-- api.add_message -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет сообщение.
 * @param {uuid} pParent - Родительский объект
 * @param {uuid} pType - Идентификатор типа
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
CREATE OR REPLACE FUNCTION api.add_message (
  pParent       uuid,
  pType         uuid,
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
  RETURN CreateMessage(pParent, pType, pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
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
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pAgent - Агент
 * @param {text} pCode - Код (MsgId)
 * @param {text} pProfile - Профиль отправителя
 * @param {text} pAddress - Адрес получателя
 * @param {text} pSubject - Тема
 * @param {text} pContent - Содержимое
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_message (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pAgent        uuid default null,
  pCode         text default null,
  pProfile      text default null,
  pAddress      text default null,
  pSubject      text default null,
  pContent		text default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uMessage      uuid;
BEGIN
  SELECT a.id INTO uMessage FROM db.message a WHERE a.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('message', 'id', pId);
  END IF;

  PERFORM EditMessage(uMessage, pParent, pType, pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
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
  pType         uuid default null,
  pAgent        uuid default null,
  pCode         text default null,
  pProfile      text default null,
  pAddress      text default null,
  pSubject      text default null,
  pContent      text default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       SETOF api.message
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_message(pParent, pType, pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
  ELSE
    PERFORM api.update_message(pId, pParent, pType, pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
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
  pParent       uuid,
  pAgent        uuid,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       SETOF api.message
AS $$
DECLARE
  uMessageId	uuid;
BEGIN
  uMessageId := SendMessage(pParent, pAgent, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
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
	PERFORM SubstituteUser(GetUser('apibot'), vOAuthSecret);
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

  uMessageId := SendMail(null, vProfile, vEmail, pSubject, vBody, null, pDescription);

  IF vOAuthSecret IS NOT NULL THEN
    PERFORM SubstituteUser(session_userid(), vOAuthSecret);
  END IF;

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
  pTitle        text,
  pBody         text,
  pUserId       uuid DEFAULT current_userid(),
  pData         jsonb DEFAULT null,
  pAndroid      jsonb DEFAULT null,
  pApns         jsonb DEFAULT null
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

  uMessageId := SendPush(pObject, pTitle, pBody, pUserId, pData, pAndroid, pApns);

  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_push_data ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.send_push_data (
  pObject       uuid,
  pSubject      text,
  pData         json,
  pUserId       uuid DEFAULT current_userid(),
  pPriority     text DEFAULT null,
  pCollapse     text DEFAULT null
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

  uMessageId := SendPushData(pObject, pSubject, pData, pUserId, pPriority, pCollapse);

  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_push_to_role -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.send_push_to_role (
  pRoleName     text,
  pTitle        text,
  pBody         text,
  pData         jsonb DEFAULT null,
  pAndroid      jsonb DEFAULT null,
  pApns         jsonb DEFAULT null
) RETURNS		integer
AS $$
DECLARE
  r             record;
  nCount        integer;
  uUserId		uuid;
  vType         char;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('message')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  nCount := 0;

  SELECT id, type INTO uUserId, vType FROM db.user WHERE status & B'0100' != B'0100' AND username = pRoleName;

  IF NOT FOUND THEN
	RETURN 0;
  END IF;

  IF vType = 'G' THEN
    FOR r IN SELECT member FROM db.member_group WHERE userid = uUserId
    LOOP
      PERFORM SendPush(null, pTitle, pBody, r.member, pData, pAndroid, pApns);
      nCount := nCount + 1;
	END LOOP;
  ELSE
    PERFORM SendPush(null, pTitle, pBody, uUserId, pData, pAndroid, pApns);
    nCount := 1;
  END IF;

  RETURN nCount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
