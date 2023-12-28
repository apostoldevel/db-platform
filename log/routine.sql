--------------------------------------------------------------------------------
-- AddEventLog -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddEventLog (
  pType     char,
  pCode     integer,
  pEvent    text,
  pText     text,
  pCategory text DEFAULT null,
  pObject   uuid DEFAULT null
) RETURNS   bigint
AS $$
DECLARE
  nId       bigint;
BEGIN
  INSERT INTO db.log (type, code, event, text, category, object)
  VALUES (pType, pCode, pEvent, pText, pCategory, pObject)
  RETURNING id INTO nId;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewEventLog -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewEventLog (
  pType     char,
  pCode     integer,
  pEvent    text,
  pText     text,
  pCategory text DEFAULT null,
  pObject   uuid DEFAULT null
) RETURNS   void
AS $$
DECLARE
  nId        bigint;
BEGIN
  nId := AddEventLog(pType, pCode, pEvent, pText, pCategory, pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteToEventLog -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION WriteToEventLog (
  pType     char,
  pCode     integer,
  pEvent    text,
  pText     text,
  pObject   uuid DEFAULT null
) RETURNS   void
AS $$
DECLARE
  vCategory text;
BEGIN
  IF pType IN ('M', 'W', 'E', 'D') AND GetLogMode() THEN

    IF pObject IS NOT NULL THEN
      SELECT GetClassCode(class) INTO vCategory FROM db.object WHERE id = pObject;
    END IF;

    PERFORM NewEventLog(pType, pCode, pEvent, pText, vCategory, pObject);
  END IF;

  IF pType = 'D' AND GetDebugMode() THEN
    pType := 'N';
  END IF;

  IF pType = 'N' THEN
    RAISE NOTICE '[%] [%] [%] [%] %', pType, pCode, pEvent, pObject, pText;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteToEventLog -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION WriteToEventLog (
  pType     char,
  pCode     integer,
  pText     text,
  pObject   uuid DEFAULT null
) RETURNS   void
AS $$
BEGIN
  PERFORM WriteToEventLog(pType, pCode, 'log', pText, pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteEventLog --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteEventLog (
  pId       bigint
) RETURNS   void
AS $$
BEGIN
  DELETE FROM db.log WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteDiagnostics ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION WriteDiagnostics (
  pMessage      text,
  pContext      text default null,
  pObject       uuid default null
) RETURNS       void
AS $$
DECLARE
  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  PERFORM SetErrorMessage(pMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(pMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', ErrorMessage, pObject);

  IF pContext IS NOT NULL THEN
    PERFORM WriteToEventLog('D', ErrorCode, 'exception', pContext, pObject);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
