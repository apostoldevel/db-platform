--------------------------------------------------------------------------------
-- db.scope_alias --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.scope_alias (
    scope            uuid NOT NULL REFERENCES db.scope(id) ON DELETE CASCADE,
    code            text NOT NULL,
    PRIMARY KEY (scope, code)
);

COMMENT ON TABLE db.scope_alias IS 'Псевдоним области видимости базы данных.';

COMMENT ON COLUMN db.scope_alias.scope IS 'Идентификатор области видимости базы данных';
COMMENT ON COLUMN db.scope_alias.code IS 'Код области видимости базы данных';

CREATE INDEX ON db.scope_alias (scope);
CREATE INDEX ON db.scope_alias (code);
