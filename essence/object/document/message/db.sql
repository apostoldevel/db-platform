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
    code            text,
    address_from    text,
    address_to      text,
    subject         text,
    body            text,
    CONSTRAINT fk_message_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_message_agent FOREIGN KEY (agent) REFERENCES db.agent(id)
);

COMMENT ON TABLE db.message IS 'Сообщение.';

COMMENT ON COLUMN db.message.id IS 'Идентификатор';
COMMENT ON COLUMN db.message.document IS 'Документ';
COMMENT ON COLUMN db.message.agent IS 'Агент';
COMMENT ON COLUMN db.message.code IS 'Код';
COMMENT ON COLUMN db.message.address_from IS 'От';
COMMENT ON COLUMN db.message.address_to IS 'Кому';
COMMENT ON COLUMN db.message.subject IS 'Тема';
COMMENT ON COLUMN db.message.body IS 'Тело';

CREATE UNIQUE INDEX ON db.message (code);

CREATE INDEX ON db.message (document);
CREATE INDEX ON db.message (agent);
CREATE INDEX ON db.message (address_from);
CREATE INDEX ON db.message (address_to);

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

  RAISE DEBUG 'Создано сообщение Id: %', NEW.id;

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

  RAISE DEBUG 'Обнавлёно сообщение Id: %', NEW.id;

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
 * @param {text} pAddressFrom - От
 * @param {text} pAddressTo - Кому
 * @param {text} pSubject - Тема
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {(id|exception)} - Id сообщения или ошибку
 */
CREATE OR REPLACE FUNCTION CreateMessage (
  pParent       numeric,
  pType         numeric,
  pAgent        numeric,
  pAddressFrom  text,
  pAddressTo    text,
  pSubject      text,
  pBody         text,
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

  INSERT INTO db.message (id, document, agent, address_from, address_to, subject, body)
  VALUES (nDocument, nDocument, pAgent, pAddressFrom, pAddressTo, pSubject, pBody)
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
 * @param {text} pAddressFrom - От
 * @param {text} pAddressTo - Кому
 * @param {text} pSubject - Тема
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditMessage (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         numeric DEFAULT null,
  pAgent        numeric DEFAULT null,
  pAddressFrom  text DEFAULT null,
  pAddressTo    text DEFAULT null,
  pSubject      text DEFAULT null,
  pBody         text DEFAULT null,
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
  cBody         text;
  cDescription	text;
BEGIN
  SELECT parent, type, label INTO cParent, cType, cSubject FROM db.object WHERE id = pId;
  SELECT description INTO cDescription FROM db.document WHERE id = pId;
  SELECT body INTO cBody FROM db.message WHERE id = pId;

  pParent := coalesce(pParent, cParent, 0);
  pType := coalesce(pType, cType);
  pSubject := coalesce(pSubject, cSubject, '<null>');
  pBody := coalesce(pBody, cBody, '<null>');
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
         address_from = coalesce(pAddressFrom, address_from),
         address_to = coalesce(pAddressTo, address_to),
         body = CheckNull(pBody)
   WHERE id = pId;

  SELECT class INTO nClass FROM type WHERE id = pType;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SendMessage -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SendMessage (
  pId           numeric
) RETURNS       void
AS $$
BEGIN
  PERFORM ExecuteObjectAction(pId, GetAction('submit'));
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
  Code, AddressFrom, AddressTo,  Subject, Body
)
AS
  SELECT m.id, m.document,
         o.type, t.code, t.name, t.description,
         m.agent, ra.code, ra.name, ra.description,
         m.code, m.address_from, m.address_to, m.subject, m.body
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
  Code, AddressFrom, AddressTo, Subject, Body,
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
         m.code, m.addressfrom, m.addressto, m.subject, m.body,
         d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.area, d.areacode, d.areaname
    FROM Message m INNER JOIN ObjectDocument d ON d.id = m.document;

GRANT SELECT ON ObjectMessage TO administrator;
