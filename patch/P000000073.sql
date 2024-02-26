CREATE OR REPLACE FUNCTION db.ft_file_notify()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.type != 's' THEN
      PERFORM pg_notify('file', json_build_object('session', current_session(), 'operation', TG_OP, 'id', NEW.id, 'type', NEW.type, 'name', NEW.name, 'path', NEW.path, 'hash', NEW.hash)::text);
    END IF;
  ELSE
    PERFORM pg_notify('file', json_build_object('session', current_session(), 'operation', TG_OP, 'id', OLD.id, 'type', NEW.type, 'name', OLD.name, 'path', OLD.path, 'hash', OLD.hash)::text);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
