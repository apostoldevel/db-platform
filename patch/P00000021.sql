DROP FUNCTION IF EXISTS api.set_object_file(uuid, text, text, integer, timestamp, bytea, text, text, text);

DROP FUNCTION IF EXISTS oper_date(varchar) CASCADE;
DROP FUNCTION IF EXISTS AddObjectState(uuid, uuid, timestamp);
DROP FUNCTION IF EXISTS GetObjectState(uuid, timestamp);
DROP FUNCTION IF EXISTS SetObjectLink(uuid, uuid, text, timestamp);
DROP FUNCTION IF EXISTS GetObjectLink(uuid, text, timestamp);
DROP FUNCTION IF EXISTS NewObjectFile(uuid, text, text, integer, timestamp, bytea, text, text, text);
DROP FUNCTION IF EXISTS SetObjectFile(uuid, text, text, integer, timestamp, bytea, text, text, text);
DROP FUNCTION IF EXISTS EditObjectFile(uuid, text, text, integer, timestamp, bytea, text, text, text, timestamp);

DROP VIEW Object CASCADE;

ALTER TABLE db.object
  ALTER COLUMN pdate TYPE timestamptz,
  ALTER COLUMN ldate TYPE timestamptz,
  ALTER COLUMN udate TYPE timestamptz;

DROP VIEW ObjectState CASCADE;

ALTER TABLE db.object_state
  ALTER COLUMN validfromdate TYPE timestamptz,
  ALTER COLUMN validtodate TYPE timestamptz;

DROP VIEW ObjectAddresses CASCADE;

ALTER TABLE db.object_link
  ALTER COLUMN validfromdate TYPE timestamptz,
  ALTER COLUMN validtodate TYPE timestamptz;

DROP VIEW ObjectFile CASCADE;

ALTER TABLE db.object_file
  ALTER COLUMN file_date TYPE timestamptz,
  ALTER COLUMN load_date TYPE timestamptz;
