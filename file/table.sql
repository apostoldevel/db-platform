--------------------------------------------------------------------------------
-- FILE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.file ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.file (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    root        uuid NOT NULL REFERENCES db.file(id),
    parent      uuid REFERENCES db.file(id),
    link        uuid REFERENCES db.file(id),
    owner       uuid NOT NULL REFERENCES db.user(id),
    type        char NOT NULL CHECK (type IN ('-', 'd', 'l', 's')),
    mask        bit(9) DEFAULT B'111110100' NOT NULL,
    level       integer NOT NULL,
    path        text NOT NULL,
    name        text NOT NULL,
    size        integer DEFAULT 0,
    date        timestamptz,
    data        bytea,
    mime        text,
    text        text,
    hash        text,
    url         text,
    done        text,
    fail        text
);

COMMENT ON TABLE db.file IS 'Virtual file system entry (file, directory, link, or S3 storage bucket).';

COMMENT ON COLUMN db.file.id IS 'Unique file identifier (UUID).';
COMMENT ON COLUMN db.file.root IS 'Root node identifier (top-level ancestor in the tree).';
COMMENT ON COLUMN db.file.parent IS 'Parent directory identifier.';
COMMENT ON COLUMN db.file.link IS 'Linked file identifier (for symlink-type entries).';
COMMENT ON COLUMN db.file.owner IS 'Owner user identifier.';
COMMENT ON COLUMN db.file.type IS 'Entry type: "-" = file, "d" = directory, "l" = link, "s" = storage (S3 bucket).';
COMMENT ON COLUMN db.file.mask IS 'UNIX-style permission bitmask: 9 bits {owner:rwx}{group:rwx}{other:rwx}.';
COMMENT ON COLUMN db.file.level IS 'Nesting depth in the directory tree (0 = root).';
COMMENT ON COLUMN db.file.path IS 'Absolute path to the parent directory.';
COMMENT ON COLUMN db.file.name IS 'File or directory name.';
COMMENT ON COLUMN db.file.size IS 'Content size in bytes.';
COMMENT ON COLUMN db.file.date IS 'Last modification timestamp.';
COMMENT ON COLUMN db.file.data IS 'Binary content (stored inline when present).';
COMMENT ON COLUMN db.file.mime IS 'MIME type (e.g. image/png, application/pdf).';
COMMENT ON COLUMN db.file.text IS 'Free-text description or metadata.';
COMMENT ON COLUMN db.file.hash IS 'Content hash (SHA-256 hex digest).';
COMMENT ON COLUMN db.file.url IS 'Computed public URL for the file.';
COMMENT ON COLUMN db.file.done IS 'Callback function name on successful remote file download.';
COMMENT ON COLUMN db.file.fail IS 'Callback function name on failed remote file download.';

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

/**
 * @brief Initialise defaults and compute the public URL on file insert.
 * @since 1.0.0
 */
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
    vStorage := coalesce(RegGetValueString('CURRENT_CONFIG', 'CONFIGCurrentProject', 'Host', current_userid()), '') || '/file';
  END IF;

  NEW.url := concat(vStorage, NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));

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

/**
 * @brief Recompute the public URL when the file type changes.
 * @since 1.0.0
 */
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

/**
 * @brief Normalise the path and recompute the public URL when the path changes.
 * @since 1.0.0
 */
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

CREATE TRIGGER t_file_path
  BEFORE UPDATE ON db.file
  FOR EACH ROW
  WHEN (OLD.path IS DISTINCT FROM NEW.path)
  EXECUTE PROCEDURE db.ft_file_path();

--------------------------------------------------------------------------------

/**
 * @brief Normalise the name and recompute the public URL when the name changes.
 * @since 1.0.0
 */
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

CREATE TRIGGER t_file_name
  BEFORE UPDATE ON db.file
  FOR EACH ROW
  WHEN (OLD.name IS DISTINCT FROM NEW.name)
  EXECUTE PROCEDURE db.ft_file_name();

--------------------------------------------------------------------------------

/**
 * @brief Emit a LISTEN/NOTIFY event for the PGFile helper on every file change.
 * @since 1.0.0
 */
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

--------------------------------------------------------------------------------

CREATE TRIGGER t_file_notify
  AFTER INSERT OR UPDATE OR DELETE ON db.file
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_file_notify();
