--------------------------------------------------------------------------------
-- OAUTH 2.0 -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- oauth2.provider -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.provider (
    id          serial PRIMARY KEY,
    type        char NOT NULL,
    code        text NOT NULL,
    name        text,
    CHECK (type IN ('I', 'E'))
);

COMMENT ON TABLE oauth2.provider IS 'Поставщик.';

COMMENT ON COLUMN oauth2.provider.id IS 'Идентификатор';
COMMENT ON COLUMN oauth2.provider.type IS 'Тип: "I" - внутренний; "E" - внешний';
COMMENT ON COLUMN oauth2.provider.code IS 'Код';
COMMENT ON COLUMN oauth2.provider.name IS 'Наименование';

CREATE UNIQUE INDEX ON oauth2.provider (type, code);

CREATE INDEX ON oauth2.provider (type);
CREATE INDEX ON oauth2.provider (code);
CREATE INDEX ON oauth2.provider (code text_pattern_ops);

--------------------------------------------------------------------------------
-- oauth2.application ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.application (
    id          serial PRIMARY KEY,
    type        char NOT NULL,
    code        text NOT NULL,
    name        text,
    CHECK (type IN ('S', 'W', 'N'))
);

COMMENT ON TABLE oauth2.application IS 'Приложение.';

COMMENT ON COLUMN oauth2.application.id IS 'Идентификатор';
COMMENT ON COLUMN oauth2.application.type IS 'Тип: "S" - Сервис; "W" - Веб; "N" - Нативное';
COMMENT ON COLUMN oauth2.application.code IS 'Код';
COMMENT ON COLUMN oauth2.application.name IS 'Наименование';

CREATE UNIQUE INDEX ON oauth2.application (type, code);

CREATE INDEX ON oauth2.application (type);
CREATE INDEX ON oauth2.application (code);
CREATE INDEX ON oauth2.application (code text_pattern_ops);

--------------------------------------------------------------------------------
-- oauth2.issuer ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.issuer (
    id          serial PRIMARY KEY,
    provider    integer NOT NULL REFERENCES oauth2.provider,
    code        text NOT NULL,
    name        text
);

COMMENT ON TABLE oauth2.issuer IS 'Издатель.';

COMMENT ON COLUMN oauth2.issuer.id IS 'Идентификатор';
COMMENT ON COLUMN oauth2.issuer.provider IS 'Поставщик';
COMMENT ON COLUMN oauth2.issuer.code IS 'Код';
COMMENT ON COLUMN oauth2.issuer.name IS 'Наименование';

CREATE UNIQUE INDEX ON oauth2.issuer (provider, code);

CREATE INDEX ON oauth2.issuer (provider);
CREATE INDEX ON oauth2.issuer (code);
CREATE INDEX ON oauth2.issuer (code text_pattern_ops);

--------------------------------------------------------------------------------
-- oauth2.algorithm ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.algorithm (
    id          serial PRIMARY KEY,
    code        text NOT NULL,
    name        text
);

COMMENT ON TABLE oauth2.algorithm IS 'Алгоритмы хеширования.';

COMMENT ON COLUMN oauth2.algorithm.id IS 'Идентификатор';
COMMENT ON COLUMN oauth2.algorithm.code IS 'Код';
COMMENT ON COLUMN oauth2.algorithm.name IS 'Наименование (как в pgcrypto)';

CREATE INDEX ON oauth2.algorithm (code);

--------------------------------------------------------------------------------
-- oauth2.audience -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.audience (
    id          serial PRIMARY KEY,
    provider    integer NOT NULL REFERENCES oauth2.provider,
    application integer NOT NULL REFERENCES oauth2.application,
    algorithm   integer NOT NULL,
    code        text NOT NULL,
    secret      text NOT NULL,
    hash        text NOT NULL,
    name        text
);

COMMENT ON TABLE oauth2.audience IS 'Аудитория (Клиенты OAuth 2.0).';

COMMENT ON COLUMN oauth2.audience.id IS 'Идентификатор';
COMMENT ON COLUMN oauth2.audience.provider IS 'Поставщик';
COMMENT ON COLUMN oauth2.audience.application IS 'Приложение';
COMMENT ON COLUMN oauth2.audience.algorithm IS 'Алгоритм хеширования';
COMMENT ON COLUMN oauth2.audience.code IS 'Код';
COMMENT ON COLUMN oauth2.audience.secret IS 'Секрет';
COMMENT ON COLUMN oauth2.audience.hash IS 'Секрет (хеш)';
COMMENT ON COLUMN oauth2.audience.name IS 'Наименование';

CREATE UNIQUE INDEX ON oauth2.audience (provider, code);

CREATE INDEX ON oauth2.audience (provider);
CREATE INDEX ON oauth2.audience (code);
CREATE INDEX ON oauth2.audience (code text_pattern_ops);
