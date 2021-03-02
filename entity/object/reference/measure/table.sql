--------------------------------------------------------------------------------
-- MEASURE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.measure ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.measure (
    id			    uuid PRIMARY KEY,
    reference		uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE
);

COMMENT ON TABLE db.measure IS 'Мера.';

COMMENT ON COLUMN db.measure.id IS 'Идентификатор.';
COMMENT ON COLUMN db.measure.reference IS 'Справочник.';

CREATE INDEX ON db.measure (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_measure_insert()
RETURNS trigger AS $$
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

CREATE TRIGGER t_measure_insert
  BEFORE INSERT ON db.measure
  FOR EACH ROW
  EXECUTE PROCEDURE ft_measure_insert();
