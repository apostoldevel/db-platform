--------------------------------------------------------------------------------
-- db.api_log ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.api_log (
    id          bigserial PRIMARY KEY,
    datetime    timestamp DEFAULT clock_timestamp() NOT NULL,
    su          text NOT NULL DEFAULT session_user,
    session     char(40),
    username    text,
    path        text NOT NULL,
    nonce       double precision,
    signature   text,
    json        jsonb,
    eventid     bigint,
    runtime     interval,
    CONSTRAINT fk_api_log_eventid FOREIGN KEY (eventid) REFERENCES db.log(id)
);

COMMENT ON TABLE db.api_log IS 'Лог API.';

COMMENT ON COLUMN db.api_log.id IS 'Идентификатор';
COMMENT ON COLUMN db.api_log.datetime IS 'Дата и время';
COMMENT ON COLUMN db.api_log.su IS 'Пользователь (СУБД)';
COMMENT ON COLUMN db.api_log.session IS 'Сессия';
COMMENT ON COLUMN db.api_log.username IS 'Пользователь (виртуальный)';
COMMENT ON COLUMN db.api_log.path IS 'Путь';
COMMENT ON COLUMN db.api_log.json IS 'JSON';
COMMENT ON COLUMN db.api_log.runtime IS 'Время выполнения запроса';

CREATE INDEX ON db.api_log (datetime);
CREATE INDEX ON db.api_log (username);
CREATE INDEX ON db.api_log (path);
CREATE INDEX ON db.api_log (eventid);

--------------------------------------------------------------------------------
-- AddApiLog -------------------------------------------------------------------
--------------------------------------------------------------------------------

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
  SELECT code, userid INTO vSession, uUserId FROM db.session WHERE code = GetCurrentSession();

  IF FOUND THEN
    SELECT username INTO vUserName FROM db.user WHERE id = uUserId;
  END IF;

  IF pJson ? 'password' THEN
    pJson := pJson - 'password';
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

CREATE OR REPLACE FUNCTION NewApiLog (
  pPath			text,
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

CREATE OR REPLACE FUNCTION DeleteApiLog (
  pId		bigint
) RETURNS	void
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

CREATE OR REPLACE FUNCTION ClearApiLog (
  pDateTime	timestamp
) RETURNS	void
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
  SELECT al.id, al.datetime, al.su, al.session, al.username,
         al.path, al.json, al.nonce, to_timestamp(al.nonce / 1000000), al.signature,
         round(extract(second from runtime)::numeric, 3), al.eventid, el.text
    FROM db.api_log al LEFT JOIN db.log el ON el.id = al.eventid;
