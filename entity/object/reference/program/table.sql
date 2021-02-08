--------------------------------------------------------------------------------
-- PROGRAM ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.program ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.program (
    id			    numeric(12) PRIMARY KEY,
    reference		numeric(12) NOT NULL,
    body            text NOT NULL,
    CONSTRAINT fk_program_reference FOREIGN KEY (reference) REFERENCES db.reference(id)
);

COMMENT ON TABLE db.program IS 'Программа.';

COMMENT ON COLUMN db.program.id IS 'Идентификатор.';
COMMENT ON COLUMN db.program.reference IS 'Справочник.';
COMMENT ON COLUMN db.program.body IS 'Тело.';

CREATE INDEX ON db.program (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_program_insert()
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

CREATE TRIGGER t_program_insert
  BEFORE INSERT ON db.program
  FOR EACH ROW
  EXECUTE PROCEDURE ft_program_insert();

