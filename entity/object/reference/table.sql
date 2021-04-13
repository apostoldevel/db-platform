--------------------------------------------------------------------------------
-- db.reference ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.reference (
    id              uuid PRIMARY KEY,
    object          uuid NOT NULL REFERENCES db.object(id),
    scope			uuid NOT NULL REFERENCES db.scope(id),
    entity		    uuid NOT NULL REFERENCES db.entity(id),
    class           uuid NOT NULL REFERENCES db.class_tree(id),
    type			uuid NOT NULL REFERENCES db.type(id),
    code            text NOT NULL
);

COMMENT ON TABLE db.reference IS 'Справочник.';

COMMENT ON COLUMN db.reference.id IS 'Идентификатор';
COMMENT ON COLUMN db.reference.object IS 'Объект';
COMMENT ON COLUMN db.reference.scope IS 'Область видимости';
COMMENT ON COLUMN db.reference.entity IS 'Сущность';
COMMENT ON COLUMN db.reference.class IS 'Класс';
COMMENT ON COLUMN db.reference.type IS 'Тип';
COMMENT ON COLUMN db.reference.code IS 'Код';

CREATE INDEX ON db.reference (object);
CREATE INDEX ON db.reference (scope);
CREATE INDEX ON db.reference (entity);
CREATE INDEX ON db.reference (class);
CREATE INDEX ON db.reference (type);

CREATE UNIQUE INDEX ON db.reference (scope, entity, code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_reference_before_insert()
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

  IF NEW.scope IS NULL THEN
    SELECT current_scope() INTO NEW.scope;
  END IF;

  IF NULLIF(NEW.code, '') IS NULL THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_reference_before_insert
  BEFORE INSERT ON db.reference
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_reference_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_reference_before_update_type()
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

CREATE TRIGGER t_reference_before_update_type
  BEFORE UPDATE ON db.reference
  FOR EACH ROW
  WHEN (OLD.type IS DISTINCT FROM NEW.type)
  EXECUTE PROCEDURE db.ft_reference_before_update_type();

--------------------------------------------------------------------------------
-- db.reference_text -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.reference_text (
    reference		uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    locale			uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    name            text,
    description     text,
    PRIMARY KEY (reference, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.reference_text IS 'Текст справочника.';

COMMENT ON COLUMN db.reference_text.reference IS 'Идентификатор';
COMMENT ON COLUMN db.reference_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.reference_text.name IS 'Наименование';
COMMENT ON COLUMN db.reference_text.description IS 'Описание';

--------------------------------------------------------------------------------

CREATE INDEX ON db.reference_text (reference);
CREATE INDEX ON db.reference_text (locale);

CREATE INDEX ON db.reference_text (name);
CREATE INDEX ON db.reference_text (name text_pattern_ops);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_reference_text_update_name()
RETURNS trigger AS $$
BEGIN
  UPDATE db.object_text SET label = NEW.name WHERE object = NEW.reference AND locale = NEW.locale;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_reference_text_update_name
  AFTER UPDATE ON db.reference_text
  FOR EACH ROW
  WHEN (OLD.name IS DISTINCT FROM NEW.name)
  EXECUTE PROCEDURE db.ft_reference_text_update_name();
