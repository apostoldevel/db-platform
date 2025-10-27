DROP FUNCTION IF EXISTS api.set_file(uuid, char, integer, uuid, uuid, uuid, uuid, text, text, integer, timestamp with time zone, text, text, text, text);

DROP FUNCTION IF EXISTS NewObjectFile(uuid, uuid, text, text, integer, timestamp with time zone, bytea, text, text, text);

DROP FUNCTION IF EXISTS NewFile(uuid, uuid, uuid, text, char, uuid, bit, uuid, integer, timestamp with time zone, bytea, text, text, text);
DROP FUNCTION IF EXISTS AddFile(uuid, uuid, text, char, uuid, bit, uuid, integer, timestamp with time zone, bytea, text, text, text);
DROP FUNCTION IF EXISTS EditFile(uuid, uuid, uuid, text, uuid, bit, uuid, integer, timestamp with time zone, bytea, text, text, text);
DROP FUNCTION IF EXISTS SetFile(uuid, char, bit, uuid, uuid, uuid, uuid, text, integer, timestamp with time zone, bytea, text, text, text);

DROP VIEW File CASCADE;
DROP VIEW FileData CASCADE;

ALTER TABLE db.file DROP CONSTRAINT file_type_check;
ALTER TABLE db.file ADD CHECK (type IN ('-', 'd', 'l', 's'));

ALTER TABLE db.file
  ADD COLUMN done text,
  ADD COLUMN fail text;

COMMENT ON COLUMN db.file.type IS 'Тип: "-" - file (файл), "d" - directory (каталог), "l" - link (ссылка), "s" - storage (хранилище)';
COMMENT ON COLUMN db.file.done IS 'Имя функции обратного вызова в случае успешной загрузки файла по ссылке';
COMMENT ON COLUMN db.file.fail IS 'Имя функции обратного вызова в случае сбоя при загрузке файла по ссылке';

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_insert()
RETURNS trigger AS $$
DECLARE
  vStorage  text;
BEGIN
  IF NEW.owner IS NULL THEN
    NEW.owner := current_userid();
  END IF;

  IF NEW.root IS NULL THEN
    SELECT NEW.id INTO NEW.root;
  END IF;

  NEW.path := NormalizeFilePath(NEW.path, false);
  NEW.name := NormalizeFileName(NEW.name, false);

  IF NEW.type = 's' THEN
    vStorage := convert_from(NEW.data, 'utf8');
  ELSE
    vStorage := coalesce(RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Host', current_userid()), '') || '/file';
  END IF;

  NEW.url := concat(vStorage, NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));

  RETURN NEW;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_type()
RETURNS trigger AS $$
DECLARE
  vStorage  text;
BEGIN
  IF NEW.type = 's' THEN
    vStorage := convert_from(NEW.data, 'utf8');
  ELSE
    vStorage := coalesce(RegGetValueString('CURRENT_CONFIG', 'CONFIGCurrentProject', 'Host', current_userid()), '') || '/file';
  END IF;

  NEW.url := concat(vStorage, NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_file_type
  BEFORE UPDATE ON db.file
  FOR EACH ROW
  WHEN (OLD.type IS DISTINCT FROM NEW.type)
  EXECUTE PROCEDURE db.ft_file_type();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_path()
RETURNS trigger AS $$
DECLARE
  vStorage  text;
BEGIN
  NEW.path := NormalizeFilePath(NEW.path, false);

  IF NEW.type = 's' THEN
    vStorage := convert_from(NEW.data, 'utf8');
  ELSE
    vStorage := coalesce(RegGetValueString('CURRENT_CONFIG', 'CONFIGCurrentProject', 'Host', current_userid()), '') || '/file';
  END IF;

  NEW.url := concat(vStorage, NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_name()
RETURNS trigger AS $$
DECLARE
  vStorage  text;
BEGIN
  NEW.name := NormalizeFileName(NEW.name, false);

  IF NEW.type = 's' THEN
    vStorage := convert_from(NEW.data, 'utf8');
  ELSE
    vStorage := coalesce(RegGetValueString('CURRENT_CONFIG', 'CONFIGCurrentProject', 'Host', current_userid()), '') || '/file';
  END IF;

  NEW.url := concat(vStorage, NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_notify()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM pg_notify('file', json_build_object('session', current_session(), 'operation', TG_OP, 'id', NEW.id, 'type', NEW.type, 'path', NEW.path, 'name', NEW.name, 'hash', NEW.hash)::text);
  ELSE
    PERFORM pg_notify('file', json_build_object('session', current_session(), 'operation', TG_OP, 'id', OLD.id, 'type', NEW.type, 'path', OLD.path, 'name', OLD.name, 'hash', OLD.hash)::text);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
