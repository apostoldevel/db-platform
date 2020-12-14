--------------------------------------------------------------------------------
-- OBSERVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.observer -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.observer (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		text NOT NULL,
    name		text NOT NULL,
	description text
);

COMMENT ON TABLE db.observer IS 'Наблюдатель.';

COMMENT ON COLUMN db.observer.id IS 'Идентификатор';
COMMENT ON COLUMN db.observer.code IS 'Код';
COMMENT ON COLUMN db.observer.name IS 'Наименование';
COMMENT ON COLUMN db.observer.description IS 'Описание';

CREATE INDEX ON db.observer (code);

--------------------------------------------------------------------------------
-- VIEW Observer ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Observer
AS
  SELECT * FROM db.observer;

GRANT SELECT ON Observer TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION CreateObserver -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateObserver (
  pCode   		text,
  pName			text,
  pDescription	text DEFAULT null
) RETURNS		numeric
AS $$
DECLARE
  nId			numeric;
BEGIN
  INSERT INTO db.observer (code, name, description)
  VALUES (pCode, pName, pDescription)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditObserver -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObserver (
  pId       	numeric,
  pCode   		text DEFAULT null,
  pName			text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS		void
AS $$
BEGIN
  UPDATE db.observer
     SET code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = coalesce(pDescription, description)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteObserver -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObserver (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.observer WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObserver --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObserver (
  pCode         text
) RETURNS       numeric
AS $$
DECLARE
  nId			numeric;
BEGIN
  SELECT id INTO nId FROM db.observer WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.listener -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.listener (
    observer	numeric(12) NOT NULL,
    session		varchar(40) NOT NULL,
    filter		jsonb NOT NULL,
    CONSTRAINT pk_listener PRIMARY KEY(observer, session),
    CONSTRAINT fk_listener_observer FOREIGN KEY (observer) REFERENCES db.observer(id),
    CONSTRAINT fk_listener_session FOREIGN KEY (session) REFERENCES db.session(code)
);

COMMENT ON TABLE db.listener IS 'Слушатель.';

COMMENT ON COLUMN db.listener.observer IS 'Наблюдатель';
COMMENT ON COLUMN db.listener.session IS 'Код сессии';
COMMENT ON COLUMN db.listener.filter IS 'Фильтр';

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
  pObserver		numeric,
  pSession		text,
  pFilter		jsonb
) RETURNS		void
AS $$
BEGIN
  IF NOT ValidSession(pSession) THEN
	RAISE EXCEPTION 'ERR-40000: %', GetErrorMessage();
  END IF;

  INSERT INTO db.listener (observer, session, filter)
  VALUES (pObserver, pSession, pFilter);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditListener -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditListener (
  pObserver		numeric,
  pSession		text,
  pFilter		jsonb
) RETURNS		boolean
AS $$
BEGIN
  IF pSession IS NOT NULL AND NOT ValidSession(pSession) THEN
	RAISE EXCEPTION 'ERR-40000: %', GetErrorMessage();
  END IF;

  UPDATE db.listener
     SET filter = pFilter
   WHERE observer = pObserver AND session = pSession;

  RETURN FOUND;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteListener -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteListener (
  pObserver		numeric,
  pSession		text
) RETURNS 		void
AS $$
BEGIN
  DELETE FROM db.listener WHERE observer = pObserver AND session = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CheckListenerFilter ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckListenerFilter (
  pObserver		text,
  pSession		text,
  pEntity		text,
  pClass		text,
  pAction		text,
  pMethod		text,
  pObject		numeric
) RETURNS		boolean
AS $$
DECLARE
  r				record;
  f				record;

  nObserver		numeric;
BEGIN
  nObserver := GetObserver(pObserver);

  FOR r IN SELECT * FROM db.listener WHERE observer = nObserver AND session = pSession
  LOOP
	FOR f IN SELECT * FROM jsonb_to_record(r.filter) AS x(entity text, class text, action text, method text, object numeric)
	LOOP
	  IF coalesce(f.entity = pEntity, true) AND
		 coalesce(f.class = pClass, true) AND
		 coalesce(f.action = pAction, true) AND
		 coalesce(f.method = pMethod, true) AND
		 coalesce(f.object = pObject, true)
	  THEN
		 RETURN true;
	  END IF;
	END LOOP;
  END LOOP;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
