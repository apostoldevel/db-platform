--------------------------------------------------------------------------------
-- API -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.path --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE api.path (
    id			numeric(10) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_API'),
    root        numeric(10) NOT NULL,
    parent		numeric(10),
    name        text NOT NULL,
    level		integer NOT NULL,
    CONSTRAINT fk_api_root FOREIGN KEY (root) REFERENCES api.path(id),
    CONSTRAINT fk_api_parent FOREIGN KEY (parent) REFERENCES api.path(id)
);

COMMENT ON TABLE api.path IS 'API: Путь.';

COMMENT ON COLUMN api.path.id IS 'Идентификатор';
COMMENT ON COLUMN api.path.root IS 'Идентификатор корневого узла';
COMMENT ON COLUMN api.path.parent IS 'Идентификатор родительского узла';
COMMENT ON COLUMN api.path.name IS 'Наименование';
COMMENT ON COLUMN api.path.level IS 'Уровень вложенности';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON api.path (root, parent, name);

CREATE INDEX ON api.path (root);
CREATE INDEX ON api.path (parent);
CREATE INDEX ON api.path (name);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.ft_path_insert()
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
  BEFORE INSERT ON api.path
  FOR EACH ROW
  EXECUTE PROCEDURE api.ft_path_insert();

--------------------------------------------------------------------------------
-- api.endpoint ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE api.endpoint (
    id			numeric(10) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_API'),
    definition	text NOT NULL
);

COMMENT ON TABLE api.endpoint IS 'API: Конечная точка.';

COMMENT ON COLUMN api.endpoint.id IS 'Идентификатор';
COMMENT ON COLUMN api.endpoint.definition IS 'PL/pgSQL код';

--------------------------------------------------------------------------------
-- api.route -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE api.route (
    method		text NOT NULL DEFAULT 'POST',
    path       	numeric(10) NOT NULL,
    endpoint	numeric(10) NOT NULL,
    CONSTRAINT pk_route PRIMARY KEY (method, path, endpoint),
    CONSTRAINT ch_route_method CHECK (method IN ('GET', 'POST', 'PUT', 'DELETE')),
    CONSTRAINT fk_route_path FOREIGN KEY (path) REFERENCES api.path(id),
    CONSTRAINT fk_route_endpoint FOREIGN KEY (endpoint) REFERENCES api.endpoint(id)
);

COMMENT ON TABLE api.route IS 'API: Маршрут.';

COMMENT ON COLUMN api.route.method IS 'HTTP-Метод';
COMMENT ON COLUMN api.route.path IS 'Путь';
COMMENT ON COLUMN api.route.endpoint IS 'Конечная точка';

CREATE INDEX ON api.route (method);
CREATE INDEX ON api.route (path);
CREATE INDEX ON api.route (endpoint);

--------------------------------------------------------------------------------
-- VIEW apiPath ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW apiPath
AS
  SELECT * FROM api.path;

GRANT SELECT ON apiPath TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.path_to_array --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.path_to_array (
  pPath			text
) RETURNS		text[]
AS $$
DECLARE
  i				integer;
  arPath		text[];
  vStr			text;
  vPath			text;
BEGIN
  vPath := pPath;

  IF NULLIF(vPath, '') IS NOT NULL THEN

    i := StrPos(vPath, '/');
    WHILE i > 0 LOOP
      vStr := SubStr(vPath, 1, i - 1);

      IF NULLIF(vStr, '') IS NOT NULL THEN
        arPath := array_append(arPath, vStr);
      END IF;

      vPath := SubStr(vPath, i + 1);
      i := StrPos(vPath, '/');
    END LOOP;

    IF NULLIF(vPath, '') IS NOT NULL THEN
      arPath := array_append(arPath, vPath);
    END IF;
  END IF;

  RETURN arPath;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.get_rest_path --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_rest_path (
  pId		numeric
) RETURNS	text
AS $$
DECLARE
  vPath		text;
  e		    record;
BEGIN
  FOR e IN
    WITH RECURSIVE tree(id, parent, path) AS (
      SELECT id, parent, path FROM api.path WHERE id = pId
    UNION ALL
      SELECT r.id, r.parent, r.path
        FROM api.path r INNER JOIN tree t ON r.id = t.parent
    )
    SELECT path FROM tree
  LOOP
    IF vPath IS NULL THEN
      vPath := e.path;
    ELSE
     vPath := e.path || '/' || vPath;
    END IF;
  END LOOP;

  RETURN coalesce('/' || vPath, '/');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.get_endpoint_definition ----------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_endpoint_definition (
  pId		numeric
) RETURNS	text
AS $$
  SELECT definition
    FROM api.endpoint
   WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.path --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.path (
  pId		numeric
) RETURNS	SETOF api.path
AS $$
  SELECT * FROM api.path WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.endpoint ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.endpoint (
  pId		numeric
) RETURNS	SETOF api.endpoint
AS $$
  SELECT * FROM api.endpoint WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddPath ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddPath (
  pRoot		numeric,
  pParent	numeric,
  pName     text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
  nLevel	integer;
BEGIN
  nLevel := 0;
  pParent := coalesce(pParent, pRoot);

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM api.path WHERE id = pParent;
  END IF;
 
  INSERT INTO api.path (root, parent, name, level)
  VALUES (pRoot, pParent, pName, nLevel)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetPathRoot --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetPathRoot (
  pPath		text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM api.path WHERE path = pPath AND level = 0;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetPath ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetPath (
  pParent		numeric,
  pName			text
) RETURNS		numeric
AS $$
DECLARE
  nId			numeric;
BEGIN
  IF pParent IS NULL THEN
    SELECT id INTO nId FROM api.path WHERE parent IS NULL AND name = pName;
  ELSE
    SELECT id INTO nId FROM api.path WHERE parent = pParent AND name = pName;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetEndpoint --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEndpoint (
  pPath			numeric,
  pMethod       text DEFAULT 'POST'
) RETURNS	    numeric
AS $$
DECLARE
  nEndpoint		numeric;
BEGIN
  SELECT endpoint INTO nEndpoint FROM api.route WHERE method = pMethod AND path = pPath;
  RETURN nEndpoint;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeletePath ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeletePath (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  DELETE FROM api.path WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteEndpoint -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteEndpoint (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  DELETE FROM api.endpoint WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeletePaths --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeletePaths (
  pId		numeric
) RETURNS	void
AS $$
DECLARE
  r		    record;
BEGIN
  FOR r IN SELECT id FROM api.path WHERE parent = pId
  LOOP
    PERFORM DeletePaths(r.id);
  END LOOP;

  PERFORM DeletePath(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteRouts --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteRouts (
  pPath			text
) RETURNS		boolean
AS $$
DECLARE
  nPath		numeric;
BEGIN
  nPath := FindPath(pPath);
  IF nPath IS NOT NULL THEN
    PERFORM DeleteRouts(nPath);
    RETURN true;
  ELSE
    PERFORM SetErrorMessage('API: Путь не найден.');
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegisterPath -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegisterPath (
  pPath			text
) RETURNS		numeric
AS $$
DECLARE
  nId			numeric;
  nRoot			numeric;
  nParent		numeric;

  arPath		text[];
  i				integer;
BEGIN
  IF pPath IS NOT NULL THEN

    arPath := api.path_to_array(pPath);

    FOR i IN 1..array_length(arPath, 1)
    LOOP
      nParent := coalesce(nId, nRoot);
      nId := GetPath(nParent, arPath[i]);

      IF nId IS NULL THEN
        nId := AddPath(nRoot, nParent, arPath[i]);
        IF nRoot IS NULL THEN
  		  nRoot := nId;
        END IF;
      END IF;
    END LOOP;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION FindPath -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION FindPath (
  pName			text
) RETURNS		numeric
AS $$
DECLARE
  nId			numeric;
  arPath		text[];
  i				integer;
BEGIN
  IF pName IS NOT NULL THEN
    arPath := api.path_to_array(pName);
    FOR i IN 1..array_length(arPath, 1)
    LOOP
      nId := GetPath(nId, arPath[i]);
    END LOOP;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION UnregisterPath -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UnregisterPath (
  pName			text
) RETURNS		boolean
AS $$
DECLARE
  nPath			numeric;
BEGIN
  nPath := FindPath(pName);
  IF nPath IS NOT NULL THEN
    PERFORM DeletePath(nPath);
    RETURN true;
  END IF;
  PERFORM SetErrorMessage('API: Путь не найден.');
  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegisterEndpoint ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegisterEndpoint (
  pPath			numeric,
  pDefinition	text,
  pMethod		text DEFAULT 'POST'
) RETURNS	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  nId := GetEndpoint(pPath, pMethod);

  IF not found THEN

	INSERT INTO api.endpoint (definition)
	VALUES (pDefinition)
	RETURNING id INTO nId;

  ELSE

	UPDATE api.endpoint
	   SET definition = coalesce(pDefinition, definition)
	 WHERE id = nId;

  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION UnregisterEndpoint -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UnregisterEndpoint (
  pPath			text,
  pMethod		text DEFAULT 'POST'
) RETURNS       boolean
AS $$
DECLARE
  nId			numeric;
  nPath		numeric;
BEGIN
  nPath := FindPath(pPath);
  IF nPath IS NOT NULL THEN
    nId := GetEndpoint(nPath, pMethod);
    IF nId IS NOT NULL THEN
      PERFORM DeleteEndpoint(nId);
      RETURN true;
    ELSE
      PERFORM SetErrorMessage('API: Конечная точка не найдена.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('API: Путь не найден.');
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
