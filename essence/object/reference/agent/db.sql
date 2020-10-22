--------------------------------------------------------------------------------
-- AGENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.agent --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.agent (
    id			    numeric(12) PRIMARY KEY,
    reference		numeric(12) NOT NULL,
    vendor          numeric(12) NOT NULL,
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
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.REFERENCE INTO NEW.ID;
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
  nReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.agent (reference, vendor)
  VALUES (nReference, pVendor);

  SELECT class INTO nClass FROM db.type WHERE id = pType;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  nMethod := GetMethod(nClass, null, GetAction('enable'));
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
 * Меняет агента
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

  SELECT class INTO nClass FROM db.type WHERE id = pType;

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
    FROM db.agent a INNER JOIN db.reference mr ON mr.id = a.reference
                    INNER JOIN db.reference vr ON vr.id = a.vendor;

GRANT SELECT ON Agent TO administrator;

--------------------------------------------------------------------------------
-- ObjectAgent -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectAgent (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
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
  SELECT a.id, r.object, r.parent,
         r.essence, r.essencecode, r.essencename,
         r.class, r.classcode, r.classlabel,
         r.type, r.typecode, r.typename, r.typedescription,
         r.code, r.name, r.label, r.description,
         a.vendor, a.vendorcode, a.vendorname, a.vendordescription,
         r.statetype, r.statetypecode, r.statetypename,
         r.state, r.statecode, r.statelabel, r.lastupdate,
         r.owner, r.ownercode, r.ownername, r.created,
         r.oper, r.opercode, r.opername, r.operdate
    FROM Agent a INNER JOIN ObjectReference r ON r.id = a.reference;

GRANT SELECT ON ObjectAgent TO administrator;
