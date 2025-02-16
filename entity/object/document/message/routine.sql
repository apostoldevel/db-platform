--------------------------------------------------------------------------------
-- CreateMessage ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт новое сообщение
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
 * @return {(id|exception)} - Id сообщения или ошибку
 */
CREATE OR REPLACE FUNCTION CreateMessage (
  pParent       uuid,
  pType         uuid,
  pAgent        uuid,
  pCode         text,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uMessage      uuid;
  uDocument     uuid;

  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'message' THEN
    PERFORM IncorrectClassType();
  END IF;

  uDocument := CreateDocument(pParent, pType, pLabel, pDescription);

  INSERT INTO db.message (id, document, agent, code, profile, address, subject, content)
  VALUES (uDocument, uDocument, pAgent, pCode, pProfile, pAddress, pSubject, pContent)
  RETURNING id INTO uMessage;

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uMessage, uMethod);

  return uMessage;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditMessage -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует сообщение.
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
CREATE OR REPLACE FUNCTION EditMessage (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pAgent        uuid DEFAULT null,
  pCode         text DEFAULT null,
  pProfile      text DEFAULT null,
  pAddress      text DEFAULT null,
  pSubject      text DEFAULT null,
  pContent      text DEFAULT null,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  uClass        uuid;
  uMethod       uuid;
BEGIN
  PERFORM EditDocument(pId, pParent, pType, pLabel, pDescription, coalesce(pLabel, pDescription), current_locale());

  UPDATE db.message
     SET agent = coalesce(pAgent, agent),
         code = coalesce(pCode, code),
         profile = coalesce(pProfile, profile),
         address = coalesce(pAddress, address),
         subject = coalesce(pSubject, subject),
         content = coalesce(pContent, content)
   WHERE id = pId;

  uClass := GetObjectClass(pId);
  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetMessageCode --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMessageCode (
  pId      uuid
) RETURNS  text
AS $$
  SELECT code FROM db.message WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetMessageState -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMessageState (
  pCode    text
) RETURNS  uuid
AS $$
BEGIN
  RETURN GetState(GetEntity('message'), pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetEncodedTextRFC1342 -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEncodedTextRFC1342 (
  pText     text,
  pCharSet  text
) RETURNS   text
AS $$
BEGIN
  RETURN format('=?%s?B?%s?=', pCharSet, encode(pText::bytea, 'base64'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EncodingSubject -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EncodingSubject (
  pSubject  text,
  pCharSet  text
) RETURNS   text
AS $$
DECLARE
  ch        text;

  nLimit    int;
  nLength   int;

  vText     text DEFAULT '';
  Result    text;
BEGIN
  nLimit := 18;
  FOR Key IN 1..Length(pSubject)
  LOOP
    ch := SubStr(pSubject, Key, 1);
    vText := vText || ch;
    nLength := Length(vText);
    IF (nLength >= (nLimit - 6) AND ch = ' ') OR nLength >= nLimit THEN
      Result := coalesce(Result || E'\n ', '') || GetEncodedTextRFC1342(vText, pCharSet);
      vText := '';
      nLimit := 22;
    END IF;
  END LOOP;

  IF nullif(vText, '') IS NOT NULL THEN
    Result := coalesce(Result || E'\n ', '') || GetEncodedTextRFC1342(vText, pCharSet);
  END IF;

  RETURN Result;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateMailBody --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateMailBody (
  pFromName text,
  pFrom     text,
  pToName   text,
  pTo       text,
  pSubject  text,
  pText     text,
  pHTML     text
) RETURNS   text
AS $$
DECLARE
  vCharSet  text;
  vBoundary text;
  vEncoding text;
  vBody     text;
BEGIN
  vCharSet := coalesce(nullif(pg_client_encoding(), 'UTF8'), 'UTF-8');
  vEncoding := 'base64';

  vBody := E'MIME-Version: 1.0\r\n';

  vBody := vBody || format(E'Date: %s\r\n', to_char(current_timestamp, 'Dy, DD Mon YYYY HH24:MI:SS TZHTZM'));
  vBody := vBody || format(E'Subject: %s\r\n', EncodingSubject(pSubject, vCharSet));

  IF pFromName IS NULL THEN
    vBody := vBody || format(E'From: %s\r\n', pFrom);
  ELSE
    vBody := vBody || format(E'From: %s <%s>\r\n', GetEncodedTextRFC1342(pFromName, vCharSet), pFrom);
  END IF;

  IF pToName IS NULL THEN
    vBody := vBody || format(E'To: %s\r\n', pTo);
  ELSE
    vBody := vBody || format(E'To: %s <%s>\r\n', GetEncodedTextRFC1342(pToName, vCharSet), pTo);
  END IF;

  vBoundary := encode(gen_random_bytes(12), 'hex');

  vBody := vBody || format(E'Content-Type: multipart/alternative; boundary="%s"\r\n', vBoundary);

  IF pText IS NOT NULL THEN
    vBody := vBody || format(E'\r\n--%s\r\n', vBoundary);
    vBody := vBody || format(E'Content-Type: text/plain; charset="%s"\r\n', vCharSet);
    vBody := vBody || format(E'Content-Transfer-Encoding: %s\r\n\r\n', vEncoding);
    vBody := vBody || encode(pText::bytea, vEncoding);
  END IF;

  IF pHTML IS NOT NULL THEN
    vBody := vBody || format(E'\r\n--%s\r\n', vBoundary);
    vBody := vBody || format(E'Content-Type: text/html; charset="%s"\r\n', vCharSet);
    vBody := vBody || format(E'Content-Transfer-Encoding: %s\r\n\r\n', vEncoding);
    vBody := vBody || encode(pHTML::bytea, vEncoding);
  END IF;

  vBody := vBody || format(E'\r\n--%s--', vBoundary);

  RETURN vBody;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- SendMessage -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendMessage (
  pParent       uuid,
  pAgent        uuid,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pType         uuid DEFAULT GetType('message.outbox')
) RETURNS       uuid
AS $$
DECLARE
  uMessageId    uuid;
BEGIN
  uMessageId := CreateMessage(pParent, pType, pAgent, encode(gen_random_bytes(32), 'hex'), pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
  PERFORM ExecuteObjectAction(uMessageId, GetAction('submit'));
  RETURN uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- SendMail --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendMail (
  pParent       uuid,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pAgent        uuid DEFAULT GetAgent('smtp.agent')
) RETURNS       uuid
AS $$
BEGIN
  RETURN SendMessage(pParent, pAgent, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendM2M ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendM2M (
  pParent       uuid,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pAgent        uuid DEFAULT GetAgent('m2m.agent')
) RETURNS       uuid
AS $$
BEGIN
  RETURN SendMessage(pParent, pAgent, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendFCM ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendFCM (
  pParent       uuid,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pAgent        uuid DEFAULT GetAgent('fcm.agent')
) RETURNS       uuid
AS $$
BEGIN
  RETURN SendMessage(pParent, pAgent, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendSMS ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendSMS (
  pParent       uuid,
  pProfile      text,
  pMessage      text,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       uuid
AS $$
DECLARE
  profile       text;
  address       text;
  subject       text;

  content       jsonb;

  uMessageId    uuid;

  vPhone        text;
BEGIN
  SELECT phone INTO vPhone FROM db.user WHERE id = pUserId;

  IF vPhone IS NOT NULL THEN
    profile := 'mts';
    address := '/messages';
    subject := vPhone;
    content := json_build_object('messages', jsonb_build_array(json_build_object('content', json_build_object('short_text', pMessage), 'to', jsonb_build_array(json_build_object('msisdn', vPhone)))), 'options', json_build_object('from',  json_build_object('sms_address', pProfile)));

    uMessageId := SendMessage(pParent, GetAgent('mts.agent'), profile, address, subject, content::text, null, pMessage);

    PERFORM WriteToEventLog('M', 1001, 'sms', format('SMS передано на отправку: %s', uMessageId), uMessageId);
  ELSE
    PERFORM WriteToEventLog('E', 3001, 'sms', 'Не удалось отправить SMS, телефон не установлен.', pParent);
  END IF;

  RETURN uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendPush --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendPush (
  pObject       uuid,
  pTitle        text,
  pBody         text,
  pUserId       uuid DEFAULT current_userid(),
  pData         jsonb DEFAULT null,
  pAndroid      jsonb DEFAULT null,
  pApns         jsonb DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uMessageId    uuid;

  tokens        text[];

  projectId     text;
  token         text;

  message       jsonb;
BEGIN
  projectId := RegGetValueString('CURRENT_CONFIG', 'CONFIG\Firebase', 'ProjectId');
  tokens := DoFCMTokens(pUserId);

  IF tokens IS NOT NULL THEN
    FOR i IN 1..array_length(tokens, 1)
    LOOP
      token := tokens[i];
      IF token IS NOT NULL THEN
        message := jsonb_build_object('token', token, 'notification', jsonb_build_object('title', pTitle, 'body', pBody));

        IF pAndroid IS NOT NULL THEN
          message := message || jsonb_build_object('android', pAndroid);
        END IF;

        IF pApns IS NOT NULL THEN
          message := message || jsonb_build_object('apns', pApns);
        END IF;

        IF pData IS NOT NULL THEN
          message := message || jsonb_build_object('data', pData);
        END IF;

        uMessageId := SendFCM(pObject, projectId, GetUserName(pUserId), pTitle, jsonb_build_object('message', message)::text);
        PERFORM WriteToEventLog('M', 1001, 'push', format('Push сообщение передано на отправку: %s', uMessageId), pObject);
      END IF;
    END LOOP;
  ELSE
    PERFORM WriteToEventLog('E', 3001, 'push', 'Не удалось отправить Push сообщение, токен не установлен.', pObject);
  END IF;

  RETURN uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendPushData ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendPushData (
  pObject       uuid,
  pSubject      text,
  pData         json,
  pUserId       uuid DEFAULT current_userid(),
  pPriority     text DEFAULT null,
  pCollapse     text DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uMessageId    uuid;

  tokens        text[];

  projectId     text;
  token         text;

  android       jsonb;
  message       jsonb;
BEGIN
  projectId := RegGetValueString('CURRENT_CONFIG', 'CONFIG\Firebase', 'ProjectId');
  tokens := DoFCMTokens(pUserId);

  IF tokens IS NOT NULL THEN
    FOR i IN 1..array_length(tokens, 1)
    LOOP
      token := tokens[i];
      IF token IS NOT NULL THEN
        android := jsonb_build_object('priority', coalesce(pPriority, 'normal'));
        IF pCollapse IS NOT NULL THEN
          android := android || jsonb_build_object('collapse_key', pCollapse);
        END IF;

        message := jsonb_build_object('token', token, 'android', android, 'data', pData);

        uMessageId := SendFCM(pObject, projectId, GetUserName(pUserId), pSubject, jsonb_build_object('message', message)::text);
        PERFORM WriteToEventLog('M', 1001, 'push', format('Push сообщение передано на отправку: %s', uMessageId), pObject);
      END IF;
    END LOOP;
  ELSE
    PERFORM WriteToEventLog('E', 3001, 'push', 'Не удалось отправить Push сообщение, токен не установлен.', pObject);
  END IF;

  RETURN uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RecoveryPasswordByEmail -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запускает процедуру восстановления пароля пользователя по адресу электронной почты.
 * @param {text} pEmail - Адрес электронной почты пользователя.
 * @return {uuid} - Талон восстановления (recovery ticket)
 */
CREATE OR REPLACE FUNCTION RecoveryPasswordByEmail (
  pUserId         uuid
) RETURNS         uuid
AS $$
DECLARE
  uTicket         uuid;

  vName           text;
  vSMTP           text;
  vDomain         text;
  vUserName       text;
  vProject        text;
  vEmail          text;
  vHost           text;
  vNoReply        text;
  vSupport        text;
  vSubject        text;
  vText           text;
  vHTML           text;
  vBody           text;
  vDescription    text;
  vSecurityAnswer text;
  bVerified       bool;

  vMessage        text;
  vContext        text;

  ErrorCode       int;
  ErrorMessage    text;
BEGIN
  SELECT name, email, email_verified, locale INTO vName, vEmail, bVerified
  FROM db.user u INNER JOIN db.profile p ON u.id = p.userid AND p.scope = current_scope()
   WHERE id = pUserId;

  IF vEmail IS NULL THEN
    PERFORM EmailAddressNotSet();
  END IF;

  IF NOT bVerified THEN
    PERFORM EmailAddressNotVerified(vEmail);
  END IF;

  vProject := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Name', pUserId);
  vSMTP := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'SMTP', pUserId);
  vDomain := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Domain', pUserId);

  vHost := current_scope_code();
  IF vHost = current_database()::text THEN
    vHost := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Host', pUserId);
  END IF;

  vNoReply := format('noreply@%s', coalesce(vSMTP, vDomain));
  vSupport := format('support@%s', coalesce(vSMTP, vDomain));

  IF locale_code() = 'ru' THEN
    vSubject := 'Сброс пароля.';
    vDescription := 'Сброс пароля через email: ' || vEmail;
  ELSE
    vSubject := 'Password reset.';
    vDescription := 'Reset password via email: ' || vEmail;
  END IF;

  vSecurityAnswer := encode(digest(gen_random_bytes(15), 'sha1'), 'hex');
  uTicket := NewRecoveryTicket(pUserId, vSecurityAnswer, encode(digest(vEmail, 'sha1'), 'hex'), Now(), Now() + INTERVAL '1 hour');

  vText := GetRecoveryPasswordEmailText(vName, vUserName, uTicket::text, vSecurityAnswer, vProject, vHost, vSupport);
  vHTML := GetRecoveryPasswordEmailHTML(vName, vUserName, uTicket::text, vSecurityAnswer, vProject, vHost, vSupport);

  vBody := CreateMailBody(vProject, vNoReply, null, vEmail, vSubject, vText, vHTML);

  PERFORM SendMail(null, vNoReply, vEmail, vSubject, vBody, null, vDescription);
  PERFORM CreateNotice(pUserId, null, vDescription);

  PERFORM WriteToEventLog('M', 1001, 'email', vDescription);

  RETURN uTicket;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN null;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- RecoveryPasswordByPhone -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запускает процедуру восстановления пароля пользователя по номеру телефона.
 * @param {uuid} pUserId - Идентификатор пользователя.
 * @param {text} pHashCode - Хэш-код.
 * @return {uuid} - Талон восстановления (recovery ticket)
 */
CREATE OR REPLACE FUNCTION RecoveryPasswordByPhone (
  pUserId         uuid,
  pInitiator      text,
  pHashCode       text DEFAULT null
) RETURNS         uuid
AS $$
DECLARE
  uTicket         uuid;
  uMessageId      uuid;
  vProfile        text;
  vSecurityAnswer text;
  vText           text;
  vMessage        text;
BEGIN
  vProfile := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject\SMS', 'Address', pUserId);
  vSecurityAnswer := random_between(100000, 999999)::text;

  IF locale_code() = 'ru' THEN
    vText := 'Код для восстановления пароля';
  ELSE
    vText := 'Password recovery code';
  END IF;

  vMessage := format('%s: %s.', vText, vSecurityAnswer);

  IF pHashCode IS NOT NULL THEN
    vMessage := concat(vMessage, E'\n\n\n\n', pHashCode);
  END IF;

  uMessageId := SendSMS(null, vProfile, vMessage, pUserId);
  IF uMessageId IS NOT NULL THEN
    uTicket := NewRecoveryTicket(pUserId, vSecurityAnswer, pInitiator, Now(), Now() + INTERVAL '5 min');
  END IF;

  RETURN uTicket;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegistrationCodeByPhone -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запускает процедуру регистрации пользователя по номеру телефона.
 * @param {text} pPhone - Номер телефона.
 * @param {text} pHashCode - Хэш-код.
 * @return {uuid} - Талон регистрации (registration ticket)
 */
CREATE OR REPLACE FUNCTION RegistrationCodeByPhone (
  pPhone          text,
  pHashCode       text DEFAULT null
) RETURNS         uuid
AS $$
DECLARE
  uTicket         uuid;
  uMessageId      uuid;
  vCode           text;
  vNaming         text;
  vText           text;
  vMessage        text;
  jContent        json;
BEGIN
  vNaming := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject\SMS', 'Address');
  vCode := random_between(100000, 999999)::text;

  IF locale_code() = 'ru' THEN
    vText := 'Регистрационный код';
  ELSE
    vText := 'Registration code';
  END IF;

  vMessage := format('%s: %s.', vText, vCode);

  IF pHashCode IS NOT NULL THEN
    vMessage := concat(vMessage, E'\n\n\n\n', pHashCode);
  END IF;

  jContent := json_build_object('messages', jsonb_build_array(json_build_object('content', json_build_object('short_text', vMessage), 'to', jsonb_build_array(json_build_object('msisdn', pPhone)))), 'options', json_build_object('from',  json_build_object('sms_address', vNaming)));

  uMessageId := SendMessage(null, GetAgent('mts.agent'), 'mts', '/messages', pPhone, jContent::text, null, vText);

  PERFORM WriteToEventLog('M', 1001, 'sms', format('SMS передано на отправку: %s', uMessageId), uMessageId);

  IF uMessageId IS NOT NULL THEN
    uTicket := NewRecoveryTicket(current_userid(), vCode, encode(digest(pPhone, 'sha1'), 'hex'), Now(), Now() + INTERVAL '5 min');
  END IF;

  RETURN uTicket;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegistrationCodeByEmail -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запускает процедуру регистрации пользователя по email.
 * @param {text} pEmail - Почтовый адрес.
 * @return {uuid} - Талон регистрации (registration ticket)
 */
CREATE OR REPLACE FUNCTION RegistrationCodeByEmail (
  pEmail            text
) RETURNS           uuid
AS $$
DECLARE
  uTicket           uuid;

  vSMTP             text;
  vDomain           text;
  vProject          text;
  vHost             text;
  vNoReply          text;
  vSupport          text;
  vSubject          text;
  vText             text;
  vHTML             text;
  vBody             text;
  vDescription      text;
  vSecurityAnswer   text;

  vMessage          text;
  vContext          text;

  ErrorCode         int;
  ErrorMessage      text;
BEGIN
  vProject := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Name');
  vSMTP := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'SMTP');
  vDomain := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Domain');

  vHost := current_scope_code();
  IF vHost = current_database()::text THEN
    vHost := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Host');
  END IF;

  vNoReply := format('noreply@%s', coalesce(vSMTP, vDomain));
  vSupport := format('support@%s', coalesce(vSMTP, vDomain));

  IF locale_code() = 'ru' THEN
    vSubject := 'Код верификации.';
    vDescription := 'Код верификации через email: ' || pEmail;
  ELSE
    vSubject := 'Verification code.';
    vDescription := 'Verification code via email: ' || pEmail;
  END IF;

  vSecurityAnswer := random_between(100000, 999999)::text;

  uTicket := NewRecoveryTicket(current_userid(), vSecurityAnswer, encode(digest(pEmail, 'sha1'), 'hex'), Now(), Now() + INTERVAL '30 min');

  vText := GetVerificationEmailText(pEmail, pEmail, vSecurityAnswer, vProject, vHost, vSupport);
  vHTML := GetVerificationEmailHTML(pEmail, pEmail, vSecurityAnswer, vProject, vHost, vSupport);

  vBody := CreateMailBody(vProject, vNoReply, pEmail, pEmail, vSubject, vText, vHTML);

  PERFORM SendMail(null, vNoReply, pEmail, vSubject, vBody, null, vDescription);
  PERFORM CreateNotice(current_userid(), null, vDescription);

  PERFORM WriteToEventLog('M', 1001, 'email', vDescription);

  RETURN uTicket;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN null;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
