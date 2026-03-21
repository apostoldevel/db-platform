--------------------------------------------------------------------------------
-- HTTP LOG --------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Write an incoming HTTP request into the audit log.
 * @param {text} pPath - Request path (e.g. /api/v1/ping)
 * @param {jsonb} pHeaders - HTTP headers of the incoming request
 * @param {jsonb} pParams - Query-string parameters (optional)
 * @param {jsonb} pBody - Request body payload (optional, POST/PUT/PATCH)
 * @param {text} pMethod - HTTP method, defaults to GET
 * @param {text} pMessage - Exception message text if logging an error
 * @param {text} pContext - PL/pgSQL call-stack trace if logging an error
 * @return {bigint} - Auto-generated log entry ID
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.write_to_log (
  pPath         text,
  pHeaders      jsonb,
  pParams       jsonb DEFAULT null,
  pBody         jsonb DEFAULT null,
  pMethod       text DEFAULT 'GET',
  pMessage      text DEFAULT null,
  pContext      text DEFAULT null
) RETURNS       bigint
AS $$
DECLARE
  nId           bigint;
BEGIN
  INSERT INTO http.log (method, path, headers, params, body, message, context)
  VALUES (pMethod, pPath, pHeaders, pParams, pBody, pMessage, pContext)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- HTTP REQUEST ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Create an outbound HTTP request row and trigger PGFetch via NOTIFY.
 * @param {text} pResource - Target URL or resource path
 * @param {text} pType - Transport type: native or curl
 * @param {text} pMethod - HTTP method, defaults to GET
 * @param {jsonb} pHeaders - HTTP headers to send
 * @param {bytea} pContent - Request body as raw bytes
 * @param {text} pDone - Callback function name on success
 * @param {text} pFail - Callback function name on failure
 * @param {text} pStream - Callback function name for SSE streaming data
 * @param {text} pAgent - Logical agent identifier
 * @param {text} pProfile - Agent configuration profile name
 * @param {text} pCommand - Application-level command tag
 * @param {text} pMessage - Free-form message attached to the request
 * @param {jsonb} pData - Arbitrary JSON metadata
 * @return {uuid} - ID of the newly created request
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.create_request (
  pResource     text,
  pType         text DEFAULT null,
  pMethod       text DEFAULT 'GET',
  pHeaders      jsonb DEFAULT null,
  pContent      bytea DEFAULT null,
  pDone         text DEFAULT null,
  pFail         text DEFAULT null,
  pStream       text DEFAULT null,
  pAgent        text DEFAULT null,
  pProfile      text DEFAULT null,
  pCommand      text DEFAULT null,
  pMessage      text DEFAULT null,
  pData         jsonb DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
BEGIN
  INSERT INTO http.request (state, type, method, resource, headers, content, done, fail, stream, agent, profile, command, message, data)
  VALUES (1, coalesce(pType, 'curl'), pMethod, pResource, pHeaders, pContent, pDone, pFail, pStream, pAgent, pProfile, pCommand, pMessage, pData)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- HTTP RESPONSE ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Store the HTTP response, compute runtime, and mark the request as done.
 * @param {uuid} pRequest - ID of the originating http.request row
 * @param {integer} pStatus - HTTP status code from the remote server
 * @param {text} pStatusText - HTTP reason phrase (e.g. OK, Not Found)
 * @param {jsonb} pHeaders - Response headers from the remote server
 * @param {bytea} pContent - Response body as raw bytes
 * @return {uuid} - ID of the newly created response row
 * @see http.done
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.create_response (
  pRequest      uuid,
  pStatus       integer,
  pStatusText   text,
  pHeaders      jsonb,
  pContent      bytea DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  cBegin        timestamptz;
BEGIN
  SELECT datetime INTO cBegin FROM http.request WHERE id = pRequest;

  INSERT INTO http.response (id, request, status, status_text, headers, content, runtime)
  VALUES (pRequest, pRequest, pStatus, pStatusText, pHeaders, pContent, age(clock_timestamp(), cBegin))
  RETURNING id INTO uId;

  PERFORM http.done(pRequest);

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- HTTP REQUEST ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Fetch a single HTTP request row by its ID.
 * @param {uuid} pId - Request identifier
 * @return {SETOF http.request} - Matching request row (0 or 1)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.request (
  pId       uuid
) RETURNS   SETOF http.request
AS $$
  SELECT * FROM http.request WHERE id = pId;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- HTTP GET --------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle an incoming HTTP GET request and route it to the appropriate endpoint.
 * @param {text} path - URL path (e.g. /api/v1/ping)
 * @param {jsonb} headers - HTTP request headers
 * @param {jsonb} params - Query-string parameters
 * @return {SETOF json} - JSON response payload(s)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.get (
  path      text,
  headers   jsonb,
  params    jsonb DEFAULT null
) RETURNS   SETOF json
AS $$
DECLARE
  r         record;

  nId       bigint;

  cBegin    timestamptz;

  vMessage  text;
  vContext  text;
BEGIN
  nId := http.write_to_log(path, headers, params);

  IF split_part(path, '/', 3) != 'v1' THEN
    RAISE EXCEPTION 'Invalid API version.';
  END IF;

  cBegin := clock_timestamp();

  FOR r IN SELECT * FROM jsonb_each(headers)
  LOOP
    -- parse headers here
  END LOOP;

  CASE split_part(path, '/', 4)
  WHEN 'ping' THEN

    RETURN NEXT json_build_object('code', 200, 'message', 'OK');

  WHEN 'time' THEN

    RETURN NEXT json_build_object('serverTime', trunc(extract(EPOCH FROM Now())));

  WHEN 'headers' THEN

    RETURN NEXT coalesce(headers, jsonb_build_object());

  WHEN 'params' THEN

    RETURN NEXT coalesce(params, jsonb_build_object());

  WHEN 'log' THEN

    FOR r IN SELECT * FROM http.log ORDER BY id DESC
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  ELSE

    RETURN NEXT json_build_object('error', json_build_object('code', 404, 'message', format('Path "%s" not found.', path)));

  END CASE;

  UPDATE http.log SET runtime = age(clock_timestamp(), cBegin) WHERE id = nId;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM http.write_to_log(path, headers, params, null, 'GET', vMessage, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', 400, 'message', vMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- HTTP POST -------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle an incoming HTTP POST request and route it to the appropriate endpoint.
 * @param {text} path - URL path (e.g. /api/v1/ping)
 * @param {jsonb} headers - HTTP request headers
 * @param {jsonb} params - Query-string parameters
 * @param {jsonb} body - Request body payload
 * @return {SETOF json} - JSON response payload(s)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.post (
  path      text,
  headers   jsonb,
  params    jsonb DEFAULT null,
  body      json DEFAULT null
) RETURNS   SETOF json
AS $$
DECLARE
  r         record;

  nId       bigint;

  cBegin    timestamptz;

  vMessage  text;
  vContext  text;
BEGIN
  nId := http.write_to_log(path, headers, params, body::jsonb, 'POST');

  IF split_part(path, '/', 3) != 'v1' THEN
    RAISE EXCEPTION 'Invalid API version.';
  END IF;

  FOR r IN SELECT * FROM jsonb_each(headers)
  LOOP
    -- parse headers here
  END LOOP;

  cBegin := clock_timestamp();

  CASE split_part(path, '/', 4)
  WHEN 'ping' THEN

    RETURN NEXT json_build_object('code', 200, 'message', 'OK');

  WHEN 'time' THEN

    RETURN NEXT json_build_object('serverTime', trunc(extract(EPOCH FROM Now())));

  WHEN 'headers' THEN

    RETURN NEXT coalesce(headers, jsonb_build_object());

  WHEN 'params' THEN

    RETURN NEXT coalesce(params, jsonb_build_object());

  WHEN 'body' THEN

    RETURN NEXT coalesce(body::jsonb, jsonb_build_object());

  ELSE

    RAISE EXCEPTION 'Path "%" not found.', path;

  END CASE;

  UPDATE http.log SET runtime = age(clock_timestamp(), cBegin) WHERE id = nId;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM http.write_to_log(path, headers, params, body::jsonb, 'POST', vMessage, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', 400, 'message', vMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- HTTP FETCH ------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Enqueue an outbound HTTP request with callback validation (bytea content).
 * @param {text} resource - Target URL or resource path
 * @param {text} method - HTTP method, defaults to GET
 * @param {jsonb} headers - HTTP headers to send
 * @param {bytea} content - Request body as raw bytes
 * @param {text} done - Callback function name invoked on success (schema.func format)
 * @param {text} fail - Callback function name invoked on failure (schema.func format)
 * @param {text} agent - Logical agent identifier
 * @param {text} profile - Agent configuration profile name
 * @param {text} command - Application-level command tag
 * @param {text} message - Free-form message attached to the request
 * @param {text} type - Transport type: native or curl
 * @param {jsonb} data - Arbitrary JSON metadata
 * @param {text} stream - Callback function name for SSE streaming data
 * @return {uuid} - ID of the created request
 * @see http.create_request
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.fetch (
  resource      text,
  method        text DEFAULT 'GET',
  headers       jsonb DEFAULT null,
  content       bytea DEFAULT null,
  done          text DEFAULT null,
  fail          text DEFAULT null,
  agent         text DEFAULT null,
  profile       text DEFAULT null,
  command       text DEFAULT null,
  message       text DEFAULT null,
  type          text DEFAULT null,
  data          jsonb DEFAULT null,
  stream        text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  IF done IS NOT NULL THEN
    PERFORM FROM pg_namespace n INNER JOIN pg_proc p ON n.oid = p.pronamespace WHERE n.nspname = split_part(done, '.', 1) AND p.proname = split_part(done, '.', 2);
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Not found function: %', done;
    END IF;
  END IF;

  IF fail IS NOT NULL THEN
    PERFORM FROM pg_namespace n INNER JOIN pg_proc p ON n.oid = p.pronamespace WHERE n.nspname = split_part(fail, '.', 1) AND p.proname = split_part(fail, '.', 2);
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Not found function: %', fail;
    END IF;
  END IF;

  IF stream IS NOT NULL THEN
    PERFORM FROM pg_namespace n INNER JOIN pg_proc p ON n.oid = p.pronamespace WHERE n.nspname = split_part(stream, '.', 1) AND p.proname = split_part(stream, '.', 2);
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Not found function: %', stream;
    END IF;
  END IF;

  RETURN http.create_request(resource, type, method, headers, content, done, fail, stream, agent, profile, command, message, data);
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- HTTP FETCH TEXT -------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Enqueue an outbound HTTP request with text content (auto-converted to UTF-8 bytes).
 * @param {text} resource - Target URL or resource path
 * @param {text} method - HTTP method, defaults to POST
 * @param {jsonb} headers - HTTP headers to send
 * @param {text} content - Request body as plain text (converted to bytea internally)
 * @param {text} done - Callback function name invoked on success
 * @param {text} fail - Callback function name invoked on failure
 * @param {text} agent - Logical agent identifier
 * @param {text} profile - Agent configuration profile name
 * @param {text} command - Application-level command tag
 * @param {text} message - Free-form message attached to the request
 * @param {text} type - Transport type: native or curl
 * @param {jsonb} data - Arbitrary JSON metadata
 * @param {text} stream - Callback function name for SSE streaming data
 * @return {uuid} - ID of the created request
 * @see http.create_request
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.fetch (
  resource      text,
  method        text DEFAULT 'POST',
  headers       jsonb DEFAULT null,
  content       text DEFAULT null,
  done          text DEFAULT null,
  fail          text DEFAULT null,
  agent         text DEFAULT null,
  profile       text DEFAULT null,
  command       text DEFAULT null,
  message       text DEFAULT null,
  type          text DEFAULT null,
  data          jsonb DEFAULT null,
  stream        text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN http.create_request(resource, type, method, headers, convert_to(content, 'utf8'), done, fail, stream, agent, profile, command, message, data);
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- HTTP FETCH JSON -------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Enqueue an outbound HTTP request with JSON content (auto-sets Content-Type headers).
 * @param {text} resource - Target URL or resource path
 * @param {text} method - HTTP method, defaults to POST
 * @param {jsonb} headers - HTTP headers to send (defaults to application/json if NULL)
 * @param {jsonb} content - Request body as a JSON object (converted to bytea internally)
 * @param {text} done - Callback function name invoked on success
 * @param {text} fail - Callback function name invoked on failure
 * @param {text} agent - Logical agent identifier
 * @param {text} profile - Agent configuration profile name
 * @param {text} command - Application-level command tag
 * @param {text} message - Free-form message attached to the request
 * @param {text} type - Transport type: native or curl
 * @param {jsonb} data - Arbitrary JSON metadata
 * @param {text} stream - Callback function name for SSE streaming data
 * @return {uuid} - ID of the created request
 * @see http.create_request
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.fetch (
  resource      text,
  method        text DEFAULT 'POST',
  headers       jsonb DEFAULT null,
  content       jsonb DEFAULT null,
  done          text DEFAULT null,
  fail          text DEFAULT null,
  agent         text DEFAULT null,
  profile       text DEFAULT null,
  command       text DEFAULT null,
  message       text DEFAULT null,
  type          text DEFAULT null,
  data          jsonb DEFAULT null,
  stream        text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  IF headers IS NULL THEN
    headers := jsonb_build_object('Content-Type', 'application/json', 'Accept', 'application/json');
  END IF;

  RETURN http.create_request(resource, type, method, headers, convert_to(content::text, 'utf8'), done, fail, stream, agent, profile, command, message, data);
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- http.done -------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Mark an HTTP request as successfully completed (state = 2).
 * @param {uuid} pRequest - ID of the request to mark as done
 * @return {void}
 * @see http.fail
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.done (
  pRequest  uuid
) RETURNS   void
AS $$
BEGIN
  UPDATE http.request SET state = 2 WHERE id = pRequest;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- http.fail -------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Mark an HTTP request as failed (state = 3) and record the error message.
 * @param {uuid} pRequest - ID of the request to mark as failed
 * @param {text} pError - Error description text
 * @return {void}
 * @see http.done
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.fail (
  pRequest  uuid,
  pError    text
) RETURNS   void
AS $$
BEGIN
  UPDATE http.request SET state = 3, error = pError WHERE id = pRequest;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = http, pg_temp;
