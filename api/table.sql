--------------------------------------------------------------------------------
-- API -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.path ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.path (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    root        uuid NOT NULL REFERENCES db.path(id),
    parent      uuid REFERENCES db.path(id),
    name        text NOT NULL,
    level       integer NOT NULL
);

COMMENT ON TABLE db.path IS 'API route path tree node.';

COMMENT ON COLUMN db.path.id IS 'Path node identifier.';
COMMENT ON COLUMN db.path.root IS 'Root node identifier (top of the subtree).';
COMMENT ON COLUMN db.path.parent IS 'Parent node identifier.';
COMMENT ON COLUMN db.path.name IS 'Path segment name (e.g. "v1", "user").';
COMMENT ON COLUMN db.path.level IS 'Nesting depth (0 = root).';

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
    id            uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    definition    text NOT NULL
);

COMMENT ON TABLE db.endpoint IS 'API endpoint: holds the PL/pgSQL code executed for a route.';

COMMENT ON COLUMN db.endpoint.id IS 'Endpoint identifier.';
COMMENT ON COLUMN db.endpoint.definition IS 'Dynamic PL/pgSQL expression executed via EXECUTE ... USING.';

--------------------------------------------------------------------------------
-- db.route --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.route (
    method      text NOT NULL DEFAULT 'POST' CHECK (method IN ('GET', 'POST', 'PUT', 'DELETE')),
    path        uuid NOT NULL REFERENCES db.path(id),
    endpoint    uuid NOT NULL REFERENCES db.endpoint(id),
    PRIMARY KEY (method, path, endpoint)
);

COMMENT ON TABLE db.route IS 'API route: binds an HTTP method + path to an endpoint.';

COMMENT ON COLUMN db.route.method IS 'HTTP method (GET, POST, PUT, DELETE).';
COMMENT ON COLUMN db.route.path IS 'Reference to the path node in db.path.';
COMMENT ON COLUMN db.route.endpoint IS 'Reference to the endpoint in db.endpoint.';

CREATE INDEX ON db.route (method);
CREATE INDEX ON db.route (path);
CREATE INDEX ON db.route (endpoint);
