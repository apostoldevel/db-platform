DROP FUNCTION IF EXISTS replication.apply(text);
DROP FUNCTION IF EXISTS api.replication_apply(text);
DROP FUNCTION IF EXISTS api.add_to_relay_log(text, bigint, timestamp with time zone, char, text, text, jsonb, jsonb);
