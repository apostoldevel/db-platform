--------------------------------------------------------------------------------
-- db.report -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.report (
    id                  uuid PRIMARY KEY,
    reference           uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    tree				uuid NOT NULL REFERENCES db.report_tree(id),
    form				uuid REFERENCES db.report_form(id),
    info                jsonb
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.report IS 'Отчёт.';

COMMENT ON COLUMN db.report.id IS 'Идентификатор.';
COMMENT ON COLUMN db.report.reference IS 'Документ.';
COMMENT ON COLUMN db.report.tree IS 'Ссылка на дерево отчётов.';
COMMENT ON COLUMN db.report.form IS 'Ссылка на форму отчёта.';
COMMENT ON COLUMN db.report.info IS 'Дополнительная информация.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.report (reference);
CREATE INDEX ON db.report (tree);
CREATE INDEX ON db.report (form);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_report_before_insert()
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
  EXECUTE PROCEDURE ft_report_before_insert();
