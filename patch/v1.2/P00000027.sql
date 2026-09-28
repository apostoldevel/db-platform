--------------------------------------------------------------------------------
-- P00000027 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Resend of outbound requests (apostol-csms T577): a request whose NOTIFY the
-- sender (PGFetch) missed — created while its LISTEN was down: a restart of the
-- process or of PostgreSQL — stayed in state 1 and was never sent.
--
-- http.request gains the resend contract, set by the producer:
--   expire        interval  — lifetime from datetime; NULL: never resent, and
--                             http.sweep never touches the row (every row
--                             created before this patch stays as it was);
--   max_attempts  integer   — resends allowed; NULL or 0: never resent;
--   attempts      integer   — resends handed out (the first send on NOTIFY
--                             does not count);
--   attempted     timestamptz — when http.sweep last handed the row out.
-- Columns without a volatile default: metadata only, no table rewrite; one
-- ALTER — one ACCESS EXCLUSIVE, taken or refused (lock_timeout) as a whole.
--
-- FOR A PRODUCER. Resend is at-least-once: a row sent whose response was not
-- stored (the connection dropped mid-flight — the case this is for) goes again
-- with the same headers. A request that must not repeat carries its
-- idempotency key in the headers, or sets no expire. Ages count from datetime
-- — the INSERT, not the COMMIT: expire and the sender's pAge must exceed the
-- producer's longest transaction. No expire on a stream (SSE).
--
-- http.create_request and the three http.fetch take them as trailing
-- parameters (pExpire, pMaxAttempts / expire, max_attempts). The old
-- signatures are DROPPED and the new ones created IN ONE TRANSACTION:
-- CREATE OR REPLACE with a longer parameter list would add an overload (a
-- call that omits the defaults is then "not unique", see P00000024), and a
-- bare DROP would leave http.fetch missing between this patch and
-- update.psql — every producer (payments, commands to stations) fails in that
-- window. The bodies below are a snapshot of 1.2.32; update.psql re-creates
-- them from http/routine.sql.
--
-- http.take(uuid) and http.sweep(interval, integer) — the sender's side — are
-- new functions, carried by update.psql. http.request(uuid) stays: an older
-- PGFetch keeps reading by id as before.
--
-- Re-runnable.
--------------------------------------------------------------------------------

SET lock_timeout = '10s';

ALTER TABLE http.request
  ADD COLUMN IF NOT EXISTS expire interval,
  ADD COLUMN IF NOT EXISTS max_attempts integer,
  ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS attempted timestamptz;

RESET lock_timeout;

COMMENT ON COLUMN http.request.expire IS 'Lifetime counted from datetime, set by the producer. NULL: the row is outside the resend contract — http.sweep never hands it out nor closes it.';
COMMENT ON COLUMN http.request.max_attempts IS 'How many resends http.sweep may hand out, set by the producer. NULL or 0: no resend.';
COMMENT ON COLUMN http.request.attempts IS 'Resends handed out by http.sweep. The first send on NOTIFY does not count.';
COMMENT ON COLUMN http.request.attempted IS 'When http.sweep last handed the row out for a resend.';

BEGIN;

DROP FUNCTION IF EXISTS http.create_request(text, text, text, jsonb, bytea, text, text, text, text, text, text, text, jsonb);
DROP FUNCTION IF EXISTS http.fetch(text, text, jsonb, bytea, text, text, text, text, text, text, text, jsonb, text);
DROP FUNCTION IF EXISTS http.fetch(text, text, jsonb, text, text, text, text, text, text, text, text, jsonb, text);
DROP FUNCTION IF EXISTS http.fetch(text, text, jsonb, jsonb, text, text, text, text, text, text, text, jsonb, text);

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

COMMIT;
