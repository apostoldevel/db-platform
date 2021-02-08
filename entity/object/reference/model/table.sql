--------------------------------------------------------------------------------
-- MODEL -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.model --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.model (
    id			    numeric(12) PRIMARY KEY,
    reference		numeric(12) NOT NULL,
    vendor          numeric(12) NOT NULL,
    CONSTRAINT fk_model_reference FOREIGN KEY (reference) REFERENCES db.reference(id)
);

COMMENT ON TABLE db.model IS 'Модель.';

COMMENT ON COLUMN db.model.id IS 'Идентификатор.';
COMMENT ON COLUMN db.model.reference IS 'Справочник.';
COMMENT ON COLUMN db.model.vendor IS 'Производитель (поставщик).';

CREATE INDEX ON db.model (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_model_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
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
