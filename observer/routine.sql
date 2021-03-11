--------------------------------------------------------------------------------
-- FUNCTION CreatePublisher ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreatePublisher (
  pCode   		text,
  pName			text,
  pDescription	text DEFAULT null
) RETURNS		void
AS $$
BEGIN
  INSERT INTO db.publisher (code, name, description)
  VALUES (pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditPublisher ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditPublisher (
  pCode   		text,
  pName			text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS		void
AS $$
BEGIN
  UPDATE db.publisher
     SET name = coalesce(pName, name),
         description = coalesce(pDescription, description)
   WHERE code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeletePublisher ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeletePublisher (
  pCode   		text
) RETURNS 		void
AS $$
BEGIN
  DELETE FROM db.publisher WHERE code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CreateListener -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateListener (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		void
AS $$
BEGIN
  pIdentity := coalesce(pIdentity, 'main');

  IF NOT ValidSession(pSession) THEN
	RAISE EXCEPTION 'ERR-40000: %', GetErrorMessage();
  END IF;

  IF pFilter IS NOT NULL THEN
    PERFORM CheckListenerFilter(pPublisher, pFilter);
  ELSE
	pFilter := '{}';
  END IF;

  IF pParams IS NOT NULL THEN
    PERFORM CheckListenerParams(pPublisher, pParams);
  ELSE
	pParams := '{"type": "notify"}';
  END IF;

  INSERT INTO db.listener (publisher, session, identity, filter, params)
  VALUES (pPublisher, pSession, pIdentity, pFilter, pParams);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditListener -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditListener (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		boolean
AS $$
BEGIN
  pIdentity := coalesce(pIdentity, 'main');

  IF pSession IS NOT NULL AND NOT ValidSession(pSession) THEN
	RAISE EXCEPTION 'ERR-40000: %', GetErrorMessage();
  END IF;

  IF pFilter IS NOT NULL THEN
    PERFORM CheckListenerFilter(pPublisher, pFilter);
  ELSE
	pFilter := '{}';
  END IF;

  IF pParams IS NOT NULL THEN
    PERFORM CheckListenerParams(pPublisher, pParams);
  ELSE
	pParams := '{"type": "notify"}';
  END IF;

  UPDATE db.listener
     SET filter = pFilter,
         params = pParams
   WHERE publisher = pPublisher AND session = pSession AND identity = pIdentity;

  RETURN FOUND;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteListener -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteListener (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text DEFAULT null
) RETURNS 		boolean
AS $$
BEGIN
  pIdentity := coalesce(pIdentity, 'main');
  DELETE FROM db.listener WHERE publisher = pPublisher AND session = pSession AND identity = pIdentity;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION InitListen ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitListen (
) RETURNS 		void
AS $$
DECLARE
  r				record;
BEGIN
  FOR r IN SELECT * FROM db.publisher
  LOOP
	EXECUTE format('LISTEN %s;', r.code);
    PERFORM WriteToEventLog('M', 5000, 'listen', format('Запущен слушатель: %s.', r.code));
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoCheckListenerFilter ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoCheckListenerFilter (
  pPublisher	text,
  pFilter		jsonb
) RETURNS		void
AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CheckListenerFilter ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckListenerFilter (
  pPublisher	text,
  pFilter		jsonb
) RETURNS		void
AS $$
DECLARE
  r				record;

  nMethod		uuid;

  arFilter		text[];
  arSource		text[];
BEGIN
  CASE pPublisher
  WHEN 'notify' THEN
  	arFilter := array_cat(arFilter, ARRAY['entities', 'classes', 'actions', 'methods', 'objects']);
  	PERFORM CheckJsonbKeys('/listener/notify/filter', arFilter, pFilter);

	FOR r IN SELECT code FROM db.entity
	LOOP
	  arSource := array_append(arSource, r.code);
	END LOOP;

  	PERFORM CheckCodes(arSource, JsonbToStrArray(pFilter->'entities'));

    arSource := NULL;

	FOR r IN SELECT code FROM db.class_tree
	LOOP
	  arSource := array_append(arSource, r.code);
	END LOOP;

  	PERFORM CheckCodes(arSource, JsonbToStrArray(pFilter->'classes'));

    arSource := NULL;

	FOR r IN SELECT code FROM db.action
	LOOP
	  arSource := array_append(arSource, r.code);
	END LOOP;

  	PERFORM CheckCodes(arSource, JsonbToStrArray(pFilter->'actions'));

    IF jsonb_typeof(pFilter->'methods') = 'array' THEN
	  FOR r IN SELECT * FROM jsonb_array_elements_text(pFilter->'methods')
	  LOOP
		SELECT id INTO nMethod FROM db.method WHERE code = r.value;
		IF NOT FOUND THEN
		  RAISE EXCEPTION 'ERR-40000: Не найден метод по коду "%".', r.value;
		END IF;
	  END LOOP;
	ELSE
      PERFORM IncorrectJsonType(jsonb_typeof(pFilter->'methods'), 'array');
    END IF;

  WHEN 'notice' THEN
  	arFilter := array_cat(arFilter, ARRAY['categories']);
  	PERFORM CheckJsonbKeys('/listener/notice/filter', arFilter, pFilter);

  WHEN 'log' THEN
  	arFilter := array_cat(arFilter, ARRAY['types', 'codes', 'categories']);
  	PERFORM CheckJsonbKeys('/listener/log/filter', arFilter, pFilter);

  WHEN 'geo' THEN
  	arFilter := array_cat(arFilter, ARRAY['codes', 'objects']);
  	PERFORM CheckJsonbKeys('/listener/geo/filter', arFilter, pFilter);

  ELSE
  	PERFORM DoCheckListenerFilter(pPublisher, pFilter);
  END CASE;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoCheckListenerParams ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoCheckListenerParams (
  pPublisher	text,
  pParams		jsonb
) RETURNS		void
AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CheckListenerParams ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckListenerParams (
  pPublisher	text,
  pParams		jsonb
) RETURNS		void
AS $$
DECLARE
  type			text;
  path			text;

  hook			jsonb;

  arParams		text[];
  arValues      text[];
BEGIN
  CASE pPublisher
  WHEN 'notify' THEN
	arParams := array_cat(null, ARRAY['type', 'hook']);
	PERFORM CheckJsonbKeys('/listener/notify/params', arParams, pParams);

	type := pParams->>'type';

	arValues := array_cat(null, ARRAY['notify', 'object', 'mixed', 'hook']);
	IF array_position(arValues, type) IS NULL THEN
	  PERFORM IncorrectValueInArray(coalesce(type, '<null>'), 'type', arValues);
	END IF;

	IF type = 'hook' THEN
	  hook := pParams->'hook';

	  IF hook IS NULL THEN
		PERFORM JsonIsEmpty();
	  END IF;

	  arParams := array_cat(null, ARRAY['method', 'path', 'payload']);
	  PERFORM CheckJsonbKeys('/listener/notify/params/hook', arParams, hook);

	  path := hook->>'path';
	  IF path IS NULL THEN
		PERFORM RouteIsEmpty();
	  END IF;

	  IF QueryPath(path) IS NULL THEN
		PERFORM RouteNotFound(path);
	  END IF;
	END IF;

  WHEN 'notice' THEN
	arParams := array_cat(null, ARRAY['type']);
	PERFORM CheckJsonbKeys('/listener/notice/params', arParams, pParams);

	type := pParams->>'type';

	arValues := array_cat(null, ARRAY['notify']);
	IF array_position(arValues, type) IS NULL THEN
	  PERFORM IncorrectValueInArray(coalesce(type, '<null>'), 'type', arValues);
	END IF;

  WHEN 'log' THEN
	arParams := array_cat(null, ARRAY['type']);
	PERFORM CheckJsonbKeys('/listener/log/params', arParams, pParams);

	type := pParams->>'type';

	arValues := array_cat(null, ARRAY['notify']);
	IF array_position(arValues, type) IS NULL THEN
	  PERFORM IncorrectValueInArray(coalesce(type, '<null>'), 'type', arValues);
	END IF;

  WHEN 'geo' THEN
	arParams := array_cat(null, ARRAY['type']);
	PERFORM CheckJsonbKeys('/listener/geo/params', arParams, pParams);

	type := pParams->>'type';

	arValues := array_cat(null, ARRAY['notify']);
	IF array_position(arValues, type) IS NULL THEN
	  PERFORM IncorrectValueInArray(coalesce(type, '<null>'), 'type', arValues);
	END IF;

  ELSE
  	PERFORM DoCheckListenerParams(pPublisher, pParams);
  END CASE;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoFilterListener ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoFilterListener (
  pPublisher	text,
  pUserId		uuid,
  pFilter		jsonb,
  pData			jsonb
) RETURNS		boolean
AS $$
BEGIN
  RETURN false;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION FilterListener -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION FilterListener (
  pPublisher	text,
  pSession		varchar,
  pFilter		jsonb,
  pData			jsonb
) RETURNS		boolean
AS $$
DECLARE
  f				record;
  d				record;
  n				record;

  nUserId		uuid;
  vUserName		text;
BEGIN
  SELECT userid INTO nUserId FROM db.session WHERE code = pSession;

  CASE pPublisher
  WHEN 'notify' THEN

	SELECT * INTO f FROM jsonb_to_record(pFilter) AS x(entities jsonb, classes jsonb, actions jsonb, methods jsonb, objects jsonb);
	SELECT * INTO d FROM jsonb_to_record(pData) AS x(id uuid, entity uuid, class uuid, action uuid, method uuid, object uuid);
	SELECT * INTO n FROM Notification WHERE id = d.id;

	RETURN array_position(coalesce(JsonbToStrArray(f.entities), ARRAY[n.entitycode]), n.entitycode::text) IS NOT NULL AND
           array_position(coalesce(JsonbToStrArray(f.classes) , ARRAY[n.classcode]) , n.classcode::text ) IS NOT NULL AND
           array_position(coalesce(JsonbToStrArray(f.actions) , ARRAY[n.actioncode]), n.actioncode::text) IS NOT NULL AND
           array_position(coalesce(JsonbToStrArray(f.methods) , ARRAY[n.methodcode]), n.methodcode::text) IS NOT NULL AND
           array_position(coalesce(JsonbToUUIDArray(f.objects) , ARRAY[d.object])    , d.object    ) IS NOT NULL AND
	       CheckObjectAccess(d.object, B'100', nUserId);

  WHEN 'notice' THEN

	SELECT * INTO f FROM jsonb_to_record(pFilter) AS x(categories jsonb);
	SELECT * INTO d FROM jsonb_to_record(pData) AS x(userid uuid, object uuid, category text);

	RETURN d.userid = nUserId AND
		   array_position(coalesce(JsonbToStrArray(f.categories), ARRAY[d.category]), d.category) IS NOT NULL;

  WHEN 'log' THEN

    SELECT username INTO vUserName FROM db.user WHERE id = nUserId;

	SELECT * INTO f FROM jsonb_to_record(pFilter) AS x(types jsonb, codes jsonb, categories jsonb);
	SELECT * INTO d FROM jsonb_to_record(pData) AS x(type text, code integer, username text, category text);

	RETURN vUserName = d.username AND
	       array_position(coalesce(JsonbToStrArray(f.types), ARRAY[d.type]), d.type) IS NOT NULL AND
		   array_position(coalesce(JsonbToNumArray(f.codes), ARRAY[d.code]), d.code) IS NOT NULL AND
		   array_position(coalesce(JsonbToStrArray(f.categories), ARRAY[d.category]), d.category) IS NOT NULL;

  WHEN 'geo' THEN

	SELECT * INTO f FROM jsonb_to_record(pFilter) AS x(codes jsonb, objects jsonb);
	SELECT * INTO d FROM jsonb_to_record(pData) AS x(code text, object uuid);

	RETURN array_position(coalesce(JsonbToStrArray(f.codes), ARRAY[d.code]), d.code) IS NOT NULL AND
           array_position(coalesce(JsonbToUUIDArray(f.objects), ARRAY[d.object]), d.object) IS NOT NULL AND
	       CheckObjectAccess(d.object, B'100', nUserId);

  ELSE
  	RETURN DoFilterListener(pPublisher, nUserId, pFilter, pData);
  END CASE;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoEventListener ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoEventListener (
  pPublisher	text,
  pData			jsonb
) RETURNS       SETOF json
AS $$
BEGIN
  RETURN NEXT pData;
  RETURN;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EventListener ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventListener (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text,
  pData			jsonb
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;
  e             record;

  nId			uuid;

  vType			text;

  mixed			jsonb;
  hook			jsonb;
BEGIN
  pIdentity := coalesce(pIdentity, 'main');

  SELECT * INTO r FROM db.listener WHERE publisher = pPublisher AND session = pSession AND identity = pIdentity;

  IF FOUND AND FilterListener(r.publisher, r.session, r.filter, pData) THEN

	CASE pPublisher
	WHEN 'notify' THEN
	  vType := r.params->>'type';
	  IF vType = 'object' THEN
		FOR e IN EXECUTE format('SELECT * FROM api.get_%s($1)', GetEntityCode((pData->>'entity')::uuid)) USING (pData->>'object')::uuid
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  ELSIF vType = 'mixed' THEN
	    nId := pData->>'id';

        mixed := jsonb_build_object();

		FOR e IN SELECT * FROM Notification WHERE id = nId
		LOOP
		  mixed := jsonb_build_object('notify', row_to_json(e));
		END LOOP;

		FOR e IN EXECUTE format('SELECT * FROM api.get_%s($1)', GetEntityCode((pData->>'entity')::uuid)) USING (pData->>'object')::uuid
		LOOP
		  mixed := mixed || jsonb_build_object('object', row_to_json(e));
		END LOOP;

        RETURN NEXT mixed;
	  ELSIF vType = 'hook' THEN
        hook := r.params->'hook';
		FOR e IN SELECT * FROM api.run(coalesce(hook->>'method', 'POST'), hook->>'path', hook->'payload')
		LOOP
		  RETURN NEXT e.run;
		END LOOP;
	  ELSE
	    nId := pData->>'id';
		FOR e IN SELECT * FROM Notification WHERE id = nId
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END IF;

    WHEN 'notice' THEN
	  nId := pData->>'id';
	  FOR e IN SELECT * FROM Notice WHERE id = nId
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;

    WHEN 'log' THEN
	  nId := pData->>'id';
	  FOR e IN SELECT * FROM EventLog WHERE id = nId
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;

    WHEN 'geo' THEN
	  nId := pData->>'id';
	  FOR e IN SELECT * FROM ObjectCoordinates WHERE id = nId
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM DoEventListener(pPublisher, pData) AS data
	  LOOP
		RETURN NEXT r.data;
	  END LOOP;

	END CASE;
  END IF;

  RETURN;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
