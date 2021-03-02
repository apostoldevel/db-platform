--------------------------------------------------------------------------------
-- PROPERTY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.property -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.property (
    id			    uuid PRIMARY KEY,
    reference		uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE
);

COMMENT ON TABLE db.property IS 'Свойство.';

COMMENT ON COLUMN db.property.id IS 'Идентификатор.';
COMMENT ON COLUMN db.property.reference IS 'Справочник.';

CREATE INDEX ON db.property (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_property_insert()
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

CREATE TRIGGER t_property_insert
  BEFORE INSERT ON db.property
  FOR EACH ROW
  EXECUTE PROCEDURE ft_property_insert();
