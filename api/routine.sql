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
  pRoot		uuid,
  pParent	uuid,
  pName     text
) RETURNS	uuid
AS $$
DECLARE
  nId		uuid;
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
  pParent		uuid,
  pName			text
) RETURNS		uuid
AS $$
DECLARE
  nId			uuid;
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
  pId		uuid
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
  pId		uuid
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
) RETURNS		uuid
AS $$
DECLARE
  nId			uuid;
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
  pId			uuid,
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
  pPath			uuid,
  pMethod       text DEFAULT 'POST'
) RETURNS	    uuid
AS $$
DECLARE
  nEndpoint		uuid;
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
  pId		uuid
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
  pId		uuid
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
) RETURNS		uuid
AS $$
DECLARE
  nId			uuid;
  nRoot			uuid;
  nParent		uuid;

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
  nPath			uuid;
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
) RETURNS		uuid
AS $$
DECLARE
  nId			uuid;
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
) RETURNS		uuid
AS $$
DECLARE
  nId			uuid;
  nParent		uuid;
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
  pId		uuid
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
-- FUNCTION ExecuteDynamicMethod -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteDynamicMethod (
  pPath     	text,
  pPayload  	jsonb
) RETURNS		jsonb
AS $$
DECLARE
  r				record;

  nObject		uuid;
  nAction		uuid;

  arKeys		text[];
BEGIN
  IF current_session() IS NULL THEN
	PERFORM LoginFailed();
  END IF;

  SELECT GetAction(x[2]) INTO nAction FROM path_to_array(pPath) AS x;

  IF nAction IS NULL THEN
    PERFORM RouteNotFound(pPath);
  END IF;

  arKeys := array_cat(arKeys, ARRAY['id', 'params']);
  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, params jsonb)
  LOOP
	IF r.id IS NULL THEN
	  PERFORM ObjectIsNull();
	END IF;

	SELECT id INTO nObject FROM db.object WHERE id = r.id;

	IF NOT FOUND THEN
	  PERFORM ObjectNotFound('object', 'id', r.id);
	END IF;

	RETURN ExecuteObjectAction(nObject, nAction, r.params);
  END LOOP;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegisterRoute ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegisterRoute (
  pPath			text,
  pEndpoint		uuid,
  pVersion		text DEFAULT 'v1',
  pNamespace	text DEFAULT 'api',
  pMethod		text[] DEFAULT ARRAY['GET','POST']
) RETURNS	    void
AS $$
DECLARE
  nPath			uuid;
BEGIN
  pPath := '/' || pNamespace || '/' || pVersion || coalesce('/' || pPath, '');

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
  pVersion		text DEFAULT 'v1',
  pNamespace	text DEFAULT 'api',
  pMethod		text[] DEFAULT ARRAY['GET','POST']
) RETURNS	    void
AS $$
DECLARE
  nPath			uuid;
BEGIN
  pPath := '/' || pNamespace || '/' || pVersion || coalesce('/' || pPath, '');

  nPath := FindPath(pPath);
  IF nPath IS NULL THEN
    DELETE FROM db.route WHERE method = pMethod AND path = nPath;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
