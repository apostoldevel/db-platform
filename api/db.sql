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

--------------------------------------------------------------------------------
-- FUNCTION path_to_array ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION path_to_array (
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
    SELECT level + 1 INTO nLevel FROM db.path WHERE id = pParent;
  END IF;
 
  INSERT INTO db.path (root, parent, name, level)
  VALUES (pRoot, pParent, pName, nLevel)
  RETURNING id INTO nId;

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
    SELECT id INTO nId FROM db.path WHERE parent IS NULL AND name = pName;
  ELSE
    SELECT id INTO nId FROM db.path WHERE parent = pParent AND name = pName;
  END IF;

  RETURN nId;
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
  DELETE FROM db.path WHERE id = pId;
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
  FOR r IN SELECT id FROM db.path WHERE parent = pId
  LOOP
    PERFORM DeletePaths(r.id);
  END LOOP;

  PERFORM DeletePath(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddEndPoint --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddEndPoint (
  pDefinition	text
) RETURNS		numeric
AS $$
DECLARE
  nId			numeric;
BEGIN
  INSERT INTO db.endpoint (definition)
  VALUES (pDefinition)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditEndPoint -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditEndPoint (
  pId			numeric,
  pDefinition	text
) RETURNS		void
AS $$
BEGIN
  UPDATE db.endpoint
	 SET definition = coalesce(pDefinition, definition)
   WHERE id = pId;
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
  SELECT endpoint INTO nEndpoint FROM db.route WHERE method = pMethod AND path = pPath;
  RETURN nEndpoint;
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
  DELETE FROM db.endpoint WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetEndpointDefinition ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEndpointDefinition (
  pId		numeric
) RETURNS	text
AS $$
  SELECT definition FROM db.endpoint WHERE id = pId
$$ LANGUAGE SQL
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
    arPath := path_to_array(pPath);
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
-- FUNCTION UnregisterPath -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UnregisterPath (
  pPath			text
) RETURNS		void
AS $$
DECLARE
  nPath			numeric;
BEGIN
  nPath := FindPath(pPath);
  IF nPath IS NOT NULL THEN
    PERFORM DeletePath(nPath);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION FindPath -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION FindPath (
  pPath			text
) RETURNS		numeric
AS $$
DECLARE
  nId			numeric;
  arPath		text[];
  i				integer;
BEGIN
  IF pPath IS NOT NULL THEN
    arPath := path_to_array(pPath);
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
-- FUNCTION QueryPath ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION QueryPath (
  pPath			text
) RETURNS		numeric
AS $$
DECLARE
  nId			numeric;
  nParent		numeric;
  arPath		text[];
  Index			integer;
BEGIN
  IF pPath IS NOT NULL THEN
    arPath := path_to_array(pPath);
    IF array_length(arPath, 1) > 0 THEN
      Index := 1;
      nId := GetPath(nParent, arPath[Index]);
	  WHILE nId IS NOT NULL
	  LOOP
	    nParent := nId;
        Index := Index + 1;
        nId := GetPath(nParent, arPath[Index]);
	  END LOOP;
	END IF;
  END IF;

  RETURN coalesce(nId, nParent);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CollectPath --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CollectPath (
  pId		numeric
) RETURNS	text
AS $$
DECLARE
  r		    record;
  vPath		text;
BEGIN
  FOR r IN
    WITH RECURSIVE tree(id, parent, name) AS (
      SELECT id, parent, name FROM db.path WHERE id = pId
    UNION ALL
      SELECT p.id, p.parent, p.name
        FROM db.path p INNER JOIN tree t ON p.id = t.parent
    )
    SELECT name FROM tree
  LOOP
    IF vPath IS NULL THEN
      vPath := r.name;
    ELSE
     vPath := r.name || '/' || vPath;
    END IF;
  END LOOP;

  RETURN coalesce('/' || vPath, '/');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegisterRoute ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegisterRoute (
  pPath			text,
  pEndpoint		numeric,
  pMethod		text[] DEFAULT ARRAY['GET','POST']
) RETURNS	    void
AS $$
DECLARE
  nPath			numeric;
BEGIN
  nPath := FindPath(pPath);

  IF nPath IS NULL THEN
	nPath := RegisterPath(pPath);
  END IF;

  FOR i IN 1..array_length(pMethod, 1)
  LOOP
    INSERT INTO db.route (method, path, endpoint)
    VALUES (pMethod[i], nPath, pEndpoint);
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION UnregisterRoute ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UnregisterRoute (
  pPath			text,
  pMethod		text DEFAULT 'POST'
) RETURNS       void
AS $$
DECLARE
  nPath			numeric;
BEGIN
  nPath := FindPath(pPath);
  IF nPath IS NULL THEN
    DELETE FROM db.route WHERE method = pMethod AND path = nPath;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW Routs ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Routs
AS
  SELECT r.method, CollectPath(r.path) AS path, e.definition
    FROM db.route r INNER JOIN db.endpoint e ON r.endpoint = e.id;

GRANT SELECT ON Routs TO administrator;
