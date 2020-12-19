--------------------------------------------------------------------------------
-- OBSERVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.publisher ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.publisher (
    code		text PRIMARY KEY,
    name		text NOT NULL,
	description text
);

COMMENT ON TABLE db.publisher IS 'Издатель.';

COMMENT ON COLUMN db.publisher.code IS 'Код';
COMMENT ON COLUMN db.publisher.name IS 'Наименование';
COMMENT ON COLUMN db.publisher.description IS 'Описание';

--------------------------------------------------------------------------------
-- VIEW Publisher --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Publisher
AS
  SELECT * FROM db.publisher;

GRANT SELECT ON Publisher TO administrator;

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
-- db.listener -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.listener (
    publisher	text NOT NULL,
    session		varchar(40) NOT NULL,
    filter		jsonb NOT NULL,
    params		jsonb NOT NULL,
    CONSTRAINT pk_listener PRIMARY KEY(publisher, session),
    CONSTRAINT fk_listener_publisher FOREIGN KEY (publisher) REFERENCES db.publisher(code),
    CONSTRAINT fk_listener_session FOREIGN KEY (session) REFERENCES db.session(code)
);

COMMENT ON TABLE db.listener IS 'Слушатель.';

COMMENT ON COLUMN db.listener.publisher IS 'Издатель';
COMMENT ON COLUMN db.listener.session IS 'Код сессии';
COMMENT ON COLUMN db.listener.filter IS 'Фильтр';
COMMENT ON COLUMN db.listener.params IS 'Параметры';

--------------------------------------------------------------------------------
-- VIEW Listener ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Listener
AS
  SELECT * FROM db.listener;

GRANT SELECT ON Listener TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION CreateListener -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateListener (
  pPublisher	text,
  pSession		varchar,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		void
AS $$
BEGIN
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

  INSERT INTO db.listener (publisher, session, filter, params)
  VALUES (pPublisher, pSession, pFilter, pParams);
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
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		boolean
AS $$
DECLARE
BEGIN
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
   WHERE publisher = pPublisher AND session = pSession;

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
  pSession		varchar
) RETURNS 		void
AS $$
BEGIN
  DELETE FROM db.listener WHERE publisher = pPublisher AND session = pSession;
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
    PERFORM WriteToEventLog('M', 5000, format('Запущен слушатель: %s.', r.code));
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckCodes ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckCodes (
  pSource		text[],
  pCodes		text[]
) RETURNS       text[]
AS $$
DECLARE
  arValid       text[];
  arInvalid     text[];
BEGIN
  IF pCodes IS NOT NULL THEN
    FOR i IN 1..array_length(pCodes, 1)
    LOOP
      IF array_position(pSource, pCodes[i]) IS NULL THEN
        arInvalid := array_append(arInvalid, pCodes[i]);
      ELSE
        arValid := array_append(arValid, pCodes[i]);
      END IF;
    END LOOP;

    IF arInvalid IS NOT NULL THEN

      IF arValid IS NULL THEN
        arValid := array_append(arValid, '');
      END IF;

      PERFORM InvalidCodes(arValid, arInvalid);
    END IF;
  END IF;

  RETURN arValid;
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

  arFilter		text[];
  arSource		text[];
BEGIN
  IF pPublisher = 'notify' THEN

  	arFilter := array_cat(arFilter, ARRAY['entities', 'classes', 'actions', 'methods', 'objects']);
  	PERFORM CheckJsonbKeys('/listener/filter', arFilter, pFilter);

	FOR r IN SELECT code FROM db.entity
	LOOP
	  arSource := array_append(arSource, r.code::text);
	END LOOP;

  	PERFORM CheckCodes(arSource, JsonbToStrArray(pFilter->'entities'));

    arSource := NULL;

	FOR r IN SELECT code FROM db.class_tree
	LOOP
	  arSource := array_append(arSource, r.code::text);
	END LOOP;

  	PERFORM CheckCodes(arSource, JsonbToStrArray(pFilter->'classes'));

    arSource := NULL;

	FOR r IN SELECT code FROM db.action
	LOOP
	  arSource := array_append(arSource, r.code::text);
	END LOOP;

  	PERFORM CheckCodes(arSource, JsonbToStrArray(pFilter->'actions'));

  ELSIF pPublisher = 'log' THEN
  	arFilter := array_cat(arFilter, ARRAY['types', 'codes', 'categories']);
  	PERFORM CheckJsonbKeys('/listener/filter', arFilter, pFilter);
  ELSIF pPublisher = 'geo' THEN
  	arFilter := array_cat(arFilter, ARRAY['codes', 'objects']);
  	PERFORM CheckJsonbKeys('/listener/filter', arFilter, pFilter);
  END IF;
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
  IF pPublisher = 'notify' THEN
	arParams := array_cat(null, ARRAY['type', 'hook']);
	PERFORM CheckJsonbKeys('/listener/params', arParams, pParams);

	type := pParams->>'type';

	arValues := array_cat(null, ARRAY['notify', 'object', 'hook']);
	IF array_position(arValues, type) IS NULL THEN
	  PERFORM IncorrectValueInArray(coalesce(type, '<null>'), 'type', arValues);
	END IF;

	IF type = 'hook' THEN
	  hook := pParams->'hook';

	  IF hook IS NULL THEN
		PERFORM JsonIsEmpty();
	  END IF;

	  arParams := array_cat(null, ARRAY['method', 'path', 'payload']);
	  PERFORM CheckJsonbKeys('/listener/params/hook', arParams, hook);

	  path := hook->>'path';
	  IF path IS NULL THEN
		PERFORM RouteIsEmpty();
	  END IF;

	  IF QueryPath(path) IS NULL THEN
		PERFORM RouteNotFound(path);
	  END IF;
	END IF;
  END IF;
END;
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

  nUserId		numeric;
  vUserName		text;

  vEntityCode	text;
  vClassCode	text;
  vActionCode	text;
  vMethodCode	text;
BEGIN
  SELECT userid INTO nUserId FROM db.session WHERE code = pSession;

  CASE pPublisher
  WHEN 'notify' THEN

	SELECT * INTO f FROM jsonb_to_record(pFilter) AS x(entities jsonb, classes jsonb, actions jsonb, methods jsonb, objects jsonb);
	SELECT * INTO d FROM jsonb_to_record(pData) AS x(entity numeric, class numeric, action numeric, method numeric, object numeric);

	SELECT code INTO vEntityCode FROM db.entity WHERE id = d.entity;
	SELECT code INTO vClassCode FROM db.class_tree WHERE id = d.class;
	SELECT code INTO vActionCode FROM db.action WHERE id = d.action;
	SELECT code INTO vMethodCode FROM db.method WHERE id = d.method;

	RETURN array_position(coalesce(JsonbToStrArray(f.entities), ARRAY[vEntityCode]), vEntityCode) IS NOT NULL AND
           array_position(coalesce(JsonbToStrArray(f.classes), ARRAY[vClassCode]), vClassCode) IS NOT NULL AND
           array_position(coalesce(JsonbToStrArray(f.actions), ARRAY[vActionCode]), vActionCode) IS NOT NULL AND
           array_position(coalesce(JsonbToStrArray(f.methods), ARRAY[vMethodCode]), vMethodCode) IS NOT NULL AND
           array_position(coalesce(JsonbToNumArray(f.objects), ARRAY[d.object]), d.object) IS NOT NULL AND
	       CheckObjectAccess(d.object, B'100', nUserId);

  WHEN 'log' THEN

    SELECT username INTO vUserName FROM db.user WHERE id = nUserId;

	SELECT * INTO f FROM jsonb_to_record(pFilter) AS x(types jsonb, codes jsonb, categories jsonb);
	SELECT * INTO d FROM jsonb_to_record(pData) AS x(type text, code numeric, category text);

	RETURN vUserName = pData->>'username' AND
	       array_position(coalesce(JsonbToStrArray(f.types), ARRAY[d.type]), d.type) IS NOT NULL AND
		   array_position(coalesce(JsonbToNumArray(f.codes), ARRAY[d.code]), d.code) IS NOT NULL AND
		   array_position(coalesce(JsonbToStrArray(f.categories), ARRAY[d.category]), d.category) IS NOT NULL;

  WHEN 'geo' THEN

	SELECT * INTO f FROM jsonb_to_record(pFilter) AS x(codes jsonb, objects jsonb);
	SELECT * INTO d FROM jsonb_to_record(pData) AS x(code text, object numeric);

	RETURN array_position(coalesce(JsonbToNumArray(f.codes), ARRAY[d.code]), d.code) IS NOT NULL AND
           array_position(coalesce(JsonbToNumArray(f.objects), ARRAY[d.object]), d.object) IS NOT NULL AND
	       CheckObjectAccess(d.object, B'100', nUserId);

  ELSE
  	RETURN false;
  END CASE;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EventListener ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventListener (
  pPublisher	text,
  pSession		varchar,
  pData			jsonb
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;
  e             record;

  type			text;
  hook			jsonb;
BEGIN
  SELECT * INTO r FROM db.listener WHERE publisher = pPublisher AND session = pSession;

  IF FOUND AND FilterListener(r.publisher, r.session, r.filter, pData) THEN
	type := r.params->>'type';
	hook := r.params->'hook';

	IF type = 'object' THEN
	  FOR e IN EXECUTE format('SELECT * FROM api.get_%s($1)', GetEntityCode((pData->>'entity')::numeric)) USING (pData->>'object')::numeric
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	ELSIF type = 'hook' THEN
	  FOR e IN SELECT * FROM api.run(coalesce(hook->>'method', 'POST'), hook->>'path', hook->'payload')
	  LOOP
		RETURN NEXT e.run;
	  END LOOP;
	ELSE
	  RETURN NEXT pData;
	END IF;
  END IF;

  RETURN;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
