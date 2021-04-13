--------------------------------------------------------------------------------
-- db.document -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.document (
    id			    uuid PRIMARY KEY,
    object		    uuid NOT NULL REFERENCES db.object(id),
    entity		    uuid NOT NULL REFERENCES db.entity(id),
    class           uuid NOT NULL REFERENCES db.class_tree(id),
    type			uuid NOT NULL REFERENCES db.type(id),
    area		    uuid NOT NULL REFERENCES db.area(id)
);

COMMENT ON TABLE db.document IS 'Документ.';

COMMENT ON COLUMN db.document.id IS 'Идентификатор';
COMMENT ON COLUMN db.document.object IS 'Объект';
COMMENT ON COLUMN db.document.entity IS 'Сущность';
COMMENT ON COLUMN db.document.class IS 'Класс';
COMMENT ON COLUMN db.document.type IS 'Тип';
COMMENT ON COLUMN db.document.area IS 'Зона';

CREATE INDEX ON db.document (object);
CREATE INDEX ON db.document (entity);
CREATE INDEX ON db.document (class);
CREATE INDEX ON db.document (type);
CREATE INDEX ON db.document (area);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_document_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.object INTO NEW.id;
  END IF;

  IF current_area_type() = GetAreaType('root') THEN
    PERFORM RootAreaError();
  END IF;

  IF current_area_type() = GetAreaType('guest') THEN
    PERFORM GuestAreaError();
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

CREATE OR REPLACE FUNCTION db.ft_document_before_update_type()
RETURNS trigger AS $$
BEGIN
  SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
  SELECT entity INTO NEW.entity FROM db.class_tree WHERE id = NEW.class;

  IF OLD.entity <> NEW.entity THEN
	PERFORM IncorrectEntity();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_document_before_update_type
  BEFORE UPDATE ON db.document
  FOR EACH ROW
  WHEN (OLD.type IS DISTINCT FROM NEW.type)
  EXECUTE PROCEDURE db.ft_document_before_update_type();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_document_update_area()
RETURNS trigger AS $$
BEGIN
  IF session_user <> 'kernel' THEN
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

CREATE TRIGGER t_document_update_area
  BEFORE UPDATE ON db.document
  FOR EACH ROW
  WHEN (OLD.area IS DISTINCT FROM NEW.area)
  EXECUTE PROCEDURE db.ft_document_update_area();

--------------------------------------------------------------------------------
-- db.document_text ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.document_text (
    document		uuid NOT NULL REFERENCES db.document(id) ON DELETE CASCADE,
    locale			uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    description     text,
    PRIMARY KEY (document, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.document_text IS 'Текст документа.';

COMMENT ON COLUMN db.document_text.document IS 'Идентификатор';
COMMENT ON COLUMN db.document_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.document_text.description IS 'Описание';

--------------------------------------------------------------------------------

CREATE INDEX ON db.document_text (document);
CREATE INDEX ON db.document_text (locale);

CREATE INDEX ON db.document_text (description);
CREATE INDEX ON db.document_text (description text_pattern_ops);
