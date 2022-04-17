--------------------------------------------------------------------------------
-- REPLICATION -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- replication.log -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE replication.log (
    id          bigserial PRIMARY KEY,
    datetime	timestamptz DEFAULT Now() NOT NULL,
    action      char NOT NULL CHECK (action IN ('I', 'U', 'D')),
    schema      text NOT NULL,
    name        text NOT NULL,
    key         jsonb,
    data        jsonb,
    source      text DEFAULT null
);

COMMENT ON TABLE replication.log IS 'Журнал репликации.';

COMMENT ON COLUMN replication.log.id IS 'Идентификатор';
COMMENT ON COLUMN replication.log.datetime IS 'Дата и время';
COMMENT ON COLUMN replication.log.action IS 'Действие';
COMMENT ON COLUMN replication.log.schema IS 'Схема';
COMMENT ON COLUMN replication.log.name IS 'Наименование таблицы';
COMMENT ON COLUMN replication.log.key IS 'Ключ';
COMMENT ON COLUMN replication.log.data IS 'Данные';
COMMENT ON COLUMN replication.log.source IS 'Источник данных';

CREATE INDEX ON replication.log (action);
CREATE INDEX ON replication.log (schema);
CREATE INDEX ON replication.log (name);
CREATE INDEX ON replication.log (source);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.ft_log_after_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM pg_notify('replication', json_build_object('id', NEW.id, 'datetime', NEW.datetime, 'action', NEW.action, 'schema', NEW.schema, 'name', NEW.name, 'source', NEW.source)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_replication_log
  AFTER INSERT ON replication.log
  FOR EACH ROW
  EXECUTE PROCEDURE replication.ft_log_after_insert();

--------------------------------------------------------------------------------
-- replication.relay -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE replication.relay (
    source      text NOT NULL,
    id          bigint NOT NULL,
    state		integer NOT NULL DEFAULT 0 CHECK (state BETWEEN 0 AND 2),
    created     timestamptz DEFAULT Now() NOT NULL,
    datetime	timestamptz NOT NULL,
    action      char NOT NULL CHECK (action IN ('I', 'U', 'D')),
    schema      text NOT NULL,
    name        text NOT NULL,
    key         jsonb,
    data        jsonb,
    message		text,
    proxy       boolean NOT NULL DEFAULT false,
    PRIMARY KEY (source, id)
);

COMMENT ON TABLE replication.relay IS 'Журнал ретрансляции.';

COMMENT ON COLUMN replication.relay.source IS 'Источник данных';
COMMENT ON COLUMN replication.relay.id IS 'Идентификатор';
COMMENT ON COLUMN replication.relay.state IS 'Состояние';
COMMENT ON COLUMN replication.relay.created IS 'Дата и время загрузки';
COMMENT ON COLUMN replication.relay.datetime IS 'Дата и время';
COMMENT ON COLUMN replication.relay.action IS 'Действие';
COMMENT ON COLUMN replication.relay.schema IS 'Схема';
COMMENT ON COLUMN replication.relay.name IS 'Наименование таблицы';
COMMENT ON COLUMN replication.relay.key IS 'Ключ';
COMMENT ON COLUMN replication.relay.data IS 'Данные';
COMMENT ON COLUMN replication.relay.message IS 'Сообщение об ошибке при наличии';
COMMENT ON COLUMN replication.relay.proxy IS 'Дублировать запись в журнал репликации';

CREATE INDEX ON replication.relay (source);
CREATE INDEX ON replication.relay (state);

--------------------------------------------------------------------------------
-- replication.list ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE replication.list (
    schema      text NOT NULL,
    name        text NOT NULL,
    updated     timestamptz DEFAULT Now() NOT NULL,
    PRIMARY KEY (schema, name)
);

COMMENT ON TABLE replication.list IS 'Список таблиц для репликации.';

COMMENT ON COLUMN replication.list.schema IS 'Схема';
COMMENT ON COLUMN replication.list.name IS 'Наименование таблицы';
COMMENT ON COLUMN replication.list.updated IS 'Дата и время последнего обновления';

--------------------------------------------------------------------------------
-- replication.pkey ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE replication.pkey (
    schema      text NOT NULL,
    name        text NOT NULL,
    field       text NOT NULL,
    PRIMARY KEY (schema, name, field)
);

COMMENT ON TABLE replication.pkey IS 'Список публичных ключей таблиц.';

COMMENT ON COLUMN replication.pkey.schema IS 'Схема';
COMMENT ON COLUMN replication.pkey.name IS 'Наименование таблицы';
COMMENT ON COLUMN replication.pkey.field IS 'Поле';
