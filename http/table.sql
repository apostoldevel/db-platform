--------------------------------------------------------------------------------
-- http.log --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE http.log (
  id            bigserial PRIMARY KEY,
  datetime      timestamptz DEFAULT clock_timestamp() NOT NULL,
  username      text NOT NULL DEFAULT session_user,
  method        text NOT NULL DEFAULT 'GET' CHECK (method = ANY (ARRAY['GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'PATCH', 'TRACE'])),
  path          text NOT NULL,
  headers       jsonb,
  params        jsonb,
  body          jsonb,
  message       text,
  context       text,
  runtime       interval
);

COMMENT ON TABLE http.log IS 'Audit log for incoming HTTP requests processed by the platform.';

COMMENT ON COLUMN http.log.id IS 'Auto-incremented log entry identifier.';
COMMENT ON COLUMN http.log.datetime IS 'Timestamp when the request was received (wall-clock precision).';
COMMENT ON COLUMN http.log.username IS 'Database session user who executed the request.';
COMMENT ON COLUMN http.log.method IS 'HTTP method (GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH, TRACE).';
COMMENT ON COLUMN http.log.path IS 'Request path (e.g. /api/v1/ping).';
COMMENT ON COLUMN http.log.headers IS 'HTTP request headers as a JSON object.';
COMMENT ON COLUMN http.log.params IS 'Query-string parameters as a JSON object.';
COMMENT ON COLUMN http.log.body IS 'Request body payload as JSON (POST/PUT/PATCH only).';
COMMENT ON COLUMN http.log.message IS 'Primary exception message text if the request failed.';
COMMENT ON COLUMN http.log.context IS 'PL/pgSQL call-stack trace captured at the point of exception.';
COMMENT ON COLUMN http.log.runtime IS 'Wall-clock execution time of the request handler.';

CREATE INDEX ON http.log (method);
CREATE INDEX ON http.log (path);
CREATE INDEX ON http.log (datetime);

--------------------------------------------------------------------------------
-- http.request ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE http.request (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  datetime      timestamptz DEFAULT clock_timestamp() NOT NULL,
  state         integer NOT NULL DEFAULT 0 CHECK (state BETWEEN 0 AND 3),
  type          text NOT NULL DEFAULT 'native' CHECK (type = ANY (ARRAY['native', 'curl'])),
  method        text NOT NULL DEFAULT 'GET' CHECK (method = ANY (ARRAY['GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'PATCH', 'TRACE'])),
  resource      text NOT NULL,
  headers       jsonb,
  content       bytea,
  done          text,
  fail          text,
  stream        text,
  agent         text,
  profile       text,
  command       text,
  message       text,
  error         text,
  data          jsonb,
  expire        interval,
  max_attempts  integer,
  attempts      integer NOT NULL DEFAULT 0,
  attempted     timestamptz
);

COMMENT ON TABLE http.request IS 'Outbound HTTP request queue. PGFetch listens via NOTIFY and executes queued rows.';

COMMENT ON COLUMN http.request.id IS 'Unique request identifier (UUID v4, auto-generated).';
COMMENT ON COLUMN http.request.datetime IS 'Timestamp when the request was created.';
COMMENT ON COLUMN http.request.state IS 'Lifecycle state: 0 = created, 1 = executing, 2 = completed, 3 = failed.';
COMMENT ON COLUMN http.request.type IS 'Transport type: native (built-in) or curl (via libcurl).';
COMMENT ON COLUMN http.request.method IS 'HTTP method (GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH, TRACE).';
COMMENT ON COLUMN http.request.resource IS 'Target URL or resource path for the outbound request.';
COMMENT ON COLUMN http.request.headers IS 'HTTP headers to send, stored as a JSON object.';
COMMENT ON COLUMN http.request.content IS 'Request body as raw bytes.';
COMMENT ON COLUMN http.request.done IS 'Fully-qualified callback function name invoked on successful response.';
COMMENT ON COLUMN http.request.fail IS 'Fully-qualified callback function name invoked on failure.';
COMMENT ON COLUMN http.request.stream IS 'Fully-qualified callback function name for Server-Sent Events (SSE) streaming data.';
COMMENT ON COLUMN http.request.agent IS 'Logical agent identifier associated with this request.';
COMMENT ON COLUMN http.request.profile IS 'Agent configuration profile name.';
COMMENT ON COLUMN http.request.command IS 'Application-level command tag associated with the request.';
COMMENT ON COLUMN http.request.message IS 'Free-form message or description attached to the request.';
COMMENT ON COLUMN http.request.error IS 'Error description text populated when the request fails (state = 3).';
COMMENT ON COLUMN http.request.data IS 'Arbitrary JSON payload for caller-defined metadata.';
COMMENT ON COLUMN http.request.expire IS 'Lifetime counted from datetime, set by the producer. NULL: the row is outside the resend contract — http.sweep never hands it out nor closes it.';
COMMENT ON COLUMN http.request.max_attempts IS 'How many resends http.sweep may hand out, set by the producer. NULL or 0: no resend.';
COMMENT ON COLUMN http.request.attempts IS 'Resends handed out by http.sweep. The first send on NOTIFY does not count.';
COMMENT ON COLUMN http.request.attempted IS 'When http.sweep last handed the row out for a resend.';

CREATE INDEX ON http.request (state);
CREATE INDEX ON http.request (method);
CREATE INDEX ON http.request (resource);
CREATE INDEX ON http.request (agent);
CREATE INDEX ON http.request (command);
CREATE INDEX ON http.request (datetime);

--------------------------------------------------------------------------------

/**
 * @brief Hand a new HTTP request to the sender: notify.send of the channel http.
 * @return {trigger} - After-insert trigger return
 * @since 1.0.0
 *
 * max_attempts goes on only with a lifetime: a request without `expire` is outside the resend contract and is
 * never sent twice (http.sweep has never touched it), so notify, which would otherwise take a repeat without
 * a lifetime for an unlimited one, is told none.
 */
CREATE OR REPLACE FUNCTION http.ft_request_after_insert()
RETURNS     trigger
AS $$
BEGIN
  PERFORM notify.send('http', NEW.id::text, NEW.id::text, NEW.expire,
                      CASE WHEN NEW.expire IS NOT NULL THEN NEW.max_attempts ELSE 0 END);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_request_after_insert
  AFTER INSERT ON http.request
  FOR EACH ROW
  EXECUTE PROCEDURE http.ft_request_after_insert();

--------------------------------------------------------------------------------
-- http.response ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE http.response (
  id            uuid PRIMARY KEY,
  request       uuid REFERENCES http.request ON DELETE CASCADE,
  datetime      timestamptz DEFAULT clock_timestamp() NOT NULL,
  status        integer NOT NULL,
  status_text   text NOT NULL,
  headers       jsonb NOT NULL,
  content       bytea,
  runtime       interval
);

COMMENT ON TABLE http.response IS 'Stored responses for completed outbound HTTP requests.';

COMMENT ON COLUMN http.response.id IS 'Response identifier (matches the originating request UUID).';
COMMENT ON COLUMN http.response.request IS 'Foreign key to the originating http.request row.';
COMMENT ON COLUMN http.response.datetime IS 'Timestamp when the response was recorded.';
COMMENT ON COLUMN http.response.status IS 'HTTP status code returned by the remote server (e.g. 200, 404).';
COMMENT ON COLUMN http.response.status_text IS 'HTTP reason phrase accompanying the status code (e.g. OK, Not Found).';
COMMENT ON COLUMN http.response.headers IS 'Response headers returned by the remote server, stored as JSON.';
COMMENT ON COLUMN http.response.content IS 'Response body as raw bytes.';
COMMENT ON COLUMN http.response.runtime IS 'Wall-clock time elapsed from request creation to response receipt.';

CREATE INDEX ON http.response (request);
CREATE INDEX ON http.response (status);
