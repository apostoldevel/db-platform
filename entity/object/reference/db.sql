--------------------------------------------------------------------------------
-- db.reference ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.reference (
    id              numeric(12) PRIMARY KEY,
    object          numeric(12) NOT NULL,
    entity		    numeric(12) NOT NULL,
    class           numeric(12) NOT NULL,
    code            text NOT NULL,
    name            text,
    description     text,
    CONSTRAINT fk_reference_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_reference_entity FOREIGN KEY (entity) REFERENCES db.entity(id),
    CONSTRAINT fk_reference_class FOREIGN KEY (class) REFERENCES db.class_tree(id)
);

COMMENT ON TABLE db.reference IS 'Справочник.';

COMMENT ON COLUMN db.reference.id IS 'Идентификатор';
COMMENT ON COLUMN db.reference.object IS 'Объект';
COMMENT ON COLUMN db.reference.entity IS 'Сущность';
COMMENT ON COLUMN db.reference.class IS 'Класс';
COMMENT ON COLUMN db.reference.code IS 'Код';
COMMENT ON COLUMN db.reference.name IS 'Наименование';
COMMENT ON COLUMN db.reference.description IS 'Описание';

CREATE INDEX ON db.reference (object);
CREATE INDEX ON db.reference (entity);
CREATE INDEX ON db.reference (class);

CREATE UNIQUE INDEX ON db.reference (entity, code);

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
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nObject       numeric;
  nEntity       numeric;
  nClass        numeric;

--  vCode         varchar;
BEGIN
  nObject := CreateObject(pParent, pType, pName, pDescription);

  nEntity := GetObjectEntity(nObject);
  nClass := GetObjectClass(nObject);

--  IF StrPos(pCode, '.') = 0 THEN
--    SELECT code INTO vCode FROM db.entity WHERE Id = nEntity;
--    pCode := pCode || '.' || vCode;
--  END IF;

  INSERT INTO db.reference (id, object, entity, class, code, name, description)
  VALUES (nObject, nObject, nEntity, nClass, pCode, pName, pDescription)
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
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM EditObject(pId, pParent, pType, pName, pDescription);

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
  pCode         text,
  pEntity       numeric
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
--  vCode         varchar;
BEGIN
--  IF StrPos(pCode, '.') = 0 THEN
--    SELECT code INTO vCode FROM db.entity WHERE Id = pEntity;
--    pCode := pCode || '.' || vCode;
--  END IF;

  SELECT id INTO nId FROM db.reference WHERE entity = pEntity AND code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReference -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReference (
  pCode         text,
  pEntity       varchar DEFAULT null
) RETURNS       numeric
AS $$
BEGIN
  RETURN GetReference(pCode, GetEntity(coalesce(pEntity, SubStr(pCode, StrPos(pCode, '.') + 1))));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReferenceCode ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReferenceCode (
  pId           numeric
) RETURNS       varchar
AS $$
DECLARE
  vCode         varchar;
BEGIN
  SELECT code INTO vCode FROM db.reference WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReferenceName ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReferenceName (
  pId           numeric
) RETURNS       varchar
AS $$
DECLARE
  vName         varchar;
BEGIN
  SELECT name INTO vName FROM db.reference WHERE id = pId;
  RETURN vName;
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
  Entity, EntityCode, EntityName,
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
         r.entity, e.code, e.name,
         r.class, ct.code, ct.label,
         o.type, t.code, t.name, t.description,
         r.code, r.name, o.label, r.description,
         o.state_type, st.code, st.name,
         o.state, s.code, s.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate
    FROM db.reference r INNER JOIN db.entity     e ON r.entity = e.id
                        INNER JOIN db.class_tree ct ON r.class = ct.id
                        INNER JOIN db.object      o ON r.object = o.id
                        INNER JOIN db.type        t ON o.type = t.id
                        INNER JOIN db.state_type st ON o.state_type = st.id
                        INNER JOIN db.state       s ON o.state = s.id
                        INNER JOIN db.user        w ON o.owner = w.id
                        INNER JOIN db.user        u ON o.oper = u.id;

GRANT SELECT ON ObjectReference TO administrator;
