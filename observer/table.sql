--------------------------------------------------------------------------------
-- OBSERVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.publisher ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.publisher (
    code        text PRIMARY KEY,
    name        text NOT NULL,
    description text
);

COMMENT ON TABLE db.publisher IS 'Издатель.';

COMMENT ON COLUMN db.publisher.code IS 'Код';
COMMENT ON COLUMN db.publisher.name IS 'Наименование';
COMMENT ON COLUMN db.publisher.description IS 'Описание';

--------------------------------------------------------------------------------
-- db.listener -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.listener (
    publisher   text NOT NULL REFERENCES db.publisher(code) ON DELETE RESTRICT,
    session     varchar(40) NOT NULL REFERENCES db.session(code) ON DELETE CASCADE,
    identity    text NOT NULL,
    filter		jsonb NOT NULL,
    params		jsonb NOT NULL,
    PRIMARY KEY (publisher, session, identity)
);

COMMENT ON TABLE db.listener IS 'Слушатель.';

COMMENT ON COLUMN db.listener.publisher IS 'Издатель';
COMMENT ON COLUMN db.listener.session IS 'Сессия';
COMMENT ON COLUMN db.listener.identity IS 'Идентификатор в рамках сессии';
COMMENT ON COLUMN db.listener.filter IS 'Фильтр';
COMMENT ON COLUMN db.listener.params IS 'Параметры';
