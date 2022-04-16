ALTER TABLE replication.log
  ADD COLUMN source text DEFAULT null;

COMMENT ON COLUMN replication.log.source IS 'Источник данных';

CREATE INDEX ON replication.log (source);

DROP FUNCTION replication.add_log(timestamp with time zone, char, text, text, jsonb, jsonb);
