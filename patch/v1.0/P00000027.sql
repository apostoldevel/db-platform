DROP VIEW ObjectFile CASCADE;

ALTER TABLE db.object_file
  ADD COLUMN owner uuid REFERENCES db.user(id) ON DELETE RESTRICT;

CREATE INDEX ON db.object_file (owner);

UPDATE db.object_file SET owner = '00000000-0000-4000-a001-000000000001';

ALTER TABLE db.object_file
  ALTER COLUMN owner SET NOT NULL;

COMMENT ON COLUMN db.object_file.owner IS 'Владелец (пользователь)';

CREATE OR REPLACE FUNCTION db.ft_object_file_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.owner IS NULL THEN
    NEW.owner := current_userid();
  END IF;

  IF NULLIF(NEW.file_path, '') IS NULL THEN
    NEW.file_path := '~/';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
