--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.report_form --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.report_form (
    id			uuid PRIMARY KEY,
    reference	uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    definition	text
);

COMMENT ON TABLE db.report_form IS 'Форма.';

COMMENT ON COLUMN db.report_form.id IS 'Идентификатор.';
COMMENT ON COLUMN db.report_form.reference IS 'Справочник.';
COMMENT ON COLUMN db.report_form.definition IS 'Функция создания формы.';

CREATE INDEX ON db.report_form (reference);

--------------------------------------------------------------------------------

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
