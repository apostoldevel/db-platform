--------------------------------------------------------------------------------
-- ALL_TAB_COLUMNS -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW all_tab_columns(table_name, column_id, column_name, data_type, udt_name)
AS
  SELECT table_name, ordinal_position as column_id, column_name, data_type, udt_name
    FROM information_schema.columns
   WHERE table_schema = 'kernel';

GRANT SELECT ON all_tab_columns TO PUBLIC;

--------------------------------------------------------------------------------
-- ALL_COL_COMMENTS ------------------------------------------------------------
--------------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION get_columns (
  pTable	text,
  pSchema	text DEFAULT current_schema(),
  pAlias	text DEFAULT null
) RETURNS	text[]
AS $$
DECLARE
  arResult	text[];
  r			record;
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

CREATE OR REPLACE FUNCTION GetColumns (
  pTable	text,
  pSchema	text DEFAULT current_schema(),
  pAlias	text DEFAULT null
) RETURNS	text[]
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

CREATE OR REPLACE FUNCTION get_routines (
  pRoutine      text,
  pSchema	    text DEFAULT current_schema(),
  pDataType 	boolean DEFAULT false,
  pAlias	    text DEFAULT null,
  pNameFrom     int DEFAULT 2
) RETURNS	    text[]
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

CREATE OR REPLACE FUNCTION GetRoutines (
  pRoutine      text,
  pSchema	    text DEFAULT current_schema(),
  pDataType 	boolean DEFAULT false,
  pAlias	    text DEFAULT null,
  pNameFrom     int DEFAULT 2
) RETURNS	    text[]
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

CREATE OR REPLACE FUNCTION array_pos (
  anyarray	    text[],
  anyelement 	text
) RETURNS	    int
AS $$
DECLARE
  i		        int;
  l		        int;
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
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION array_pos ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_pos (
  anyarray	    numeric[],
  anyelement 	numeric
) RETURNS	    int
AS $$
DECLARE
  i		        int;
  l		        int;
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
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION string_to_array_trim -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION string_to_array_trim (
  str		text,
  sep	 	text
) RETURNS	text[]
AS $$
DECLARE
  i		    int;
  pos		int;
  arr		text[];
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
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION str_to_inet --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION str_to_inet (
  str		text,
  OUT host	inet,
  OUT range integer
) RETURNS	record
AS $$
DECLARE
  vHost		text;
  vStr		text;

  pos		int;
  nMask		int;
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
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION IntToStr -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IntToStr (
  pValue	numeric,
  pFormat	text DEFAULT 'FM999999999990'
) RETURNS	text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION IntToStr(numeric, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToInt -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToInt (
  pValue	text,
  pFormat	text DEFAULT '999999999999'
) RETURNS	numeric
AS $$
BEGIN
  RETURN to_number(pValue, pFormat);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION IntToStr(numeric, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION DateToStr ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DateToStr (
  pValue	timestamptz,
  pFormat	text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION DateToStr(timestamptz, text) TO PUBLIC;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DateToStr (
  pValue	timestamp,
  pFormat	text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION DateToStr(timestamp, text) TO PUBLIC;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DateToStr (
  pValue	date,
  pFormat	text DEFAULT 'DD.MM.YYYY'
) RETURNS	text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION DateToStr(date, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToDate ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToDate (
  pValue	text,
  pFormat	text DEFAULT 'DD.MM.YYYY'
) RETURNS	date
AS $$
BEGIN
  RETURN to_date(pValue, pFormat);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION StrToDate(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToTimeStamp -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToTimeStamp (
  pValue	text,
  pFormat	text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	timestamp
AS $$
BEGIN
  RETURN to_timestamp(pValue, pFormat);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION StrToTimeStamp(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToTimeStampTZ ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToTimeStampTZ (
  pValue	text,
  pFormat	text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	timestamptz
AS $$
BEGIN
  RETURN to_timestamp(pValue, pFormat);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION StrToTimeStampTZ(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToTime ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToTime (
  pValue	text
) RETURNS	time
AS $$
DECLARE
  t         time;
BEGIN
  EXECUTE 'SELECT time ' || quote_literal(pValue) INTO t;
  RETURN t;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION StrToTime(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToInterval ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToInterval (
  pValue	text
) RETURNS	interval
AS $$
DECLARE
  i         interval;
BEGIN
  EXECUTE 'SELECT interval ' || quote_literal(pValue) INTO i;
  RETURN i;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION StrToInterval(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION IntervalArrayToStr -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IntervalArrayToStr (
  pValue	interval[][],
  pFormat   text DEFAULT 'HH24:MI'
) RETURNS	text[][]
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
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

GRANT EXECUTE ON FUNCTION IntervalArrayToStr(interval[][], text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION MINDATE ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION MINDATE() RETURNS DATE
AS $$
BEGIN
  RETURN TO_DATE('1970-01-01', 'YYYY-MM-DD');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION MINDATE() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION MAXDATE ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION MAXDATE() RETURNS DATE
AS $$
BEGIN
  RETURN TO_DATE('4433-12-31', 'YYYY-MM-DD');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION MAXDATE() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	uuid
) RETURNS	uuid
AS $$
BEGIN
  RETURN NULLIF(pValue, '00000000-0000-4000-8000-000000000000');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION CheckNull(uuid) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	text
) RETURNS	text
AS $$
BEGIN
  RETURN NULLIF(pValue, '');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION CheckNull(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	json
) RETURNS	json
AS $$
BEGIN
  RETURN NULLIF(pValue::jsonb, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION CheckNull(json) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	jsonb
) RETURNS	jsonb
AS $$
BEGIN
  RETURN NULLIF(pValue, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION CheckNull(jsonb) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	numeric
) RETURNS	numeric
AS $$
BEGIN
  RETURN NULLIF(pValue, 0);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION CheckNull(numeric) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	integer
) RETURNS	integer
AS $$
BEGIN
  RETURN NULLIF(pValue, -1);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION CheckNull(integer) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	timestamp
) RETURNS	timestamp
AS $$
BEGIN
  RETURN NULLIF(pValue, MINDATE());
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION CheckNull(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	timestamptz
) RETURNS	timestamptz
AS $$
BEGIN
  RETURN NULLIF(pValue, MINDATE());
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION CheckNull(timestamptz) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	interval
) RETURNS	interval
AS $$
BEGIN
  RETURN NULLIF(pValue, interval '0');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION CheckNull(interval) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetCompare ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCompare (
  pCompare	text
) RETURNS	text
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
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION GetCompare(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- array_add_text --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_add_text (
  pArray	text[],
  pText		text
) RETURNS	text[]
AS $$
DECLARE
  i		    integer;
  arResult	text[];
BEGIN
  FOR i IN 1..array_length(pArray, 1)
  LOOP
    arResult := array_append(arResult, pArray[i] || pText);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION array_add_text(text[], text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION min_array ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION min_array (
  parray	anyarray,
  pelement 	anyelement DEFAULT null
) RETURNS	anyelement
AS $$
DECLARE
  i		integer;
  r		integer;
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
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION min_array(anyarray, anyelement) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION max_array ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION max_array (
  parray	anyarray,
  pelement 	anyelement DEFAULT null
) RETURNS	anyelement
AS $$
DECLARE
  i		    integer;
  r		    integer;
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
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION max_array(anyarray, anyelement) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION inet_to_array ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION inet_to_array (
  ip		inet
) RETURNS	text[]
AS $$
DECLARE
  r		    text[];
  i		    integer;
  p		    integer;
  v		    text;
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
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION inet_to_array(inet) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION UTC ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UTC()
RETURNS 	timestamptz
AS $$
BEGIN
  RETURN current_timestamp at time zone 'utc';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION UTC() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetISOTime ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetISOTime (
  pTime		timestamp DEFAULT current_timestamp at time zone 'utc'
)
RETURNS 	text
AS $$
BEGIN
  RETURN replace(to_char(pTime, 'YYYY-MM-DD#HH24:MI:SS.MSZ'), '#', 'T');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION GetISOTime(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetEpoch -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEpoch (
  pTime		timestamp DEFAULT current_timestamp at time zone 'utc'
)
RETURNS 	double precision
AS $$
BEGIN
  RETURN trunc(extract(EPOCH FROM pTime));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION GetEpoch(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetEpochMs ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEpochMs (
  pTime		timestamp DEFAULT current_timestamp at time zone 'utc'
)
RETURNS 	double precision
AS $$
BEGIN
  RETURN trunc(extract(EPOCH FROM pTime) * 1000);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION GetEpochMs(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- quote_literal_json ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION quote_literal_json (
  pStr		text
) RETURNS	text
AS $$
DECLARE
  l		    integer;
  c		    integer;
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
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION quote_literal_json(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- array_quote_literal_json ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_quote_literal_json (
  pArray	anyarray
) RETURNS	anyarray
AS $$
DECLARE
  i		    integer;
  l		    integer;
  vStr		text;
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
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION array_quote_literal_json(anyarray) TO PUBLIC;

--------------------------------------------------------------------------------
-- find_value_in_array ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION find_value_in_array (
  pArray	anyarray,
  pKey      text
) RETURNS	text
AS $$
DECLARE
  i		    integer;
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
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

GRANT EXECUTE ON FUNCTION find_value_in_array(anyarray, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION result_success -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION result_success (
  result	out boolean,
  message	out text
)
RETURNS 	record
AS $$
BEGIN
  result := true;
  message := 'Success';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION result_success() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION error_success ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION error_success (
  result	out int,
  message	out text
)
RETURNS 	record
AS $$
BEGIN
  result := 0;
  message := 'Success';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION error_success() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION random_between -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION random_between (
  low     int,
  high    int
) RETURNS int
AS
$$
BEGIN
  RETURN floor(random() * (high - low + 1)) + low;
END;
$$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION random_between(int, int) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION bin_to_dec ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION bin_to_dec (
  B          text
) RETURNS    numeric
AS
$$
DECLARE
  N          numeric;
  L          integer;
  I          integer;
BEGIN
  N := 0;
  L := length(B);

  FOR I IN 1 .. L
  LOOP
	N := N + to_number(SubStr(B, I, 1), '0') * power(2::numeric, L - I);
  END LOOP;

  RETURN N;
END
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION dec_to_bin ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dec_to_bin (
  D			 numeric,
  L			 integer DEFAULT 1,
  F			 text DEFAULT '0'
) RETURNS    text
AS
$$
DECLARE
  S 		 text;
  N 		 numeric;
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
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION bit_to_dec ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION bit_to_dec (
  B          bit varying
) RETURNS    numeric
AS
$$
BEGIN
  RETURN bin_to_dec(B::text);
END
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION hex_to_bit ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hex_to_bit (
  hex			text
) RETURNS		bit varying
AS
$$
DECLARE
  bits          bit varying;
BEGIN
  EXECUTE 'SELECT x' || quote_literal(hex) INTO bits;
  RETURN bits;
END
$$ LANGUAGE plpgsql STABLE STRICT;

GRANT EXECUTE ON FUNCTION hex_to_bit(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION hex_to_int ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hex_to_int (
  H          text
) RETURNS    bigint
AS
$$
DECLARE
  R          bigint;
BEGIN
  EXECUTE 'SELECT x' || quote_literal(H) || '::bigint' INTO R;
  RETURN R;
END
$$ LANGUAGE plpgsql STABLE STRICT;

GRANT EXECUTE ON FUNCTION hex_to_int(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION hex_to_dec ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hex_to_dec (
  H          text
) RETURNS    numeric
AS
$$
DECLARE
  B          bit varying;
BEGIN
  EXECUTE 'SELECT x' || quote_literal(H) INTO B;
  RETURN bit_to_dec(B);
END
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION dec_to_hex ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dec_to_hex (
  D          numeric,
  L          int default null
) RETURNS    text
AS
$$
DECLARE
  H          text;
  M          numeric;
  R          numeric;
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
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION hex_to_num64 -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hex_to_num64 (
  H          text
) RETURNS    numeric
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
$$ LANGUAGE SQL STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION bin_to_dec ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hex_to_bigint (
  H          text
) RETURNS    bigint
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
$$ LANGUAGE SQL STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION bit_copy -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION bit_copy (
  B 		numeric,
  P 		integer,
  C 		integer
) RETURNS 	numeric
AS
$$
DECLARE
  S 		text;
BEGIN
  IF B >= 0 THEN
	S := dec_to_bin(B, 64, '0');
  ELSE
	S := dec_to_bin(B, 64, '1');
  END IF;

  RETURN bin_to_dec(SubStr(S, length(S) - (P + C - 1), C));
END
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION to_little_endian ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION to_little_endian (
  B         bytea
) RETURNS 	bytea
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
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION to_little_endian ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION to_little_endian (
  D 		numeric,
  L         integer
) RETURNS 	numeric
AS $$
DECLARE
  B         bytea;
  R         bytea;
BEGIN
  B := decode(dec_to_hex(D, L), 'hex');
  R := to_little_endian(B);
  RETURN hex_to_dec(encode(R, 'hex'));
END
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION to_little_endian ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION to_little_endian (
  H 		text
) RETURNS 	text
AS $$
BEGIN
  RETURN encode(to_little_endian(decode(H, 'hex')), 'hex');
END
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- IEEE754_32 ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IEEE754_32 (
  P			numeric
) RETURNS 	numeric
AS
$$
DECLARE
  F   		numeric;
  S   		numeric;
  E   		numeric;
  M   		numeric;
BEGIN
  S := bit_copy(P, 31, 1);
  E := bit_copy(P, 23, 8);
  M := bit_copy(P, 0, 23);

  F := power(-1, S) * power(2, E - 127) * (1 + M / power(2, 23));

  RETURN F;
END
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION IEEE754_32(numeric) TO PUBLIC;

--------------------------------------------------------------------------------
-- IEEE754_64 ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IEEE754_64 (
  P			numeric
) RETURNS 	numeric
AS
$$
DECLARE
  F   		numeric;
  S   		numeric;
  E   		numeric;
  M   		numeric;
BEGIN
  S := bit_copy(P, 63, 1);
  E := bit_copy(P, 52, 11);
  M := bit_copy(P, 0, 52);

  F := power(-1, S) * power(2, E - 1023) * (1 + M / power(2, 52));

  RETURN F;
END
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION IEEE754_64(numeric) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION null_uuid ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION null_uuid (
) RETURNS	uuid
AS $$
BEGIN
  RETURN '00000000-0000-4000-8000-000000000000';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION null_uuid() TO PUBLIC;

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
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION CheckCodes(text[], text[]) TO PUBLIC;

--------------------------------------------------------------------------------
-- URLEncode -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION URLEncode (
  url       text
) RETURNS   text
AS $$
DECLARE
  result    text;
  c         text;
  i         int;
BEGIN
  result := '';

  FOR i IN 1..length(url)
  LOOP
    c := substr(url, i, 1);
    IF regexp_match(c, '[A-Za-z0-9_~.-]') IS NOT NULL THEN
      result := result || c;
    ELSE
      result := concat(result, '%', to_hex(ascii(c)));
    END IF;
  END LOOP;

  RETURN result;
END
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION URLEncode(text) TO PUBLIC;
