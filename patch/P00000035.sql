ALTER TABLE replication.log
  ADD COLUMN source text DEFAULT null;

COMMENT ON COLUMN replication.log.source IS 'Источник данных';

CREATE INDEX ON replication.log (source);
---

ALTER TABLE replication.relay
  ADD COLUMN proxy bool DEFAULT false;

COMMENT ON COLUMN replication.relay.proxy IS 'Дублировать запись в журнал репликации';

UPDATE replication.relay SET proxy = false;

ALTER TABLE replication.relay
  ALTER COLUMN proxy SET NOT NULL;
---

DROP FUNCTION IF EXISTS api.replication_log(bigint, integer);
DROP FUNCTION IF EXISTS replication.log(bigint, integer);
DROP FUNCTION IF EXISTS replication.add_log(timestamp with time zone, char, text, text, jsonb, jsonb);
DROP FUNCTION IF EXISTS replication.add_relay(text, bigint, timestamp with time zone, char, text, text, jsonb, jsonb);
---

CREATE OR REPLACE FUNCTION replication.ft_log_after_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM pg_notify('replication', json_build_object('id', NEW.id, 'datetime', NEW.datetime, 'action', NEW.action, 'schema', NEW.schema, 'name', NEW.name, 'source', NEW.source)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
