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

COMMENT ON TABLE db.report_ready IS 'Generated report (output document) — stores a completed report result with its input parameters.';

COMMENT ON COLUMN db.report_ready.id IS 'Primary key (matches document.id).';
COMMENT ON COLUMN db.report_ready.document IS 'Parent document entity (lifecycle record).';
COMMENT ON COLUMN db.report_ready.report IS 'Source report definition that produced this output.';
COMMENT ON COLUMN db.report_ready.form IS 'Input parameters snapshot (JSON) used for this generation run.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.report_ready (document);

--------------------------------------------------------------------------------

/**
 * @brief Auto-set primary key from parent document id on new report ready rows.
 * @return {trigger}
 * @since 1.0.0
 */
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
