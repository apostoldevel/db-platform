--------------------------------------------------------------------------------
-- FORM ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.form_field ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.form_field (
    form            uuid NOT NULL REFERENCES db.form(id) ON DELETE CASCADE,
    key             text NOT NULL,
    type            text NOT NULL,
    label           text NOT NULL,
    format          text,
    value           text,
    data            jsonb,
    mutable         boolean NOT NULL DEFAULT false,
    sequence        integer NOT NULL DEFAULT 0,
    PRIMARY KEY (form, key)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.form_field IS 'Поля формы журнала.';

COMMENT ON COLUMN db.form_field.form IS 'Форма.';
COMMENT ON COLUMN db.form_field.key IS 'Ключ.';
COMMENT ON COLUMN db.form_field.type IS 'Тип.';
COMMENT ON COLUMN db.form_field.label IS 'Метка.';
COMMENT ON COLUMN db.form_field.format IS 'Формат.';
COMMENT ON COLUMN db.form_field.value IS 'Значение.';
COMMENT ON COLUMN db.form_field.data IS 'Данные.';
COMMENT ON COLUMN db.form_field.mutable IS 'Изменчивый.';
COMMENT ON COLUMN db.form_field.sequence IS 'Очерёдность.';

CREATE INDEX ON db.form_field (form);
CREATE INDEX ON db.form_field (form, key, sequence);
