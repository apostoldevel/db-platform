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

COMMENT ON TABLE db.report_routine IS 'Функция создания отчёта.';

COMMENT ON COLUMN db.report_routine.id IS 'Идентификатор.';
COMMENT ON COLUMN db.report_routine.reference IS 'Справочник.';
COMMENT ON COLUMN db.report_routine.report IS 'Отчёт.';
COMMENT ON COLUMN db.report_routine.definition IS 'Функция создания отчета.';
COMMENT ON COLUMN db.report_routine.sequence IS 'Очерёдность.';

CREATE UNIQUE INDEX ON db.report_routine (report, definition);

CREATE INDEX ON db.report_routine (reference);
CREATE INDEX ON db.report_routine (report);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_report_routine_insert()
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
  EXECUTE PROCEDURE ft_report_routine_insert();
