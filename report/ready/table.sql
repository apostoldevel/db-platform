--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.report_ready -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.report_ready (
    id              uuid PRIMARY KEY,
    document        uuid NOT NULL REFERENCES db.document(id) ON DELETE CASCADE,
    report          uuid NOT NULL REFERENCES db.report(id) ON DELETE RESTRICT,
    form            jsonb
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.report_ready IS 'Готовый отчёт.';

COMMENT ON COLUMN db.report_ready.id IS 'Идентификатор';
COMMENT ON COLUMN db.report_ready.document IS 'Документ';
COMMENT ON COLUMN db.report_ready.form IS 'Форма';

--------------------------------------------------------------------------------

CREATE INDEX ON db.report_ready (document);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_report_ready_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_report_ready_insert
  BEFORE INSERT ON db.report_ready
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_report_ready_insert();
