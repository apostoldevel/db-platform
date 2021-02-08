--------------------------------------------------------------------------------
-- db.document -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.document (
    id			    numeric(12) PRIMARY KEY,
    object		    numeric(12) NOT NULL,
    entity		    numeric(12) NOT NULL,
    class           numeric(12) NOT NULL,
    area		    numeric(12) NOT NULL,
    description		text,
    CONSTRAINT fk_document_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_document_entity FOREIGN KEY (entity) REFERENCES db.entity(id),
    CONSTRAINT fk_document_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_document_area FOREIGN KEY (area) REFERENCES db.area(id)
);

COMMENT ON TABLE db.document IS 'Документ.';

COMMENT ON COLUMN db.document.id IS 'Идентификатор';
COMMENT ON COLUMN db.document.object IS 'Объект';
COMMENT ON COLUMN db.document.entity IS 'Сущность';
COMMENT ON COLUMN db.document.class IS 'Класс';
COMMENT ON COLUMN db.document.area IS 'Зона';
COMMENT ON COLUMN db.document.description IS 'Описание';

CREATE INDEX ON db.document (object);
CREATE INDEX ON db.document (entity);
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
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM ChangeAreaError();
    END IF;
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

