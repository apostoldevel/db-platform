--------------------------------------------------------------------------------
-- RESOURCE --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.resource -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.resource (
    id              uuid PRIMARY KEY,
    root            uuid NOT NULL REFERENCES db.resource(id),
    node            uuid REFERENCES db.resource(id),
    type            text NOT NULL,
    level           integer NOT NULL,
    sequence        integer NOT NULL
);

COMMENT ON TABLE db.resource IS 'Hierarchical resource tree node.';

COMMENT ON COLUMN db.resource.id IS 'Primary key (UUID).';
COMMENT ON COLUMN db.resource.root IS 'Root node of the tree this resource belongs to.';
COMMENT ON COLUMN db.resource.node IS 'Parent node (NULL for root nodes).';
COMMENT ON COLUMN db.resource.type IS 'MIME type of the resource content.';
COMMENT ON COLUMN db.resource.level IS 'Nesting depth (0 = root).';
COMMENT ON COLUMN db.resource.sequence IS 'Sort order among siblings.';

CREATE INDEX ON db.resource (root);
CREATE INDEX ON db.resource (node);

--------------------------------------------------------------------------------

/**
 * @brief Assign default values for new resource tree nodes.
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_resource_before()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    NEW.id := gen_kernel_uuid('8');
  END IF;

  IF NEW.root IS NULL THEN
    NEW.root := NEW.id;
  END IF;

  IF NEW.node IS NULL THEN
    IF NEW.root <> NEW.id THEN
      NEW.node := NEW.root;
    END IF;
  END IF;

  IF NEW.type IS NULL THEN
    NEW.type := 'text/plain';
  END IF;

  IF NEW.sequence IS NULL THEN
    NEW.sequence := 1;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_resource_before
  BEFORE INSERT ON db.resource
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_resource_before();

--------------------------------------------------------------------------------
-- db.resource_data ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.resource_data (
    resource        uuid NOT NULL REFERENCES db.resource(id) ON DELETE CASCADE,
    locale          uuid NOT NULL REFERENCES db.locale(id),
    name            text,
    description     text,
    encoding        text,
    data            text,
    updated         timestamptz DEFAULT Now() NOT NULL,
    PRIMARY KEY (resource, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.resource_data IS 'Locale-specific content for a resource node.';

COMMENT ON COLUMN db.resource_data.resource IS 'FK to db.resource(id).';
COMMENT ON COLUMN db.resource_data.locale IS 'FK to db.locale(id) — target language.';
COMMENT ON COLUMN db.resource_data.name IS 'Human-readable name / key for the resource.';
COMMENT ON COLUMN db.resource_data.description IS 'Longer description or label text.';
COMMENT ON COLUMN db.resource_data.encoding IS 'Character encoding of the data payload (e.g. UTF-8, base64).';
COMMENT ON COLUMN db.resource_data.data IS 'Actual content payload (text, HTML, etc.).';
COMMENT ON COLUMN db.resource_data.updated IS 'Timestamp of last modification.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.resource_data (resource);
CREATE INDEX ON db.resource_data (locale);

CREATE INDEX ON db.resource_data (name);
CREATE INDEX ON db.resource_data (name text_pattern_ops);

CREATE UNIQUE INDEX ON db.resource_data (name, locale);
--------------------------------------------------------------------------------

/**
 * @brief Apply default locale and preserve non-NULL values on INSERT/UPDATE.
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_resource_data_before()
RETURNS trigger AS $$
BEGIN
  IF NEW.locale IS NULL THEN
    NEW.locale := current_locale();
  END IF;

  IF NEW.name IS NULL THEN
    NEW.name := CheckNull(coalesce(NEW.name, OLD.name, ''));
  END IF;

  IF NEW.description IS NULL THEN
    NEW.description := CheckNull(coalesce(NEW.description, OLD.description, ''));
  END IF;

  IF NEW.encoding IS NULL THEN
    NEW.encoding := CheckNull(coalesce(NEW.encoding, OLD.encoding, ''));
  END IF;

  IF NEW.data IS NULL THEN
    NEW.data := CheckNull(coalesce(NEW.data, OLD.data, ''));
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_resource_data_before
  BEFORE INSERT OR UPDATE ON db.resource_data
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_resource_data_before();
