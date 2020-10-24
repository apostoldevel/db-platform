--------------------------------------------------------------------------------
-- db.reference ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.reference (
    id              numeric(12) PRIMARY KEY,
    object          numeric(12) NOT NULL,
    essence		    numeric(12) NOT NULL,
    class           numeric(12) NOT NULL,
    code            varchar(30) NOT NULL,
    name            text,
    description     text,
    CONSTRAINT fk_reference_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_reference_essence FOREIGN KEY (essence) REFERENCES db.essence(id),
    CONSTRAINT fk_reference_class FOREIGN KEY (class) REFERENCES db.class_tree(id)
);

COMMENT ON TABLE db.reference IS 'Справочник.';

COMMENT ON COLUMN db.reference.id IS 'Идентификатор';
COMMENT ON COLUMN db.reference.object IS 'Объект';
COMMENT ON COLUMN db.reference.essence IS 'Сущность';
COMMENT ON COLUMN db.reference.class IS 'Класс';
COMMENT ON COLUMN db.reference.code IS 'Код';
COMMENT ON COLUMN db.reference.name IS 'Наименование';
COMMENT ON COLUMN db.reference.description IS 'Описание';

CREATE INDEX ON db.reference (object);
CREATE INDEX ON db.reference (essence);
CREATE INDEX ON db.reference (class);

CREATE UNIQUE INDEX ON db.reference (essence, code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_reference_before_insert()
RETURNS trigger AS $$
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEW.object INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS NULL THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_reference_before_insert
  BEFORE INSERT ON db.reference
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_reference_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_reference_update()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF coalesce(NEW.name <> OLD.name, true) THEN
    UPDATE db.object SET label = NEW.name WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_reference_update
  BEFORE UPDATE ON db.reference
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_reference_update();

--------------------------------------------------------------------------------
-- CreateReference -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateReference (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nObject       numeric;
  nEssence      numeric;
  nClass        numeric;
BEGIN
  nObject := CreateObject(pParent, pType, pName);

  nEssence := GetObjectEssence(nObject);
  nClass := GetObjectClass(nObject);

  INSERT INTO db.reference (id, object, essence, class, code, name, description)
  VALUES (nObject, nObject, nEssence, nClass, pCode, pName, pDescription)
  RETURNING id INTO nObject;

  RETURN nObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReference ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditReference (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         numeric DEFAULT null,
  pCode         varchar DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  cParent       numeric;
  cType         numeric;
  cName         varchar;
BEGIN
  SELECT parent, type, label INTO cParent, cType, cName FROM db.object WHERE id = pId;

  pParent := coalesce(pParent, cParent, 0);
  pType := coalesce(pType, cType);
  pName := coalesce(pName, cName);

  IF pParent <> coalesce(cParent, 0) THEN
    UPDATE db.object SET parent = CheckNull(pParent) WHERE id = pId;
  END IF;

  IF pType <> cType THEN
    UPDATE db.object SET type = pType WHERE id = pId;
  END IF;

  UPDATE db.reference
     SET code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = CheckNull(coalesce(pDescription, description, '<null>'))
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReference -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReference (
  pCode         varchar,
  pEssence      numeric
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
BEGIN
  SELECT id INTO nId FROM db.reference WHERE essence = pEssence AND code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReference -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReference (
  pCode         varchar,
  pEssence      varchar DEFAULT null
) RETURNS       numeric
AS $$
BEGIN
  RETURN GetReference(pCode, GetEssence(coalesce(pEssence, SubStr(pCode, StrPos(pCode, '.') + 1))));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Reference -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Reference
AS
  SELECT * FROM db.reference;

GRANT SELECT ON Reference TO administrator;

--------------------------------------------------------------------------------
-- ObjectReference -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReference (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT r.id, r.object, o.parent,
         o.essence, o.essencecode, o.essencename,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM Reference r INNER JOIN Object o ON o.id = r.object;

GRANT SELECT ON ObjectReference TO administrator;
