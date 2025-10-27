DROP VIEW EventLog CASCADE;
ALTER TABLE db.log ALTER COLUMN datetime TYPE timestamptz;
