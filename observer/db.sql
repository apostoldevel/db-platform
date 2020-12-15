--------------------------------------------------------------------------------
-- OBSERVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.publisher ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.publisher (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		text NOT NULL,
    name		text NOT NULL,
	description text
);

COMMENT ON TABLE db.publisher IS 'Издатель.';

COMMENT ON COLUMN db.publisher.id IS 'Идентификатор';
COMMENT ON COLUMN db.publisher.code IS 'Код';
COMMENT ON COLUMN db.publisher.name IS 'Наименование';
COMMENT ON COLUMN db.publisher.description IS 'Описание';

CREATE INDEX ON db.publisher (code);

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
) RETURNS		numeric
AS $$
DECLARE
  nId			numeric;
BEGIN
  INSERT INTO db.publisher (code, name, description)
  VALUES (pCode, pName, pDescription)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditPublisher ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditPublisher (
  pId       	numeric,
  pCode   		text DEFAULT null,
  pName			text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS		void
AS $$
BEGIN
  UPDATE db.publisher
     SET code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = coalesce(pDescription, description)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeletePublisher ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeletePublisher (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.publisher WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetPublisher -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetPublisher (
  pCode         text
) RETURNS       numeric
AS $$
DECLARE
  nId			numeric;
BEGIN
  SELECT id INTO nId FROM db.publisher WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetPublisherCode ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetPublisherCode (
  pId			numeric
) RETURNS       text
AS $$
DECLARE
  vCode			text;
BEGIN
  SELECT code INTO vCode FROM db.publisher WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.listener -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.listener (
    publisher	numeric(12) NOT NULL,
    session		varchar(40) NOT NULL,
    filter		jsonb NOT NULL,
    params		jsonb NOT NULL,
    CONSTRAINT pk_listener PRIMARY KEY(publisher, session),
    CONSTRAINT fk_listener_publisher FOREIGN KEY (publisher) REFERENCES db.publisher(id),
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
  SELECT l.publisher, o.code, o.name, o.description, l.session, l.filter, l.params
    FROM db.listener l INNER JOIN publisher o on l.publisher = o.id;

GRANT SELECT ON Listener TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION CreateListener -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateListener (
  pPublisher	numeric,
  pSession		text,
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
  pPublisher	numeric,
  pSession		text,
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
  pPublisher	numeric,
  pSession		text
) RETURNS 		void
AS $$
BEGIN
  DELETE FROM db.listener WHERE publisher = pPublisher AND session = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CheckListenerFilter ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckListenerFilter (
  pPublisher	numeric,
  pFilter		jsonb
) RETURNS		void
AS $$
DECLARE
  vCode			text;
  arFilter		text[];
BEGIN
  vCode := GetPublisherCode(pPublisher);
  IF vCode = 'notify' THEN
  	arFilter := array_cat(arFilter, ARRAY['entities', 'classes', 'actions', 'methods', 'objects']);
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
  pPublisher	numeric,
  pParams		jsonb
) RETURNS		void
AS $$
DECLARE
  vCode			text;

  type			text;
  path			text;

  hook			jsonb;

  arParams		text[];
  arValues      text[];
BEGIN
  vCode := GetPublisherCode(pPublisher);
  IF vCode = 'notify' THEN
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
-- FUNCTION IsListenerFilter ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IsListenerFilter (
  pPublisher	text,
  pFilter		jsonb,
  pEntity		text,
  pClass		text,
  pAction		text,
  pMethod		text,
  pObject		numeric
) RETURNS		boolean
AS $$
DECLARE
  r				record;
BEGIN
  IF pPublisher = 'notify' THEN
	FOR r IN SELECT * FROM jsonb_to_record(pFilter) AS x(entities jsonb, classes jsonb, actions jsonb, methods jsonb, objects jsonb)
	LOOP
	  IF array_position(coalesce(JsonbToStrArray(r.entities), ARRAY[pEntity]), pEntity) IS NOT NULL AND
		 array_position(coalesce(JsonbToStrArray(r.classes) , ARRAY[pClass]) , pClass ) IS NOT NULL AND
		 array_position(coalesce(JsonbToStrArray(r.actions) , ARRAY[pAction]), pAction) IS NOT NULL AND
		 array_position(coalesce(JsonbToStrArray(r.methods) , ARRAY[pMethod]), pMethod) IS NOT NULL AND
		 array_position(coalesce(JsonbToNumArray(r.objects) , ARRAY[pObject]), pObject) IS NOT NULL
	  THEN
		 RETURN true;
	  END IF;
	END LOOP;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
