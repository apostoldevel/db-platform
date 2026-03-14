--------------------------------------------------------------------------------
-- GENERAL ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- FUNCTION gen_kernel_uuid ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Generate a new UUID with an optional single-character prefix marker.
 * @param {char} prefix - Character placed at position 20 of the UUID to tag its origin
 * @return {uuid} - Random UUID, optionally branded with the prefix
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION gen_kernel_uuid (
  prefix    char DEFAULT null
) RETURNS   uuid
AS $$
DECLARE
  result    uuid;
BEGIN
  result := gen_random_uuid();
  IF prefix IS NOT null THEN
    result := overlay(result::text placing prefix from 20 for 1)::uuid;
  END IF;
  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION gen_random_code ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Generate a URL-safe random code from 12 cryptographic bytes.
 * @return {text} - 16-character alphanumeric string suitable for tokens or codes
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION gen_random_code()
RETURNS text
AS $$
  SELECT replace(replace(encode(gen_random_bytes(12), 'base64'), '+', 'p'), '/', 's');
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION TrimPhone ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Strip a phone number to digits only and validate its length.
 * @param {text} pPhone - Raw phone string possibly containing formatting characters
 * @return {text} - Digits-only phone number (10-12 digits)
 * @throws InvalidPhoneNumber - When the resulting digit count is outside 10-12
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION TrimPhone (
  pPhone    text
) RETURNS   text
AS $$
DECLARE
  ch        text;
  code      int;
  Result    text;
BEGIN
  IF pPhone IS NOT NULL THEN
    FOR Key IN 1..Length(pPhone)
    LOOP
      ch := SubStr(pPhone, Key, 1);
      code := ascii(ch);
      IF code >= 48 AND code <= 57 THEN
        Result := coalesce(Result, '') || ch;
      END IF;
    END LOOP;

    ch := SubStr(Result, 1, 1);
    IF length(Result) < 10 OR length(Result) > 12 THEN
      PERFORM InvalidPhoneNumber(pPhone);
    END IF;
  END IF;

  RETURN Result;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetVar -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Store a text value in a session-level configuration variable.
 * @param {TVarType} pType - Variable namespace (kernel, context, object)
 * @param {text} pName - Variable name within the namespace
 * @param {text} pValue - Text value to store
 * @return {void}
 * @see GetVar
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetVar (
  pType     TVarType,
  pName     text,
  pValue    text
) RETURNS   void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, pValue, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
/**
 * @brief Store a numeric value in a session-level configuration variable.
 * @param {TVarType} pType - Variable namespace (kernel, context, object)
 * @param {text} pName - Variable name within the namespace
 * @param {numeric} pValue - Numeric value to store (converted to text)
 * @return {void}
 * @see GetVar
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetVar (
  pType     TVarType,
  pName     text,
  pValue    numeric
) RETURNS   void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, IntToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
/**
 * @brief Store a UUID value in a session-level configuration variable.
 * @param {TVarType} pType - Variable namespace (kernel, context, object)
 * @param {text} pName - Variable name within the namespace
 * @param {uuid} pValue - UUID value to store (converted to text)
 * @return {void}
 * @see GetVar
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetVar (
  pType     TVarType,
  pName     text,
  pValue    uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, pValue::text, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
/**
 * @brief Store a timestamp value in a session-level configuration variable.
 * @param {TVarType} pType - Variable namespace (kernel, context, object)
 * @param {text} pName - Variable name within the namespace
 * @param {timestamp} pValue - Timestamp value to store (converted to text)
 * @return {void}
 * @see GetVar
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetVar (
  pType     TVarType,
  pName     text,
  pValue    timestamp
) RETURNS   void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, DateToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
/**
 * @brief Store a timestamptz value in a session-level configuration variable.
 * @param {TVarType} pType - Variable namespace (kernel, context, object)
 * @param {text} pName - Variable name within the namespace
 * @param {timestamptz} pValue - Timezone-aware timestamp to store (converted to text)
 * @return {void}
 * @see GetVar
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetVar (
  pType     TVarType,
  pName     text,
  pValue    timestamptz
) RETURNS   void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, DateToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
/**
 * @brief Store a date value in a session-level configuration variable.
 * @param {TVarType} pType - Variable namespace (kernel, context, object)
 * @param {text} pName - Variable name within the namespace
 * @param {date} pValue - Date value to store (converted to text)
 * @return {void}
 * @see GetVar
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetVar (
  pType     TVarType,
  pName     text,
  pValue    date
) RETURNS   void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, DateToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetVar -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a session-level configuration variable as text.
 * @param {TVarType} pType - Variable namespace (kernel, context, object)
 * @param {text} pName - Variable name within the namespace
 * @return {text} - Stored value, or NULL if empty or not set
 * @see SetVar
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetVar (
  pType     TVarType,
  pName     text
) RETURNS   text
AS $$
DECLARE
  vValue    text;
BEGIN
  SELECT INTO vValue current_setting(pType || '.' || pName);

  IF vValue <> '' THEN
    RETURN vValue;
  END IF;

  RETURN NULL;
EXCEPTION
WHEN syntax_error_or_access_rule_violation THEN
  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetErrorMessage ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Store an error message in the kernel session variable space.
 * @param {text} pMessage - Error message text to persist for the current session
 * @return {void}
 * @see GetErrorMessage
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetErrorMessage (
  pMessage    text
) RETURNS     void
AS $$
BEGIN
  PERFORM SetVar('kernel', 'error_message', pMessage);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetErrorMessage ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the last error message stored in the kernel session.
 * @return {text} - Error message text, or NULL if none was set
 * @see SetErrorMessage
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetErrorMessage (
) RETURNS     text
AS $$
BEGIN
  RETURN GetVar('kernel', 'error_message');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION InitContext --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Initialize the workflow execution context with object, class, method, and action.
 * @param {uuid} pObject - Current business object identifier
 * @param {uuid} pClass - Class of the business object
 * @param {uuid} pMethod - Method being executed on the object
 * @param {uuid} pAction - Action triggered by the method
 * @return {void}
 * @see context_object, context_class, context_method, context_action
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION InitContext (
  pObject   uuid,
  pClass    uuid,
  pMethod   uuid,
  pAction   uuid
)
RETURNS     void
AS $$
BEGIN
  PERFORM SetVar('context', 'object', pObject);
  PERFORM SetVar('context', 'class',  pClass);
  PERFORM SetVar('context', 'method', pMethod);
  PERFORM SetVar('context', 'action', pAction);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION InitParams ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Store workflow parameters in the session context as a JSONB blob.
 * @param {jsonb} pParams - Key-value parameters for the current workflow step
 * @return {void}
 * @see context_params
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION InitParams (
  pParams   jsonb
)
RETURNS     void
AS $$
BEGIN
  PERFORM SetVar('context', 'params', pParams::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetContextMethod ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Override the current workflow method in the session context.
 * @param {uuid} pMethod - New method identifier to set
 * @return {void}
 * @see ClearContextMethod, context_method
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetContextMethod (
  pMethod   uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM SetVar('context', 'method', pMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION ClearContextMethod -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Reset the current workflow method to the null UUID sentinel.
 * @return {void}
 * @see SetContextMethod, context_method
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ClearContextMethod (
) RETURNS   void
AS $$
BEGIN
  PERFORM SetContextMethod(null_uuid());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_object -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current business object UUID from the session context.
 * @return {uuid} - Object identifier, or NULL if not set
 * @see InitContext
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION context_object()
RETURNS     uuid
AS $$
DECLARE
  vValue    text;
BEGIN
  SELECT INTO vValue GetVar('context', 'object');
  RETURN vValue;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_class ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current class UUID from the session context.
 * @return {uuid} - Class identifier, or NULL if not set
 * @see InitContext
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION context_class()
RETURNS     uuid
AS $$
DECLARE
  vValue    text;
BEGIN
  SELECT INTO vValue GetVar('context', 'class');
  RETURN vValue;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_method -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current method UUID from the session context.
 * @return {uuid} - Method identifier, or NULL if not set
 * @see InitContext, SetContextMethod
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION context_method()
RETURNS     uuid
AS $$
DECLARE
  vValue    text;
BEGIN
  SELECT INTO vValue GetVar('context', 'method');
  RETURN vValue;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_action -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current action UUID from the session context.
 * @return {uuid} - Action identifier, or NULL if not set
 * @see InitContext
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION context_action()
RETURNS     uuid
AS $$
DECLARE
  vValue    text;
BEGIN
  SELECT INTO vValue GetVar('context', 'action');
  RETURN vValue;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_params -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the workflow parameters JSONB blob from the session context.
 * @return {jsonb} - Parameters object, or NULL if not set
 * @see InitParams
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION context_params()
RETURNS     jsonb
AS $$
DECLARE
  vValue    text;
BEGIN
  SELECT INTO vValue GetVar('context', 'params');
  RETURN vValue;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JSON ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- JsonToIntArray --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSON array or object values to a PostgreSQL integer array.
 * @param {json} pJson - JSON array of integers or object with integer values
 * @return {integer[]} - PostgreSQL integer array
 * @see JsonbToIntArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonToIntArray (
  pJson     json
) RETURNS   integer[]
AS $$
DECLARE
  r         record;
  result    integer[];
BEGIN
  IF json_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::integer);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      result := array_append(result, r.value::integer);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToIntArray -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSONB array or object values to a PostgreSQL integer array.
 * @param {jsonb} pJson - JSONB array of integers or object with integer values
 * @return {integer[]} - PostgreSQL integer array
 * @see JsonToIntArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonbToIntArray (
  pJson     jsonb
) RETURNS   integer[]
AS $$
DECLARE
  r         record;
  result    integer[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::integer);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      result := array_append(result, r.value::integer);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonToNumArray --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSON array or object values to a PostgreSQL numeric array.
 * @param {json} pJson - JSON array of numbers or object with numeric values
 * @return {numeric[]} - PostgreSQL numeric array
 * @see JsonbToNumArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonToNumArray (
  pJson     json
) RETURNS   numeric[]
AS $$
DECLARE
  r         record;
  result    numeric[];
BEGIN
  IF json_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::numeric);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      result := array_append(result, r.value::numeric);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToNumArray -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSONB array or object values to a PostgreSQL numeric array.
 * @param {jsonb} pJson - JSONB array of numbers or object with numeric values
 * @return {numeric[]} - PostgreSQL numeric array
 * @see JsonToNumArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonbToNumArray (
  pJson     jsonb
) RETURNS   numeric[]
AS $$
DECLARE
  r         record;
  result    numeric[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::numeric);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      result := array_append(result, r.value::numeric);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonToStrArray --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSON array or object values to a PostgreSQL text array.
 * @param {json} pJson - JSON array of strings or object with text values
 * @return {text[]} - PostgreSQL text array
 * @see JsonbToStrArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonToStrArray (
  pJson     json
) RETURNS   text[]
AS $$
DECLARE
  r         record;
  result    text[];
BEGIN
  IF json_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      result := array_append(result, r.value);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToStrArray -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSONB array or object values to a PostgreSQL text array.
 * @param {jsonb} pJson - JSONB array of strings or object with text values
 * @return {text[]} - PostgreSQL text array
 * @see JsonToStrArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonbToStrArray (
  pJson     jsonb
) RETURNS   text[]
AS $$
DECLARE
  r         record;
  result    text[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      result := array_append(result, r.value);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonToUUIDArray -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSON array or object values to a PostgreSQL UUID array.
 * @param {json} pJson - JSON array of UUID strings or object with UUID values
 * @return {uuid[]} - PostgreSQL UUID array
 * @see JsonbToUUIDArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonToUUIDArray (
  pJson     json
) RETURNS   uuid[]
AS $$
DECLARE
  r         record;
  result    uuid[];
BEGIN
  IF json_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::uuid);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      result := array_append(result, r.value::uuid);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToUUIDArray ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSONB array or object values to a PostgreSQL UUID array.
 * @param {jsonb} pJson - JSONB array of UUID strings or object with UUID values
 * @return {uuid[]} - PostgreSQL UUID array
 * @see JsonToUUIDArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonbToUUIDArray (
  pJson     jsonb
) RETURNS   uuid[]
AS $$
DECLARE
  r         record;
  result    uuid[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::uuid);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      result := array_append(result, r.value::uuid);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonToBoolArray -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSON array or object values to a PostgreSQL boolean array.
 * @param {json} pJson - JSON array of booleans or object with boolean values
 * @return {boolean[]} - PostgreSQL boolean array
 * @see JsonbToBoolArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonToBoolArray (
  pJson     json
) RETURNS   boolean[]
AS $$
DECLARE
  r         record;
  result    boolean[];
BEGIN
  IF json_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::boolean);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      result := array_append(result, r.value::boolean);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToBoolArray ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSONB array or object values to a PostgreSQL boolean array.
 * @param {jsonb} pJson - JSONB array of booleans or object with boolean values
 * @return {boolean[]} - PostgreSQL boolean array
 * @see JsonToBoolArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonbToBoolArray (
  pJson     jsonb
) RETURNS   boolean[]
AS $$
DECLARE
  r         record;
  result    boolean[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::boolean);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      result := array_append(result, r.value::boolean);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonToIntervalArray ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSON array or object values to a PostgreSQL interval array.
 * @param {json} pJson - JSON array of interval strings or object with interval values
 * @return {interval[]} - PostgreSQL interval array
 * @see JsonbToIntervalArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonToIntervalArray (
  pJson     json
) RETURNS   interval[]
AS $$
DECLARE
  r         record;
  result    interval[];
BEGIN
  IF json_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      result := array_append(result, StrToInterval(r.value));
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      result := array_append(result, StrToInterval(r.value));
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToIntervalArray --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSONB array or object values to a PostgreSQL interval array.
 * @param {jsonb} pJson - JSONB array of interval strings or object with interval values
 * @return {interval[]} - PostgreSQL interval array
 * @see JsonToIntervalArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonbToIntervalArray (
  pJson     jsonb
) RETURNS   interval[]
AS $$
DECLARE
  r         record;
  result    interval[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      result := array_append(result, StrToInterval(r.value));
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      result := array_append(result, StrToInterval(r.value));
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- jsonb_array_to_string -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Join JSONB array elements into a single delimited text string.
 * @param {jsonb} pJson - JSONB array whose elements will be quoted and joined
 * @param {text} pSep - Separator placed between elements
 * @return {text} - Comma-separated quoted values; NULLs rendered as '*'
 * @throws IncorrectJsonType - When the input is not a JSON array
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION jsonb_array_to_string (
  pJson     jsonb,
  pSep      text
) RETURNS   text
AS $$
DECLARE
  r         record;
  arStr     text[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      arStr := array_append(arStr, quote_nullable(r.value));
    END LOOP;

  ELSE
    PERFORM IncorrectJsonType(jsonb_typeof(pJson), 'array');
  END IF;

  RETURN array_to_string(arStr, pSep, '*');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION jsonb_compare_value ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Compare two JSONB objects and return keys from the old object whose values differ in the new one.
 * @param {jsonb} pOld - Original JSONB object
 * @param {jsonb} pNew - Updated JSONB object to compare against
 * @return {jsonb} - JSONB object containing only the changed key-value pairs from pOld
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION jsonb_compare_value (
  pOld      jsonb,
  pNew      jsonb
) RETURNS   jsonb
AS $$
DECLARE
  r         record;
  j         jsonb;
  result    jsonb;
BEGIN
  result := jsonb_build_object();

  FOR r IN SELECT * FROM jsonb_each(pOld)
  LOOP
    j := jsonb_build_object(r.key, r.value);
    IF NOT pNew @> j THEN
      result := result || j;
    END IF;
  END LOOP;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckJsonKeys ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validate that all keys in a JSON structure belong to an allowed set.
 * @param {text} pRoute - API route name used in error messages
 * @param {text[]} pKeys - Allowed key names
 * @param {json} pJson - JSON object or array of objects to validate
 * @return {void}
 * @throws IncorrectJsonKey - When an unexpected key is found
 * @see CheckJsonbKeys
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckJsonKeys (
  pRoute    text,
  pKeys     text[],
  pJson     json
) RETURNS   void
AS $$
DECLARE
  e         record;
  r         record;
BEGIN
  IF json_typeof(pJson) = 'array' THEN

    FOR e IN SELECT * FROM json_array_elements(pJson)
    LOOP
      FOR r IN SELECT * FROM json_each_text(e.value)
      LOOP
        IF array_position(pKeys, r.key) IS NULL THEN
          PERFORM IncorrectJsonKey(pRoute, r.key, pKeys);
        END IF;
      END LOOP;
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      IF array_position(pKeys, r.key) IS NULL THEN
        PERFORM IncorrectJsonKey(pRoute, r.key, pKeys);
      END IF;
    END LOOP;

  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckJsonbKeys --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validate that all keys in a JSONB structure belong to an allowed set.
 * @param {text} pRoute - API route name used in error messages
 * @param {text[]} pKeys - Allowed key names
 * @param {jsonb} pJson - JSONB object or array of objects to validate
 * @return {void}
 * @throws IncorrectJsonKey - When an unexpected key is found
 * @see CheckJsonKeys
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckJsonbKeys (
  pRoute    text,
  pKeys     text[],
  pJson     jsonb
) RETURNS   void
AS $$
DECLARE
  e         record;
  r         record;
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN

    FOR e IN SELECT * FROM jsonb_array_elements(pJson)
    LOOP
      FOR r IN SELECT * FROM jsonb_each_text(e.value)
      LOOP
        IF array_position(pKeys, r.key) IS NULL THEN
          PERFORM IncorrectJsonKey(pRoute, r.key, pKeys);
        END IF;
      END LOOP;
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      IF array_position(pKeys, r.key) IS NULL THEN
        PERFORM IncorrectJsonKey(pRoute, r.key, pKeys);
      END IF;
    END LOOP;

  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckJsonValues -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validate that all values in a JSON array exist in an allowed set.
 * @param {text} pArrayName - Descriptive name of the allowed-values array for error messages
 * @param {anyarray} pArray - Allowed values
 * @param {json} pJson - JSON array whose elements are checked
 * @return {void}
 * @throws IncorrectValueInArray - When a value is not in the allowed set
 * @throws IncorrectJsonType - When the input is not a JSON array
 * @see CheckJsonbValues
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckJsonValues (
  pArrayName    text,
  pArray        anyarray,
  pJson         json
) RETURNS       void
AS $$
DECLARE
  r             record;
BEGIN
  IF json_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      IF array_position(pArray, coalesce(r.value, '')) IS NULL THEN
        PERFORM IncorrectValueInArray(coalesce(r.value, ''), pArrayName, pArray);
      END IF;
    END LOOP;

  ELSE
    PERFORM IncorrectJsonType(json_typeof(pJson), 'array');
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckJsonbValues ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validate that all values in a JSONB array exist in an allowed set.
 * @param {text} pArrayName - Descriptive name of the allowed-values array for error messages
 * @param {anyarray} pArray - Allowed values
 * @param {jsonb} pJson - JSONB array whose elements are checked
 * @return {void}
 * @throws IncorrectValueInArray - When a value is not in the allowed set
 * @throws IncorrectJsonType - When the input is not a JSON array
 * @see CheckJsonValues
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckJsonbValues (
  pArrayName    text,
  pArray        anyarray,
  pJson         jsonb
) RETURNS       void
AS $$
DECLARE
  r             record;
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      IF array_position(pArray, coalesce(r.value, '')) IS NULL THEN
        PERFORM IncorrectValueInArray(coalesce(r.value, ''), pArrayName, pArray);
      END IF;
    END LOOP;

  ELSE
    PERFORM IncorrectJsonType(jsonb_typeof(pJson), 'array');
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonToFields ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSON array of field names into a SQL-safe comma-separated column list.
 * @param {json} pJson - JSON array of column names to select
 * @param {text[]} pFields - Allowed column names for validation
 * @return {text} - Comma-separated quoted column names, or '*' if pJson is NULL
 * @see JsonbToFields
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonToFields (
  pJson     json,
  pFields   text[]
) RETURNS   text
AS $$
BEGIN
  IF pJson IS NOT NULL THEN
    PERFORM CheckJsonValues('fields', pFields, pJson);

    RETURN array_to_string(array_quote_literal_json(JsonToStrArray(pJson)), ',');
  END IF;

  RETURN '*';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToFields ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a JSONB array of field names into a SQL-safe comma-separated column list.
 * @param {jsonb} pJson - JSONB array of column names to select; aggregate expressions are auto-allowed
 * @param {text[]} pFields - Allowed column names for validation
 * @return {text} - Comma-separated quoted column names, or '*' if pJson is NULL/empty
 * @see JsonToFields
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonbToFields (
  pJson		jsonb,
  pFields	text[]
) RETURNS	text
AS $$
DECLARE
  r         record;
BEGIN
  pJson := NULLIF(pJson, '{}');
  pJson := NULLIF(pJson, '[]');

  IF pJson IS NOT NULL THEN
    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      IF regexp_like(r.value, '\m(sum|count|max|min|avg)\s*\(\s*(?:DISTINCT\s+)?(\*|[A-Za-z_][A-Za-z0-9_]*|\([^)]*\))\s*\)', 'i') THEN
        pFields := array_append(pFields, r.value);
      END IF;
    END LOOP;

    PERFORM CheckJsonbValues('fields', pFields, pJson);
    RETURN array_to_string(array_quote_literal_json(JsonbToStrArray(pJson)), ',');
  END IF;

  RETURN '*';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
