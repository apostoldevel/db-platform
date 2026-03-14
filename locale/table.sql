--------------------------------------------------------------------------------
-- db.locale -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.locale (
    id          uuid PRIMARY KEY,
    code        text NOT NULL,
    name        text NOT NULL,
    description text
);

COMMENT ON TABLE db.locale IS 'Supported UI/content locales (ISO 639-1). One row per language.';

COMMENT ON COLUMN db.locale.id IS 'Primary key (UUID).';
COMMENT ON COLUMN db.locale.code IS 'ISO 639-1 two-letter language code (unique).';
COMMENT ON COLUMN db.locale.name IS 'Human-readable locale name.';
COMMENT ON COLUMN db.locale.description IS 'Optional extended description of the locale.';

CREATE UNIQUE INDEX ON db.locale(code);
