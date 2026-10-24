--------------------------------------------------------------------------------
-- HTTP LOG: CREDENTIAL MASK ---------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief The one list of what the name of a credential looks like, as a regular expression.
 * @return {text} - The alternation, to be used case-insensitively
 * @since 1.2.36
 *
 * authorization, cookie, token, secret, password, passwd, passphrase, pwd, credential; cryptogram (a card packet),
 * csc, cvc, cvv (a card's security code); api / access / secret / private / signing / encryption / session / auth
 * followed by `key`.
 */
CREATE OR REPLACE FUNCTION http.credential_pattern ()
RETURNS         text
AS $$
  SELECT 'authorization|cookie|token|secret|passw(or)?d|passphrase|pwd|credential|cryptogram|csc|cvc|cvv|(api|access|secret|private|signing|encryption|session|auth)[_.-]?key'::text
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE
   SECURITY DEFINER
   SET search_path = http, pg_temp;

/**
 * @brief Tells whether the name of an HTTP header, a JSON key or a query-string field carries a credential.
 * @param {text} pName - The name as received
 * @param {boolean} pHeader - true for an HTTP header name, false for a key of a body or of a query string
 * @return {boolean}
 * @since 1.2.36
 *
 * A name rule, not a list: the name (lower case, blanks around it cut) is a credential when it matches
 * http.credential_pattern(). A header name that merely ends with `key` is one too (`X-Api-Key`, `X-AccessKey`,
 * `Sec-WebSocket-Key`: fail closed) — except an idempotency key, which a provider looks a request up by.
 * A bare `key` in a body is not: it names a setting. Neither is `authorization_details` in a body: what the bank
 * said about the authorisation of a payment is evidence, not a credential (as a header name it stays one).
 */
CREATE OR REPLACE FUNCTION http.is_credential_name (
  pName         text,
  pHeader       boolean DEFAULT true
) RETURNS       boolean
AS $$
  SELECT (n.name ~ http.credential_pattern()
          OR (pHeader AND n.name ~ 'key$' AND n.name !~ 'idempoten(ce|cy)[-_]?key$'))
     AND (pHeader OR n.name <> 'authorization_details')
    FROM (SELECT lower(btrim(pName, E' \t\r\n')) AS name) n
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE
   SECURITY DEFINER
   SET search_path = http, pg_temp;

/**
 * @brief Replaces the value of every credential header of a header object with `***`.
 * @param {jsonb} pHeaders - HTTP headers of a request: an object, name → value
 * @return {jsonb} - The same object with `"***"` as the value of each credential header; NULL and a JSON null come
 *                   back as they are; anything else that is not an object comes back as the marker {"_masked": false}
 *                   (a header set is an object; a string or an array could still hold "Authorization: ..." as text)
 * @since 1.2.36
 *
 * The name stays and only the value goes: "a header was sent" and "no header was sent" stay different in the log.
 * Which names count — http.is_credential_name, header rule.
 */
CREATE OR REPLACE FUNCTION http.mask_headers (
  pHeaders      jsonb
) RETURNS       jsonb
AS $$
BEGIN
  IF pHeaders IS NULL THEN
    RETURN NULL;
  END IF;

  CASE jsonb_typeof(pHeaders)
  WHEN 'object' THEN
    RETURN coalesce((
      SELECT jsonb_object_agg(e.key, CASE WHEN http.is_credential_name(e.key, true) THEN to_jsonb('***'::text) ELSE e.value END)
        FROM jsonb_each(pHeaders) e
    ), '{}'::jsonb);
  WHEN 'null' THEN
    RETURN pHeaders;
  ELSE
    RETURN jsonb_build_object('_masked', false);
  END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
   SECURITY DEFINER
   SET search_path = http, pg_temp;

/**
 * @brief The walk of http.mask_json: one level of a JSON document.
 * @param {jsonb} pJson - A value of the document
 * @param {integer} pLevel - The depth of pJson, 0 at the root
 * @return {jsonb}
 * @since 1.2.36
 *
 * The recursion is bounded: a container nested more than 32 levels deep comes back as `"***"` whole (fail closed — a
 * real request is never that deep). Without the bound a body a couple of kilobytes long and nested a thousand levels
 * deep, which PostgreSQL accepts as jsonb, would make the walk raise "stack depth limit exceeded" inside the function
 * that writes the log — and the exception handlers of the callers write the log again.
 */
CREATE OR REPLACE FUNCTION http.mask_json_level (
  pJson         jsonb,
  pLevel        integer
) RETURNS       jsonb
AS $$
BEGIN
  IF pJson IS NULL THEN
    RETURN NULL;
  END IF;

  IF pLevel > 32 AND jsonb_typeof(pJson) IN ('object', 'array') THEN
    RETURN to_jsonb('***'::text);
  END IF;

  CASE jsonb_typeof(pJson)
  WHEN 'object' THEN
    RETURN coalesce((
      SELECT jsonb_object_agg(e.key,
               CASE WHEN http.is_credential_name(e.key, false)
                      OR (lower(btrim(e.key)) = 'number' AND jsonb_typeof(e.value) = 'string'
                          AND (e.value #>> '{}') ~ '^[0-9][0-9 -]{11,21}[0-9]$')
                    THEN to_jsonb('***'::text)
                    ELSE http.mask_json_level(e.value, pLevel + 1) END)
        FROM jsonb_each(pJson) e
    ), '{}'::jsonb);
  WHEN 'array' THEN
    RETURN coalesce((
      SELECT jsonb_agg(http.mask_json_level(e.value, pLevel + 1) ORDER BY e.ord)
        FROM jsonb_array_elements(pJson) WITH ORDINALITY AS e(value, ord)
    ), '[]'::jsonb);
  ELSE
    RETURN pJson;
  END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
   SECURITY DEFINER
   SET search_path = http, pg_temp;

/**
 * @brief Replaces the value of every credential key of a JSON document, down to 32 levels, with `***`.
 * @param {jsonb} pJson - The query-string parameters or the body of a request: any JSON value
 * @return {jsonb} - The same document; NULL and scalars come back as they are
 * @since 1.2.36
 *
 * The key stays, the value goes whatever its type (a string, a number, an object, an array): a credential object is
 * hidden whole. Which keys count — http.is_credential_name, body rule. One more case by the shape of the value, not of
 * the name: a `number` key that holds a card number (13–23 digits, blanks and dashes allowed).
 *
 * A document that names no credential and has no `number` key is not walked: one regular expression over its text
 * decides (the text may also match a value that merely contains the word — the walk then removes nothing). Large
 * bodies of partner integrations pass through without a recursion in plpgsql.
 */
CREATE OR REPLACE FUNCTION http.mask_json (
  pJson         jsonb
) RETURNS       jsonb
AS $$
BEGIN
  IF jsonb_typeof(pJson) IS NULL OR jsonb_typeof(pJson) NOT IN ('object', 'array') THEN
    RETURN pJson;
  END IF;

  IF lower(pJson::text) !~ (http.credential_pattern() || '|" *number *"') THEN
    RETURN pJson;
  END IF;

  RETURN http.mask_json_level(pJson, 0);
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
   SECURITY DEFINER
   SET search_path = http, pg_temp;

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
 *
 * The log keeps no credential in the clear: the value of every credential header (Authorization, Cookie, an API key)
 * and of every credential key of the parameters and of the body, at any depth, is stored as `***` (http.mask_headers,
 * http.mask_json). The message and the context are stored as they are.
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
  VALUES (pMethod, pPath, http.mask_headers(pHeaders), http.mask_json(pParams), http.mask_json(pBody), pMessage, pContext)
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
 * @param {interval} pExpire - Lifetime of the request; NULL: never resent (see http.sweep)
 * @param {integer} pMaxAttempts - Resends allowed within the lifetime; NULL or 0: never resent
 * @return {uuid} - ID of the newly created request
 * @throws Invalid callback function name - a callback is not exactly schema.function in lower case
 * @throws Not found function - a callback names no existing function
 * @since 1.0.0
 *
 * Every callback (pDone, pFail, pStream) is checked here, on every path that creates a request: the
 * sender calls the function by that name, so only a plain two-part lower-case identifier
 * of an existing function is accepted.
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
  pData         jsonb DEFAULT null,
  pExpire       interval DEFAULT null,
  pMaxAttempts  integer DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  vCallback     text;
BEGIN
  FOREACH vCallback IN ARRAY ARRAY[pDone, pFail, pStream]
  LOOP
    CONTINUE WHEN vCallback IS NULL;

    IF vCallback !~ '^[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*$' THEN
      RAISE EXCEPTION 'Invalid callback function name: %', vCallback;
    END IF;

    PERFORM FROM pg_namespace n INNER JOIN pg_proc p ON n.oid = p.pronamespace WHERE n.nspname = split_part(vCallback, '.', 1) AND p.proname = split_part(vCallback, '.', 2);
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Not found function: %', vCallback;
    END IF;
  END LOOP;

  INSERT INTO http.request (state, type, method, resource, headers, content, done, fail, stream, agent, profile, command, message, data, expire, max_attempts)
  VALUES (1, coalesce(pType, 'curl'), pMethod, pResource, pHeaders, pContent, pDone, pFail, pStream, pAgent, pProfile, pCommand, pMessage, pData, pExpire, pMaxAttempts)
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
-- http.take -------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Hand a request row to the sender (PGFetch) — the row if it is to be sent, nothing if not.
 * @param {uuid} pId - Request identifier
 * @return {SETOF http.request} - The row to send (0 or 1). No row means: do not send, drop the task
 *   silently — the request is gone, already done or failed (state 2/3), or its lifetime has elapsed.
 *   An elapsed row is closed here on the way (state 3, no callback): a sender never calls the
 *   producer back for a request it did not send.
 * @see http.sweep
 * @since 1.2.32
 */
CREATE OR REPLACE FUNCTION http.take (
  pId       uuid
) RETURNS   SETOF http.request
AS $$
DECLARE
  r         http.request%rowtype;
BEGIN
  SELECT * INTO r FROM http.request WHERE id = pId AND state <= 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF r.expire IS NOT NULL AND r.datetime + r.expire <= now() THEN
    UPDATE http.request
       SET state = 3,
           error = format('expired: not sent, lifetime %s elapsed (resends %s of %s)', r.expire, r.attempts, coalesce(r.max_attempts, 0))
     WHERE id = pId AND state <= 1;

    RETURN;
  END IF;

  RETURN NEXT r;
END;
$$ LANGUAGE plpgsql STRICT
   SECURITY DEFINER
   SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- http.sweep ------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Hand out requests to resend — rows whose NOTIFY the sender may have missed.
 * @param {interval} pAge - The longest a request may be in flight: a row created or last handed out
 *   less than pAge ago may still be on its way and is left alone. Must exceed the sender's timeout.
 * @param {integer} pLimit - At most this many rows handed out per call; a full batch means: call again
 * @return {SETOF uuid} - Requests to send again, oldest first; each marked attempts + 1, attempted = now()
 * @note Resend is at-least-once: a row sent whose response was not stored (the connection dropped
 *   mid-flight) goes again, with the same headers — a producer that must not repeat puts its
 *   idempotency key there, or sets no expire. Ages count from datetime, the INSERT, not the COMMIT:
 *   expire and pAge must exceed the producer's longest transaction. No expire on a stream.
 * @note Only rows under the resend contract (expire IS NOT NULL) are touched. Of those older than pAge
 *   and not handed out within pAge, the live ones (lifetime not elapsed, attempts < max_attempts) are
 *   handed out; the rest are closed on the way — state 3 with the reason, no callback. Closed rows do
 *   not count against pLimit. FOR UPDATE SKIP LOCKED: two concurrent calls never take the same row.
 * @see http.take
 * @since 1.2.32
 */
CREATE OR REPLACE FUNCTION http.sweep (
  pAge      interval,
  pLimit    integer DEFAULT 100
) RETURNS   SETOF uuid
AS $$
BEGIN
  IF pAge <= interval '0' OR pLimit <= 0 THEN
    RETURN;
  END IF;

  UPDATE http.request r
     SET state = 3,
         error = CASE
                   WHEN r.datetime + r.expire <= now()
                   THEN format('abandoned: not resent, lifetime %s elapsed (resends %s of %s)', r.expire, r.attempts, coalesce(r.max_attempts, 0))
                   ELSE format('abandoned: not resent, resends %s of %s used', r.attempts, coalesce(r.max_attempts, 0))
                 END
    FROM (
      SELECT id
        FROM http.request
       WHERE state <= 1
         AND expire IS NOT NULL
         AND datetime < now() - pAge
         AND (attempted IS NULL OR attempted < now() - pAge)
         AND (datetime + expire <= now() OR attempts >= coalesce(max_attempts, 0))
         FOR UPDATE SKIP LOCKED
    ) c
   WHERE r.id = c.id;

  RETURN QUERY
    WITH handed AS (
    UPDATE http.request r
       SET attempts = r.attempts + 1,
           attempted = now()
      FROM (
        SELECT id
          FROM http.request
         WHERE state <= 1
           AND expire IS NOT NULL
           AND datetime < now() - pAge
           AND (attempted IS NULL OR attempted < now() - pAge)
           AND datetime + expire > now()
           AND attempts < coalesce(max_attempts, 0)
         ORDER BY datetime
         LIMIT pLimit
           FOR UPDATE SKIP LOCKED
      ) c
     WHERE r.id = c.id
    RETURNING r.id, r.datetime
    )
    SELECT h.id FROM handed h ORDER BY h.datetime;
END;
$$ LANGUAGE plpgsql STRICT
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
 * @brief Enqueue an outbound HTTP request (bytea content); callbacks are checked by http.create_request.
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
 * @param {interval} expire - Lifetime of the request; NULL: never resent (see http.sweep)
 * @param {integer} max_attempts - Resends allowed within the lifetime; NULL or 0: never resent
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
  stream        text DEFAULT null,
  expire        interval DEFAULT null,
  max_attempts  integer DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN http.create_request(resource, type, method, headers, content, done, fail, stream, agent, profile, command, message, data, expire, max_attempts);
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
 * @param {interval} expire - Lifetime of the request; NULL: never resent (see http.sweep)
 * @param {integer} max_attempts - Resends allowed within the lifetime; NULL or 0: never resent
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
  stream        text DEFAULT null,
  expire        interval DEFAULT null,
  max_attempts  integer DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN http.create_request(resource, type, method, headers, convert_to(content, 'utf8'), done, fail, stream, agent, profile, command, message, data, expire, max_attempts);
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
 * @param {interval} expire - Lifetime of the request; NULL: never resent (see http.sweep)
 * @param {integer} max_attempts - Resends allowed within the lifetime; NULL or 0: never resent
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
  stream        text DEFAULT null,
  expire        interval DEFAULT null,
  max_attempts  integer DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  IF headers IS NULL THEN
    headers := jsonb_build_object('Content-Type', 'application/json', 'Accept', 'application/json');
  END IF;

  RETURN http.create_request(resource, type, method, headers, convert_to(content::text, 'utf8'), done, fail, stream, agent, profile, command, message, data, expire, max_attempts);
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

--------------------------------------------------------------------------------
-- http.try_done ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Close an open request as completed (state = 2), unless an outcome has been written already.
 * @param {uuid} pRequest - ID of the request
 * @return {boolean} - true: this call closed the row; false: the row is not open (done or failed already) or there is none
 * @see http.done
 * @see http.try_fail
 * @since 1.2.37
 *
 * The outcome of a request is written by whoever holds it, and for a while two may: a sender that woke up after it
 * lost the lock, the next holder of a row that http.sweep handed out again. http.done and http.fail write
 * unconditionally, so the later of two overwrites the earlier: a stored 200 turns into state 3. This function writes
 * only into an open row (state 0 or 1) and says whether it did. Of two concurrent calls the row lock lets one through;
 * the other, re-reading the row, finds it closed and gets false. A producer's callback follows a true only.
 *
 * http.done is not replaced: it is also the CORRECTION of an outcome already written (the sender stores a response,
 * the done callback rolls back, the row is marked failed so that it does not look delivered), and a sender of the
 * previous release calls it. The same goes for http.fail.
 */
CREATE OR REPLACE FUNCTION http.try_done (
  pRequest  uuid
) RETURNS   boolean
AS $$
BEGIN
  UPDATE http.request SET state = 2 WHERE id = pRequest AND state <= 1;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- http.try_fail ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Close an open request as failed (state = 3) with the error text, unless an outcome has been written already.
 * @param {uuid} pRequest - ID of the request
 * @param {text} pError - Error description text
 * @return {boolean} - true: this call closed the row; false: the row is not open (done or failed already) or there is none
 * @see http.fail
 * @see http.try_done
 * @since 1.2.37
 *
 * A fail that arrives after a done leaves the stored response and state 2 alone, and one after a fail keeps the
 * first error. See http.try_done.
 */
CREATE OR REPLACE FUNCTION http.try_fail (
  pRequest  uuid,
  pError    text
) RETURNS   boolean
AS $$
BEGIN
  UPDATE http.request SET state = 3, error = pError WHERE id = pRequest AND state <= 1;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = http, pg_temp;
