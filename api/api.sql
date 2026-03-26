--------------------------------------------------------------------------------
-- API -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- API LOG ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.log
AS
  SELECT * FROM apiLog;

GRANT SELECT ON api.log TO administrator;

--------------------------------------------------------------------------------
-- api.log ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Filter API log entries for the current user.
 * @param {text} pUserName - Filter by username (NULL = all)
 * @param {text} pPath - Filter by request path (NULL = all)
 * @param {timestamptz} pDateFrom - Start of the time range (inclusive)
 * @param {timestamptz} pDateTo - End of the time range (exclusive)
 * @return {SETOF api.log} - Matching log records (max 500)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.log (
  pUserName     text DEFAULT null,
  pPath         text DEFAULT null,
  pDateFrom     timestamptz DEFAULT null,
  pDateTo       timestamptz DEFAULT null
) RETURNS       SETOF api.log
AS $$
  SELECT *
    FROM api.log
   WHERE username = coalesce(pUserName, username)
     AND path = coalesce(pPath, path)
     AND datetime >= coalesce(pDateFrom, MINDATE())
     AND datetime < coalesce(pDateTo, MAXDATE())
   ORDER BY datetime DESC, id
   LIMIT 500
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_log -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a single API log entry by identifier.
 * @param {bigint} pId - Log record identifier
 * @return {SETOF api.log} - The matching log record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_log (
  pId       bigint
) RETURNS   SETOF api.log
AS $$
  SELECT * FROM api.log WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_log ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count API log records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_log (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'log', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_log ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List API log entries with dynamic search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions array: [{"condition":"AND|OR","field":"<col>","compare":"EQL|NEQ|...","value":"<val>"}, ...]
 * @param {jsonb} pFilter - Simple key-value filter: {"<col>": "<val>"}
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names for ORDER BY
 * @return {SETOF api.log} - Matching log records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_log (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.log
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'log', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.sql ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Build a dynamic SQL SELECT query with search, filter, pagination, and ordering.
 * @param {text} pScheme - Schema name (e.g. 'api')
 * @param {text} pTable - View/table name within the schema
 * @param {jsonb} pSearch - Search conditions: [{"condition":"AND|OR","field":"<col>","compare":"<op>","value":"<val>"}, ...]
 * @param {jsonb} pFilter - Simple key-value filter: {"<col>": "<val>"}
 * @param {integer} pLimit - Maximum number of rows (default 500)
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names for ORDER BY
 * @param {jsonb} pFields - Array of column names for SELECT (NULL = all)
 * @param {jsonb} pGroupBy - Array of column names for GROUP BY
 * @return {text} - Complete SQL query string ready for EXECUTE
 *
 * Compare operators:
 *   EQL = equal, NEQ = not equal, LSS = less than, LEQ = less or equal,
 *   GTR = greater than, GEQ = greater or equal, GIN = JSON containment,
 *   AND/OR/XOR/NOT = bitwise operators,
 *   ISN = IS NULL, INN = IS NOT NULL (value key must be omitted),
 *   LKE = LIKE, IKE = ILIKE (value must include '%' wildcards),
 *   SIM = SIMILAR TO,
 *   PSX = POSIX ~, PSI = ~*, PSN = !~, PIN = !~*
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.sql (
  pScheme       text,
  pTable        text,
  pSearch       jsonb DEFAULT null,
  pFilter       jsonb DEFAULT null,
  pLimit        integer DEFAULT null,
  pOffSet       integer DEFAULT null,
  pOrderBy      jsonb DEFAULT null,
  pFields       jsonb DEFAULT null,
  pGroupBy      jsonb DEFAULT null
) RETURNS       text
AS $$
DECLARE
  r             record;

  uId           uuid;

--  vTable        text;

  vWith         text;
  vSelect       text;
  vWhere        text;
  vOrderBy      text;
  vJoin         text;

  vCondition    text;
  vField        text;
  vCompare      text;
  vValue        text;
  vLStr         text;
  vRStr         text;

  arValues      text[];
  arColumns     text[];
BEGIN
/*
  SELECT table_name INTO vTable
    FROM information_schema.tables
   WHERE table_catalog = current_database()
     AND table_schema = pScheme
     AND table_name = pTable
     AND table_type = 'VIEW';

  IF NOT FOUND THEN
    PERFORM ViewNotFound(pScheme, pTable);
  END IF;
*/

  pOrderBy := NULLIF(pOrderBy, '[]');
  pGroupBy := NULLIF(pGroupBy, '[]');

  arColumns := GetColumns(pTable, pScheme);

  vSelect := coalesce(vWith, '') || 'SELECT ' || JsonbToFields(pFields, arColumns) || E'\n  FROM ' || pScheme || '.' || pTable || ' t ' || coalesce(vJoin, '');

  IF pFilter IS NOT NULL THEN
    PERFORM CheckJsonbKeys(pTable || '/filter', arColumns, pFilter);

    FOR r IN SELECT * FROM jsonb_each(pFilter)
    LOOP
      IF jsonb_typeof(r.value) = 'array' THEN
        pSearch := coalesce(pSearch, '[]'::jsonb) || jsonb_build_object('field', r.key, 'valarr', r.value);
      ELSE
        pSearch := coalesce(pSearch, '[]'::jsonb) || jsonb_build_object('field', r.key, 'value', r.value);
      END IF;
    END LOOP;
  END IF;

  IF pSearch IS NOT NULL THEN

    IF jsonb_typeof(pSearch) = 'array' THEN

      PERFORM CheckJsonbKeys(pTable || '/search', ARRAY['condition', 'field', 'compare', 'value', 'valarr', 'lstr', 'rstr'], pSearch);

      FOR r IN SELECT * FROM jsonb_to_recordset(pSearch) AS x(condition text, field text, compare text, value text, valarr jsonb, lstr text, rstr text)
      LOOP
        vCondition := coalesce(upper(r.condition), 'AND');
        vField     := coalesce(lower(r.field), '');
        vCompare   := coalesce(upper(r.compare), 'EQL');
        vLStr      := CASE WHEN r.lstr = '(' THEN '(' ELSE '' END;
        vRStr      := CASE WHEN r.rstr = ')' THEN ')' ELSE '' END;

        vField := quote_literal_json(vField);

        arValues := array_cat(null, ARRAY['AND', 'OR']);
        IF NOT vCondition = ANY (arValues) THEN
          PERFORM IncorrectValueInArray(vCondition, 'condition', arValues);
        END IF;

        IF NOT vField = ANY (arColumns) THEN
          PERFORM IncorrectValueInArray(vField, 'field', arColumns);
        END IF;

        IF r.valarr IS NOT NULL THEN
          vValue := jsonb_array_to_string(r.valarr, ',');

          IF vValue IS NOT NULL THEN
            vCompare := coalesce(nullif(upper(vCompare), 'EQL'), 'IN');

            arValues := array_cat(null, ARRAY['IN', 'NOT IN']);
            IF NOT vCompare = ANY (arValues) THEN
              PERFORM IncorrectValueInArray(coalesce(r.compare, ''), 'compare', arValues);
            END IF;

            IF vWhere IS NULL THEN
              vWhere := E'\n WHERE ' || vField || ' ' || vCompare || ' (' || vValue || ')';
            ELSE
              vWhere := vWhere || E'\n   ' || vCondition || ' ' || vField || ' ' || vCompare || ' (' || vValue  || ')';
            END IF;
          END IF;

        ELSE
          vValue := quote_nullable(r.value);

          arValues := array_cat(null, ARRAY['EQL', 'NEQ', 'LSS', 'LEQ', 'GTR', 'GEQ', 'GIN', 'AND', 'OR', 'XOR', 'NOT', 'ISN', 'INN', 'LKE', 'IKE', 'SIM', 'PSX', 'PSI', 'PSN', 'PIN']);
          IF NOT vCompare = ANY (arValues) THEN
            PERFORM IncorrectValueInArray(vCompare, 'compare', arValues);
          END IF;

          IF vField = 'statetypecode' THEN
            vField := 'statetype';
            SELECT id INTO uId FROM db.state_type WHERE code = r.value;
            vValue := quote_nullable(uId);
          ELSIF vField = 'typecode' THEN
            vField := 'type';
            SELECT id INTO uId FROM db.type WHERE code = r.value;
        	vValue := quote_nullable(uId);
		  ELSIF vField = 'classcode' THEN
			vField := 'class';
			SELECT id INTO uId FROM db.class_tree WHERE code = r.value;
			vValue := quote_nullable(uId);
		  ELSIF vField = 'entitycode' THEN
			vField := 'entity';
			SELECT id INTO uId FROM db.entity WHERE code = r.value;
			vValue := quote_nullable(uId);
		  END IF;

          IF vCompare IN ('AND', 'OR', 'XOR', 'NOT') THEN
            vValue := vValue || ' = ' || vValue;
          END IF;

          IF vWhere IS NULL THEN
            vWhere := E'\n WHERE ' || vLStr || vField || GetCompare(vCompare) || vValue || vRStr;
          ELSE
            vWhere := vWhere || E'\n   ' || vCondition || ' ' || vLStr || vField || GetCompare(vCompare) || vValue || vRStr;
          END IF;
        END IF;

      END LOOP;

    ELSE
      PERFORM IncorrectJsonType(jsonb_typeof(pSearch), 'array');
    END IF;

  END IF;

  vSelect := vSelect || coalesce(vWhere, '');

  IF pGroupBy IS NOT NULL THEN
    PERFORM CheckJsonbValues('groupby', arColumns, pGroupBy);
    IF jsonb_typeof(pGroupBy) = 'array' THEN
      IF JsonbToStrArray(pGroupBy) IS NOT NULL THEN
        vSelect := vSelect || E'\n GROUP BY ' || array_to_string(array_quote_literal_json(JsonbToStrArray(pGroupBy)), ',');
      END IF;
    END IF;
  END IF;

  IF pOrderBy IS NOT NULL THEN
    IF jsonb_typeof(pOrderBy) = 'array' THEN
      vOrderBy := JsonbToOrderBy(pOrderBy, arColumns);
      IF vOrderBy IS NOT NULL THEN
        vSelect := vSelect || E'\n ORDER BY ' || vOrderBy;
      END IF;
    END IF;
  ELSE
    IF 'sequence' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY sequence';
    ELSIF 'created' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY created DESC';
    ELSIF 'date' = ANY(arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY date DESC';
    ELSIF 'datetime' = ANY(arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY datetime DESC';
    ELSIF 'name' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY name';
    ELSIF 'label' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY label';
    ELSIF 'text' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY text';
    ELSIF 'code' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY code';
    ELSIF 'id' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY id';
    END IF;
  END IF;

  IF pLimit IS NOT NULL THEN
    IF pLimit > 0 THEN
      vSelect := vSelect || E'\n LIMIT ' || pLimit;
    END IF;
  ELSE
    vSelect := vSelect || E'\n LIMIT 500';
  END IF;

  IF pOffSet IS NOT NULL THEN
    vSelect := vSelect || E'\nOFFSET ' || pOffSet;
  END IF;

  IF GetDebugMode() THEN
    PERFORM WriteToEventLog('D', 9001, 'sql', vSelect);
  END IF;

  RETURN vSelect;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.run ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a REST JSON API request by resolving the route and running the endpoint.
 * @param {text} pMethod - HTTP method (GET, POST, PUT, DELETE)
 * @param {text} pPath - Full request path (e.g. "/api/v1/user/get")
 * @param {jsonb} pPayload - Request body as JSON
 * @return {SETOF json} - JSON result rows from the endpoint, or an error object
 * @throws RouteIsEmpty - When pPath is NULL or empty
 * @throws RouteNotFound - When no matching path node exists
 * @throws EndPointNotSet - When no endpoint is bound to the resolved route
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.run (
  pMethod		text,
  pPath			text,
  pPayload		jsonb DEFAULT null
) RETURNS		SETOF json
AS $$
DECLARE
  r				record;

  arPath		text[];

  uPath			uuid;
  uEndpoint		uuid;

  nLength		integer;

  nApiId        bigint;
  dtBegin       timestamptz;

  vMessage      text;
  vContext      text;
  vErrorId      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  dtBegin := clock_timestamp();

  uPath := QueryPath(pPath);
  IF uPath IS NULL THEN
	PERFORM RouteNotFound(pPath);
  END IF;

  uEndpoint := GetEndpoint(uPath, pMethod);
  IF uEndpoint IS NULL THEN
	PERFORM EndPointNotSet(pPath);
  END IF;

  arPath := path_to_array(pPath);
  nLength := array_length(arPath, 1);

  pPath := '/';
  IF nLength >= 3 THEN
    FOR i IN 3..nLength
    LOOP
	  pPath := coalesce(nullif(pPath, '/'), '') || '/' || arPath[i];
    END LOOP;
  END IF;

  IF arPath[nLength] = 'count' THEN
    pPayload := pPayload || jsonb_build_object('reclimit', 0);
  END IF;

  nApiId := AddApiLog(pPath, pPayload);

  FOR r IN EXECUTE GetEndpointDefinition(uEndpoint) USING pPath, pPayload
  LOOP
	RETURN NEXT r;
  END LOOP;

  UPDATE db.api_log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  nApiId := AddApiLog(pPath, pPayload);
  UPDATE db.api_log SET eventid = AddEventLog('E', ErrorCode, 'run', ErrorMessage) WHERE id = nApiId;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
