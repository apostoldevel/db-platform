--------------------------------------------------------------------------------
-- db.report -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.report (
    id                  uuid PRIMARY KEY,
    reference           uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    tree                uuid NOT NULL REFERENCES db.report_tree(id),
    form                uuid REFERENCES db.report_form(id),
    binding             uuid REFERENCES db.class_tree(id),
    info                jsonb
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.report IS 'Report definition — links a reference entity to a tree node, input form, and optional class binding.';

COMMENT ON COLUMN db.report.id IS 'Primary key (matches reference.id).';
COMMENT ON COLUMN db.report.reference IS 'Parent reference entity (catalog record).';
COMMENT ON COLUMN db.report.tree IS 'Report tree node this report belongs to.';
COMMENT ON COLUMN db.report.form IS 'Input form used to collect report parameters (NULL = no parameters).';
COMMENT ON COLUMN db.report.binding IS 'Class tree binding for object-scoped reports (NULL = global report).';
COMMENT ON COLUMN db.report.info IS 'Arbitrary extra metadata (JSON).';

--------------------------------------------------------------------------------

CREATE INDEX ON db.report (reference);
CREATE INDEX ON db.report (tree);
CREATE INDEX ON db.report (form);
CREATE INDEX ON db.report (binding);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_report_before_insert()
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

CREATE TRIGGER t_report_before_insert
  BEFORE INSERT ON db.report
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_report_before_insert();
