--------------------------------------------------------------------------------
-- JSON ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- JsonToIntArray --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonToIntArray (
  pJson		json
) RETURNS	integer[]
AS $$
DECLARE
  r		    record;
  result	integer[];
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

CREATE OR REPLACE FUNCTION JsonbToIntArray (
  pJson		jsonb
) RETURNS	integer[]
AS $$
DECLARE
  r		    record;
  result	integer[];
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

CREATE OR REPLACE FUNCTION JsonToNumArray (
  pJson		json
) RETURNS	numeric[]
AS $$
DECLARE
  r		    record;
  result	numeric[];
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

CREATE OR REPLACE FUNCTION JsonbToNumArray (
  pJson		jsonb
) RETURNS	numeric[]
AS $$
DECLARE
  r		    record;
  result	numeric[];
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

CREATE OR REPLACE FUNCTION JsonToStrArray (
  pJson		json
) RETURNS	text[]
AS $$
DECLARE
  r		    record;
  result	text[];
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

CREATE OR REPLACE FUNCTION JsonbToStrArray (
  pJson		jsonb
) RETURNS	text[]
AS $$
DECLARE
  r		    record;
  result	text[];
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
-- JsonToBoolArray -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonToBoolArray (
  pJson		json
) RETURNS	boolean[]
AS $$
DECLARE
  r		    record;
  result	boolean[];
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

CREATE OR REPLACE FUNCTION JsonbToBoolArray (
  pJson		jsonb
) RETURNS	boolean[]
AS $$
DECLARE
  r		    record;
  result	boolean[];
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
-- jsonb_array_to_string -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION jsonb_array_to_string (
  pJson		jsonb,
  pSep		text
) RETURNS	text
AS $$
DECLARE
  r		    record;
  arStr		text[];
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
-- CheckJsonKeys ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckJsonKeys (
  pRoute	text,
  pKeys		text[],
  pJson		json
) RETURNS	void
AS $$
DECLARE
  e		    record;
  r		    record;
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

CREATE OR REPLACE FUNCTION CheckJsonbKeys (
  pRoute	text,
  pKeys		text[],
  pJson		jsonb
) RETURNS	void
AS $$
DECLARE
  e		    record;
  r		    record;
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

CREATE OR REPLACE FUNCTION CheckJsonValues (
  pArrayName	text,
  pArray	anyarray,
  pJson		json
) RETURNS	void
AS $$
DECLARE
  r		record;
BEGIN
  IF json_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      IF array_position(pArray, coalesce(r.value, '<null>')) IS NULL THEN
        PERFORM IncorrectValueInArray(coalesce(r.value, '<null>'), pArrayName, pArray);
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

CREATE OR REPLACE FUNCTION CheckJsonbValues (
  pArrayName	text,
  pArray	anyarray,
  pJson		jsonb
) RETURNS	void
AS $$
DECLARE
  r		record;
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN

    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      IF array_position(pArray, coalesce(r.value, '<null>')) IS NULL THEN
        PERFORM IncorrectValueInArray(coalesce(r.value, '<null>'), pArrayName, pArray);
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

CREATE OR REPLACE FUNCTION JsonToFields (
  pJson		json,
  pFields	text[]
) RETURNS	text
AS $$
DECLARE
  vFields	text;
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

CREATE OR REPLACE FUNCTION JsonbToFields (
  pJson		jsonb,
  pFields	text[]
) RETURNS	text
AS $$
BEGIN
  pJson := NULLIF(pJson, '{}');
  pJson := NULLIF(pJson, '[]');

  IF pJson IS NOT NULL THEN
    PERFORM CheckJsonbValues('fields', pFields, pJson);
    RETURN array_to_string(array_quote_literal_json(JsonbToStrArray(pJson)), ',');
  END IF;

  RETURN '*';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetVar -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetVar (
  pType		TVarType,
  pName		text, 
  pValue	text
) RETURNS void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, pValue, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetVar (
  pType		TVarType,
  pName		text, 
  pValue	numeric
) RETURNS void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, IntToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetVar (
  pType		TVarType,
  pName		text, 
  pValue	timestamp
) RETURNS void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, DateToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetVar (
  pType		TVarType,
  pName		text, 
  pValue	timestamptz
) RETURNS void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, DateToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetVar (
  pType		TVarType,
  pName		text, 
  pValue	date
) RETURNS void
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

CREATE OR REPLACE FUNCTION GetVar (
  pType		TVarType,
  pName 	text
) RETURNS text
AS $$
DECLARE
  vValue text;
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

CREATE OR REPLACE FUNCTION SetErrorMessage (
  pMessage 	text
) RETURNS 	void
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

CREATE OR REPLACE FUNCTION GetErrorMessage (
) RETURNS 	text
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

CREATE OR REPLACE FUNCTION InitContext (
  pObject	numeric,
  pClass	numeric,
  pMethod	numeric,
  pAction	numeric
)
RETURNS 	void
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
-- FUNCTION InitForm -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitForm (
  pForm		jsonb
)
RETURNS 	void
AS $$
BEGIN
  PERFORM SetVar('context', 'form', pForm::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_object -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION context_object()
RETURNS 	numeric
AS $$
DECLARE
  vValue	text;
BEGIN
  SELECT INTO vValue GetVar('context', 'object');

  IF vValue IS NOT NULL THEN
    RETURN StrToInt(vValue);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_class ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION context_class()
RETURNS 	numeric
AS $$
DECLARE
  vValue	text;
BEGIN
  SELECT INTO vValue GetVar('context', 'class');

  IF vValue IS NOT NULL THEN
    RETURN StrToInt(vValue);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_method -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION context_method()
RETURNS 	numeric
AS $$
DECLARE
  vValue	text;
BEGIN
  SELECT INTO vValue GetVar('context', 'method');

  IF vValue IS NOT NULL THEN
    RETURN StrToInt(vValue);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_action -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION context_action()
RETURNS 	numeric
AS $$
DECLARE
  vValue	text;
BEGIN
  SELECT INTO vValue GetVar('context', 'action');

  IF vValue IS NOT NULL THEN
    RETURN StrToInt(vValue);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_form -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION context_form()
RETURNS 	jsonb
AS $$
DECLARE
  vValue	text;
BEGIN
  SELECT INTO vValue GetVar('context', 'form');

  IF vValue IS NOT NULL THEN
    RETURN vValue::jsonb;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
