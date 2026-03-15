--------------------------------------------------------------------------------
-- ALL_TAB_COLUMNS -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Expose kernel schema column metadata through an Oracle-style view.
 * @since 1.0.0
 */
CREATE OR REPLACE VIEW all_tab_columns(table_name, column_id, column_name, data_type, udt_name)
AS
  SELECT table_name, ordinal_position as column_id, column_name, data_type, udt_name
    FROM information_schema.columns
   WHERE table_schema = 'kernel';

GRANT SELECT ON all_tab_columns TO PUBLIC;

--------------------------------------------------------------------------------
-- ALL_COL_COMMENTS ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Expose kernel schema column comments alongside table descriptions.
 * @since 1.0.0
 */
CREATE OR REPLACE VIEW all_col_comments(table_name, table_description, column_name, column_description)
AS
  SELECT table_name,
         obj_description(format('%s.%s', isc.table_schema, isc.table_name)::regclass::oid, 'pg_class') as table_description,
         column_name,
         pg_catalog.col_description(format('%s.%s', isc.table_schema, isc.table_name)::regclass::oid, isc.ordinal_position) as column_description
    FROM information_schema.columns isc
   WHERE table_schema = 'kernel';

GRANT SELECT ON all_col_comments TO PUBLIC;

--------------------------------------------------------------------------------
-- get_columns -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve column names for a given table, optionally prefixed with an alias.
 * @param {text} pTable - Table name to introspect
 * @param {text} pSchema - Schema name (defaults to current schema)
 * @param {text} pAlias - Optional table alias prepended as "alias.column"
 * @return {text[]} - Array of column names in ordinal order
 * @see GetColumns
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION get_columns (
  pTable    text,
  pSchema   text DEFAULT current_schema(),
  pAlias    text DEFAULT null
) RETURNS   text[]
AS $$
DECLARE
  arResult  text[];
  r         record;
BEGIN
  FOR r IN
    SELECT column_name
      FROM information_schema.columns
     WHERE table_schema = lower(pSchema)
       AND table_name = lower(pTable)
     ORDER BY ordinal_position
  LOOP
    arResult := array_append(arResult, coalesce(pAlias || '.', '') || r.column_name::text);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

GRANT EXECUTE ON FUNCTION get_columns(text, text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- GetColumns ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve column names for a given table (CamelCase wrapper).
 * @param {text} pTable - Table name to introspect
 * @param {text} pSchema - Schema name (defaults to current schema)
 * @param {text} pAlias - Optional table alias prepended as "alias.column"
 * @return {text[]} - Array of column names in ordinal order
 * @see get_columns
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetColumns (
  pTable    text,
  pSchema   text DEFAULT current_schema(),
  pAlias    text DEFAULT null
) RETURNS   text[]
AS $$
BEGIN
  RETURN get_columns(pTable, pSchema, pAlias);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

GRANT EXECUTE ON FUNCTION GetColumns(text, text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- get_routines ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve input parameter names (and optionally types) for a stored routine.
 * @param {text} pRoutine - Routine name to introspect
 * @param {text} pSchema - Schema name (defaults to current schema)
 * @param {boolean} pDataType - When true, append data type after each parameter name
 * @param {text} pAlias - Optional alias prepended as "alias.param"
 * @param {int} pNameFrom - Character position to start extracting the parameter name (strips prefix)
 * @return {text[]} - Array of parameter descriptors in ordinal order
 * @see GetRoutines
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION get_routines (
  pRoutine      text,
  pSchema       text DEFAULT current_schema(),
  pDataType     boolean DEFAULT false,
  pAlias        text DEFAULT null,
  pNameFrom     int DEFAULT 2
) RETURNS       text[]
AS $$
DECLARE
  r             record;
  arResult      text[];
BEGIN
  FOR r IN
    SELECT ip.ordinal_position, ip.parameter_name, ip.data_type
      FROM information_schema.routines ir INNER JOIN information_schema.parameters ip ON ip.specific_name = ir.specific_name
     WHERE ir.specific_schema = pSchema
       AND ir.routine_name = pRoutine
       AND ip.parameter_mode = 'IN'
     ORDER BY ordinal_position
  LOOP
    IF pDataType THEN
      arResult := array_append(arResult, SubStr(r.parameter_name::text, pNameFrom) || ' ' || r.data_type::text);
    ELSE
      arResult := array_append(arResult, coalesce(pAlias || '.', '') || SubStr(r.parameter_name::text, pNameFrom));
    END IF;
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

GRANT EXECUTE ON FUNCTION get_routines(text, text, boolean, text, int) TO PUBLIC;

--------------------------------------------------------------------------------
-- GetRoutines -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve input parameter names for a stored routine (CamelCase wrapper).
 * @param {text} pRoutine - Routine name to introspect
 * @param {text} pSchema - Schema name (defaults to current schema)
 * @param {boolean} pDataType - When true, append data type after each parameter name
 * @param {text} pAlias - Optional alias prepended as "alias.param"
 * @param {int} pNameFrom - Character position to start extracting the parameter name
 * @return {text[]} - Array of parameter descriptors in ordinal order
 * @see get_routines
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetRoutines (
  pRoutine      text,
  pSchema       text DEFAULT current_schema(),
  pDataType     boolean DEFAULT false,
  pAlias        text DEFAULT null,
  pNameFrom     int DEFAULT 2
) RETURNS       text[]
AS $$
BEGIN
  RETURN get_routines(pRoutine, pSchema, pDataType, pAlias, pNameFrom);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

GRANT EXECUTE ON FUNCTION GetRoutines(text, text, boolean, text, int) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION array_pos ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Find the 1-based index of a text element in a text array.
 * @param {text[]} anyarray - Array to search
 * @param {text} anyelement - Value to locate
 * @return {int} - 1-based position, or 0 if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION array_pos (
  anyarray       text[],
  anyelement     text
) RETURNS        int
AS $$
DECLARE
  i              int;
  l              int;
BEGIN
  i := 1;
  l := array_length(anyarray, 1);
  WHILE (i <= l) AND (anyarray[i] <> anyelement) LOOP
    i := i + 1;
  END LOOP;

  IF i > l THEN
    i := 0;
  END IF;

  RETURN i;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION array_pos ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Find the 1-based index of a numeric element in a numeric array.
 * @param {numeric[]} anyarray - Array to search
 * @param {numeric} anyelement - Value to locate
 * @return {int} - 1-based position, or 0 if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION array_pos (
  anyarray       numeric[],
  anyelement     numeric
) RETURNS        int
AS $$
DECLARE
  i              int;
  l              int;
BEGIN
  i := 1;
  l := array_length(anyarray, 1);
  WHILE (i <= l) AND (anyarray[i] <> anyelement) LOOP
    i := i + 1;
  END LOOP;

  IF i > l THEN
    i := 0;
  END IF;

  RETURN i;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION string_to_array_trim -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Split a string by a separator and trim whitespace from each element.
 * @param {text} str - Input string to split
 * @param {text} sep - Single-character separator
 * @return {text[]} - Array of trimmed substrings
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION string_to_array_trim (
  str       text,
  sep       text
) RETURNS   text[]
AS $$
DECLARE
  i         int;
  pos       int;
  arr       text[];
BEGIN
  pos := StrPos(str, sep);
  i := 1;

  WHILE pos > 0
  LOOP
    arr[i] := trim(SubStr(str, 1, pos - 1));
    str := trim(SubStr(str, pos + 1));
    pos := StrPos(str, sep);
    i := i + 1;
  END LOOP;

  arr[i] := str;

  RETURN arr;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION path_to_array ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Split a '/'-delimited path string into an array of path segments.
 * @param {text} pPath - URL or filesystem-style path (leading '/' is ignored)
 * @return {text[]} - Array of non-empty path segments
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION path_to_array (
  pPath     text
) RETURNS   text[]
AS $$
DECLARE
  i         integer;
  arPath    text[];
  vStr      text;
  vPath     text;
BEGIN
  vPath := pPath;

  IF NULLIF(vPath, '') IS NOT NULL THEN

    i := StrPos(vPath, '/');
    WHILE i > 0 LOOP
      vStr := SubStr(vPath, 1, i - 1);

      IF NULLIF(vStr, '') IS NOT NULL THEN
        arPath := array_append(arPath, vStr);
      END IF;

      vPath := SubStr(vPath, i + 1);
      i := StrPos(vPath, '/');
    END LOOP;

    IF NULLIF(vPath, '') IS NOT NULL THEN
      arPath := array_append(arPath, vPath);
    END IF;
  END IF;

  RETURN arPath;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION str_to_inet --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Parse an IP address string (with optional range or wildcard) into an inet value and range count.
 * @param {text} str - IP string like "192.168.1.1", "10.0.0.1-10.0.0.5", or "192.168.*.*"
 * @param {inet} host - Parsed inet address with CIDR mask (OUT)
 * @param {integer} range - Number of addresses in range, or NULL for single/CIDR (OUT)
 * @return {record} - (host inet, range integer)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION str_to_inet (
  str       text,
  OUT host  inet,
  OUT range integer
) RETURNS   record
AS $$
DECLARE
  vHost     text;
  vStr      text;

  pos       int;
  nMask     int;
BEGIN
  range := null;
  nMask := 32;

  vStr := str;
  pos := StrPos(vStr, '-');

  IF pos > 0 THEN
    vHost := SubStr(vStr, 1, pos - 1);
    vStr := SubStr(vStr, pos + 1);
    range := (vStr::inet - vHost::inet) + 1;
  ELSE
    vHost := vStr;
  END IF;

  vStr := vHost;
  pos := StrPos(vStr, '*');

  WHILE pos > 0
  LOOP
    nMask := nMask - 8;
    vStr := SubStr(vStr, pos + 1);
    pos := StrPos(vStr, '*');
  END LOOP;

  host := replace(vHost, '*', '0') || '/' || nMask;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IntToStr -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a numeric value to its text representation using to_char.
 * @param {numeric} pValue - Number to format
 * @param {text} pFormat - to_char format mask (default FM999999999999990)
 * @return {text} - Formatted number string
 * @see StrToInt
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IntToStr (
  pValue    numeric,
  pFormat   text DEFAULT 'FM999999999999990'
) RETURNS   text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION IntToStr(numeric, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToInt -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Parse a text string into a numeric value using to_number.
 * @param {text} pValue - Numeric string to parse
 * @param {text} pFormat - to_number format mask (default 999999999999999)
 * @return {numeric} - Parsed numeric value
 * @see IntToStr
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION StrToInt (
  pValue    text,
  pFormat   text DEFAULT '999999999999999'
) RETURNS   numeric
AS $$
BEGIN
  RETURN to_number(pValue, pFormat);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION IntToStr(numeric, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION DateToStr ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Format a timestamptz value as a text string.
 * @param {timestamptz} pValue - Timezone-aware timestamp to format
 * @param {text} pFormat - to_char format mask (default DD.MM.YYYY HH24:MI:SS)
 * @return {text} - Formatted date-time string
 * @see StrToTimeStampTZ
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DateToStr (
  pValue    timestamptz,
  pFormat   text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS   text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION DateToStr(timestamptz, text) TO PUBLIC;

--------------------------------------------------------------------------------
/**
 * @brief Format a timestamp value as a text string.
 * @param {timestamp} pValue - Timestamp to format
 * @param {text} pFormat - to_char format mask (default DD.MM.YYYY HH24:MI:SS)
 * @return {text} - Formatted date-time string
 * @see StrToTimeStamp
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DateToStr (
  pValue    timestamp,
  pFormat   text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS   text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION DateToStr(timestamp, text) TO PUBLIC;

--------------------------------------------------------------------------------
/**
 * @brief Format a date value as a text string.
 * @param {date} pValue - Date to format
 * @param {text} pFormat - to_char format mask (default DD.MM.YYYY)
 * @return {text} - Formatted date string
 * @see StrToDate
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DateToStr (
  pValue    date,
  pFormat   text DEFAULT 'DD.MM.YYYY'
) RETURNS   text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION DateToStr(date, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToDate ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Parse a text string into a date value using to_date.
 * @param {text} pValue - Date string to parse
 * @param {text} pFormat - to_date format mask (default DD.MM.YYYY)
 * @return {date} - Parsed date value
 * @see DateToStr
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION StrToDate (
  pValue    text,
  pFormat   text DEFAULT 'DD.MM.YYYY'
) RETURNS   date
AS $$
BEGIN
  RETURN to_date(pValue, pFormat);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION StrToDate(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToTimeStamp -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Parse a text string into a timestamp value using to_timestamp.
 * @param {text} pValue - Timestamp string to parse
 * @param {text} pFormat - to_timestamp format mask (default DD.MM.YYYY HH24:MI:SS)
 * @return {timestamp} - Parsed timestamp value
 * @see DateToStr
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION StrToTimeStamp (
  pValue    text,
  pFormat   text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS   timestamp
AS $$
BEGIN
  RETURN to_timestamp(pValue, pFormat);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION StrToTimeStamp(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToTimeStampTZ ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Parse a text string into a timezone-aware timestamp using to_timestamp.
 * @param {text} pValue - Timestamp string to parse
 * @param {text} pFormat - to_timestamp format mask (default DD.MM.YYYY HH24:MI:SS)
 * @return {timestamptz} - Parsed timestamptz value
 * @see DateToStr
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION StrToTimeStampTZ (
  pValue    text,
  pFormat   text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS   timestamptz
AS $$
BEGIN
  RETURN to_timestamp(pValue, pFormat);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION StrToTimeStampTZ(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToTime ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Parse a text string into a time value via dynamic SQL.
 * @param {text} pValue - Time string to parse (e.g. '14:30:00')
 * @return {time} - Parsed time value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION StrToTime (
  pValue    text
) RETURNS   time
AS $$
DECLARE
  t         time;
BEGIN
  EXECUTE 'SELECT time ' || quote_literal(pValue) INTO t;
  RETURN t;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION StrToTime(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToInterval ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Parse a text string into an interval value via dynamic SQL.
 * @param {text} pValue - Interval string to parse (e.g. '1 hour', '30 minutes')
 * @return {interval} - Parsed interval value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION StrToInterval (
  pValue    text
) RETURNS   interval
AS $$
DECLARE
  i         interval;
BEGIN
  EXECUTE 'SELECT interval ' || quote_literal(pValue) INTO i;
  RETURN i;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION StrToInterval(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION IntervalArrayToStr -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a two-dimensional interval array to a formatted text array.
 * @param {interval[][]} pValue - 2D array of intervals (e.g. schedule time ranges)
 * @param {text} pFormat - to_char format for each interval (default HH24:MI)
 * @return {text[][]} - 2D text array with formatted interval strings
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IntervalArrayToStr (
  pValue    interval[][],
  pFormat   text DEFAULT 'HH24:MI'
) RETURNS   text[][]
AS $$
DECLARE
  t         interval;
  r1        text[];
  r2        text[][];
BEGIN
  r2 := ARRAY[['','']];

  FOR i IN 1..coalesce(array_length(pValue, 1), 1)
  LOOP
    r1 := null;

    FOR j IN 1..coalesce(array_length(pValue, 2), 1)
    LOOP
      t := pValue[i][j];
      IF t IS NOT NULL THEN
        r1 := array_append(r1, TO_CHAR(t, pFormat));
      END IF;
    END LOOP;

    r2 := array_cat(r2, r1);
  END LOOP;

  RETURN r2[2:];
END;
$$ LANGUAGE plpgsql STRICT
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION IntervalArrayToStr(interval[][], text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION MINDATE ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Return the platform-wide minimum sentinel date (1970-01-01).
 * @return {date} - Epoch start date used as a NULL substitute
 * @see MAXDATE
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION MINDATE() RETURNS DATE
AS $$
BEGIN
  RETURN TO_DATE('1970-01-01', 'YYYY-MM-DD');
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION MINDATE() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION MAXDATE ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Return the platform-wide maximum sentinel date (4433-12-31).
 * @return {date} - Far-future date used as an "infinity" substitute
 * @see MINDATE
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION MAXDATE() RETURNS DATE
AS $$
BEGIN
  RETURN TO_DATE('4433-12-31', 'YYYY-MM-DD');
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION MAXDATE() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a null-sentinel UUID to actual NULL.
 * @param {uuid} pValue - UUID that may be the null sentinel (00000000-0000-4000-8000-000000000000)
 * @return {uuid} - NULL if the value equals the sentinel, otherwise the original value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckNull (
  pValue    uuid
) RETURNS   uuid
AS $$
BEGIN
  RETURN NULLIF(pValue, '00000000-0000-4000-8000-000000000000');
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION CheckNull(uuid) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert an empty string to actual NULL.
 * @param {text} pValue - Text that may be an empty string
 * @return {text} - NULL if empty, otherwise the original value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckNull (
  pValue    text
) RETURNS   text
AS $$
BEGIN
  RETURN NULLIF(pValue, '');
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION CheckNull(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert an empty JSON object to actual NULL.
 * @param {json} pValue - JSON value that may be an empty object
 * @return {json} - NULL if '{}', otherwise the original value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckNull (
  pValue    json
) RETURNS   json
AS $$
BEGIN
  RETURN NULLIF(pValue::jsonb, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION CheckNull(json) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert an empty JSONB object to actual NULL.
 * @param {jsonb} pValue - JSONB value that may be an empty object
 * @return {jsonb} - NULL if '{}', otherwise the original value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckNull (
  pValue    jsonb
) RETURNS   jsonb
AS $$
BEGIN
  RETURN NULLIF(pValue, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION CheckNull(jsonb) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a zero numeric to actual NULL.
 * @param {numeric} pValue - Numeric value that may be zero
 * @return {numeric} - NULL if 0, otherwise the original value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckNull (
  pValue    numeric
) RETURNS   numeric
AS $$
BEGIN
  RETURN NULLIF(pValue, 0);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION CheckNull(numeric) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a sentinel integer (-1) to actual NULL.
 * @param {integer} pValue - Integer value that may be -1
 * @return {integer} - NULL if -1, otherwise the original value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckNull (
  pValue    integer
) RETURNS   integer
AS $$
BEGIN
  RETURN NULLIF(pValue, -1);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION CheckNull(integer) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a MINDATE() timestamp to actual NULL.
 * @param {timestamp} pValue - Timestamp that may equal the minimum sentinel date
 * @return {timestamp} - NULL if equal to MINDATE(), otherwise the original value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckNull (
  pValue    timestamp
) RETURNS   timestamp
AS $$
BEGIN
  RETURN NULLIF(pValue, MINDATE());
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION CheckNull(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a MINDATE() timestamptz to actual NULL.
 * @param {timestamptz} pValue - Timestamptz that may equal the minimum sentinel date
 * @return {timestamptz} - NULL if equal to MINDATE(), otherwise the original value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckNull (
  pValue    timestamptz
) RETURNS   timestamptz
AS $$
BEGIN
  RETURN NULLIF(pValue, MINDATE());
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION CheckNull(timestamptz) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a zero interval to actual NULL.
 * @param {interval} pValue - Interval that may be zero
 * @return {interval} - NULL if interval '0', otherwise the original value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckNull (
  pValue    interval
) RETURNS   interval
AS $$
BEGIN
  RETURN NULLIF(pValue, interval '0');
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION CheckNull(interval) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetCompare ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Map a short comparison code to its SQL operator string.
 * @param {text} pCompare - Three-letter comparison code (EQL, NEQ, LSS, LEQ, GTR, GEQ, GIN, LKE, IKE, etc.)
 * @return {text} - SQL operator string with surrounding spaces, defaults to ' = '
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetCompare (
  pCompare  text
) RETURNS   text
AS $$
BEGIN
  CASE pCompare
  WHEN 'EQL' THEN
    RETURN ' = ';
  WHEN 'NEQ' THEN
    RETURN ' <> ';
  WHEN 'LSS' THEN
    RETURN ' < ';
  WHEN 'LEQ' THEN
    RETURN ' <= ';
  WHEN 'GTR' THEN
    RETURN ' > ';
  WHEN 'GEQ' THEN
    RETURN ' >= ';
  WHEN 'GIN' THEN
    RETURN ' @> ';
  WHEN 'AND' THEN
    RETURN ' & ';
  WHEN 'OR' THEN
    RETURN ' | ';
  WHEN 'XOR' THEN
    RETURN ' # ';
  WHEN 'NOT' THEN
    RETURN ' ~ ';
  WHEN 'ISN' THEN
    RETURN ' IS ';
  WHEN 'INN' THEN
    RETURN ' IS NOT ';
  WHEN 'LKE' THEN
    RETURN ' LIKE ';
  WHEN 'IKE' THEN
    RETURN ' ILIKE ';
  WHEN 'SIM' THEN
    RETURN ' SIMILAR TO ';
  WHEN 'PSX' THEN
    RETURN ' ~ ';
  WHEN 'PSI' THEN
    RETURN ' ~* ';
  WHEN 'PSN' THEN
    RETURN ' !~ ';
  WHEN 'PIN' THEN
    RETURN ' !~* ';
  ELSE
    NULL;
  END CASE;

  RETURN ' = ';
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION GetCompare(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- array_add_text --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Append a suffix string to every element in a text array.
 * @param {text[]} pArray - Source array of strings
 * @param {text} pText - Text to append to each element
 * @return {text[]} - New array with the suffix applied to each element
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION array_add_text (
  pArray    text[],
  pText     text
) RETURNS   text[]
AS $$
DECLARE
  i         integer;
  arResult  text[];
BEGIN
  FOR i IN 1..array_length(pArray, 1)
  LOOP
    arResult := array_append(arResult, pArray[i] || pText);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION array_add_text(text[], text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION min_array ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Find the minimum value in an array, optionally excluding a specific element.
 * @param {anyarray} parray - Array to scan
 * @param {anyelement} pelement - Value to exclude from comparison (optional)
 * @return {anyelement} - Minimum value found, or NULL on error
 * @see max_array
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION min_array (
  parray    anyarray,
  pelement  anyelement DEFAULT null
) RETURNS   anyelement
AS $$
DECLARE
  i         integer;
  r         integer;
BEGIN
  i := 1;
  r := null;
  FOR i IN 1..array_length(parray, 1)
  LOOP
    IF pelement IS NOT NULL THEN
      IF coalesce(r, pelement) = pelement THEN
        r = parray[i];
      ELSE
        IF parray[i] <> pelement THEN
          r = least(coalesce(r, parray[i]), parray[i]);
        END IF;
      END IF;
    ELSE
      r = least(coalesce(r, parray[i]), parray[i]);
    END IF;
  END LOOP;

  RETURN r;
EXCEPTION
WHEN others THEN
  RETURN null;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION min_array(anyarray, anyelement) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION max_array ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Find the maximum value in an array, optionally excluding a specific element.
 * @param {anyarray} parray - Array to scan
 * @param {anyelement} pelement - Value to exclude from comparison (optional)
 * @return {anyelement} - Maximum value found, or NULL on error
 * @see min_array
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION max_array (
  parray    anyarray,
  pelement  anyelement DEFAULT null
) RETURNS   anyelement
AS $$
DECLARE
  i         integer;
  r         integer;
BEGIN
  i := 1;
  r := null;
  FOR i IN 1..array_length(parray, 1)
  LOOP
    IF pelement IS NOT NULL THEN
      IF coalesce(r, pelement) = pelement THEN
        r = parray[i];
      ELSE
        IF parray[i] <> pelement THEN
          r = greatest(coalesce(r, parray[i]), parray[i]);
        END IF;
      END IF;
    ELSE
      r = greatest(coalesce(r, parray[i]), parray[i]);
    END IF;
  END LOOP;

  RETURN r;
EXCEPTION
WHEN others THEN
  RETURN null;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION max_array(anyarray, anyelement) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION inet_to_array ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Split an IPv4 address into an array of its four octets.
 * @param {inet} ip - IPv4 address to decompose
 * @return {text[]} - Array of four octet strings (index 0..3)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION inet_to_array (
  ip        inet
) RETURNS   text[]
AS $$
DECLARE
  r         text[];
  i         integer;
  p         integer;
  v         text;
BEGIN
  v := host(ip);
  p := position('.' in v);
  i := 0;

  WHILE p > 0
  LOOP
    r[i] := SubString(v FROM 1 FOR p - 1);
    v := SubString(v FROM p + 1);
    p := position('.' in v);
    i := i + 1;
  END LOOP;

  r[i] := v;

  RETURN r;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION inet_to_array(inet) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION UTC ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Return the current timestamp in UTC.
 * @return {timestamptz} - Current time converted to UTC
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UTC()
RETURNS     timestamptz
AS $$
BEGIN
  RETURN current_timestamp at time zone 'utc';
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION UTC() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetISOTime ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Format a timestamp as an ISO 8601 string with milliseconds.
 * @param {timestamp} pTime - Timestamp to format (defaults to current UTC time)
 * @return {text} - ISO 8601 formatted string (e.g. "2024-01-15T12:30:45.123Z")
 * @see GetEpoch
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetISOTime (
  pTime     timestamp DEFAULT current_timestamp at time zone 'utc'
) RETURNS   text
AS $$
BEGIN
  RETURN replace(to_char(pTime, 'YYYY-MM-DD#HH24:MI:SS.MSZ'), '#', 'T');
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION GetISOTime(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetEpoch -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a timestamp to a Unix epoch in seconds (truncated).
 * @param {timestamp} pTime - Timestamp to convert (defaults to current UTC time)
 * @return {double precision} - Whole seconds since 1970-01-01 00:00:00 UTC
 * @see GetEpochMs, GetISOTime
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetEpoch (
  pTime     timestamp DEFAULT current_timestamp at time zone 'utc'
) RETURNS   double precision
AS $$
BEGIN
  RETURN trunc(extract(EPOCH FROM pTime));
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION GetEpoch(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetEpochMs ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a timestamp to a Unix epoch in milliseconds (truncated).
 * @param {timestamp} pTime - Timestamp to convert (defaults to current UTC time)
 * @return {double precision} - Whole milliseconds since 1970-01-01 00:00:00 UTC
 * @see GetEpoch
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetEpochMs (
  pTime     timestamp DEFAULT current_timestamp at time zone 'utc'
) RETURNS   double precision
AS $$
BEGIN
  RETURN trunc(extract(EPOCH FROM pTime) * 1000);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION GetEpochMs(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION Dow ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Return the ISO day of week (Monday=1 .. Sunday=7) for a given timestamp.
 * @param {timestamptz} pDateTime - Timestamp to evaluate (defaults to now)
 * @return {int} - Day of week: 1 (Monday) through 7 (Sunday)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION Dow (
  pDateTime timestamptz DEFAULT Now()
) RETURNS   int
AS $$
DECLARE
  dow       int;
BEGIN
  dow := EXTRACT(DOW FROM pDateTime);

  IF dow = 0 THEN
    dow = 7;
  END IF;

  RETURN dow;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION Dow(timestamptz) TO PUBLIC;

--------------------------------------------------------------------------------
-- quote_literal_json ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Quote the value portion of a JSONB arrow expression (->>) for safe SQL embedding.
 * @param {text} pStr - String potentially containing a '->>' JSONB accessor
 * @return {text} - String with the accessor's value part properly quoted
 * @see array_quote_literal_json
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION quote_literal_json (
  pStr      text
) RETURNS   text
AS $$
DECLARE
  l         integer;
  c         integer;
BEGIN
  l := position('->>' in pStr);
  IF l > 0 THEN
    c := position(')' in SubStr(pStr, l + 3));
    IF position(E'\'' in pStr) = 0 THEN
      IF c > 0 THEN
        pStr := SubStr(pStr, 1, l + 2) || quote_literal(SubStr(pStr, l + 3, c - 1)) || ')';
      ELSE
        pStr := SubStr(pStr, 1, l + 2) || quote_literal(SubStr(pStr, l + 3));
      END IF;
    END IF;
  END IF;
  RETURN pStr;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION quote_literal_json(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- array_quote_literal_json ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Apply JSONB arrow quoting to every element in an array.
 * @param {anyarray} pArray - Array of strings potentially containing '->>' accessors
 * @return {anyarray} - Array with accessor values properly quoted
 * @see quote_literal_json
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION array_quote_literal_json (
  pArray    anyarray
) RETURNS   anyarray
AS $$
DECLARE
  i         integer;
  l         integer;
  vStr      text;
BEGIN
  FOR i IN 1..array_length(pArray, 1)
  LOOP
    vStr := pArray[i];
    l := position('->>' in vStr);
    IF l > 0 THEN
      IF position(E'\'' in vStr) = 0 THEN
        pArray[i] := SubString(vStr FROM 1 FOR l + 2) || quote_literal(SubString(vStr FROM l + 3));
      END IF;
    END IF;
  END LOOP;

  RETURN pArray;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION array_quote_literal_json(anyarray) TO PUBLIC;

--------------------------------------------------------------------------------
-- find_value_in_array ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a value in a key=value pair array by key name.
 * @param {anyarray} pArray - Array of "key=value" strings
 * @param {text} pKey - Key to search for
 * @return {text} - Associated value, or NULL if the key is not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION find_value_in_array (
  pArray    anyarray,
  pKey      text
) RETURNS   text
AS $$
DECLARE
  i         integer;
  pairs     text[];
BEGIN
  FOR i IN 1..array_length(pArray, 1)
  LOOP
    pairs := string_to_array(pArray[i], '=');
    IF pairs[1] = pKey THEN
      RETURN pairs[2];
    END IF;
  END LOOP;

  RETURN null;
END;
$$ LANGUAGE plpgsql STRICT
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION find_value_in_array(anyarray, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION result_success -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Return a standard success record with boolean result and message.
 * @return {record} - (result: true, message: 'Success')
 * @see error_success
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION result_success (
  result    out boolean,
  message   out text
)
RETURNS     record
AS $$
BEGIN
  result := true;
  message := 'Success';
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION result_success() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION error_success ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Return a standard success record with integer error code and message.
 * @return {record} - (result: 0, message: 'Success')
 * @see result_success
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION error_success (
  result    out int,
  message   out text
)
RETURNS     record
AS $$
BEGIN
  result := 0;
  message := 'Success';
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION error_success() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION random_between -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Generate a random integer within an inclusive range.
 * @param {int} low - Lower bound (inclusive)
 * @param {int} high - Upper bound (inclusive)
 * @return {int} - Random integer between low and high
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION random_between (
  low       int,
  high      int
) RETURNS   int
AS
$$
BEGIN
  RETURN floor(random() * (high - low + 1)) + low;
END;
$$ LANGUAGE plpgsql VOLATILE
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION random_between(int, int) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION bin_to_dec ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a binary digit string to its decimal numeric equivalent.
 * @param {text} B - String of '0' and '1' characters
 * @return {numeric} - Decimal value
 * @see dec_to_bin, bit_to_dec
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION bin_to_dec (
  B         text
) RETURNS   numeric
AS
$$
DECLARE
  N         numeric;
  L         integer;
  I         integer;
BEGIN
  N := 0;
  L := length(B);

  FOR I IN 1 .. L
  LOOP
    N := N + to_number(SubStr(B, I, 1), '0') * power(2::numeric, L - I);
  END LOOP;

  RETURN N;
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION dec_to_bin ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a decimal numeric value to a binary digit string.
 * @param {numeric} D - Decimal value to convert
 * @param {integer} L - Minimum output length (left-padded)
 * @param {text} F - Padding character (default '0')
 * @return {text} - Binary string representation
 * @see bin_to_dec
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION dec_to_bin (
  D         numeric,
  L         integer DEFAULT 1,
  F         text DEFAULT '0'
) RETURNS   text
AS
$$
DECLARE
  S         text;
  N         numeric;
BEGIN
  N := D;
  S := '';

  WHILE N > 0
  LOOP
    S := to_char(mod(N, 2), 'FM0') || S;
    N := floor(N / 2);
  END LOOP;

  RETURN lpad(S, greatest(length(S), L), F);
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION bit_to_dec ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a bit varying value to its decimal numeric equivalent.
 * @param {bit varying} B - Bit string to convert
 * @return {numeric} - Decimal value
 * @see bin_to_dec, dec_to_bin
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION bit_to_dec (
  B         bit varying
) RETURNS   numeric
AS
$$
BEGIN
  RETURN bin_to_dec(B::text);
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION hex_to_bit ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a hexadecimal string to a bit varying value.
 * @param {text} hex - Hexadecimal string (without '0x' prefix)
 * @return {bit varying} - Corresponding bit string
 * @see hex_to_int, hex_to_dec
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION hex_to_bit (
  hex       text
) RETURNS   bit varying
AS
$$
DECLARE
  bits      bit varying;
BEGIN
  EXECUTE 'SELECT x' || quote_literal(hex) INTO bits;
  RETURN bits;
END
$$ LANGUAGE plpgsql STABLE STRICT
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION hex_to_bit(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION hex_to_int ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a hexadecimal string to a bigint value.
 * @param {text} H - Hexadecimal string (without '0x' prefix)
 * @return {bigint} - Integer value (limited to bigint range)
 * @see hex_to_dec, hex_to_bit
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION hex_to_int (
  H         text
) RETURNS   bigint
AS
$$
DECLARE
  R         bigint;
BEGIN
  EXECUTE 'SELECT x' || quote_literal(H) || '::bigint' INTO R;
  RETURN R;
END
$$ LANGUAGE plpgsql STABLE STRICT
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION hex_to_int(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION hex_to_dec ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a hexadecimal string to an arbitrary-precision numeric value.
 * @param {text} H - Hexadecimal string (without '0x' prefix)
 * @return {numeric} - Decimal value (supports values larger than bigint)
 * @see hex_to_int, dec_to_hex
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION hex_to_dec (
  H         text
) RETURNS   numeric
AS
$$
DECLARE
  B         bit varying;
BEGIN
  EXECUTE 'SELECT x' || quote_literal(H) INTO B;
  RETURN bit_to_dec(B);
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION dec_to_hex ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a decimal numeric value to a lowercase hexadecimal string.
 * @param {numeric} D - Decimal value to convert
 * @param {int} L - Minimum output length (left-padded with '0')
 * @return {text} - Lowercase hexadecimal string
 * @see hex_to_dec
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION dec_to_hex (
  D         numeric,
  L         int default null
) RETURNS   text
AS
$$
DECLARE
  H         text;
  M         numeric;
  R         numeric;
BEGIN
  R := D;

  WHILE R > 0
  LOOP
    M := mod(R, 16);
    H := concat(
           CASE
             WHEN M < 10
             THEN chr(CAST(M + 48 AS INTEGER))
             ELSE chr(CAST(M + 87 AS INTEGER))
           END, H);
    R := div(R, 16);
  END LOOP;

  IF H IS NULL THEN
    H := '0';
  END IF;

  IF L IS NOT NULL AND length(H) < L THEN
    RETURN lpad(H, L, '0');
  END IF;

  RETURN H;
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION hex_to_num64 -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a hexadecimal string to a 256-bit numeric using byte-level bit shifting.
 * @param {text} H - Hexadecimal string (up to 64 hex chars / 32 bytes)
 * @return {numeric} - Numeric value representing the full 256-bit number
 * @see hex_to_dec
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION hex_to_num64 (
  H         text
) RETURNS   numeric
AS $$
  SELECT
    (get_byte(x,0)::int8<<(31*8)) |
    (get_byte(x,1)::int8<<(30*8)) |
    (get_byte(x,2)::int8<<(29*8)) |
    (get_byte(x,3)::int8<<(28*8)) |
    (get_byte(x,4)::int8<<(27*8)) |
    (get_byte(x,5)::int8<<(26*8)) |
    (get_byte(x,6)::int8<<(25*8)) |
    (get_byte(x,7)::int8<<(24*8)) |
    (get_byte(x,8)::int8<<(23*8)) |
    (get_byte(x,9)::int8<<(22*8)) |
    (get_byte(x,10)::int8<<(21*8)) |
    (get_byte(x,11)::int8<<(20*8)) |
    (get_byte(x,12)::int8<<(19*8)) |
    (get_byte(x,13)::int8<<(18*8)) |
    (get_byte(x,14)::int8<<(17*8)) |
    (get_byte(x,15)::int8<<(16*8)) |
    (get_byte(x,16)::int8<<(15*8)) |
    (get_byte(x,17)::int8<<(14*8)) |
    (get_byte(x,18)::int8<<(13*8)) |
    (get_byte(x,19)::int8<<(12*8)) |
    (get_byte(x,20)::int8<<(11*8)) |
    (get_byte(x,21)::int8<<(10*8)) |
    (get_byte(x,22)::int8<<(9*8)) |
    (get_byte(x,23)::int8<<(8*8)) |
    (get_byte(x,24)::int8<<(7*8)) |
    (get_byte(x,25)::int8<<(6*8)) |
    (get_byte(x,26)::int8<<(5*8)) |
    (get_byte(x,27)::int8<<(4*8)) |
    (get_byte(x,28)::int8<<(3*8)) |
    (get_byte(x,29)::int8<<(2*8)) |
    (get_byte(x,30)::int8<<(1*8)) |
    (get_byte(x,31)::int8)
  FROM (SELECT decode(lpad(H, 64, '0'), 'hex') AS x) AS a;
$$ LANGUAGE SQL STABLE STRICT;

--------------------------------------------------------------------------------
-- FUNCTION hex_to_bigint ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a hexadecimal string to a bigint using byte-level bit shifting.
 * @param {text} H - Hexadecimal string (up to 16 hex chars / 8 bytes)
 * @return {bigint} - Bigint value
 * @see hex_to_int, hex_to_num64
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION hex_to_bigint (
  H         text
) RETURNS   bigint
AS $$
  SELECT
    (get_byte(x,0)::int8<<(7*8)) |
    (get_byte(x,1)::int8<<(6*8)) |
    (get_byte(x,2)::int8<<(5*8)) |
    (get_byte(x,3)::int8<<(4*8)) |
    (get_byte(x,4)::int8<<(3*8)) |
    (get_byte(x,5)::int8<<(2*8)) |
    (get_byte(x,6)::int8<<(1*8)) |
    (get_byte(x,7)::int8)
  FROM (SELECT decode(lpad(H, 16, '0'), 'hex') AS x) AS a;
$$ LANGUAGE SQL STABLE STRICT;

--------------------------------------------------------------------------------
-- FUNCTION bit_copy -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Extract a contiguous range of bits from a numeric value as a decimal.
 * @param {numeric} B - Source numeric value interpreted as a bit field
 * @param {integer} P - Bit position (0-based from LSB) of the range start
 * @param {integer} C - Number of bits to extract
 * @return {numeric} - Decimal value of the extracted bit range
 * @see IEEE754_32, IEEE754_64
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION bit_copy (
  B         numeric,
  P         integer,
  C         integer
) RETURNS   numeric
AS
$$
DECLARE
  S         text;
BEGIN
  IF B >= 0 THEN
    S := dec_to_bin(B, 64, '0');
  ELSE
    S := dec_to_bin(B, 64, '1');
  END IF;

  RETURN bin_to_dec(SubStr(S, length(S) - (P + C - 1), C));
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION to_little_endian ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Reverse the byte order of a bytea value (big-endian to little-endian).
 * @param {bytea} B - Bytes in big-endian order
 * @return {bytea} - Bytes in little-endian order
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION to_little_endian (
  B         bytea
) RETURNS   bytea
AS $$
DECLARE
  R         bytea;
BEGIN
  FOR i IN 0 .. length(B) - 1
  LOOP
    IF R IS NOT NULL THEN
      R := decode(dec_to_hex(get_byte(B, i), 2), 'hex') || R;
    ELSE
      R := decode(dec_to_hex(get_byte(B, i), 2), 'hex');
    END IF;
  END LOOP;

  RETURN R;
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION to_little_endian ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Convert a numeric value to little-endian byte order and return as numeric.
 * @param {numeric} D - Decimal value to convert
 * @param {integer} L - Hex string length (byte count * 2) for the intermediate representation
 * @return {numeric} - Numeric value reinterpreted in little-endian byte order
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION to_little_endian (
  D         numeric,
  L         integer
) RETURNS   numeric
AS $$
DECLARE
  B         bytea;
  R         bytea;
BEGIN
  B := decode(dec_to_hex(D, L), 'hex');
  R := to_little_endian(B);
  RETURN hex_to_dec(encode(R, 'hex'));
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION to_little_endian ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Reverse the byte order of a hex string (big-endian to little-endian).
 * @param {text} H - Hexadecimal string in big-endian order
 * @return {text} - Hexadecimal string in little-endian order
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION to_little_endian (
  H         text
) RETURNS   text
AS $$
BEGIN
  RETURN encode(to_little_endian(decode(H, 'hex')), 'hex');
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- IEEE754_32 ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Decode a 32-bit IEEE 754 single-precision float from its numeric bit pattern.
 * @param {numeric} P - 32-bit value as a decimal number
 * @return {numeric} - Decoded floating-point value
 * @see IEEE754_64, bit_copy
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IEEE754_32 (
  P         numeric
) RETURNS   numeric
AS
$$
DECLARE
  F         numeric;
  S         numeric;
  E         numeric;
  M         numeric;
BEGIN
  S := bit_copy(P, 31, 1);
  E := bit_copy(P, 23, 8);
  M := bit_copy(P, 0, 23);

  F := power(-1, S) * power(2, E - 127) * (1 + M / power(2, 23));

  RETURN F;
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION IEEE754_32(numeric) TO PUBLIC;

--------------------------------------------------------------------------------
-- IEEE754_64 ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Decode a 64-bit IEEE 754 double-precision float from its numeric bit pattern.
 * @param {numeric} P - 64-bit value as a decimal number
 * @return {numeric} - Decoded floating-point value
 * @see IEEE754_32, bit_copy
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IEEE754_64 (
  P         numeric
) RETURNS   numeric
AS
$$
DECLARE
  F         numeric;
  S         numeric;
  E         numeric;
  M         numeric;
BEGIN
  S := bit_copy(P, 63, 1);
  E := bit_copy(P, 52, 11);
  M := bit_copy(P, 0, 52);

  F := power(-1, S) * power(2, E - 1023) * (1 + M / power(2, 52));

  RETURN F;
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION IEEE754_64(numeric) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION null_uuid ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Return the platform-wide null sentinel UUID.
 * @return {uuid} - Constant UUID 00000000-0000-4000-8000-000000000000
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION null_uuid (
) RETURNS   uuid
AS $$
BEGIN
  RETURN '00000000-0000-4000-8000-000000000000';
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION null_uuid() TO PUBLIC;

--------------------------------------------------------------------------------
-- CheckCodes ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validate a list of codes against a source set, raising an error for invalid ones.
 * @param {text[]} pSource - Allowed code values
 * @param {text[]} pCodes - Codes to validate
 * @return {text[]} - Array of valid codes only
 * @throws InvalidCodes - When any code is not found in the source set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckCodes (
  pSource   text[],
  pCodes    text[]
) RETURNS   text[]
AS $$
DECLARE
  arValid   text[];
  arInvalid text[];
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
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION CheckCodes(text[], text[]) TO PUBLIC;

--------------------------------------------------------------------------------
-- URLEncode -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Percent-encode a URL string per RFC 3986 (unreserved characters pass through).
 * @param {text} url - Raw URL string to encode
 * @return {text} - Percent-encoded string safe for use in query parameters
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION URLEncode (
  url       text
) RETURNS   text
AS $$
DECLARE
  result    text;
  c         text;
  h         text;
  i         int;
  j         int;
BEGIN
  result := '';

  FOR i IN 1..length(url)
  LOOP
    c := substr(url, i, 1);
    IF regexp_match(c, '[A-Za-z0-9_~.-]') IS NOT NULL THEN
      result := result || c;
    ELSE
      h := encode(convert_to(c, 'utf8'), 'hex');
      FOR j IN 0..length(h) / 2 - 1
      LOOP
        result := concat(result, '%', substr(h, j * 2 + 1, 2));
      END LOOP;
    END IF;
  END LOOP;

  RETURN result;
END
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION URLEncode(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- word_count ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count the number of whitespace-separated words in a string.
 * @param {text} str - Input text
 * @return {integer} - Number of words
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION word_count (
  str       text
) RETURNS   integer
AS $$
BEGIN
  RETURN (SELECT COUNT(*) FROM regexp_split_to_table(str, '\s+') as word);
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- generate_aws_signature ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Compute an AWS Signature Version 4 for S3 requests.
 * @param {text} HTTPMethod - HTTP method (GET, PUT, etc.)
 * @param {text} canonicalURI - URL path component
 * @param {text} canonicalQueryString - Sorted query string parameters
 * @param {text} canonicalHeaders - Lowercase sorted headers with values
 * @param {text} signedHeaders - Semicolon-separated list of signed header names
 * @param {text} hashedPayload - SHA-256 hex digest of the request body
 * @param {text} SECRET_KEY - AWS secret access key
 * @param {text} REGION - AWS region identifier (e.g. 'us-east-1')
 * @param {timestamp} currentTimeStamp - Override timestamp for testing (defaults to current UTC)
 * @return {text} - Hex-encoded HMAC-SHA256 signature
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION generate_aws_signature (
  HTTPMethod            text,
  canonicalURI          text,
  canonicalQueryString  text,
  canonicalHeaders      text,
  signedHeaders         text,
  hashedPayload         text,
  SECRET_KEY            text,
  REGION                text,
  currentTimeStamp      timestamp DEFAULT null
) RETURNS               text
AS $$
DECLARE
  canonicalRequest      text;
  stringToSign          text;
  dateKey               bytea;
  dateRegionKey         bytea;
  dateRegionServiceKey  bytea;
  signingKey            bytea;
  signature             text;
  currentDate           text;
BEGIN
  currentTimeStamp := coalesce(currentTimeStamp, current_timestamp AT TIME ZONE 'UTC');

  -- Build canonical request
  canonicalRequest := coalesce(HTTPMethod, 'GET') || E'\n' ||
                      coalesce(canonicalURI, '/') || E'\n' ||
                      coalesce(canonicalQueryString, '') || E'\n' ||
                      canonicalHeaders || E'\n' ||
                      signedHeaders || E'\n' ||
                      coalesce(hashedPayload, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');

  -- Format current date for the credential scope
  currentDate := to_char(currentTimeStamp, 'YYYYMMDD"T"HH24MISS"Z"');

  -- Build string to sign
  stringToSign := 'AWS4-HMAC-SHA256' || E'\n' ||
                  currentDate || E'\n' ||
                  to_char(currentTimeStamp, 'YYYYMMDD') || '/' ||
                  REGION || '/s3/aws4_request' || E'\n' ||
                  encode(digest(canonicalRequest, 'sha256'), 'hex');

  -- Derive the signing key through a chain of HMAC operations
  dateKey := hmac(to_char(currentTimeStamp, 'YYYYMMDD'), 'AWS4' || SECRET_KEY, 'sha256');
  dateRegionKey := hmac(convert_to(REGION, 'utf8'), dateKey, 'sha256');
  dateRegionServiceKey := hmac(convert_to('s3', 'utf8'), dateRegionKey, 'sha256');
  signingKey := hmac(convert_to('aws4_request', 'utf8'), dateRegionServiceKey, 'sha256');

  -- Produce the final signature
  signature := encode(hmac(convert_to(stringToSign, 'utf8'), signingKey, 'sha256'), 'hex');

  RETURN signature;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- get_hostname_from_uri -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Extract the hostname from a URI string (strips protocol and path).
 * @param {text} uri - Full URI (e.g. 'https://example.com/path?q=1')
 * @return {text} - Hostname portion only (e.g. 'example.com')
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION get_hostname_from_uri(uri TEXT)
RETURNS TEXT AS $$
DECLARE
  v_hostname TEXT;
BEGIN
  SELECT SubString(uri FROM '^(?:https?://)?([^/?#]+)') INTO v_hostname;
  RETURN v_hostname;
END;
$$ LANGUAGE plpgsql STRICT
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- get_input_value -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Extract the value attribute from an HTML input tag identified by a search string.
 * @param {text} html - HTML source to search
 * @param {text} str - Identifying string (e.g. input name) to locate the target tag
 * @return {text} - Content of the value="" attribute, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION get_input_value (
  html      text,
  str       text
) RETURNS   text
AS $$
DECLARE
  pos       int;
  value     text;
  start_pos int;
  end_pos   int;
BEGIN
  pos := position(str IN html);

  IF pos = 0 THEN
    RETURN NULL;
  END IF;

  start_pos := position('value="' IN SubString(html FROM pos));

  IF start_pos = 0 THEN
    RETURN NULL;
  END IF;

  -- Offset to the actual value content after 'value="'
  start_pos := pos + start_pos + length('value="') - 1;

  end_pos := position('"' IN SubString(html FROM start_pos));

  value := SubString(html FROM start_pos FOR end_pos - 1);

  RETURN value;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- is_valid_email --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validate an email address against a standard regex pattern.
 * @param {text} email - Email address string to validate
 * @return {boolean} - TRUE if the email matches the pattern, FALSE otherwise
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION is_valid_email (
  email             text
) RETURNS           boolean
AS $$
DECLARE
  email_pattern     text;
BEGIN
  email_pattern := '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  RETURN email ~ email_pattern;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;
