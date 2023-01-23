--------------------------------------------------------------------------------
-- FILE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.file ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.file (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    root        uuid NOT NULL REFERENCES db.file(id),
    parent		uuid REFERENCES db.file(id),
    link		uuid REFERENCES db.file(id),
    owner		uuid NOT NULL REFERENCES db.user(id),
    type        char NOT NULL CHECK (type IN ('-', 'd', 'l')),
    mask        bit(9) DEFAULT B'111110100' NOT NULL,
    level		integer NOT NULL,
    path        text NOT NULL,
    name        text NOT NULL,
    size        integer DEFAULT 0,
    date        timestamptz,
    data        bytea,
    mime        text,
    text        text,
    hash        text,
    url         text
);

COMMENT ON TABLE db.file IS 'Файлы.';

COMMENT ON COLUMN db.file.id IS 'Идентификатор';
COMMENT ON COLUMN db.file.root IS 'Идентификатор корневого узла';
COMMENT ON COLUMN db.file.parent IS 'Идентификатор родительского узла';
COMMENT ON COLUMN db.file.link IS 'Ссылка на файл (идентификатор узла)';
COMMENT ON COLUMN db.file.owner IS 'Идентификатор владелеца';
COMMENT ON COLUMN db.file.type IS 'Тип: "-" - file (файл), "d" - directory (каталог), "l" - link (ссылка)';
COMMENT ON COLUMN db.file.mask IS 'Маска доступа. Девять бит ({u:rwe}{g:rwe}{o:rwe}), по три бита на действие r - read, w - write, e - execute, для: u - user (владелец) g - group (группа) o - other (остальные)';
COMMENT ON COLUMN db.file.level IS 'Уровень вложенности';
COMMENT ON COLUMN db.file.path IS 'Путь';
COMMENT ON COLUMN db.file.name IS 'Наименование';
COMMENT ON COLUMN db.file.size IS 'Размер';
COMMENT ON COLUMN db.file.date IS 'Дата и время';
COMMENT ON COLUMN db.file.data IS 'Содержимое (при наличии)';
COMMENT ON COLUMN db.file.mime IS 'Тип в формате MIME';
COMMENT ON COLUMN db.file.text IS 'Произвольный текст (описание)';
COMMENT ON COLUMN db.file.hash IS 'Хеш';
COMMENT ON COLUMN db.file.url IS 'URL';

CREATE UNIQUE INDEX ON db.file (root, parent, name);
CREATE UNIQUE INDEX ON db.file (path, name);

CREATE INDEX ON db.file (type);
CREATE INDEX ON db.file (owner);
CREATE INDEX ON db.file (root);
CREATE INDEX ON db.file (parent);
CREATE INDEX ON db.file (link);
CREATE INDEX ON db.file (path);
CREATE INDEX ON db.file (name);
CREATE INDEX ON db.file (hash);

--------------------------------------------------------------------------------

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

CREATE TRIGGER t_file_insert
  BEFORE INSERT ON db.file
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_file_insert();

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

CREATE TRIGGER t_file_name
  BEFORE UPDATE ON db.file
  FOR EACH ROW
  WHEN (OLD.name IS DISTINCT FROM NEW.name)
  EXECUTE PROCEDURE db.ft_file_name();

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

CREATE TRIGGER t_file_path
  BEFORE UPDATE ON db.file
  FOR EACH ROW
  WHEN (OLD.path IS DISTINCT FROM NEW.path)
  EXECUTE PROCEDURE db.ft_file_path();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_notify()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    PERFORM pg_notify('file', json_build_object('session', current_session(), 'operation', TG_OP, 'id', OLD.id)::text);
  ELSE
    PERFORM pg_notify('file', json_build_object('session', current_session(), 'operation', TG_OP, 'id', NEW.id)::text);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_file_notify
  AFTER INSERT OR UPDATE OR DELETE ON db.file
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_file_notify();
