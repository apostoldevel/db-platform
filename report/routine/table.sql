--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.report_routine -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.report_routine (
    id          uuid PRIMARY KEY,
    reference   uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    report      uuid NOT NULL REFERENCES db.report(id) ON DELETE RESTRICT,
    definition  text NOT NULL,
    sequence    integer NOT NULL
);

COMMENT ON TABLE db.report_routine IS 'Report generation routine — PL/pgSQL function that produces report output data.';

COMMENT ON COLUMN db.report_routine.id IS 'Primary key (matches reference.id).';
COMMENT ON COLUMN db.report_routine.reference IS 'Parent reference entity (catalog record).';
COMMENT ON COLUMN db.report_routine.report IS 'Report this routine belongs to.';
COMMENT ON COLUMN db.report_routine.definition IS 'PL/pgSQL function name executed to generate the report.';
COMMENT ON COLUMN db.report_routine.sequence IS 'Execution order when a report has multiple routines.';

CREATE UNIQUE INDEX ON db.report_routine (report, definition);

CREATE INDEX ON db.report_routine (reference);
CREATE INDEX ON db.report_routine (report);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_report_routine_insert()
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

CREATE TRIGGER t_report_routine_insert
  BEFORE INSERT ON db.report_routine
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_report_routine_insert();
