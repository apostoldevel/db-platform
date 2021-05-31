DROP VIEW EventLog CASCADE;
ALTER TABLE db.log ALTER COLUMN datetime TYPE timestamptz USING datetime + interval '3 hour';
