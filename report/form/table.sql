--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.report_form --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.report_form (
    id           uuid PRIMARY KEY,
    reference    uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    definition   text
);

COMMENT ON TABLE db.report_form IS 'Report input form — defines a PL/pgSQL function that builds the parameter form for a report.';

COMMENT ON COLUMN db.report_form.id IS 'Primary key (matches reference.id).';
COMMENT ON COLUMN db.report_form.reference IS 'Parent reference entity (catalog record).';
COMMENT ON COLUMN db.report_form.definition IS 'PL/pgSQL function name that generates the form JSON.';

CREATE INDEX ON db.report_form (reference);

--------------------------------------------------------------------------------

/**
 * @brief Auto-set primary key from parent reference id on new report form rows.
 * @return {trigger}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_report_form_insert()
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

CREATE TRIGGER t_report_form_insert
  BEFORE INSERT ON db.report_form
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_report_form_insert();
