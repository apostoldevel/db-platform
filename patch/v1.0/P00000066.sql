CREATE OR REPLACE FUNCTION db.ft_file_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.owner IS NULL THEN
    NEW.owner := current_userid();
  END IF;

  IF NEW.root IS NULL THEN
    SELECT NEW.id INTO NEW.root;
  END IF;

  NEW.path := NormalizeFilePath(NEW.path, false);
  NEW.name := NormalizeFileName(NEW.name, false);
  NEW.url := concat('/file', NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));

  RETURN NEW;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_name()
RETURNS trigger AS $$
BEGIN
  NEW.name := NormalizeFileName(NEW.name, false);
  NEW.url := concat('/file', NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_path()
RETURNS trigger AS $$
BEGIN
  NEW.path := NormalizeFilePath(NEW.path, false);
  NEW.url := concat('/file', NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_notify()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    PERFORM pg_notify('file', json_build_object('session', current_session(), 'operation', TG_OP, 'id', OLD.id, 'name', OLD.name, 'path', OLD.path)::text);
  ELSE
    PERFORM pg_notify('file', json_build_object('session', current_session(), 'operation', TG_OP, 'id', NEW.id, 'name', NEW.name, 'path', NEW.path)::text);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
