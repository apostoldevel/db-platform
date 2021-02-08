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

--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------

CREATE TRIGGER t_reference_update
  BEFORE UPDATE ON db.reference
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_reference_update();
