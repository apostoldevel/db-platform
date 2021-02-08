--------------------------------------------------------------------------------
-- db.locale -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.locale (
    id		    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code	    text NOT NULL,
    name	    text NOT NULL,
    description	text
);

COMMENT ON TABLE db.locale IS 'Локаль.';

COMMENT ON COLUMN db.locale.id IS 'Идентификатор';
COMMENT ON COLUMN db.locale.code IS 'Код';
COMMENT ON COLUMN db.locale.name IS 'Наименование';
COMMENT ON COLUMN db.locale.description IS 'Описание';

CREATE UNIQUE INDEX ON db.locale(code);

--------------------------------------------------------------------------------

INSERT INTO db.locale (code, name, description) VALUES ('ru', 'Русский', 'Русский язык');
INSERT INTO db.locale (code, name, description) VALUES ('en', 'English', 'English');
