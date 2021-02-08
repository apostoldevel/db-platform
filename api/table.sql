--------------------------------------------------------------------------------
-- API -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.path ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.path (
    id			numeric(10) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_API'),
    root        numeric(10) NOT NULL,
    parent		numeric(10),
    name        text NOT NULL,
    level		integer NOT NULL,
    CONSTRAINT fk_path_root FOREIGN KEY (root) REFERENCES db.path(id),
    CONSTRAINT fk_path_parent FOREIGN KEY (parent) REFERENCES db.path(id)
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

CREATE OR REPLACE FUNCTION ft_path_insert()
RETURNS trigger AS $$
BEGIN
  IF NULLIF(NEW.root, 0) IS NULL THEN
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
  EXECUTE PROCEDURE ft_path_insert();

--------------------------------------------------------------------------------
-- db.endpoint -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.endpoint (
    id			numeric(10) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_API'),
    definition	text NOT NULL
);

COMMENT ON TABLE db.endpoint IS 'API: Конечная точка.';

COMMENT ON COLUMN db.endpoint.id IS 'Идентификатор';
COMMENT ON COLUMN db.endpoint.definition IS 'PL/pgSQL код';

--------------------------------------------------------------------------------
-- db.route --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.route (
    method		text NOT NULL DEFAULT 'POST',
    path       	numeric(10) NOT NULL,
    endpoint	numeric(10) NOT NULL,
    CONSTRAINT pk_route PRIMARY KEY (method, path, endpoint),
    CONSTRAINT ch_route_method CHECK (method IN ('GET', 'POST', 'PUT', 'DELETE')),
    CONSTRAINT fk_route_path FOREIGN KEY (path) REFERENCES db.path(id),
    CONSTRAINT fk_route_endpoint FOREIGN KEY (endpoint) REFERENCES db.endpoint(id)
);

COMMENT ON TABLE db.route IS 'API: Маршрут.';

COMMENT ON COLUMN db.route.method IS 'HTTP-Метод';
COMMENT ON COLUMN db.route.path IS 'Путь';
COMMENT ON COLUMN db.route.endpoint IS 'Конечная точка';

CREATE INDEX ON db.route (method);
CREATE INDEX ON db.route (path);
CREATE INDEX ON db.route (endpoint);

