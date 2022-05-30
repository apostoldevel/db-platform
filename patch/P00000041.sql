--------------------------------------------------------------------------------
-- URLEncode -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION URLEncode (
  url       text
) RETURNS   text
AS $$
DECLARE
  result    text;
  c         text;
  i         int;
BEGIN
  result := '';

  FOR i IN 1..length(url)
  LOOP
    c := substr(url, i, 1);
    IF regexp_match(c, '[A-Za-z0-9_~.-]') IS NOT NULL THEN
      result := result || c;
    ELSE
      result := concat(result, '%', dec_to_hex(ascii(c), 2));
    END IF;
  END LOOP;

  RETURN result;
END
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION URLEncode(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- replication.off -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.off()
RETURNS void
AS $$
DECLARE
  r             record;

  vMessage      text;
  vContext      text;
BEGIN
  FOR r IN SELECT * FROM ReplicationTable
  LOOP
    EXECUTE replication.drop_trigger(r.schema, r.name);
  END LOOP;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;
  PERFORM WriteDiagnostics(vMessage, vContext);
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- NormalizeFileName -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NormalizeFileName (
  pName		text,
  pLink     boolean DEFAULT false
) RETURNS	text
AS $$
BEGIN
  IF StrPos(pName, '/') != 0 THEN
	RAISE EXCEPTION 'ERR-40000: Invalid file name value: %', pName;
  END IF;

  IF pLink THEN
    RETURN URLEncode(pName);
  END IF;

  RETURN pName;
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NormalizeFilePath -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NormalizeFilePath (
  pPath		text,
  pLink     boolean DEFAULT false
) RETURNS	text
AS $$
DECLARE
  i         int;
  arPath    text[];
BEGIN
  IF SubStr(pPath, 1, 1) = '.' OR StrPos(pPath, '..') != 0 THEN
	RAISE EXCEPTION 'ERR-40000: Invalid file path value: %', pPath;
  END IF;

  IF NULLIF(NULLIF(pPath, ''), '~/') IS NULL THEN
    RETURN '/';
  END IF;

  arPath := path_to_array(pPath);
  IF arPath IS NULL THEN
    RETURN '/';
  END IF;

  pPath := '/';

  FOR i IN 1..array_length(arPath, 1)
  LOOP
    IF pLink THEN
	  pPath := concat(pPath, URLEncode(arPath[i]), '/');
	ELSE
	  pPath := concat(pPath, arPath[i], '/');
    END IF;
  END LOOP;

  RETURN pPath;
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

DROP FUNCTION EditObjectFile(uuid, text, text, integer, timestamp with time zone, bytea, text, text, text, timestamp with time zone);
DROP FUNCTION NewObjectFile(uuid, text, text, integer, timestamp with time zone, bytea, text, text, text);
DROP FUNCTION SetObjectFile(uuid, text, text, integer, timestamp with time zone, bytea, text, text, text);

DROP VIEW ObjectFile CASCADE;

ALTER TABLE db.object_file
  ADD COLUMN file_link text,
  ADD COLUMN call_back text;

COMMENT ON COLUMN db.object_file.file_link IS 'Ссылка на файл';
COMMENT ON COLUMN db.object_file.call_back IS 'Наименовании функции обратного вызова';

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_file_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.owner IS NULL THEN
    NEW.owner := current_userid();
  END IF;

  IF NEW.call_back IS NOT NULL THEN
    PERFORM FROM pg_namespace n INNER JOIN pg_proc p ON n.oid = p.pronamespace WHERE n.nspname = split_part(NEW.call_back, '.', 1) AND p.proname = split_part(NEW.call_back, '.', 2);
    IF NOT FOUND THEN
	  RAISE EXCEPTION 'ERR-40000: Not found callback function: %', NEW.call_back;
    END IF;
  END IF;

  NEW.file_name := NormalizeFileName(NEW.file_name, false);
  NEW.file_path := NormalizeFilePath(NEW.file_path, false);
  NEW.file_link := concat('/file/', NEW.object, NormalizeFilePath(NEW.file_path, true), NormalizeFileName(NEW.file_name, true));

  RETURN NEW;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_file_name()
RETURNS trigger AS $$
BEGIN
  NEW.file_name := NormalizeFileName(NEW.file_name, false);
  NEW.file_link := concat('/file/', NEW.object, NormalizeFilePath(NEW.file_path, true), NormalizeFileName(NEW.file_name, true));

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_file_name
  BEFORE UPDATE ON db.object_file
  FOR EACH ROW
  WHEN (OLD.file_name IS DISTINCT FROM NEW.file_name)
  EXECUTE PROCEDURE db.ft_object_file_name();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_file_path()
RETURNS trigger AS $$
BEGIN
  NEW.file_path := NormalizeFilePath(NEW.file_path, false);
  NEW.file_link := concat('/file/', NEW.object, NormalizeFilePath(NEW.file_path, true), NormalizeFileName(NEW.file_name, true));

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_file_path
  BEFORE UPDATE ON db.object_file
  FOR EACH ROW
  WHEN (OLD.file_path IS DISTINCT FROM NEW.file_path)
  EXECUTE PROCEDURE db.ft_object_file_path();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_file_notify()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    PERFORM pg_notify('file', json_build_object('operation', TG_OP, 'object', OLD.object, 'name', OLD.file_name, 'path', OLD.file_path)::text);
  ELSE
    PERFORM pg_notify('file', json_build_object('operation', TG_OP, 'object', NEW.object, 'name', NEW.file_name, 'path', NEW.file_path)::text);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_file_notify
  AFTER INSERT OR UPDATE OR DELETE ON db.object_file
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_file_notify();

--------------------------------------------------------------------------------

SELECT replication.off();

UPDATE db.object_file SET file_path = '/' WHERE file_path = '~/';
UPDATE db.object_file SET file_path = NormalizeFilePath(file_path) WHERE file_path != '~/';
UPDATE db.object_file SET file_link = concat('/file/', object, file_path, URLEncode(file_name));

SELECT replication.on();