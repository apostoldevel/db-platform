--------------------------------------------------------------------------------
-- FORM ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.form ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.form (
    id			uuid PRIMARY KEY,
    reference	uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE
);

COMMENT ON TABLE db.form IS 'Форма.';

COMMENT ON COLUMN db.form.id IS 'Идентификатор.';
COMMENT ON COLUMN db.form.reference IS 'Справочник.';

CREATE INDEX ON db.form (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_form_insert()
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

CREATE TRIGGER t_form_insert
  BEFORE INSERT ON db.form
  FOR EACH ROW
  EXECUTE PROCEDURE ft_form_insert();
