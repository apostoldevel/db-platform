--------------------------------------------------------------------------------
-- db.document -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.document (
    id			    numeric(12) PRIMARY KEY,
    object		    numeric(12) NOT NULL,
    essence		    numeric(12) NOT NULL,
    class           numeric(12) NOT NULL,
    area		    numeric(12) NOT NULL,
    description		text,
    CONSTRAINT fk_document_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_document_essence FOREIGN KEY (essence) REFERENCES db.essence(id),
    CONSTRAINT fk_document_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_document_area FOREIGN KEY (area) REFERENCES db.area(id)
);

COMMENT ON TABLE db.document IS 'Документ.';

COMMENT ON COLUMN db.document.id IS 'Идентификатор';
COMMENT ON COLUMN db.document.object IS 'Объект';
COMMENT ON COLUMN db.document.essence IS 'Сущность';
COMMENT ON COLUMN db.document.class IS 'Класс';
COMMENT ON COLUMN db.document.area IS 'Зона';
COMMENT ON COLUMN db.document.description IS 'Описание';

CREATE INDEX ON db.document (object);
CREATE INDEX ON db.document (essence);
CREATE INDEX ON db.document (class);
CREATE INDEX ON db.document (area);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_document_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEW.object INTO NEW.id;
  END IF;

  IF current_area_type() = GetAreaType('root') THEN
    PERFORM RootAreaError();
  END IF;

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
  IF OLD.area <> NEW.area THEN
    SELECT ChangeAreaError();
  END IF;

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
  pParent	    numeric,
  pType		    numeric,
  pLabel	    text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS 	    numeric
AS $$
DECLARE
  nObject	    numeric;
  nEssence      numeric;
  nClass        numeric;
BEGIN
  nObject := CreateObject(pParent, pType, pLabel);

  nEssence := GetObjectEssence(nObject);
  nClass := GetObjectClass(nObject);

  INSERT INTO db.document (id, object, essence, class, area, description)
  VALUES (nObject, nObject, nEssence, nClass, current_area(), pDescription)
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

CREATE OR REPLACE VIEW Document (Id, Object, Essence, Class, Area, Description,
  AreaCode, AreaName, AreaDescription
) AS
  WITH RECURSIVE area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE id = current_area()
     UNION ALL
    SELECT a.id, a.parent
      FROM db.area a INNER JOIN area_tree t ON a.parent = t.id
  )
  SELECT d.id, d.object, d.essence, d.class, d.area, d.description,
         a.code, a.name, a.description
    FROM db.document d INNER JOIN area_tree t ON d.area = t.id
                       INNER JOIN db.area a ON d.area = a.id;

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
  Area, AreaCode, AreaName, AreaDescription
)
AS
  WITH RECURSIVE area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE id = current_area()
     UNION ALL
    SELECT a.id, a.parent
      FROM db.area a INNER JOIN area_tree t ON a.parent = t.id
  )
  SELECT d.id, d.object, o.parent,
         d.essence, e.code, e.name,
         d.class, ct.code, ct.label,
         o.type, t.code, t.name, t.description,
         o.label, d.description,
         o.state_type, st.code, st.name,
         o.state, s.code, s.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         d.area, a.code, a.name, a.description
    FROM db.document d INNER JOIN area_tree     at ON d.area = at.id
                       INNER JOIN db.area        a ON d.area = a.id
                       INNER JOIN db.essence     e ON d.essence = e.id
                       INNER JOIN db.class_tree ct ON d.class = ct.id
                       INNER JOIN db.object      o ON d.object = o.id
                       INNER JOIN db.type        t ON o.type = t.id
                       INNER JOIN db.state_type st ON o.state_type = st.id
                       INNER JOIN db.state       s ON o.state = s.id
                       INNER JOIN db.user        w ON o.owner = w.id
                       INNER JOIN db.user        u ON o.oper = u.id;

GRANT SELECT ON ObjectDocument TO administrator;
