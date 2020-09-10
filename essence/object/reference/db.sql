--------------------------------------------------------------------------------
-- db.reference ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.reference (
    id              numeric(12) PRIMARY KEY,
    object          numeric(12) NOT NULL,
    code            varchar(30) NOT NULL,
    name            varchar(50),
    description     text,
    CONSTRAINT fk_reference_object FOREIGN KEY (object) REFERENCES db.object(id)
);

COMMENT ON TABLE db.reference IS 'Справочник.';

COMMENT ON COLUMN db.reference.id IS 'Идентификатор';
COMMENT ON COLUMN db.reference.object IS 'Объект';
COMMENT ON COLUMN db.reference.code IS 'Код';
COMMENT ON COLUMN db.reference.name IS 'Наименование';
COMMENT ON COLUMN db.reference.description IS 'Описание';

CREATE INDEX ON db.reference (object);
CREATE INDEX ON db.reference (code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_reference_before_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.OBJECT INTO NEW.ID;
  END IF;

  IF NULLIF(NEW.CODE, '') IS NULL THEN
    NEW.CODE := encode(gen_random_bytes(12), 'hex');
  END IF;

  RAISE DEBUG 'Создан справочник Id: %', NEW.ID;

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
  IF coalesce(NEW.NAME <> OLD.NAME, true) THEN
    UPDATE db.object SET label = NEW.NAME WHERE id = NEW.ID;
  END IF;

  RAISE DEBUG 'Изменён справочник Id: %', NEW.ID;

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

create or replace function CreateReference (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         varchar,
  pDescription  text DEFAULT null
) returns       numeric
as $$
declare
  nObject       numeric;
begin
  nObject := CreateObject(pParent, pType, pName);

  insert into db.reference (object, code, name, description)
  values (nObject, pCode, pName, pDescription)
  RETURNING id into nObject;

  return nObject;
end;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReference ---------------------------------------------------------------
--------------------------------------------------------------------------------

create or replace function EditReference (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         numeric DEFAULT null,
  pCode         varchar DEFAULT null,
  pName         varchar DEFAULT null,
  pDescription  text DEFAULT null
) returns       void
as $$
declare
  cParent       numeric;
  cType         numeric;
  cName         varchar;
begin
  select parent, type, label into cParent, cType, cName from db.object where id = pId;

  pParent := coalesce(pParent, cParent, 0);
  pType := coalesce(pType, cType);
  pName := coalesce(pName, cName);

  if pParent <> coalesce(cParent, 0) then
    update db.object set parent = CheckNull(pParent) where id = pId;
  end if;

  if pType <> cType then
    update db.object set type = pType where id = pId;
  end if;

  update db.reference
     set code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = CheckNull(coalesce(pDescription, description, '<null>'))
   where id = pId;
end;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReference -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReference (
  pCode                varchar
) RETURNS         numeric
AS $$
DECLARE
  nId                numeric;
BEGIN
  SELECT id INTO nId FROM db.reference WHERE code = pCode;
  RETURN nId;
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
