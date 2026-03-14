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

COMMENT ON TABLE db.form_field IS 'Field within a dynamic form — defines type, label, default value, and display order.';

COMMENT ON COLUMN db.form_field.form IS 'Owning form (FK to db.form).';
COMMENT ON COLUMN db.form_field.key IS 'Unique field key within the form (parameter name).';
COMMENT ON COLUMN db.form_field.type IS 'Data type of the field (text, integer, date, etc.).';
COMMENT ON COLUMN db.form_field.label IS 'Human-readable label shown in the UI.';
COMMENT ON COLUMN db.form_field.format IS 'Display/input format hint (e.g., date mask).';
COMMENT ON COLUMN db.form_field.value IS 'Default value for this field.';
COMMENT ON COLUMN db.form_field.data IS 'Extra metadata or lookup data as JSON.';
COMMENT ON COLUMN db.form_field.mutable IS 'Whether the user can change this field at runtime.';
COMMENT ON COLUMN db.form_field.sequence IS 'Display order (lower values appear first).';

CREATE INDEX ON db.form_field (form);
CREATE INDEX ON db.form_field (form, key, sequence);
