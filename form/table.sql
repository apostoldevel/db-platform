--------------------------------------------------------------------------------
-- FORM ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.form ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.form (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    entity      uuid NOT NULL REFERENCES db.entity(id) ON DELETE CASCADE,
    code        text NOT NULL
);

COMMENT ON TABLE db.form IS 'Форма.';

COMMENT ON COLUMN db.form.id IS 'Идентификатор.';
COMMENT ON COLUMN db.form.entity IS 'Сущность.';
COMMENT ON COLUMN db.form.code IS 'Код';

CREATE UNIQUE INDEX ON db.form (entity, code);
CREATE INDEX ON db.form (entity);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_form_insert()
RETURNS trigger AS $$
BEGIN
  IF NULLIF(NEW.code, '') IS NULL THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_form_insert
  BEFORE INSERT ON db.form
  FOR EACH ROW
  EXECUTE PROCEDURE ft_form_insert();

--------------------------------------------------------------------------------
-- db.form_text ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.form_text (
    form            uuid NOT NULL REFERENCES db.form(id) ON DELETE CASCADE,
    locale			uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    name            text,
    description     text,
    PRIMARY KEY (form, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.form_text IS 'Текст формы.';

COMMENT ON COLUMN db.form_text.form IS 'Идентификатор';
COMMENT ON COLUMN db.form_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.form_text.name IS 'Наименование';
COMMENT ON COLUMN db.form_text.description IS 'Описание';

--------------------------------------------------------------------------------

CREATE INDEX ON db.form_text (form);
CREATE INDEX ON db.form_text (locale);

CREATE INDEX ON db.form_text (name);
CREATE INDEX ON db.form_text (name text_pattern_ops);
