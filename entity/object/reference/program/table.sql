--------------------------------------------------------------------------------
-- PROGRAM ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.program ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.program (
    id              uuid PRIMARY KEY,
    reference       uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    body            text NOT NULL
);

COMMENT ON TABLE db.program IS 'Программа.';

COMMENT ON COLUMN db.program.id IS 'Идентификатор.';
COMMENT ON COLUMN db.program.reference IS 'Справочник.';
COMMENT ON COLUMN db.program.body IS 'Тело.';

CREATE INDEX ON db.program (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_program_insert()
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

CREATE TRIGGER t_program_insert
  BEFORE INSERT ON db.program
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_program_insert();

