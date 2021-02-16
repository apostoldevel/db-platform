--------------------------------------------------------------------------------
-- VERSION ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.version ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.version (
    id			    uuid PRIMARY KEY,
    reference		uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE
);

COMMENT ON TABLE db.version IS 'Версия.';

COMMENT ON COLUMN db.version.id IS 'Идентификатор.';
COMMENT ON COLUMN db.version.reference IS 'Справочник.';

CREATE INDEX ON db.version (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_version_insert()
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

CREATE TRIGGER t_version_insert
  BEFORE INSERT ON db.version
  FOR EACH ROW
  EXECUTE PROCEDURE ft_version_insert();
