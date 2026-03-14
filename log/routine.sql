--------------------------------------------------------------------------------
-- AddEventLog -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new event into the event log and return its identifier.
 * @param {char} pType - Event severity: M=message, W=warning, E=error, D=debug
 * @param {integer} pCode - Application-defined numeric event code
 * @param {text} pEvent - Event name or subsystem label
 * @param {text} pText - Human-readable event description
 * @param {text} pCategory - Optional object class code for categorization
 * @param {uuid} pObject - Optional UUID of the related business object
 * @return {bigint} - Auto-generated identifier of the new log row
 * @since 1.0.0
 */
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
/**
 * @brief Create a new event log entry (fire-and-forget wrapper around AddEventLog).
 * @param {char} pType - Event severity: M=message, W=warning, E=error, D=debug
 * @param {integer} pCode - Application-defined numeric event code
 * @param {text} pEvent - Event name or subsystem label
 * @param {text} pText - Human-readable event description
 * @param {text} pCategory - Optional object class code for categorization
 * @param {uuid} pObject - Optional UUID of the related business object
 * @return {void} - No return value
 * @see AddEventLog
 * @since 1.0.0
 */
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
/**
 * @brief Write an event to the log if logging is enabled, optionally raising a NOTICE in debug mode.
 * @param {char} pType - Event severity: M=message, W=warning, E=error, D=debug
 * @param {integer} pCode - Application-defined numeric event code
 * @param {text} pEvent - Event name or subsystem label
 * @param {text} pText - Human-readable event description
 * @param {uuid} pObject - Optional UUID of the related business object (used to resolve category)
 * @return {void} - No return value
 * @see NewEventLog
 * @since 1.0.0
 */
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
/**
 * @brief Write an event to the log using the default 'log' event name.
 * @param {char} pType - Event severity: M=message, W=warning, E=error, D=debug
 * @param {integer} pCode - Application-defined numeric event code
 * @param {text} pText - Human-readable event description
 * @param {uuid} pObject - Optional UUID of the related business object
 * @return {void} - No return value
 * @see WriteToEventLog
 * @since 1.0.0
 */
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
/**
 * @brief Delete a single event log entry by its identifier.
 * @param {bigint} pId - Identifier of the log row to remove
 * @return {void} - No return value
 * @since 1.0.0
 */
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
/**
 * @brief Parse an error message, persist it as an error event, and optionally log the call context as debug.
 * @param {text} pMessage - Raw error message (parsed into code + text via ParseMessage)
 * @param {text} pContext - Optional PL/pgSQL call stack context for debug logging
 * @param {uuid} pObject - Optional UUID of the related business object
 * @return {record} - errorCode (int) and errorMessage (text) extracted from pMessage
 * @see WriteToEventLog
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION WriteDiagnostics (
  pMessage      text,
  pContext      text default null,
  pObject       uuid default null,
  errorCode     OUT int,
  errorMessage  OUT text
) RETURNS       record
AS $$
BEGIN
  SELECT * INTO errorCode, errorMessage FROM ParseMessage(pMessage);

  PERFORM SetErrorMessage(pMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', ErrorMessage, pObject);

  IF pContext IS NOT NULL THEN
    PERFORM WriteToEventLog('D', ErrorCode, 'exception', pContext, pObject);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
