--------------------------------------------------------------------------------
-- db.document -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.document (
    id			numeric(12) PRIMARY KEY,
    object		numeric(12) NOT NULL,
    area		numeric(12) NOT NULL,
    description		text,
    CONSTRAINT fk_document_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_document_area FOREIGN KEY (area) REFERENCES db.area(id)
);

COMMENT ON TABLE db.document IS 'Документ.';

COMMENT ON COLUMN db.document.id IS 'Идентификатор';
COMMENT ON COLUMN db.document.object IS 'Объект';
COMMENT ON COLUMN db.document.area IS 'Зона';
COMMENT ON COLUMN db.document.description IS 'Описание';

CREATE INDEX ON db.document (object);
CREATE INDEX ON db.document (area);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_document_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.OBJECT INTO NEW.ID;
  END IF;

  IF current_area_type() = GetAreaType('root') THEN
    PERFORM RootAreaError();
  END IF;

  NEW.area := current_area();

  RAISE DEBUG 'Создан документ Id: %', NEW.ID;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_document_insert
  BEFORE INSERT ON db.document
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_document_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_document_update()
RETURNS trigger AS $$
BEGIN
  IF OLD.AREA <> NEW.AREA THEN
    SELECT ChangeAreaError();
  END IF;

  RAISE DEBUG 'Изменён документ Id: %', NEW.ID;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_document_update
  BEFORE UPDATE ON db.document
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_document_update();

--------------------------------------------------------------------------------
-- CreateDocument --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateDocument (
  pParent	numeric,
  pType		numeric,
  pLabel	text DEFAULT null,
  pDesc		text DEFAULT null
) RETURNS 	numeric
AS $$
DECLARE
  nObject	numeric;
BEGIN
  nObject := CreateObject(pParent, pType, pLabel);

  INSERT INTO db.document (object, description)
  VALUES (nObject, pDesc)
  RETURNING id INTO nObject;

  RETURN nObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditDocument ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditDocument (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         numeric DEFAULT null,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM EditObject(pId, pParent, pType, pLabel);

  UPDATE db.document
     SET description = CheckNull(coalesce(pDescription, description, '<null>'))
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Document --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Document (Id, Object, Area, Description,
  AreaCode, AreaName
) AS
  WITH RECURSIVE area_tree(id) AS (
    SELECT id FROM db.area WHERE id = current_area()
     UNION ALL
    SELECT a.id
      FROM db.area a, area_tree t
     WHERE a.parent = t.id
  )
  SELECT d.id, d.object, d.area, d.description, a.code, a.name
    FROM db.document d INNER JOIN area_tree t ON d.area = t.id
                       INNER JOIN db.area a ON a.id = d.area;

GRANT SELECT ON Document TO administrator;

--------------------------------------------------------------------------------
-- ObjectDocument --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectDocument (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName
)
AS
  SELECT d.id, d.object, o.parent,
         o.essence, o.essencecode, o.essencename,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname
    FROM Document d INNER JOIN Object o ON o.id = d.object;

GRANT SELECT ON ObjectDocument TO administrator;
