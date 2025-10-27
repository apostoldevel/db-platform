DROP FUNCTION IF EXISTS api.add_notice(uuid, uuid, text, text, integer, json);
DROP FUNCTION IF EXISTS api.update_notice(uuid, uuid, uuid, text, text, integer, json);
DROP FUNCTION IF EXISTS api.set_notice(uuid, uuid, uuid, text, text, integer, json);

DROP FUNCTION IF EXISTS CreateNotice(uuid, uuid, text, text, integer, json);
DROP FUNCTION IF EXISTS EditNotice(uuid, uuid, uuid, text, text, integer, json);
DROP FUNCTION IF EXISTS SetNotice(uuid, uuid, uuid, text, text, integer, json);

DROP VIEW Notice CASCADE;

ALTER TABLE db.notice ALTER COLUMN data TYPE jsonb;