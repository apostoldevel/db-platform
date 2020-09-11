--------------------------------------------------------------------------------
-- api.log ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE api.log (
    id            numeric PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_API_LOG'),
    datetime      timestamp DEFAULT clock_timestamp() NOT NULL,
    su            text NOT NULL DEFAULT session_user,
    session       char(40),
    username      text,
    route         text NOT NULL,
    nonce         double precision,
    signature     text,
    json          jsonb,
    eventid       numeric(12),
    runtime       interval,
    CONSTRAINT fk_api_log_eventid FOREIGN KEY (eventid) REFERENCES db.log(id)
);

COMMENT ON TABLE api.log IS 'Лог API.';

COMMENT ON COLUMN api.log.id IS 'Идентификатор';
COMMENT ON COLUMN api.log.datetime IS 'Дата и время';
COMMENT ON COLUMN api.log.su IS 'Пользователь (СУБД)';
COMMENT ON COLUMN api.log.session IS 'Сессия';
COMMENT ON COLUMN api.log.username IS 'Пользователь (Виртуальный)';
COMMENT ON COLUMN api.log.route IS 'Путь';
COMMENT ON COLUMN api.log.json IS 'JSON';
COMMENT ON COLUMN api.log.runtime IS 'Время выполнения запроса';

CREATE INDEX ON api.log (datetime);
--CREATE INDEX ON api.log (su);
--CREATE INDEX ON api.log (session);
CREATE INDEX ON api.log (username);
CREATE INDEX ON api.log (eventid);

--------------------------------------------------------------------------------
-- AddApiLog -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddApiLog (
  pRoute        text,
  pJson         jsonb,
  pNonce        double precision DEFAULT null,
  pSignature    text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
  nUserId       numeric;

  vSession      text;
  vUserName     text;
BEGIN
  SELECT code, userid INTO vSession, nUserId FROM db.session WHERE code = GetCurrentSession();

  IF found THEN
    SELECT username INTO vUserName FROM db.user WHERE id = nUserId;
  END IF;

  IF pJson ? 'password' THEN
    pJson := pJson - 'password';
  END IF;

  INSERT INTO api.log (session, username, route, json, nonce, signature)
  VALUES (vSession, vUserName, pRoute, pJson, pNonce, pSignature)
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
  pRoute        text,
  pJson         jsonb,
  pNonce        double precision DEFAULT null,
  pSignature    text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  nId           numeric;
BEGIN
  nId := AddApiLog(pRoute, pJson, pNonce, pSignature);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteToApiLog ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION WriteToApiLog (
  pRoute        text,
  pJson         jsonb,
  pNonce        double precision DEFAULT null,
  pSignature    text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM NewApiLog(pRoute, pJson, pNonce, pSignature);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteApiLog ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteApiLog (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  DELETE FROM api.log WHERE id = pId;
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
  DELETE FROM api.log WHERE datetime < pDateTime;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW ApiLog -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ApiLog (Id, DateTime, su, Session, UserName,
  Path, JSON, Nonce, NonceTime, Signature, RunTime, EventId, Error)
AS
  SELECT al.id, al.datetime, al.su, al.session, al.username,
         al.route, al.json, al.nonce, to_timestamp(al.nonce / 1000000), al.signature,
         round(extract(second from runtime)::numeric, 3), al.eventid, el.text
    FROM api.log al LEFT JOIN db.log el ON el.id = al.eventid;
