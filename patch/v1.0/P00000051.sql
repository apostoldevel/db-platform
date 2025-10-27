DROP VIEW EventLog CASCADE;

ALTER TABLE db.log
    ADD COLUMN timestamp timestamptz DEFAULT Now() NOT NULL;

CREATE OR REPLACE FUNCTION db.ft_log_insert()
RETURNS trigger AS $$
BEGIN
  NEW.datetime := clock_timestamp();

  IF NULLIF(NEW.username, '') IS NULL THEN
     NEW.username := coalesce(current_username(), session_user);
  END IF;

  IF NEW.session IS NULL THEN
    NEW.session := current_session();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
