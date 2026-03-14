--------------------------------------------------------------------------------
-- db.api_log ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.api_log (
    id          bigserial PRIMARY KEY,
    datetime    timestamptz DEFAULT clock_timestamp() NOT NULL,
    su          text NOT NULL DEFAULT session_user,
    session     char(40),
    username    text,
    path        text NOT NULL,
    nonce       double precision,
    signature   text,
    json        jsonb,
    eventId     bigint REFERENCES db.log(id),
    runtime     interval
);

COMMENT ON TABLE db.api_log IS 'API request log: every REST call is recorded here.';

COMMENT ON COLUMN db.api_log.id IS 'Log entry identifier (auto-increment).';
COMMENT ON COLUMN db.api_log.datetime IS 'Timestamp when the request was received.';
COMMENT ON COLUMN db.api_log.su IS 'Database session user (PostgreSQL role).';
COMMENT ON COLUMN db.api_log.session IS 'Application session token.';
COMMENT ON COLUMN db.api_log.username IS 'Virtual (application-level) username.';
COMMENT ON COLUMN db.api_log.path IS 'Request path (e.g. "/user/get").';
COMMENT ON COLUMN db.api_log.json IS 'Request payload (passwords stripped).';
COMMENT ON COLUMN db.api_log.runtime IS 'Server-side execution duration.';

CREATE INDEX ON db.api_log (datetime);
CREATE INDEX ON db.api_log (username);
CREATE INDEX ON db.api_log (path);
CREATE INDEX ON db.api_log (eventid);

--------------------------------------------------------------------------------
-- AddApiLog -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Record an API request in the log, stripping sensitive fields.
 * @param {text} pPath - Request path
 * @param {jsonb} pJson - Request payload (password/hidden keys are removed)
 * @param {double precision} pNonce - Optional cryptographic nonce (microsecond timestamp)
 * @param {text} pSignature - Optional request signature
 * @return {bigint} - Identifier of the new log entry
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddApiLog (
  pPath         text,
  pJson         jsonb,
  pNonce        double precision DEFAULT null,
  pSignature    text DEFAULT null
) RETURNS       bigint
AS $$
DECLARE
  nId           bigint;
  uUserId       uuid;

  vSession      text;
  vUserName     text;
BEGIN
  SELECT code, userid INTO vSession, uUserId FROM db.session WHERE code = current_session();

  IF FOUND THEN
    SELECT username INTO vUserName FROM db.user WHERE id = uUserId;
  END IF;

  IF pJson ? 'password' THEN
    pJson := pJson - 'password';
  END IF;

  IF pJson ? 'hidden' THEN
    pJson := pJson - 'hidden';
  END IF;

  INSERT INTO db.api_log (session, username, path, json, nonce, signature)
  VALUES (vSession, vUserName, pPath, pJson, pNonce, pSignature)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewApiLog -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new API log entry (fire-and-forget wrapper around AddApiLog).
 * @param {text} pPath - Request path
 * @param {jsonb} pJson - Request payload
 * @param {double precision} pNonce - Optional cryptographic nonce
 * @param {text} pSignature - Optional request signature
 * @return {void}
 * @see AddApiLog
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewApiLog (
  pPath         text,
  pJson         jsonb,
  pNonce        double precision DEFAULT null,
  pSignature    text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  nId           bigint;
BEGIN
  nId := AddApiLog(pPath, pJson, pNonce, pSignature);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteToApiLog ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Write an entry to the API log (convenience alias for NewApiLog).
 * @param {text} pPath - Request path
 * @param {jsonb} pJson - Request payload
 * @param {double precision} pNonce - Optional cryptographic nonce
 * @param {text} pSignature - Optional request signature
 * @return {void}
 * @see NewApiLog
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION WriteToApiLog (
  pPath         text,
  pJson         jsonb,
  pNonce        double precision DEFAULT null,
  pSignature    text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM NewApiLog(pPath, pJson, pNonce, pSignature);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteApiLog ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a single API log entry by identifier.
 * @param {bigint} pId - Log entry identifier to remove
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteApiLog (
  pId        bigint
) RETURNS    void
AS $$
BEGIN
  DELETE FROM db.api_log WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ClearApiLog -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Purge API log entries older than the specified timestamp.
 * @param {timestamptz} pDateTime - Delete all entries before this date/time
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ClearApiLog (
  pDateTime  timestamptz
) RETURNS    void
AS $$
BEGIN
  DELETE FROM db.api_log WHERE datetime < pDateTime;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW apiLog -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW apiLog (Id, DateTime, su, Session, UserName,
  Path, JSON, Nonce, NonceTime, Signature, RunTime, EventId, Error)
AS
  SELECT id, datetime, su, session, username,
         path, json, nonce, to_timestamp(nonce / 1000000), signature,
         round(extract(second from runtime)::numeric, 3), eventid, null
    FROM db.api_log;

GRANT SELECT ON apiLog TO administrator;