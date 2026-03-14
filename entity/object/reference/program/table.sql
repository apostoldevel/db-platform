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

COMMENT ON TABLE db.program IS 'Executable program — stores an SQL function body for scheduled jobs.';

COMMENT ON COLUMN db.program.id IS 'Primary key (same as reference.id).';
COMMENT ON COLUMN db.program.reference IS 'Parent reference catalog entry.';
COMMENT ON COLUMN db.program.body IS 'SQL/PL/pgSQL source code to execute.';

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

