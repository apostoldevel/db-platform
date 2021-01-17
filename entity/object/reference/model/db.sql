--------------------------------------------------------------------------------
-- MODEL -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.model --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.model (
    id			    numeric(12) PRIMARY KEY,
    reference		numeric(12) NOT NULL,
    vendor          numeric(12) NOT NULL,
    CONSTRAINT fk_model_reference FOREIGN KEY (reference) REFERENCES db.reference(id)
);

COMMENT ON TABLE db.model IS 'Модель.';

COMMENT ON COLUMN db.model.id IS 'Идентификатор.';
COMMENT ON COLUMN db.model.reference IS 'Справочник.';
COMMENT ON COLUMN db.model.vendor IS 'Производитель (поставщик).';

CREATE INDEX ON db.model (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_model_insert()
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

CREATE TRIGGER t_model_insert
  BEFORE INSERT ON db.model
  FOR EACH ROW
  EXECUTE PROCEDURE ft_model_insert();

--------------------------------------------------------------------------------
-- CreateModel -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт модель
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pVendor - Производитель
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION CreateModel (
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

  IF GetEntityCode(nClass) <> 'model' THEN
    PERFORM IncorrectClassType();
  END IF;

  nReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.model (id, reference, vendor)
  VALUES (nReference, nReference, pVendor);

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  RETURN nReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditModel -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует модель
 * @param {numeric} pId - Идентификатор
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pVendor - Производитель
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditModel (
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

  UPDATE db.model
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
-- FUNCTION GetModel ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetModel (
  pCode		varchar
) RETURNS 	numeric
AS $$
BEGIN
  RETURN GetReference(pCode, 'model');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetModelVendor -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetModelVendor (
  pId       numeric
) RETURNS 	numeric
AS $$
  SELECT vendor FROM db.model WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Model -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Model (Id, Reference, Code, Name, Description,
    Vendor, VendorCode, VendorName, VendorDescription
)
AS
  SELECT m.id, m.reference, r.code, r.name, r.description, m.vendor,
         v.code, v.name, v.description
    FROM db.model m INNER JOIN db.reference r ON m.reference = r.id
                    INNER JOIN db.reference v ON m.vendor = v.id;

GRANT SELECT ON Model TO administrator;

--------------------------------------------------------------------------------
-- AccessModel -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessModel
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('model'), current_userid())
  )
  SELECT m.* FROM Model m INNER JOIN access ac ON m.id = ac.object;

GRANT SELECT ON AccessModel TO administrator;

--------------------------------------------------------------------------------
-- ObjectModel ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectModel (Id, Object, Parent,
  Event, EventCode, EventName,
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
  SELECT m.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         m.vendor, m.vendorcode, m.vendorname, m.vendordescription,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessModel m INNER JOIN Reference r ON m.reference = r.id
                       INNER JOIN Object    o ON m.reference = o.id;

GRANT SELECT ON ObjectModel TO administrator;
