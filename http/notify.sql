--------------------------------------------------------------------------------
-- The channel `http` on notify (T1102, stage E3 of T996) ----------------------
--------------------------------------------------------------------------------
-- What a sender needs once the channel is switched to `single`: the answer stored
-- only for an open row, the closing of a request whose outcome is not known, the
-- `on_abandon` of the channel, the row of a repeat. Kept apart from routine.sql so
-- that patch P00000038 can include THIS file alone: routine.sql also holds
-- http.get and http.post, which a configuration overrides, and a patch that ran
-- the whole file would put the platform's copies in place of the override for as
-- long as the patches that follow it take.
--
-- CREATE OR REPLACE only; the privileges at the end are the same every run.

--------------------------------------------------------------------------------
-- http.try_create_response ----------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Store the response of an open request and close it as completed (state = 2) — only if it is still open.
 * @param {uuid} pRequest - ID of the originating http.request row
 * @param {integer} pStatus - HTTP status code from the remote server
 * @param {text} pStatusText - HTTP reason phrase
 * @param {jsonb} pHeaders - Response headers from the remote server
 * @param {bytea} pContent - Response body as raw bytes
 * @return {boolean} - true: this call stored the response and closed the row; false: the row is not open
 *   (an outcome was written already) or there is none, and nothing was stored
 * @see http.create_response
 * @see http.try_fail
 * @since 1.2.39
 *
 * The sender of a request that notify.queue leads calls this in the one query that carries the producer's done
 * callback and notify.ack, and calls the callback only for a true. http.create_response closes the row through
 * http.done, which writes over any outcome, and stops on the primary key of http.response when an answer is there
 * already; here the row is closed first, under its lock, so that of two senders racing for one request (a woken
 * one that lost its lease, and the one that was given the row afterwards) the second waits for the first, finds the
 * row closed and gets false. http.create_response is left as it is: the previous sender calls it.
 */
CREATE OR REPLACE FUNCTION http.try_create_response (
  pRequest      uuid,
  pStatus       integer,
  pStatusText   text,
  pHeaders      jsonb,
  pContent      bytea DEFAULT null
) RETURNS       boolean
AS $$
DECLARE
  dBegin        timestamptz;
BEGIN
  -- The delivery row first, the request second: notify.close (the sweep) takes the row of the queue and then, in
  -- http.abandon, the request. A settle that took them the other way round could deadlock with it.
  PERFORM 1 FROM notify.queue WHERE channel = 'http' AND key = pRequest::text AND state = 1 FOR UPDATE;

  UPDATE http.request SET state = 2 WHERE id = pRequest AND state <= 1 RETURNING datetime INTO dBegin;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  INSERT INTO http.response (id, request, status, status_text, headers, content, runtime)
  VALUES (pRequest, pRequest, pStatus, pStatusText, pHeaders, pContent, age(clock_timestamp(), dBegin));

  RETURN true;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- http.fail_unknown -----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Close an open request whose outcome is not known and call the producer's fail callback.
 * @param {uuid} pRequest - ID of the request
 * @param {text} pMessage - What is stored in http.request.error and given to the callback (as PGFetch does)
 * @return {boolean} - true: this call closed the row (and made the callback, if the request names one);
 *   false: the row is not open or there is none, and nothing was called
 * @see http.try_fail
 * @see http.abandon
 * @see http.retake
 * @since 1.2.39
 *
 * "Outcome unknown": the request was, or may have been, sent, and no answer was stored — the sender died, the lease
 * ran out, the lifetime ended before a repeat. A producer that pays learns it from the callback and asks the other
 * side (T492). The row is closed first, by http.try_fail: of two callers only one calls the callback.
 *
 * The callback is made inside its own sub-transaction. One that throws takes only itself down: the row stays
 * closed, the reason is appended to http.request.error (the same line PGFetch writes), and the function returns
 * true. Left to propagate, the exception would roll back http.try_fail with it, and notify.close, which calls this
 * from a sweep, would leave the request open for good. The name is read from the row, so it is checked again as
 * http.create_request checks it, and quoted when used.
 */
CREATE OR REPLACE FUNCTION http.fail_unknown (
  pRequest      uuid,
  pMessage      text
) RETURNS       boolean
AS $$
DECLARE
  vFail         text;
  rFn           regprocedure;
  bAllowed      boolean;
BEGIN
  IF NOT http.try_fail(pRequest, pMessage) THEN
    RETURN false;
  END IF;

  SELECT fail INTO vFail FROM http.request WHERE id = pRequest;

  IF vFail IS NULL THEN
    RETURN true;
  END IF;

  IF vFail !~ '^[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*$' THEN
    UPDATE http.request
       SET error = left(pMessage || '; fail callback ''' || vFail || ''' is not a function name -- not called', 4000)
     WHERE id = pRequest;

    RETURN true;
  END IF;

  -- This function runs as its owner; the sender used to call the callback from its own pool (apibot). The
  -- callback is called only where that pool could call it: a function (uuid, text) of a schema it has USAGE on,
  -- with EXECUTE. Otherwise the name chosen by whoever created the request would run as kernel.
  rFn := to_regprocedure(format('%I.%I(uuid, text)', split_part(vFail, '.', 1), split_part(vFail, '.', 2)));
  bAllowed := rFn IS NOT NULL;

  IF bAllowed THEN
    bAllowed := has_schema_privilege('apibot', split_part(vFail, '.', 1), 'USAGE')
            AND has_function_privilege('apibot', rFn, 'EXECUTE');
  END IF;

  IF NOT bAllowed THEN
    UPDATE http.request
       SET error = left(pMessage || '; fail callback ' || vFail || ' is not callable by the sender (no such function (uuid, text), or apibot has no USAGE on its schema or EXECUTE on it) -- not called', 4000)
     WHERE id = pRequest;

    RETURN true;
  END IF;

  BEGIN
    EXECUTE format('SELECT %I.%I($1, $2)', split_part(vFail, '.', 1), split_part(vFail, '.', 2))
      USING pRequest, pMessage;
  EXCEPTION
  WHEN OTHERS THEN
    UPDATE http.request
       SET error = left(pMessage || '; fail callback ' || vFail || ' rolled back: ' || SQLERRM, 4000)
     WHERE id = pRequest;
  END;

  RETURN true;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- http.abandon ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief `on_abandon` of the notify channel `http`: a delivery row was closed without a confirmation — close the
 *   request it carries.
 * @param {bigint} pId - Row of notify.queue
 * @param {text} pKey - Its key: the request id
 * @param {text} pPayload - Its payload: the request id
 * @param {text} pReason - Why notify closed it (notify.close)
 * @return {void}
 * @see http.fail_unknown
 * @see http.retake
 * @since 1.2.39
 *
 * The reason says whether the request left:
 *  - `unsent:` (the lifetime ended before any sender looked), `unrouted:`, and a refusal of a sender that did not
 *    send it (`nack: unsent:` — the sender stops; `nack: stopping:` — the stop began as it took the row) when it
 *    is the FIRST delivery of the row (notify.queue.attempts <= 1): the request is closed with `not sent: <reason>`
 *    and its producer is NOT called back — nothing happened to it (the plan's closing 1, T996 plan § 5);
 *  - everything else (`orphaned:` — the lease ran out and no repeat is allowed, or the lifetime ended between two
 *    deliveries; `nack:` with any other text, or an `unsent:` refusal of a repeat delivery): the request may have
 *    reached the other side. It is closed with
 *    `outcome unknown: <reason>` and the producer's fail callback is called (http.fail_unknown).
 * A row that is closed already (the sender settled it a moment ago) is left alone. Nothing here throws: notify.close
 * runs this function inside a sweep, and a key that is not a request id is a row of someone else's.
 */
CREATE OR REPLACE FUNCTION http.abandon (
  pId           bigint,
  pKey          text,
  pPayload      text,
  pReason       text
) RETURNS       void
AS $$
DECLARE
  uRequest      uuid;
  nAttempts     integer;
  bUnsent       boolean;
BEGIN
  BEGIN
    uRequest := coalesce(pKey, pPayload)::uuid;
  EXCEPTION
  WHEN OTHERS THEN
    RETURN;
  END;

  bUnsent := pReason ~ '^(unsent|unrouted):';

  -- A sender that refuses a row says it did not send it. That is believed of a FIRST delivery only: on the second
  -- the previous sender may have sent it before it died, and the refusal says nothing about that one.
  IF NOT bUnsent AND pReason ~ '^nack: (unsent|stopping):' THEN
    SELECT attempts INTO nAttempts FROM notify.queue WHERE id = pId;

    bUnsent := coalesce(nAttempts, 1) <= 1;
  END IF;

  IF bUnsent THEN
    PERFORM http.try_fail(uRequest, 'not sent: ' || pReason);
  ELSE
    PERFORM http.fail_unknown(uRequest, 'outcome unknown: ' || pReason);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- http.retake -----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Hand a request row to the sender for a REPEAT — the row if it may still be sent, nothing if not.
 * @param {uuid} pId - Request identifier
 * @return {SETOF http.request} - The row to send (0 or 1). No row means: do not send — the request is gone or
 *   closed, or its lifetime has elapsed (then it is closed here, see below).
 * @see http.take
 * @see http.fail_unknown
 * @since 1.2.39
 *
 * http.take is for the first delivery: a lifetime that ended before anything was sent closes the row quietly (state
 * 3, no callback). A repeat is the delivery of a row that left once and was not confirmed — the other side may
 * have it. If its lifetime (from datetime, the INSERT — not from the first look of notify, which can be later by the
 * producer's transaction: the idempotency window of the provider counts from the first request) has ended, it is not
 * sent a second time, and closing it quietly would lose a payment: it is closed as `outcome unknown` and the
 * producer's fail callback is called (http.fail_unknown), as for any other row that ended without an answer.
 * A sender that was handed a row by notify.take calls this when `attempts` is more than 1, http.take otherwise.
 */
CREATE OR REPLACE FUNCTION http.retake (
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
    PERFORM http.fail_unknown(pId, format('outcome unknown: lifetime %s elapsed before a repeat', r.expire));

    RETURN;
  END IF;

  RETURN NEXT r;
END;
$$ LANGUAGE plpgsql STRICT
   SECURITY DEFINER
   SET search_path = http, pg_temp;

--------------------------------------------------------------------------------
-- PRIVILEGES OF THE FUNCTIONS OF NOTIFY SINGLE (T1102) ------------------------
--------------------------------------------------------------------------------

-- http.fail_unknown and http.abandon run a function named by a request row, as kernel, and
-- are called from definers only (http.retake, notify.close): nobody else gets them.
-- The two the sender calls are for the pools that run senders, as the interface of notify is.
-- The older functions of this schema are left as they were.
REVOKE ALL ON FUNCTION http.fail_unknown(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION http.abandon(bigint, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION http.retake(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION http.try_create_response(uuid, integer, text, jsonb, bytea) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
  http.retake(uuid),
  http.try_create_response(uuid, integer, text, jsonb, bytea)
TO daemon, apibot;
