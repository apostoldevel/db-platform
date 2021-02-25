CREATE TABLE db._model AS
  TABLE db.model;

DROP TABLE db.model CASCADE;

--------------------------------------------------------------------------------
-- MODEL -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.model --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.model (
    id			    uuid PRIMARY KEY,
    reference		uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    vendor          uuid NOT NULL REFERENCES db.vendor(id) ON DELETE RESTRICT,
    category		uuid REFERENCES db.category(id) ON DELETE RESTRICT
);

COMMENT ON TABLE db.model IS 'Модель.';

COMMENT ON COLUMN db.model.id IS 'Идентификатор.';
COMMENT ON COLUMN db.model.reference IS 'Справочник.';
COMMENT ON COLUMN db.model.vendor IS 'Производитель (поставщик).';
COMMENT ON COLUMN db.model.category IS 'Категория.';

CREATE INDEX ON db.model (reference);
CREATE INDEX ON db.model (vendor);
CREATE INDEX ON db.model (category);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_model_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.reference INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_model_insert
  BEFORE INSERT ON db.model
  FOR EACH ROW
  EXECUTE PROCEDURE ft_model_insert();

--------------------------------------------------------------------------------

INSERT INTO db.model SELECT * FROM db._model;

DROP TABLE db._model;