
drop function createlistener(text, varchar, jsonb, jsonb);
drop function editlistener(text, varchar, jsonb, jsonb);
drop function deletelistener(text, varchar);
drop function eventlistener(text, varchar, jsonb);

DROP VIEW api.listener CASCADE;

drop function api.add_listener(text, varchar, jsonb, jsonb);
drop function api.update_listener(text, varchar, jsonb, jsonb);
drop function api.unsubscribe_observer(text, varchar);

drop function daemon.observer (text, varchar, jsonb, text, inet);

--------------------------------------------------------------------------------

CREATE TABLE db._listener AS
  TABLE db.listener;

DROP TABLE db.listener CASCADE;

--------------------------------------------------------------------------------
-- db.listener -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.listener (
    publisher	text NOT NULL REFERENCES db.publisher(code) ON DELETE RESTRICT,
    session		varchar(40) NOT NULL REFERENCES db.session(code) ON DELETE CASCADE,
    identity	text NOT NULL,
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

--------------------------------------------------------------------------------

INSERT INTO db.listener SELECT publisher, session, 'main', filter, params FROM db._listener;

DROP TABLE db._listener;
