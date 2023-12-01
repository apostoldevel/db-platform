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
  uId		uuid;
  nLevel	integer;
BEGIN
  nLevel := 0;
  pParent := coalesce(pParent, pRoot);

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.path WHERE id = pParent;
  END IF;

  INSERT INTO db.path (root, parent, name, level)
  VALUES (pRoot, pParent, pName, nLevel)
  RETURNING id INTO uId;

  RETURN uId;
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
  uId			uuid;
BEGIN
  IF pParent IS NULL THEN
    SELECT id INTO uId FROM db.path WHERE parent IS NULL AND name = pName;
  ELSE
    SELECT id INTO uId FROM db.path WHERE parent = pParent AND name = pName;
  END IF;

  RETURN uId;
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
  uId			uuid;
BEGIN
  INSERT INTO db.endpoint (definition)
  VALUES (pDefinition)
  RETURNING id INTO uId;

  RETURN uId;
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
  uId			uuid;
  uRoot			uuid;
  uParent		uuid;

  arPath		text[];
  i				integer;
BEGIN
  IF pPath IS NOT NULL THEN
    arPath := path_to_array(pPath);
    FOR i IN 1..array_length(arPath, 1)
    LOOP
      uParent := coalesce(uId, uRoot);
      uId := GetPath(uParent, arPath[i]);

      IF uId IS NULL THEN
        uId := AddPath(uRoot, uParent, arPath[i]);
        IF uRoot IS NULL THEN
  		  uRoot := uId;
        END IF;
      END IF;
    END LOOP;
  END IF;

  RETURN uId;
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
  uPath			uuid;
BEGIN
  uPath := FindPath(pPath);
  IF uPath IS NOT NULL THEN
    PERFORM DeletePath(uPath);
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
  uId			uuid;
  arPath		text[];
  i				integer;
BEGIN
  IF pPath IS NOT NULL THEN
    arPath := path_to_array(pPath);
    FOR i IN 1..array_length(arPath, 1)
    LOOP
      uId := GetPath(uId, arPath[i]);
    END LOOP;
  END IF;

  RETURN uId;
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
  uId			uuid;
  uParent		uuid;
  arPath		text[];
  Index			integer;
BEGIN
  IF pPath IS NOT NULL THEN
    arPath := path_to_array(pPath);
    IF array_length(arPath, 1) > 0 THEN
      Index := 1;
      uId := GetPath(uParent, arPath[Index]);
	  WHILE uId IS NOT NULL
	  LOOP
	    uParent := uId;
        Index := Index + 1;
        uId := GetPath(uParent, arPath[Index]);
	  END LOOP;
	END IF;
  END IF;

  RETURN coalesce(uId, uParent);
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

  uObject		uuid;
  uAction		uuid;

  arKeys		text[];
BEGIN
  IF current_session() IS NULL THEN
	PERFORM LoginFailed();
  END IF;

  SELECT GetAction(x[2]) INTO uAction FROM path_to_array(pPath) AS x;

  IF uAction IS NULL THEN
    PERFORM RouteNotFound(pPath);
  END IF;

  arKeys := array_cat(arKeys, ARRAY['id', 'params']);
  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, params jsonb)
  LOOP
	IF r.id IS NULL THEN
	  PERFORM ObjectIsNull();
	END IF;

	SELECT id INTO uObject FROM db.object WHERE id = r.id;

	IF NOT FOUND THEN
	  PERFORM ObjectNotFound('object', 'id', r.id);
	END IF;

	RETURN ExecuteObjectAction(uObject, uAction, r.params);
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
  uPath			uuid;
BEGIN
  pPath := '/' || pNamespace || '/' || pVersion || coalesce('/' || pPath, '');

  uPath := FindPath(pPath);

  IF uPath IS NULL THEN
	uPath := RegisterPath(pPath);
  END IF;

  FOR i IN 1..array_length(pMethod, 1)
  LOOP
    INSERT INTO db.route (method, path, endpoint)
    VALUES (pMethod[i], uPath, pEndpoint);
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
  r             record;
  uPath			uuid;
BEGIN
  pPath := '/' || pNamespace || '/' || pVersion || coalesce('/' || pPath, '');

  uPath := FindPath(pPath);
  IF uPath IS NOT NULL THEN
	FOR r IN SELECT unnest(pMethod) AS method
	LOOP
      DELETE FROM db.route WHERE method = r.method AND path = uPath;
	END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
