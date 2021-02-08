--------------------------------------------------------------------------------
-- OBSERVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.publisher ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.publisher (
    code		text PRIMARY KEY,
    name		text NOT NULL,
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
    publisher	text NOT NULL,
    session		varchar(40) NOT NULL,
    filter		jsonb NOT NULL,
    params		jsonb NOT NULL,
    CONSTRAINT pk_listener PRIMARY KEY(publisher, session),
    CONSTRAINT fk_listener_publisher FOREIGN KEY (publisher) REFERENCES db.publisher(code),
    CONSTRAINT fk_listener_session FOREIGN KEY (session) REFERENCES db.session(code)
);

COMMENT ON TABLE db.listener IS 'Слушатель.';

COMMENT ON COLUMN db.listener.publisher IS 'Издатель';
COMMENT ON COLUMN db.listener.session IS 'Код сессии';
COMMENT ON COLUMN db.listener.filter IS 'Фильтр';
COMMENT ON COLUMN db.listener.params IS 'Параметры';

