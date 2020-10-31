--------------------------------------------------------------------------------
-- MESSAGE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.message ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.message (
    id              numeric(12) PRIMARY KEY,
    document        numeric(12) NOT NULL,
    agent           numeric(12) NOT NULL,
    code            varchar(30) NOT NULL,
    profile         text NOT NULL,
    address         text NOT NULL,
    subject         text,
    content         text NOT NULL,
    CONSTRAINT fk_message_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_message_agent FOREIGN KEY (agent) REFERENCES db.agent(id)
);

COMMENT ON TABLE db.message IS 'Сообщение.';

COMMENT ON COLUMN db.message.id IS 'Идентификатор';
COMMENT ON COLUMN db.message.document IS 'Документ';
COMMENT ON COLUMN db.message.agent IS 'Агент';
COMMENT ON COLUMN db.message.code IS 'Код';
COMMENT ON COLUMN db.message.profile IS 'Профиль отправителя';
COMMENT ON COLUMN db.message.address IS 'Адрес получателя';
COMMENT ON COLUMN db.message.subject IS 'Тема';
COMMENT ON COLUMN db.message.content IS 'Содержимое';

CREATE UNIQUE INDEX ON db.message (agent, code);

CREATE INDEX ON db.message (document);
CREATE INDEX ON db.message (agent);
CREATE INDEX ON db.message (profile);
CREATE INDEX ON db.message (address);

CREATE INDEX ON db.message (subject);
CREATE INDEX ON db.message (subject text_pattern_ops);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_message_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS null OR NEW.id = 0 THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS null THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_message_insert
  BEFORE INSERT ON db.message
  FOR EACH ROW
  EXECUTE PROCEDURE ft_message_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_message_update()
RETURNS trigger AS $$
BEGIN
  IF NEW.code <> OLD.code THEN
    RAISE DEBUG 'Hacking alert: message code (% <> %).', OLD.code, NEW.code;
    RETURN NULL;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_message_update
  BEFORE UPDATE ON db.message
  FOR EACH ROW
  EXECUTE PROCEDURE ft_message_update();

--------------------------------------------------------------------------------
-- CreateMessage ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт новое сообщение
 * @param {numeric} pParent - Родительский объект
 * @param {numeric} pType - Тип
 * @param {numeric} pAgent - Агент
 * @param {text} pProfile - Профиль отправителя
 * @param {text} pAddress - Адрес получателя
 * @param {text} pSubject - Тема
 * @param {text} pContent - Содержимое
 * @param {text} pDescription - Описание
 * @return {(id|exception)} - Id сообщения или ошибку
 */
CREATE OR REPLACE FUNCTION CreateMessage (
  pParent       numeric,
  pType         numeric,
  pAgent        numeric,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pDescription  text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nMessage      numeric;
  nDocument     numeric;

  vEssenceCode  varchar;

  nClass        numeric;
  nMethod       numeric;
BEGIN
  SELECT class, essencecode INTO nClass, vEssenceCode FROM type WHERE id = pType;

  IF nClass IS null OR vEssenceCode <> 'message' THEN
    PERFORM IncorrectClassType();
  END IF;

  nDocument := CreateDocument(pParent, pType, null, pDescription);

  INSERT INTO db.message (id, document, agent, profile, address, subject, content)
  VALUES (nDocument, nDocument, pAgent, pProfile, pAddress, pSubject, pContent)
  RETURNING id INTO nMessage;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nMessage, nMethod);

  return nMessage;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditMessage -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет сообщение.
 * @param {numeric} pId - Идентификатор
 * @param {numeric} pParent - Родительский объект
 * @param {numeric} pType - Тип
 * @param {numeric} pAgent - Агент
 * @param {text} pProfile - Профиль отправителя
 * @param {text} pAddress - Адрес получателя
 * @param {text} pSubject - Тема
 * @param {text} pContent - Содержимое
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditMessage (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         numeric DEFAULT null,
  pAgent        numeric DEFAULT null,
  pProfile      text DEFAULT null,
  pAddress      text DEFAULT null,
  pSubject      text DEFAULT null,
  pContent      text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS 	    void
AS $$
DECLARE
  nClass        numeric;
  nMethod       numeric;

  -- current
  cParent       numeric;
  cType         numeric;
  cSubject      text;
  cContent         text;
  cDescription	text;
BEGIN
  SELECT parent, type, label INTO cParent, cType, cSubject FROM db.object WHERE id = pId;
  SELECT description INTO cDescription FROM db.document WHERE id = pId;
  SELECT content INTO cContent FROM db.message WHERE id = pId;

  pParent := coalesce(pParent, cParent, 0);
  pType := coalesce(pType, cType);
  pSubject := coalesce(pSubject, cSubject, '<null>');
  pContent := coalesce(pContent, cContent, '<null>');
  pDescription := coalesce(pDescription, cDescription, '<null>');

  IF pParent <> coalesce(cParent, 0) THEN
    UPDATE db.object SET parent = CheckNull(pParent) WHERE id = pId;
  END IF;

  IF pType <> cType THEN
    UPDATE db.object SET type = pType WHERE id = pId;
  END IF;

  IF pDescription <> coalesce(cDescription, '<null>') THEN
    UPDATE document SET description = CheckNull(pDescription) WHERE id = pId;
  END IF;

  UPDATE db.message 
     SET agent = coalesce(pAgent, agent),
         profile = coalesce(pProfile, profile),
         address = coalesce(pAddress, address),
         content = CheckNull(pContent)
   WHERE id = pId;

  SELECT class INTO nClass FROM type WHERE id = pType;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetMessageId ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMessageId (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.message WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetMessageCode --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMessageCode (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.message WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetMessageState -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMessageState (
  pCode		varchar
) RETURNS	numeric
AS $$
BEGIN
  RETURN GetState(GetEssence('message'), pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Message ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Message (Id, Document,
  Source, SourceCode, SourceName, SourceDescription,
  Agent, AgentCode, AgentName, AgentDescription,
  Code, Profile, Address, Subject, Content
)
AS
  SELECT m.id, m.document,
         o.type, t.code, t.name, t.description,
         m.agent, ra.code, ra.name, ra.description,
         m.code, m.profile, m.address, m.subject, m.content
    FROM db.message m INNER JOIN db.reference ra ON ra.id = m.agent
                      INNER JOIN db.object o ON o.id = ra.object
                      INNER JOIN db.type t ON t.id = o.type;

GRANT SELECT ON Message TO administrator;

--------------------------------------------------------------------------------
-- ObjectMessage ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectMessage (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Agent, AgentCode, AgentName, AgentDescription,
  Code, Profile, Address, Subject, Content,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName
)
AS
  SELECT m.id, d.object, d.parent,
         d.essence, d.essencecode, d.essencename,
         d.class, d.classcode, d.classlabel,
         d.type, d.typecode, d.typename, d.typedescription,
         m.agent, m.agentcode, m.agentname, m.agentdescription,
         m.code, m.profile, m.address, m.subject, m.content,
         d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.area, d.areacode, d.areaname
    FROM Message m INNER JOIN ObjectDocument d ON d.id = m.document;

GRANT SELECT ON ObjectMessage TO administrator;

--------------------------------------------------------------------------------
-- GetEncodedTextRFC1342 -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEncodedTextRFC1342 (
  pText     text,
  pCharSet  text
) RETURNS	text
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
) RETURNS	text
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
  pTo		text,
  pSubject  text,
  pText		text,
  pHTML		text
) RETURNS	text
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
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendMessage -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendMessage (
  pParent       numeric,
  pAgent        numeric,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pDescription  text DEFAULT null,
  pType         numeric DEFAULT GetType('message.outbox')
) RETURNS	    numeric
AS $$
DECLARE
  nMessageId    numeric;
BEGIN
  nMessageId := CreateMessage(pParent, pType, pAgent, pProfile, pAddress, pSubject, pContent, pDescription);
  PERFORM ExecuteObjectAction(nMessageId, GetAction('submit'));
  RETURN nMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendMessage -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendMail (
  pParent       numeric,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pDescription  text DEFAULT null,
  pAgent        numeric DEFAULT GetAgent('smtp.agent')
) RETURNS	    numeric
AS $$
BEGIN
  RETURN SendMessage(pParent, pAgent, pProfile, pAddress, pSubject, pContent, pDescription);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendSMS ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendSMS (
  pParent       numeric,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pDescription  text DEFAULT null,
  pAgent        numeric DEFAULT GetAgent('m2m.agent')
) RETURNS	    numeric
AS $$
BEGIN
  RETURN SendMessage(pParent, pAgent, pProfile, pAddress, pSubject, pContent, pDescription);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendPush --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendPush (
  pParent       numeric,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pDescription  text DEFAULT null,
  pAgent        numeric DEFAULT GetAgent('fcm.agent')
) RETURNS	    numeric
AS $$
BEGIN
  RETURN SendMessage(pParent, pAgent, pProfile, pAddress, pSubject, pContent, pDescription);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendShortMessage ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendShortMessage (
  pParent       numeric,
  pProfile      text,
  pMessage      text,
  pUserId       numeric DEFAULT current_userid()
) RETURNS	    numeric
AS $$
DECLARE
  nMessageId    numeric;

  vCharSet      text;
  vPhone        text;
  vContent      text;

  message       xml;
BEGIN
  vCharSet := coalesce(nullif(pg_client_encoding(), 'UTF8'), 'utf-8');

  SELECT phone INTO vPhone FROM db.user WHERE id = pUserId;

  IF vPhone IS NOT NULL THEN
    message := xmlelement(name "soap12:Envelope", xmlattributes('http://www.w3.org/2001/XMLSchema-instance' AS "xmlns:xsi", 'http://www.w3.org/2001/XMLSchema' AS "xmlns:xsd", 'http://www.w3.org/2003/05/soap-envelope' AS "xmlns:soap12"), xmlelement(name "soap12:Body", xmlelement(name "SendMessage", xmlattributes('http://mcommunicator.ru/M2M' AS xmlns), xmlelement(name "msid", vPhone), xmlelement(name "message", pMessage), xmlelement(name "naming", pProfile))));
    vContent := format('<?xml version="1.0" encoding="%s"?>', vCharSet) || xmlserialize(DOCUMENT message AS text);
    nMessageId := SendSMS(pParent, pProfile, vPhone, 'SendMessage', vContent, pMessage);
    PERFORM WriteToEventLog('M', 1111, format('SMS передано на отправку: %s', nMessageId), nMessageId);
  ELSE
    PERFORM WriteToEventLog('E', 3111, 'Не удалось отправить SMS, телефон не установлен.', pParent);
  END IF;

  RETURN nMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendPushMessage -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendPushMessage (
  pParent       numeric,
  pTitle        text,
  pBody         text,
  pUserId       numeric DEFAULT current_userid()
) RETURNS	    numeric
AS $$
DECLARE
  nMessageId    numeric;

  vProfile      text;
  token         text;

  message       jsonb;
  data          jsonb;
BEGIN
  vProfile := (RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\Firebase'), 'ProjectId')).vstring;
  token := (RegGetValue(RegOpenKey('CURRENT_USER', 'CONFIG\Firebase\CloudMessaging', pUserId), 'Token')).vstring;

  IF token IS NOT NULL THEN
    data := jsonb_build_object('title', pTitle, 'body', pBody);
    message := jsonb_build_object('message', jsonb_build_object('token', token, 'data', data));

    nMessageId := SendPush(pParent, vProfile, GetUserName(pUserId), pTitle, message::text, pBody);
    PERFORM WriteToEventLog('M', 1112, format('Push сообщение передано на отправку: %s', nMessageId), nMessageId);
  ELSE
    PERFORM WriteToEventLog('E', 3112, 'Не удалось отправить Push сообщение, тоекн не установлен.', pParent);
  END IF;

  RETURN nMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
