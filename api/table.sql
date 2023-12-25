--------------------------------------------------------------------------------
-- API -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.path ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.path (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    root        uuid NOT NULL REFERENCES db.path(id),
    parent		uuid REFERENCES db.path(id),
    name        text NOT NULL,
    level		integer NOT NULL
);

COMMENT ON TABLE db.path IS 'API: Путь.';

COMMENT ON COLUMN db.path.id IS 'Идентификатор';
COMMENT ON COLUMN db.path.root IS 'Идентификатор корневого узла';
COMMENT ON COLUMN db.path.parent IS 'Идентификатор родительского узла';
COMMENT ON COLUMN db.path.name IS 'Наименование';
COMMENT ON COLUMN db.path.level IS 'Уровень вложенности';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.path (root, parent, name);

CREATE INDEX ON db.path (root);
CREATE INDEX ON db.path (parent);
CREATE INDEX ON db.path (name);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_path_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.root IS NULL THEN
    SELECT NEW.id INTO NEW.root;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_path_insert
  BEFORE INSERT ON db.path
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_path_insert();

--------------------------------------------------------------------------------
-- db.endpoint -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.endpoint (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    definition	text NOT NULL
);

COMMENT ON TABLE db.endpoint IS 'API: Конечная точка.';

COMMENT ON COLUMN db.endpoint.id IS 'Идентификатор';
COMMENT ON COLUMN db.endpoint.definition IS 'PL/pgSQL код';

--------------------------------------------------------------------------------
-- db.route --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.route (
    method		text NOT NULL DEFAULT 'POST' CHECK (method IN ('GET', 'POST', 'PUT', 'DELETE')),
    path       	uuid NOT NULL REFERENCES db.path(id),
    endpoint	uuid NOT NULL REFERENCES db.endpoint(id),
    PRIMARY KEY (method, path, endpoint)
);

COMMENT ON TABLE db.route IS 'API: Маршрут.';

COMMENT ON COLUMN db.route.method IS 'HTTP-Метод';
COMMENT ON COLUMN db.route.path IS 'Путь';
COMMENT ON COLUMN db.route.endpoint IS 'Конечная точка';

CREATE INDEX ON db.route (method);
CREATE INDEX ON db.route (path);
CREATE INDEX ON db.route (endpoint);
