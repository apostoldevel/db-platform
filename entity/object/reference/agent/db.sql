--------------------------------------------------------------------------------
-- AGENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.agent --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.agent (
    id          numeric(12) PRIMARY KEY,
    reference   numeric(12) NOT NULL,
    vendor      numeric(12) NOT NULL,
    CONSTRAINT fk_agent_reference FOREIGN KEY (reference) REFERENCES db.reference(id)
);

COMMENT ON TABLE db.agent IS 'Агент.';

COMMENT ON COLUMN db.agent.id IS 'Идентификатор.';
COMMENT ON COLUMN db.agent.reference IS 'Справочник.';
COMMENT ON COLUMN db.agent.vendor IS 'Производитель (поставщик).';

CREATE INDEX ON db.agent (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_agent_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEW.reference INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_agent_insert
  BEFORE INSERT ON db.agent
  FOR EACH ROW
  EXECUTE PROCEDURE ft_agent_insert();

--------------------------------------------------------------------------------
-- CreateAgent -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт агента
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pVendor - Производитель
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION CreateAgent (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         varchar,
  pVendor       numeric,
  pDescription	text default null
) RETURNS       numeric
AS $$
DECLARE
  nReference	numeric;
  nClass        numeric;
  nMethod       numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'agent' THEN
    PERFORM IncorrectClassType();
  END IF;

  nReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.agent (id, reference, vendor)
  VALUES (nReference, nReference, pVendor);

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  RETURN nReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditAgent -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует агента
 * @param {numeric} pId - Идентификатор
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pVendor - Производитель
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditAgent (
  pId           numeric,
  pParent       numeric default null,
  pType         numeric default null,
  pCode         varchar default null,
  pName         varchar default null,
  pVendor       numeric default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nClass        numeric;
  nMethod       numeric;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription);

  UPDATE db.agent
     SET vendor = coalesce(pVendor, vendor)
   WHERE id = pId;

  SELECT class INTO nClass FROM db.object WHERE id = pId;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAgent -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAgent (
  pCode		varchar
) RETURNS 	numeric
AS $$
BEGIN
  IF StrPos(pCode, '.') = 0 THEN
    pCode := pCode || '.agent';
  END IF;

  RETURN GetReference(pCode, 'agent');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAgentVendor -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAgentVendor (
  pId       numeric
) RETURNS 	numeric
AS $$
  SELECT vendor FROM db.agent WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Agent -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Agent (Id, Reference, Code, Name, Description,
    Vendor, VendorCode, VendorName, VendorDescription
)
AS
  SELECT a.id, a.reference, mr.code, mr.name, mr.description, a.vendor,
         vr.code, vr.name, vr.description
    FROM db.agent a INNER JOIN db.reference mr ON a.reference = mr.id
                    INNER JOIN db.reference vr ON a.vendor = vr.id;

GRANT SELECT ON Agent TO administrator;

--------------------------------------------------------------------------------
-- AccessAgent -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessAgent
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('agent'), current_userid())
  )
  SELECT a.* FROM Agent a INNER JOIN access ac ON a.id = ac.object;

GRANT SELECT ON AccessAgent TO administrator;

--------------------------------------------------------------------------------
-- ObjectAgent -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectAgent (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  Vendor, VendorCode, VendorName, VendorDescription,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT a.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         a.vendor, a.vendorcode, a.vendorname, a.vendordescription,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessAgent a INNER JOIN Reference r ON a.reference = r.id
                       INNER JOIN Object    o ON a.reference = o.id;

GRANT SELECT ON ObjectAgent TO administrator;
