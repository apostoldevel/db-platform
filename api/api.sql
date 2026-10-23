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
  -- NULL-safe filter for nullable columns (username / path can be NULL
  -- for anonymous or system-internal calls). The naive
  -- `col = coalesce(NULL, col)` form drops those rows entirely.
  SELECT *
    FROM api.log
   WHERE (pUserName IS NULL OR username = pUserName)
     AND (pPath     IS NULL OR path     = pPath)
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
 * @param {jsonb} pSearch - Search conditions: [{"condition":"AND|OR","field":"<col>","compare":"<op>","value":"<val>","lstr":"(","rstr":")"}, ...]
 * @param {jsonb} pFilter - Simple key-value filter: {"<col>": "<val>"} or {"<col>": [<val>, ...]}; always ANDed
 *                          to the whole search as a group: WHERE (<search>) AND <filter>
 * @param {integer} pLimit - Maximum number of rows (default 500)
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names for ORDER BY
 * @param {jsonb} pFields - Array of column names for SELECT (NULL = all)
 * @param {jsonb} pGroupBy - Array of column names for GROUP BY
 * @return {text} - Complete SQL query string ready for EXECUTE
 * @throws IncorrectValueInArray - When the lstr/rstr brackets of pSearch do not balance
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

  vTable        text;
  vFields       text;

  vSelect       text;
  vWhere        text;
  vOrderBy      text;
  vFrom         text;
  vWith         text;

  vCondition    text;
  vField        text;
  vCompare      text;
  vValue        text;
  vLStr         text;
  vRStr         text;
  vExpr         text;
  vSearchWhere  text;
  vFilterWhere  text;

  jFilter       jsonb;
  nDepth        integer;
  bEmptyBound   boolean := false;

  arValues      text[];
  arColumns     text[];
BEGIN
  pOrderBy := NULLIF(pOrderBy, '[]');
  pGroupBy := NULLIF(pGroupBy, '[]');

  arColumns := GetColumns(pTable, pScheme);
  vFields := nullif(JsonbToFields(pFields, arColumns), '*');

  IF pScheme = 'kernel' AND GetAccessMode() THEN
    SELECT table_name INTO vTable
      FROM information_schema.tables
     WHERE table_catalog = current_database()
       AND table_schema = 'kernel'
       AND table_name = CASE WHEN lower(pTable) = 'object'
                             THEN 'accessobject'  -- Object<X> -> Access<X> below would give 'access' for the table Object itself: no such view, no join
                             ELSE replace(lower(pTable), 'object', 'access') END
       AND table_type = 'VIEW';

    IF FOUND THEN
      -- Materialise the access set once and filter the view by it as a semi-join,
      -- inside the FROM: (SELECT * FROM <view> WHERE id IN (SELECT object FROM aou)) t.
      --
      -- Access<X> is a blocking aggregate (GROUP BY object HAVING bit_or(allow) &
      -- ~bit_or(deny) & B'100' = B'100'). The planner cannot cost a HAVING over an
      -- aggregate and estimates rows=1. Joined to it (INNER JOIN aou, the form before
      -- 1.2.34), that estimate makes aou the outer side of a Nested Loop and the view —
      -- itself a join of several tables — is run once per accessible object: on the
      -- apostol-csms dev base a tenant's owner listing payment providers (2 380
      -- accessible objects) took 74.9 s, 27.1 s with the join alone (T879).
      -- MATERIALIZED alone did not cure it: the set is built once, but its size is
      -- still estimated as 1.
      --
      -- As a semi-join the plan is measured, not guaranteed: the estimate is still 1,
      -- but on that base the view was scanned once against the hashed set. Measured
      -- there (T879 p3) on 38 Object<X> views x 4 non-admin sessions, same rows in
      -- every case: 14 calls over 40 s fell to 0.3-18 s, the total from 829 s to
      -- 343 s. The price: where a session's set is empty or tiny, the old loop ended
      -- in 7-22 ms and the semi-join scans the whole view, 0.4-1.0 s on that volume.
      -- A view slow by itself (ObjectDocument, 37 s) is slow in both forms. The rows
      -- are the same in both forms: every access set is unique on object, so the
      -- join never multiplied a row.
      --
      -- In the FROM, not in the WHERE: the WHERE below is built from the caller's
      -- search and filter. A subquery in the FROM is a separate scope — the planner
      -- flattens it, and no condition of the caller can reach into it.
      -- Not enable_nestloop either: transaction-scoped, it stays off for every point
      -- lookup later in the same call (the T037 dead end).
      vWith := format('WITH aou AS MATERIALIZED (SELECT object FROM %s.%s)', pScheme, vTable) || E'\n';
      vFrom := format('(SELECT * FROM %s.%s WHERE id IN (SELECT object FROM aou)) t', pScheme, pTable);
    END IF;
  END IF;

  vSelect := coalesce(vWith, '') || 'SELECT ' || coalesce(vFields, 't.*') || E'\n  FROM ' || coalesce(vFrom, pScheme || '.' || pTable || ' t ');

  -- The search and the filter are built into two separate fragments and joined
  -- as `WHERE (<search>) AND <filter>`. The filter is where a caller passes an
  -- access bound (e.g. {"id": [...]}), so it applies to the result of the whole
  -- search, whatever conditions (AND/OR) the search itself contains. The brackets
  -- a search may carry (lstr/rstr) must balance, so that a search cannot close
  -- the outer group itself.
  IF pFilter IS NOT NULL THEN
    PERFORM CheckJsonbKeys(pTable || '/filter', arColumns, pFilter);

    FOR r IN SELECT * FROM jsonb_each(pFilter)
    LOOP
      IF jsonb_typeof(r.value) = 'array' THEN
        jFilter := coalesce(jFilter, '[]'::jsonb) || jsonb_build_object('field', r.key, 'valarr', r.value, 'bound', true);
      ELSE
        jFilter := coalesce(jFilter, '[]'::jsonb) || jsonb_build_object('field', r.key, 'value', r.value, 'bound', true);
      END IF;
    END LOOP;
  END IF;

  IF pSearch IS NOT NULL THEN
    IF jsonb_typeof(pSearch) = 'array' THEN
      -- 'bound' is not accepted here: only the filter elements above carry it.
      PERFORM CheckJsonbKeys(pTable || '/search', ARRAY['condition', 'field', 'compare', 'value', 'valarr', 'lstr', 'rstr'], pSearch);
    ELSE
      PERFORM IncorrectJsonType(jsonb_typeof(pSearch), 'array');
    END IF;
  END IF;

  IF pSearch IS NOT NULL OR jFilter IS NOT NULL THEN

    nDepth := 0;

    -- The search elements first, then the filter elements, in array order.
    FOR r IN SELECT * FROM jsonb_to_recordset(coalesce(pSearch, '[]'::jsonb) || coalesce(jFilter, '[]'::jsonb)) AS x(condition text, field text, compare text, value text, valarr jsonb, lstr text, rstr text, bound boolean)
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

      vExpr := null;

      IF r.valarr IS NOT NULL THEN
        vValue := jsonb_array_to_string(r.valarr, ',');

        IF vValue IS NOT NULL THEN
          vCompare := coalesce(nullif(upper(vCompare), 'EQL'), 'IN');

          arValues := array_cat(null, ARRAY['IN', 'NOT IN']);
          IF NOT vCompare = ANY (arValues) THEN
            PERFORM IncorrectValueInArray(coalesce(r.compare, ''), 'compare', arValues);
          END IF;

          -- lstr/rstr are not applied to a valarr element.
          vExpr := vField || ' ' || vCompare || ' (' || vValue || ')';
        ELSIF coalesce(r.bound, false) THEN
          bEmptyBound := true;
        END IF;

      ELSE
        vValue := quote_nullable(r.value);

        arValues := array_cat(null, ARRAY['EQL', 'NEQ', 'LSS', 'LEQ', 'GTR', 'GEQ', 'GIN', 'AND', 'OR', 'XOR', 'NOT', 'ISN', 'INN', 'LKE', 'IKE', 'SIM', 'PSX', 'PSI', 'PSN', 'PIN']);
        IF NOT vCompare = ANY (arValues) THEN
          PERFORM IncorrectValueInArray(vCompare, 'compare', arValues);
        END IF;

        IF NOT (vCompare = ANY (ARRAY['ISN', 'INN'])) AND nullif(r.value, '') IS NULL THEN
          IF coalesce(r.bound, false) THEN
            bEmptyBound := true;
          END IF;
          CONTINUE;
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

        vExpr := vLStr || vField || GetCompare(vCompare) || vValue || vRStr;

        IF NOT coalesce(r.bound, false) THEN
          -- Count only the brackets that reach the text: a running depth below
          -- zero closes a group the search did not open.
          nDepth := nDepth + length(vLStr);
          IF nDepth - length(vRStr) < 0 THEN
            PERFORM IncorrectValueInArray(')', pTable || '/search', ARRAY['balanced brackets']);
          END IF;
          nDepth := nDepth - length(vRStr);
        END IF;
      END IF;

      IF vExpr IS NOT NULL THEN
        IF coalesce(r.bound, false) THEN
          IF vFilterWhere IS NULL THEN
            vFilterWhere := vExpr;
          ELSE
            vFilterWhere := vFilterWhere || E'\n   ' || vCondition || ' ' || vExpr;
          END IF;
        ELSE
          IF vSearchWhere IS NULL THEN
            vSearchWhere := vExpr;
          ELSE
            vSearchWhere := vSearchWhere || E'\n   ' || vCondition || ' ' || vExpr;
          END IF;
        END IF;
      END IF;

    END LOOP;

    IF nDepth > 0 THEN
      PERFORM IncorrectValueInArray('(', pTable || '/search', ARRAY['balanced brackets']);
    END IF;

    -- A bound with nothing in it (null, '' or []) admits no row. Skipping it, as an
    -- empty search condition is skipped, would widen the list to everything the rest
    -- of the query allows: a caller that builds its bound from a function of the
    -- session gets no bound at all when that function returns NULL.
    -- A filter that has no key is a different thing and stays unbounded.
    IF bEmptyBound THEN
      vFilterWhere := 'false';
    END IF;

    -- Search alone and filter alone give a plain WHERE; the brackets around the
    -- search appear only when both are present.
    IF vSearchWhere IS NOT NULL AND vFilterWhere IS NOT NULL THEN
      vWhere := E'\n WHERE (' || vSearchWhere || E')\n   AND ' || vFilterWhere;
    ELSIF vSearchWhere IS NOT NULL THEN
      vWhere := E'\n WHERE ' || vSearchWhere;
    ELSIF vFilterWhere IS NOT NULL THEN
      vWhere := E'\n WHERE ' || vFilterWhere;
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
    PERFORM WriteToEventLog('D', 9010, 'debug', 'sql', vSelect);
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
 * @throws EndPointNotSet - When no endpoint is bound to the resolved route, or
 *         the path is under /api but not /api/v1 (since 1.2.36)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.run (
  pMethod        text,
  pPath            text,
  pPayload        jsonb DEFAULT null
) RETURNS        SETOF json
AS $$
DECLARE
  r                record;

  arPath        text[];

  uPath            uuid;
  uEndpoint        uuid;

  nLength        integer;

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

  -- api.run is the /api/v1 dispatcher: RegisterRoute files its routes under v1,
  -- and /api/v2 belongs to the gateway (daemon.begin admits only that). Without
  -- this rule QueryPath found a v2 route guard and its definition ran here as
  -- an endpoint — a raw 500 instead of a refusal (ship-safety T302). Split the
  -- same way QueryPath splits, so '//' or a trailing '/' read the same; a root
  -- other than /api keeps its RouteNotFound.
  arPath := path_to_array(pPath);
  IF arPath[1] = 'api' AND arPath[2] IS DISTINCT FROM 'v1' THEN
    PERFORM EndPointNotSet(pPath);
  END IF;

  uPath := QueryPath(pPath);
  IF uPath IS NULL THEN
    PERFORM RouteNotFound(pPath);
  END IF;

  uEndpoint := GetEndpoint(uPath, pMethod);
  IF uEndpoint IS NULL THEN
    PERFORM EndPointNotSet(pPath);
  END IF;

  nLength := array_length(arPath, 1);

  pPath := '/';
  IF nLength >= 3 THEN
    FOR i IN 3..nLength
    LOOP
      pPath := coalesce(nullif(pPath, '/'), '') || '/' || arPath[i];
    END LOOP;
  END IF;

  -- A /count carries no page: reclimit is pinned to 0 (api.sql then emits no
  -- LIMIT). For a batch — an array of requests — the key goes into EACH
  -- element: appended to the array it was a third element, and the batch
  -- answered N + 1 rows (1.2.24, ship-safety T207).
  IF arPath[nLength] = 'count' THEN
    IF jsonb_typeof(pPayload) = 'array' THEN
      SELECT coalesce(jsonb_agg(CASE WHEN jsonb_typeof(e) = 'object' THEN e || jsonb_build_object('reclimit', 0) ELSE e END), '[]'::jsonb)
        INTO pPayload
        FROM jsonb_array_elements(pPayload) AS e;
    ELSE
      pPayload := pPayload || jsonb_build_object('reclimit', 0);
    END IF;
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

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  nApiId := AddApiLog(pPath, pPayload);
  UPDATE db.api_log SET eventid = AddEventLog('E', ErrorCode, 'run', ErrorMessage) WHERE id = nApiId;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
