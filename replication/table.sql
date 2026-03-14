--------------------------------------------------------------------------------
-- REPLICATION -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- replication.log -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE replication.log (
    id          bigserial PRIMARY KEY,
    datetime    timestamptz DEFAULT Now() NOT NULL,
    action      char NOT NULL CHECK (action IN ('I', 'U', 'D')),
    schema      text NOT NULL,
    name        text NOT NULL,
    key         jsonb,
    data        jsonb,
    source      text DEFAULT null
);

COMMENT ON TABLE replication.log IS 'Replication log. Stores every change (INSERT/UPDATE/DELETE) captured for cross-instance synchronization.';

COMMENT ON COLUMN replication.log.id IS 'Auto-increment log entry identifier.';
COMMENT ON COLUMN replication.log.datetime IS 'Timestamp when the change was recorded.';
COMMENT ON COLUMN replication.log.action IS 'DML action type: I = INSERT, U = UPDATE, D = DELETE.';
COMMENT ON COLUMN replication.log.schema IS 'Source table schema name.';
COMMENT ON COLUMN replication.log.name IS 'Source table name.';
COMMENT ON COLUMN replication.log.key IS 'Primary key columns as JSONB (used for UPDATE/DELETE identification).';
COMMENT ON COLUMN replication.log.data IS 'Changed row data as JSONB (full row for INSERT, diff for UPDATE).';
COMMENT ON COLUMN replication.log.source IS 'Originating instance identifier (NULL for local changes).';

CREATE INDEX ON replication.log (action);
CREATE INDEX ON replication.log (schema);
CREATE INDEX ON replication.log (name);
CREATE INDEX ON replication.log (source);

--------------------------------------------------------------------------------

/**
 * @brief Emit pg_notify on the replication channel after a new log entry is inserted.
 * @return {trigger}
 * @since 1.0.0
 */
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
    state       integer NOT NULL DEFAULT 0 CHECK (state BETWEEN 0 AND 2),
    created     timestamptz DEFAULT Now() NOT NULL,
    datetime    timestamptz NOT NULL,
    action      char NOT NULL CHECK (action IN ('I', 'U', 'D')),
    schema      text NOT NULL,
    name        text NOT NULL,
    key         jsonb,
    data        jsonb,
    message     text,
    proxy       boolean NOT NULL DEFAULT false,
    PRIMARY KEY (source, id)
);

COMMENT ON TABLE replication.relay IS 'Relay log. Incoming replication entries received from remote instances, pending application.';

COMMENT ON COLUMN replication.relay.source IS 'Originating instance identifier.';
COMMENT ON COLUMN replication.relay.id IS 'Log entry ID from the source instance.';
COMMENT ON COLUMN replication.relay.state IS 'Processing state: 0 = pending, 1 = applied, 2 = failed.';
COMMENT ON COLUMN replication.relay.created IS 'Timestamp when the entry was received locally.';
COMMENT ON COLUMN replication.relay.datetime IS 'Original timestamp of the change on the source instance.';
COMMENT ON COLUMN replication.relay.action IS 'DML action type: I = INSERT, U = UPDATE, D = DELETE.';
COMMENT ON COLUMN replication.relay.schema IS 'Target table schema name.';
COMMENT ON COLUMN replication.relay.name IS 'Target table name.';
COMMENT ON COLUMN replication.relay.key IS 'Primary key columns as JSONB for row identification.';
COMMENT ON COLUMN replication.relay.data IS 'Row data to apply as JSONB.';
COMMENT ON COLUMN replication.relay.message IS 'Error message if application failed (state = 2).';
COMMENT ON COLUMN replication.relay.proxy IS 'When TRUE, re-insert applied entry into replication.log for further relay.';

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

COMMENT ON TABLE replication.list IS 'Replication set. Tables currently enrolled in replication.';

COMMENT ON COLUMN replication.list.schema IS 'Schema of the replicated table.';
COMMENT ON COLUMN replication.list.name IS 'Name of the replicated table.';
COMMENT ON COLUMN replication.list.updated IS 'Timestamp when the table was last enrolled or refreshed.';

--------------------------------------------------------------------------------
-- replication.pkey ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE replication.pkey (
    schema      text NOT NULL,
    name        text NOT NULL,
    field       text NOT NULL,
    PRIMARY KEY (schema, name, field)
);

COMMENT ON TABLE replication.pkey IS 'Primary key cache. Stores PK column names for replicated tables.';

COMMENT ON COLUMN replication.pkey.schema IS 'Schema of the replicated table.';
COMMENT ON COLUMN replication.pkey.name IS 'Name of the replicated table.';
COMMENT ON COLUMN replication.pkey.field IS 'Column name that is part of the primary key.';
