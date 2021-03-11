--------------------------------------------------------------------------------
-- PROJECT ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.project ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.project (
    id			    uuid PRIMARY KEY,
    reference		uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE
);

COMMENT ON TABLE db.project IS 'Проект.';

COMMENT ON COLUMN db.project.id IS 'Идентификатор.';
COMMENT ON COLUMN db.project.reference IS 'Справочник.';

CREATE INDEX ON db.project (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_project_insert()
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

CREATE TRIGGER t_project_insert
  BEFORE INSERT ON db.project
  FOR EACH ROW
  EXECUTE PROCEDURE ft_project_insert();
