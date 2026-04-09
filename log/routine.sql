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
BEGIN
  RETURN AddEventLog(pType, pCode, NULL, pEvent, pText, pCategory, pObject);
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
BEGIN
  PERFORM NewEventLog(pType, pCode, NULL, pEvent, pText, pCategory, pObject);
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
BEGIN
  PERFORM WriteToEventLog(pType, pCode, NULL, pEvent, pText, pObject);
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
-- AddEventLog (with scope) ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new event into the event log with scope and return its identifier.
 * @param {char} pType - Event severity: M=message, W=warning, E=error, D=debug
 * @param {integer} pCode - Application-defined numeric event code
 * @param {text} pScope - Event subsystem (e.g. lifecycle, workflow, payment.stripe, ocpp.status)
 * @param {text} pEvent - Event detail within scope (e.g. create, enable, capture)
 * @param {text} pText - Human-readable event description
 * @param {text} pCategory - Optional object class code for categorization
 * @param {uuid} pObject - Optional UUID of the related business object
 * @return {bigint} - Auto-generated identifier of the new log row
 * @since 1.2.2
 */
CREATE OR REPLACE FUNCTION AddEventLog (
  pType     char,
  pCode     integer,
  pScope    text,
  pEvent    text,
  pText     text,
  pCategory text DEFAULT null,
  pObject   uuid DEFAULT null
) RETURNS   bigint
AS $$
DECLARE
  nId       bigint;
BEGIN
  INSERT INTO db.log (type, code, scope, event, text, category, object)
  VALUES (pType, pCode, pScope, pEvent, pText, pCategory, pObject)
  RETURNING id INTO nId;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewEventLog (with scope) ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new event log entry with scope (fire-and-forget).
 * @param {char} pType - Event severity: M=message, W=warning, E=error, D=debug
 * @param {integer} pCode - Application-defined numeric event code
 * @param {text} pScope - Event subsystem
 * @param {text} pEvent - Event detail within scope
 * @param {text} pText - Human-readable event description
 * @param {text} pCategory - Optional object class code for categorization
 * @param {uuid} pObject - Optional UUID of the related business object
 * @return {void}
 * @since 1.2.2
 */
CREATE OR REPLACE FUNCTION NewEventLog (
  pType     char,
  pCode     integer,
  pScope    text,
  pEvent    text,
  pText     text,
  pCategory text DEFAULT null,
  pObject   uuid DEFAULT null
) RETURNS   void
AS $$
DECLARE
  nId        bigint;
BEGIN
  nId := AddEventLog(pType, pCode, pScope, pEvent, pText, pCategory, pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteToEventLog (with scope) ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Write an event with scope to the log if logging is enabled.
 * @param {char} pType - Event severity: M=message, W=warning, E=error, D=debug
 * @param {integer} pCode - Application-defined numeric event code
 * @param {text} pScope - Event subsystem (e.g. lifecycle, workflow, payment.stripe)
 * @param {text} pEvent - Event detail within scope (e.g. create, enable, capture)
 * @param {text} pText - Human-readable event description
 * @param {uuid} pObject - Optional UUID of the related business object (used to resolve category)
 * @return {void}
 * @since 1.2.2
 */
CREATE OR REPLACE FUNCTION WriteToEventLog (
  pType     char,
  pCode     integer,
  pScope    text,
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

    PERFORM NewEventLog(pType, pCode, pScope, pEvent, pText, vCategory, pObject);
  END IF;

  IF pType = 'D' AND GetDebugMode() THEN
    pType := 'N';
  END IF;

  IF pType = 'N' THEN
    RAISE NOTICE '[%] [%] [%] [%] [%] %', pType, pCode, pScope, pEvent, pObject, pText;
  END IF;
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
  SELECT * INTO errorCode, errorMessage FROM WriteDiagnostics(pMessage, pContext, 'exception', pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteDiagnostics (with scope) -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Parse an error message, persist as error event with scope, optionally log context as debug.
 * @param {text} pMessage - Raw error message (parsed into code + text via ParseMessage)
 * @param {text} pContext - Optional PL/pgSQL call stack context for debug logging
 * @param {text} pScope - Event subsystem (default: 'exception')
 * @param {uuid} pObject - Optional UUID of the related business object
 * @return {record} - errorCode (int) and errorMessage (text) extracted from pMessage
 * @since 1.2.2
 */
CREATE OR REPLACE FUNCTION WriteDiagnostics (
  pMessage      text,
  pContext      text default null,
  pScope        text default 'exception',
  pObject       uuid default null,
  errorCode     OUT int,
  errorMessage  OUT text
) RETURNS       record
AS $$
BEGIN
  SELECT p.code, p.message INTO errorCode, errorMessage FROM ParseMessage(pMessage) p;

  PERFORM SetErrorMessage(pMessage);

  PERFORM WriteToEventLog('E', ErrorCode, pScope, 'error', ErrorMessage, pObject);

  IF pContext IS NOT NULL THEN
    PERFORM WriteToEventLog('D', ErrorCode, pScope, 'context', pContext, pObject);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
