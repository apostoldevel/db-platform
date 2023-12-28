--------------------------------------------------------------------------------
-- db.locale -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.locale (
    id          uuid PRIMARY KEY,
    code        text NOT NULL,
    name        text NOT NULL,
    description text
);

COMMENT ON TABLE db.locale IS 'Локаль.';

COMMENT ON COLUMN db.locale.id IS 'Идентификатор';
COMMENT ON COLUMN db.locale.code IS 'Код ISO 639-1';
COMMENT ON COLUMN db.locale.name IS 'Наименование';
COMMENT ON COLUMN db.locale.description IS 'Описание';

CREATE UNIQUE INDEX ON db.locale(code);
