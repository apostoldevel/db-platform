TRUNCATE db.api_log;
DROP VIEW ApiLog CASCADE;
ALTER TABLE db.api_log ALTER COLUMN datetime TYPE timestamptz;
