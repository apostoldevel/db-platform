--------------------------------------------------------------------------------
-- SECURITY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- GetAreaType -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAreaType (
  pCode		text
) RETURNS 	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.area_type WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateProfile ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UpdateProfile (
  pUserId       	uuid,
  pFamilyName		text,
  pGivenName		text,
  pPatronymicName	text,
  pLocale			uuid,
  pArea				uuid,
  pInterface		uuid,
  pEmailVerified	bool,
  pPhoneVerified	bool,
  pPicture			text
) RETURNS 	    	boolean
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF pUserId <> current_userid() THEN
	  IF NOT CheckAccessControlList(B'00000000001000') THEN
		PERFORM AccessDenied();
	  END IF;
    END IF;
  END IF;

  UPDATE db.profile
	 SET family_name = coalesce(pFamilyName, family_name),
	     given_name = coalesce(pGivenName, given_name),
	     patronymic_name = coalesce(pPatronymicName, patronymic_name),
	     locale = coalesce(pLocale, locale),
		 area = coalesce(pArea, area),
		 interface = coalesce(pInterface, interface),
		 email_verified = coalesce(pEmailVerified, email_verified),
		 phone_verified = coalesce(pPhoneVerified, phone_verified),
		 picture = coalesce(pPicture, picture)
   WHERE userid = pUserId;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddRecoveryTicket -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddRecoveryTicket (
  pUserId			uuid,
  pSecurityAnswer	text,
  pDateFrom			timestamptz DEFAULT Now(),
  pDateTo			timestamptz DEFAULT null
) RETURNS			uuid
AS $$
DECLARE
  nTicket			uuid;
  dtDateFrom		timestamptz;
  dtDateTo			timestamptz;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT ticket, validFromDate, validToDate INTO nTicket, dtDateFrom, dtDateTo
    FROM db.recovery_ticket
   WHERE userid = pUserId
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.recovery_ticket SET securityAnswer = pSecurityAnswer
     WHERE userid = pUserId
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.recovery_ticket SET used = Now(), validToDate = pDateFrom
     WHERE userid = pUserId
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.recovery_ticket (userid, securityAnswer, validFromDate, validtodate)
    VALUES (pUserId, pSecurityAnswer, pDateFrom, pDateTo)
    RETURNING ticket INTO nTicket;
  END IF;

  RETURN nTicket;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewRecoveryTicket -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewRecoveryTicket (
  pUserId			uuid,
  pSecurityAnswer	text,
  pDateFrom			timestamptz DEFAULT Now(),
  pDateTo			timestamptz DEFAULT Now() + INTERVAL '1 hour'
) RETURNS			uuid
AS $$
BEGIN
  RETURN AddRecoveryTicket(pUserId, crypt(pSecurityAnswer, gen_salt('md5')), pDateFrom, pDateTo);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetRecoveryTicket -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetRecoveryTicket (
  pUserId			uuid,
  pDateFrom			timestamptz DEFAULT Now()
) RETURNS			uuid
AS $$
DECLARE
  nTicket			uuid;
BEGIN
  SELECT ticket INTO nTicket
    FROM db.recovery_ticket
   WHERE userid = pUserId
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  RETURN nTicket;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckRecoveryTicket ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckRecoveryTicket (
  pTicket			uuid,
  pSecurityAnswer	text
) RETURNS			uuid
AS $$
DECLARE
  nUserId			uuid;
  passed			boolean;
  utilized			boolean;
BEGIN
  SELECT userId, (securityAnswer = crypt(pSecurityAnswer, securityAnswer)), used IS NOT NULL INTO nUserId, passed, utilized
    FROM db.recovery_ticket
   WHERE ticket = pTicket
     AND validFromDate <= Now()
     AND validtoDate > Now();

  IF found THEN
    IF utilized THEN
      PERFORM SetErrorMessage('Талон восстановления пароля уже был использован.');
    ELSE
	  IF passed THEN
		PERFORM SetErrorMessage('Успешно.');
		RETURN nUserId;
	  ELSE
		PERFORM SetErrorMessage('Секретный ответ не прошёл проверку.');
	  END IF;
    END IF;
  ELSE
    PERFORM SetErrorMessage('Талон восстановления пароля не найден.');
  END IF;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateAuth ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAuth (
  pUserId       uuid,
  pAudience     integer,
  pCode		    text
) RETURNS 	    void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.auth (userId, audience, code) VALUES (pUserId, pAudience, pCode)
    ON CONFLICT (userid, audience) DO NOTHING;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetIPTableStr ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetIPTableStr (
  pUserId	uuid,
  pType		char DEFAULT 'A'
) RETURNS	text
AS $$
DECLARE
  r             record;
  ip		integer[4];
  vHost		text;
  aResult	text[];
BEGIN
  FOR r IN SELECT * FROM db.iptable WHERE userid = pUserId AND type = pType
  LOOP
    IF r.range IS NOT NULL THEN
      vHost := host(r.addr) || '-' || host(r.addr + r.range - 1);
    ELSE
      CASE masklen(r.addr)
      WHEN 8 THEN
        ip := inet_to_array(r.addr);
        ip[1] := null;
        ip[2] := null;
        ip[3] := null;
        vHost := array_to_string(ip, '.', '*');
      WHEN 16 THEN
        ip := inet_to_array(r.addr);
        ip[2] := null;
        ip[3] := null;
        vHost := array_to_string(ip, '.', '*');
      WHEN 24 THEN
        ip := inet_to_array(r.addr);
        ip[3] := null;
        vHost := array_to_string(ip, '.', '*');
      WHEN 32 THEN
        vHost := host(r.addr);
      ELSE
        vHost := text(r.addr);
      END CASE;
    END IF;

    aResult := array_append(aResult, vHost);
  END LOOP;

  RETURN array_to_string(aResult, ', ');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetIPTableStr ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetIPTableStr (
  pUserId	uuid,
  pType		char,
  pIpTable	text
) RETURNS	void
AS $$
DECLARE
  i             int;

  vStr		text;
  arrIp		text[];

  iHost		inet;
  nRange	int;
BEGIN
  pType := coalesce(pType, 'A');

  DELETE FROM db.iptable WHERE type = pType AND userid = pUserId;

  vStr := NULLIF(pIpTable, '');
  IF vStr IS NOT NULL THEN

    arrIp := string_to_array_trim(vStr, ',');

    FOR i IN 1..array_length(arrIp, 1)
    LOOP
      SELECT host, range INTO iHost, nRange FROM str_to_inet(arrIp[i]);

      INSERT INTO db.iptable (type, userid, addr, range)
      VALUES (pType, pUserId, iHost, nRange);
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckIPTable ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckIPTable (
  pUserId	uuid,
  pType		char,
  pHost		inet
) RETURNS	boolean
AS $$
DECLARE
  r             record;
  passed	boolean;
BEGIN
  FOR r IN SELECT * FROM db.iptable WHERE type = pType AND userid = pUserId
  LOOP
    IF r.range IS NOT NULL THEN
      passed := (pHost >= r.addr) AND (pHost <= r.addr + (r.range - 1));
    ELSE
      passed := pHost <<= r.addr;
    END IF;

    EXIT WHEN coalesce(passed, false);
  END LOOP;

  RETURN passed;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckIPTable ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckIPTable (
  pUserId	uuid,
  pHost		inet
) RETURNS	boolean
AS $$
DECLARE
  denied	boolean;
  allow		boolean;
BEGIN
  denied := coalesce(CheckIPTable(pUserId, 'D', pHost), false);

  IF NOT denied THEN
    allow := coalesce(CheckIPTable(pUserId, 'A', pHost), true);
  ELSE
    allow := NOT denied;
  END IF;

  IF NOT allow THEN
    PERFORM SetErrorMessage('Ограничен доступ по IP-адресу.');
  END IF;

  RETURN allow;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckSessionLimit -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckSessionLimit (
  pUserId	uuid
) RETURNS	void
AS $$
DECLARE
  nCount	integer;
  nLimit	integer;

  r             record;
BEGIN
  SELECT session_limit INTO nLimit FROM db.profile WHERE userid = pUserId;

  IF coalesce(nLimit, 0) > 0 THEN

    SELECT count(*) INTO nCount FROM db.session WHERE userid = pUserId;

    FOR r IN SELECT code FROM db.session WHERE userid = pUserId ORDER BY created
    LOOP
      EXIT WHEN nCount = 0;
      EXIT WHEN nCount < nLimit;

      PERFORM SessionOut(r.code, false, 'Превышен лимит.');

      nCount := nCount - 1;
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION StrPwKey -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrPwKey (
  pUserId       uuid,
  pSecret       text,
  pCreated      timestamp
) RETURNS       text
AS $$
DECLARE
  vHash         text;
  vStrPwKey     text DEFAULT null;
BEGIN
  SELECT hash INTO vHash FROM db.user WHERE id = pUserId;

  IF found THEN
    vStrPwKey := '{' || pUserId::text || '-' || vHash || '-' || pSecret || '-' || current_database() || '-' || DateToStr(pCreated, 'YYYYMMDDHH24MISS') || '}';
  END IF;

  RETURN encode(digest(vStrPwKey, 'sha1'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CreateAccessToken --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAccessToken (
  pAudience     integer,
  pSubject      text,
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT Now() + INTERVAL '60 min'
) RETURNS       text
AS $$
DECLARE
  token         json;
  nProvider     integer;
  vSecret       text;
  iss           text;
  aud           text;
BEGIN
  SELECT provider, code, secret INTO nProvider, aud, vSecret FROM oauth2.audience WHERE id = pAudience;
  SELECT code INTO iss FROM oauth2.issuer WHERE provider = nProvider;

  IF NOT found THEN
	PERFORM IssuerNotFound(coalesce(iss, 'null'));
  END IF;

  token := json_build_object('iss', iss, 'aud', aud, 'sub', pSubject, 'iat', trunc(extract(EPOCH FROM pDateFrom)), 'exp', trunc(extract(EPOCH FROM pDateTo)));

  RETURN sign(token, vSecret);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CreateIdToken ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateIdToken (
  pAudience     integer,
  pUserId       uuid,
  pScopes       text[],
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT Now() + INTERVAL '60 min'
) RETURNS       text
AS $$
DECLARE
  p             record;

  nProvider     integer;

  vSecret       text;

  iss           text;
  aud           text;

  payload       jsonb;
BEGIN
  SELECT provider, code, secret INTO nProvider, aud, vSecret FROM oauth2.audience WHERE id = pAudience;
  SELECT code INTO iss FROM oauth2.issuer WHERE provider = nProvider;

  SELECT id, username, name, given_name, family_name, patronymic_name,
         email, email_verified, phone, phone_verified, session_limit,
         created, locale, area, interface, description, picture
    INTO p
    FROM users WHERE id = pUserId;

  IF NOT FOUND THEN
    PERFORM UserNotFound(pUserId);
  END IF;

  payload := jsonb_build_object('iss', iss, 'aud', aud, 'sub', p.username, 'uid', p.id, 'iat', trunc(extract(EPOCH FROM pDateFrom)), 'exp', trunc(extract(EPOCH FROM pDateTo)));

  IF pScopes && ARRAY['profile'] THEN
    payload := payload || row_to_json(p)::jsonb;
  END IF;

  RETURN sign(payload::json, vSecret);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CreateIdToken ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateIdToken (
  pAudience     integer,
  pSession      varchar,
  pScopes       text[],
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT Now() + INTERVAL '1 hour'
) RETURNS       text
AS $$
DECLARE
  nUserId       uuid;
BEGIN
  SELECT userId INTO nUserId FROM db.session WHERE code = pSession;
  RETURN CreateIdToken(pAudience, nUserId, pScopes, pDateFrom, pDateTo);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
--------------------------------------------------------------------------------
-- FUNCTION SessionKey ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SessionKey (
  pPwKey        text,
  pPassKey      text
) RETURNS       text
AS $$
DECLARE
  vSession      text DEFAULT null;
BEGIN
  IF pPwKey IS NOT NULL THEN
    vSession := encode(hmac(pPwKey, pPassKey, 'sha1'), 'hex');
  END IF;

  RETURN vSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetTokenHash -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetTokenHash (
  pToken        text,
  pPassKey      text
) RETURNS       text
AS $$
BEGIN
  RETURN encode(hmac(pToken, pPassKey, 'sha1'), 'hex');
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GenSecretKey -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GenSecretKey (
  pSize         integer DEFAULT 48
)
RETURNS         text
AS $$
BEGIN
  RETURN encode(gen_random_bytes(pSize), 'base64');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GenTokenKey --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GenTokenKey (
  pPassKey      text
) RETURNS       text
AS $$
BEGIN
  RETURN encode(hmac(GenSecretKey(), pPassKey, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetSignature ----------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 * @param {text} pPath - Путь
 * @param {double precision} pNonce - Время в миллисекундах
 * @param {json} pJson - Данные
 * @param {text} pSecret - Секретный ключ
 * @return {text}
 */
CREATE OR REPLACE FUNCTION GetSignature (
  pPath	        text,
  pNonce        double precision,
  pJson         json,
  pSecret       text
) RETURNS	    text
AS $$
BEGIN
  RETURN encode(hmac(pPath || trim(to_char(pNonce, '9999999999999999')) || coalesce(pJson, 'null'), pSecret, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ScopeToArray ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ScopeToArray (
  pScope        text
) RETURNS       text[]
AS $$
DECLARE
  r				record;

  scopes        text[];
  arValid       text[];
  arInvalid     text[];
  arScopes      text[];
BEGIN
  IF NULLIF(pScope, '') IS NOT NULL THEN

    arScopes := array_cat(arScopes, ARRAY['api', 'openid', 'profile', 'email']);

	FOR r IN SELECT code FROM db.scope
	LOOP
	  arScopes := array_append(arScopes, r.code);
	END LOOP;

    scopes := string_to_array(pScope, ' ');

    FOR i IN 1..array_length(scopes, 1)
    LOOP
      IF array_position(arScopes, scopes[i]) IS NULL THEN
        arInvalid := array_append(arInvalid, scopes[i]);
      ELSE
        arValid := array_append(arValid, scopes[i]);
      END IF;
    END LOOP;

    IF arInvalid IS NOT NULL THEN

      IF arValid IS NULL THEN
        arValid := array_append(arValid, '');
      END IF;

      PERFORM InvalidScope(arValid, arInvalid);
    END IF;

  ELSE
    arValid := array_append(arValid, current_database());
  END IF;

  RETURN arValid;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateOAuth2 ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateOAuth2 (
  pAudience     integer,
  pScopes       text[],
  pAccessType   text DEFAULT null,
  pRedirectURI  text DEFAULT null,
  pState        text DEFAULT null
) RETURNS       bigint
AS $$
DECLARE
  nId           bigint;
BEGIN
  pAccessType := coalesce(pAccessType, 'online');

  INSERT INTO db.oauth2 (audience, scopes, access_type, redirect_uri, state)
  VALUES (pAudience, pScopes, pAccessType, pRedirectURI, pState)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateOAuth2 ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateOAuth2 (
  pAudience     integer,
  pScope		text,
  pAccessType   text DEFAULT null,
  pRedirectURI  text DEFAULT null,
  pState        text DEFAULT null
) RETURNS       bigint
AS $$
BEGIN
  pAccessType := coalesce(pAccessType, 'online');
  RETURN CreateOAuth2(pAudience, ScopeToArray(pScope), pAccessType, pRedirectURI, pState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateSystemOAuth2 ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateSystemOAuth2 (
  pScope		text DEFAULT current_database()
) RETURNS       bigint
AS $$
BEGIN
  RETURN CreateOAuth2(GetAudience(oauth2_system_client_id()), pScope);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateTokenHeader -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateTokenHeader (
  pOAuth2       bigint,
  pSession      varchar,
  pSalt         text,
  pAgent        text,
  pHost         inet
) RETURNS       bigint
AS $$
DECLARE
  nId           bigint;
BEGIN
  INSERT INTO db.token_header (oauth2, session, salt, agent, host)
  VALUES (pOAuth2, pSession, pSalt, pAgent, pHost)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddToken --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddToken (
  pHeader       bigint,
  pType         char,
  pToken        text,
  pDateFrom     timestamptz,
  pDateTo       timestamptz DEFAULT null
) RETURNS       bigint
AS $$
DECLARE
  nId           bigint;
  dtDateFrom 	timestamp;
  dtDateTo      timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT id, validFromDate, validToDate INTO nId, dtDateFrom, dtDateTo
    FROM db.token
   WHERE header = pHeader
     AND type = pType
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.token SET token = pToken
     WHERE header = pHeader
       AND type = pType
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.token SET validToDate = pDateFrom
     WHERE header = pHeader
       AND type = pType
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.token (header, type, token, validFromDate, validtodate)
    VALUES (pHeader, pType, pToken, pDateFrom, pDateTo)
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewTokenCode ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewTokenCode (
  pOAuth2       bigint,
  pSession      varchar,
  pSalt         text,
  pAgent        text,
  pHost         inet,
  pCreated      timestamptz
) RETURNS       bigint
AS $$
DECLARE
  nHeader       bigint;
BEGIN
  nHeader := CreateTokenHeader(pOAuth2, pSession, pSalt, pAgent, pHost);
  RETURN AddToken(nHeader, 'C', GenSecretKey(48), pCreated);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewToken --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewToken (
  pAudience     integer,
  pHeader       bigint,
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT Now() + INTERVAL '1 hour'
) RETURNS       jsonb
AS $$
DECLARE
  nOauth2       bigint;

  access_token  text;
  refresh_token text;
  id_token      text;

  expires_in    double precision;

  arScopes      text[];

  vSession      text;

  vAccessType   text;
  vState        text;

  Token         jsonb;
BEGIN
  SELECT oauth2, session INTO nOauth2, vSession
    FROM db.token_header WHERE id = pHeader;

  SELECT access_type, scopes, state INTO vAccessType, arScopes, vState
    FROM db.oauth2 WHERE id = nOauth2;

  IF NOT FOUND THEN
    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'The OAuth 2.0 params was not found.'));
  END IF;

  expires_in := trunc(extract(EPOCH FROM pDateTo)) - trunc(extract(EPOCH FROM pDateFrom));

  access_token := CreateAccessToken(pAudience, vSession, pDateFrom, pDateTo);
  PERFORM AddToken(pHeader, 'A', access_token, pDateFrom, pDateTo);

  Token := jsonb_build_object('session', vSession, 'secret', session_secret(vSession), 'access_token', access_token, 'token_type', 'Bearer', 'expires_in', expires_in, 'scope', array_to_string(arScopes, ' '));

  IF vState IS NOT NULL THEN
    Token := Token || jsonb_build_object('state', vState);
  END IF;

  IF vAccessType = 'offline' THEN
    refresh_token := GenSecretKey(54);
    PERFORM AddToken(pHeader, 'R', refresh_token, pDateFrom, MAXDATE());
    Token := Token || jsonb_build_object('refresh_token', refresh_token);
  END IF;

  IF arScopes && ARRAY['openid', 'profile'] THEN
    id_token := CreateIdToken(pAudience, vSession, arScopes, pDateFrom, pDateTo);
    PERFORM AddToken(pHeader, 'I', id_token, pDateFrom, pDateTo);
    Token := Token || jsonb_build_object('id_token', id_token);
  END IF;

  UPDATE db.token_header SET updated = Now() WHERE id = pHeader;

  RETURN Token;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ExchangeToken ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExchangeToken (
  pAudience     integer,
  pToken        text,
  pInterval     interval DEFAULT '1 hour',
  pType         char DEFAULT 'A'
) RETURNS       json
AS $$
DECLARE
  nHeader       bigint;
  nToken        bigint;
  vType         text;
BEGIN
  SELECT h.id, t.id INTO nHeader, nToken
    FROM db.token_header h INNER JOIN db.token t ON h.id = t.header AND t.type = pType AND NOT (pType = 'C' AND t.used IS NOT NULL)
   WHERE t.hash = GetTokenHash(pToken, GetSecretKey())
     AND t.validFromDate <= Now()
     AND t.validtoDate > Now();

  IF NOT FOUND THEN

    CASE pType
    WHEN 'C' THEN
      vType := 'authorization code.';
    WHEN 'A' THEN
      vType := 'access token.';
    WHEN 'R' THEN
      vType := 'refresh token.';
    WHEN 'I' THEN
      vType := 'id token.';
    END CASE;

    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_grant', 'message', 'Malformed ' || vType));
  END IF;

  IF pType = 'C' THEN
    UPDATE db.token SET used = Now() WHERE id = nToken;
  END IF;

  RETURN NewToken(pAudience, nHeader, Now(), Now() + pInterval);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateToken -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateToken (
  pAudience     integer,
  pCode         text,
  pInterval     interval DEFAULT '1 hour'
) RETURNS       jsonb
AS $$
BEGIN
  RETURN ExchangeToken(pAudience, pCode, pInterval, 'C');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateToken -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UpdateToken (
  pAudience     integer,
  pRefresh      text,
  pInterval     interval DEFAULT '1 hour'
) RETURNS       json
AS $$
BEGIN
  RETURN ExchangeToken(pAudience, pRefresh, pInterval, 'R');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetToken --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetToken (
  pId       bigint
) RETURNS   text
AS $$
DECLARE
  vToken    text;
BEGIN
  SELECT token INTO vToken FROM db.token WHERE id = pId;
  RETURN vToken;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SafeSetVar ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SafeSetVar (
  pName		text,
  pValue	text
) RETURNS	void
AS $$
BEGIN
  PERFORM set_config('current.' || pName, pValue, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SafeGetVar ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SafeGetVar (
  pName 	text
) RETURNS   text
AS $$
BEGIN
  RETURN NULLIF(current_setting('current.' || pName), '');
EXCEPTION
WHEN syntax_error_or_access_rule_violation THEN
  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSecretKey -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSecretKey (
  pName         text DEFAULT 'default'
) RETURNS       text
AS $$
DECLARE
  vDefaultKey	text DEFAULT 'MYXIWngoebYUkOPlGYdXuy6n';
  vSecretKey	text DEFAULT SafeGetVar(pName);
BEGIN
  RETURN coalesce(vSecretKey, vDefaultKey);
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oauth2_system_client_id --------------------------------------------
--------------------------------------------------------------------------------
/**
 * Системный клиент OAuth 2.0.
 * @return {text} - OAuth 2.0 Client Id
 */
CREATE OR REPLACE FUNCTION oauth2_system_client_id()
RETURNS		text
AS $$
BEGIN
  RETURN current_database();
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetOAuth2ClientId --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetOAuth2ClientId (
  pClientId	text
) RETURNS	void
AS $$
BEGIN
  PERFORM SafeSetVar('client_id', pClientId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetOAuth2ClientId --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetOAuth2ClientId()
RETURNS	text
AS $$
BEGIN
  RETURN SafeGetVar('client_id');
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oauth2_current_client_id -------------------------------------------
--------------------------------------------------------------------------------
/**
 * Текущий клиент OAuth 2.0.
 * @return {text} - OAuth 2.0 Client Id
 */
CREATE OR REPLACE FUNCTION oauth2_current_client_id()
RETURNS		text
AS $$
BEGIN
  RETURN GetOAuth2ClientId();
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetDebugMode -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDebugMode (
  pValue	boolean
) RETURNS	void
AS $$
BEGIN
  PERFORM SafeSetVar('debug', pValue::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetDebugMode -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDebugMode()
RETURNS		boolean
AS $$
BEGIN
  RETURN coalesce(SafeGetVar('debug')::boolean, false);
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetCurrentSession --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetCurrentSession (
  pValue	text
) RETURNS	void
AS $$
BEGIN
  PERFORM SafeSetVar('session', pValue);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetCurrentSession --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCurrentSession()
RETURNS		text
AS $$
BEGIN
  RETURN SafeGetVar('session');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetCurrentUserId ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetCurrentUserId (
  pValue	uuid
) RETURNS	void
AS $$
BEGIN
  PERFORM SafeSetVar('user', pValue::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetCurrentUserId ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCurrentUserId()
RETURNS		uuid
AS $$
BEGIN
  RETURN SafeGetVar('user')::uuid;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_session ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает ключ текущей сессии.
 * @return {text} - Код сессии
 */
CREATE OR REPLACE FUNCTION current_session()
RETURNS		text
AS $$
DECLARE
  vCode		text;
  vSession	text;
BEGIN
  vCode := GetCurrentSession();
  IF vCode IS NOT NULL THEN
    SELECT code INTO vSession FROM db.session WHERE code = vCode;
    IF found THEN
      RETURN vSession;
    END IF;
  END IF;
  RETURN null;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_secret -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает секретный ключ сессии (тсс... никому не говорить 😉 !!!).
 * @param {varchar} pSession - Код сессии
 * @return {text}
 */
CREATE OR REPLACE FUNCTION session_secret (
  pSession	varchar DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vSecret	text;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT secret INTO vSecret FROM db.session WHERE code = pSession;
  END IF;
  RETURN vSecret;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_scope ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_scope (
  pSession	varchar DEFAULT current_session()
)
RETURNS		uuid
AS $$
DECLARE
  uArea		uuid;
  uScope	uuid;
BEGIN
  SELECT area INTO uArea FROM db.session WHERE code = pSession;
  SELECT scope INTO uScope FROM db.area WHERE id = uArea;

  RETURN uScope;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetOAuth2Scopes ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetOAuth2Scopes (
  pOAuth2	bigint
)
RETURNS		SETOF uuid
AS $$
DECLARE
  i			integer;
  uScope	uuid;
  arScopes	text[];
BEGIN
  SELECT scopes INTO arScopes FROM db.oauth2 WHERE id = pOAuth2;

  IF arScopes IS NOT NULL THEN
    FOR i IN 1..array_length(arScopes, 1)
    LOOP
      SELECT id INTO uScope FROM db.scope WHERE code = arScopes[i];
      IF FOUND THEN
        RETURN NEXT uScope;
      END IF;
    END LOOP;
  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_scopes -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_scopes (
  pSession	varchar DEFAULT current_session()
)
RETURNS		SETOF uuid
AS $$
DECLARE
  nOAuth2	bigint;
BEGIN
  SELECT oauth2 INTO nOAuth2 FROM db.session WHERE code = pSession;
  RETURN QUERY SELECT * FROM GetOAuth2Scopes(nOAuth2);
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_area -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает зону сессии.
 * @param {varchar} pSession - Код сессии
 * @return {text}
 */
CREATE OR REPLACE FUNCTION session_area (
  pSession	varchar DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vArea     text;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT area INTO vArea FROM db.session WHERE code = pSession;
  END IF;
  RETURN vArea;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_agent ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает агента сессии.
 * @param {varchar} pSession - Код сессии
 * @return {text}
 */
CREATE OR REPLACE FUNCTION session_agent (
  pSession	varchar DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vAgent	text;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT agent INTO vAgent FROM db.session WHERE code = pSession;
  END IF;
  RETURN vAgent;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_host -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает IP адрес подключения.
 * @param {varchar} pSession - Код сессии
 * @return {text} - IP адрес
 */
CREATE OR REPLACE FUNCTION session_host (
  pSession	varchar DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  iHost		inet;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT host INTO iHost FROM db.session WHERE code = pSession;
  END IF;
  RETURN host(iHost);
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_userid -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор пользователя сеанса.
 * @param {varchar} pSession - Код сессии
 * @return {id} - Идентификатор пользователя: users.id
 */
CREATE OR REPLACE FUNCTION session_userid (
  pSession	varchar DEFAULT current_session()
)
RETURNS		uuid
AS $$
DECLARE
  nUserId	uuid;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT suid INTO nUserId FROM db.session WHERE code = pSession;
  END IF;
  RETURN nUserId;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_userid -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор текущего пользователя.
 * @return {id} - Идентификатор пользователя: users.id
 */
CREATE OR REPLACE FUNCTION current_userid()
RETURNS		uuid
AS $$
DECLARE
  nUserId	uuid;
  vSession	text;
BEGIN
  nUserId := GetCurrentUserId();
  IF nUserId IS NULL THEN
    vSession := current_session();
    IF vSession IS NOT NULL THEN
      SELECT userid INTO nUserId FROM db.session WHERE code = vSession;
      PERFORM SetCurrentUserId(nUserId);
    END IF;
  END IF;
  RETURN nUserId;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_username ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает имя пользователя сеанса.
 * @param {varchar} pSession - Код сессии
 * @return {text} - Имя (username) пользователя: users.username
 */
CREATE OR REPLACE FUNCTION session_username (
  pSession	varchar DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vUserName	text;
BEGIN
  SELECT username INTO vUserName FROM users WHERE id = session_userid(pSession);
  RETURN vUserName;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_username ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает имя текущего пользователя.
 * @return {text} - Имя (username) пользователя: users.username
 */
CREATE OR REPLACE FUNCTION current_username()
RETURNS		text
AS $$
DECLARE
  vUserName	text;
BEGIN
  SELECT username INTO vUserName FROM users WHERE id = current_userid();
  RETURN vUserName;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oauth2_current_code ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает текущий код авторизации (OAuth 2.0).
 * @return {text} - Код авторизации
 */
CREATE OR REPLACE FUNCTION oauth2_current_code (
  pSession      varchar DEFAULT current_session()
)
RETURNS         text
AS $$
DECLARE
  vCode         text;
BEGIN
  SELECT t.token INTO vCode
    FROM db.token_header h INNER JOIN db.token t ON h.id = t.header AND t.type = 'C'
   WHERE h.session = pSession
     AND t.validFromDate <= Now()
     AND t.validToDate > Now();

  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionArea -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetSessionArea (
  pArea 	uuid,
  pSession	varchar DEFAULT current_session()
) RETURNS 	void
AS $$
BEGIN
  UPDATE db.session SET area = pArea WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionArea -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSessionArea (
  pSession	varchar DEFAULT current_session()
)
RETURNS 	uuid
AS $$
DECLARE
  uArea	    uuid;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT area INTO uArea FROM db.session WHERE code = pSession;
  END IF;
  RETURN uArea;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_area_type --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_area_type (
  pSession	varchar DEFAULT current_session()
)
RETURNS 	uuid
AS $$
DECLARE
  nType     uuid;
BEGIN
  SELECT type INTO nType FROM db.area WHERE id = GetSessionArea(pSession);
  RETURN nType;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_area -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_area (
  pSession	varchar DEFAULT current_session()
)
RETURNS 	uuid
AS $$
BEGIN
  RETURN GetSessionArea(pSession);
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionInterface ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetSessionInterface (
  pInterface 	uuid,
  pSession	    varchar DEFAULT current_session()
) RETURNS 	    void
AS $$
BEGIN
  UPDATE db.session SET interface = pInterface WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionInterface ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSessionInterface (
  pSession	    varchar DEFAULT current_session()
)
RETURNS 	    uuid
AS $$
DECLARE
  uInterface    uuid;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT interface INTO uInterface FROM db.session WHERE code = pSession;
  END IF;
  RETURN uInterface;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_interface --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_interface (
  pSession	varchar DEFAULT current_session()
)
RETURNS 	uuid
AS $$
BEGIN
  RETURN GetSessionInterface(pSession);
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetOperDate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamp} pOperDate - Дата операционного дня
 * @param {varchar} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetOperDate (
  pOperDate 	timestamp,
  pSession	    varchar DEFAULT current_session()
) RETURNS 	    void
AS $$
BEGIN
  UPDATE db.session SET oper_date = pOperDate WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetOperDate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamptz} pOperDate - Дата операционного дня
 * @param {varchar} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetOperDate (
  pOperDate 	timestamptz,
  pSession	    varchar DEFAULT current_session()
) RETURNS 	    void
AS $$
BEGIN
  UPDATE db.session SET oper_date = pOperDate WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetOperDate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дату операционного дня.
 * @param {varchar} pSession - Код сессии
 * @return {timestamp} - Дата операционного дня
 */
CREATE OR REPLACE FUNCTION GetOperDate (
  pSession		varchar DEFAULT current_session()
)
RETURNS 		timestamp
AS $$
DECLARE
  dtOperDate	timestamp;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT oper_date INTO dtOperDate FROM db.session WHERE code = pSession;
  END IF;
  RETURN dtOperDate;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oper_date ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дату операционного дня.
 * @param {varchar} pSession - Код сессии
 * @return {timestamp} - Дата операционного дня
 */
CREATE OR REPLACE FUNCTION oper_date (
  pSession		varchar DEFAULT current_session()
)
RETURNS 		timestamp
AS $$
DECLARE
  dtOperDate	timestamp;
BEGIN
  dtOperDate := GetOperDate(pSession);
  IF dtOperDate IS NULL THEN
    dtOperDate := now();
  END IF;
  RETURN dtOperDate;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionLocale ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по идентификатору текущий язык.
 * @param {id} pLocale - Идентификатор языка
 * @param {varchar} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetSessionLocale (
  pLocale   uuid,
  pSession	varchar DEFAULT current_session()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.session SET locale = pLocale WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionLocale ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по коду текущий язык.
 * @param {text} pCode - Код языка
 * @param {varchar} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetSessionLocale (
  pCode		text DEFAULT 'ru',
  pSession	varchar DEFAULT current_session()
) RETURNS	void
AS $$
DECLARE
  nLocale	uuid;
BEGIN
  SELECT id INTO nLocale FROM db.locale WHERE code = pCode;
  IF found THEN
    PERFORM SetSessionLocale(nLocale, pSession);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionLocale ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор текущего языка.
 * @param {varchar} pSession - Код сессии
 * @return {uuid} - Идентификатор языка.
 */
CREATE OR REPLACE FUNCTION GetSessionLocale (
  pSession	varchar DEFAULT current_session()
) RETURNS	uuid
AS $$
DECLARE
  nLocale	uuid;
BEGIN
  SELECT locale INTO nLocale FROM db.session WHERE code = pSession;
  RETURN nLocale;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION locale_code --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает код текущего языка.
 * @param {varchar} pSession - Код сессии
 * @return {text} - Код языка
 */
CREATE OR REPLACE FUNCTION locale_code (
  pSession	varchar DEFAULT current_session()
) RETURNS	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.locale WHERE id = GetSessionLocale(pSession);

  IF vCode IS NULL THEN
    vCode := RegGetValueString('CURRENT_CONFIG', 'CONFIG\System', 'LocaleCode');
  END IF;

  RETURN coalesce(vCode, 'en');
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_locale -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор текущего языка.
 * @param {varchar} pSession - Код сессии
 * @return {uuid} - Идентификатор языка.
 */
CREATE OR REPLACE FUNCTION current_locale (
  pSession	varchar DEFAULT current_session()
)
RETURNS		uuid
AS $$
BEGIN
  RETURN coalesce(GetSessionLocale(pSession), GetLocale(locale_code(pSession)));
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION acl ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION acl (
  pUserId       uuid,
  OUT deny      bit varying,
  OUT allow     bit varying,
  OUT mask      bit varying
) RETURNS       SETOF record
AS $$
  WITH mg AS (
      SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT bit_or(a.deny), bit_or(a.allow), bit_or(a.mask)
    FROM db.acl a INNER JOIN mg ON a.userid = mg.userid;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAccessControlListMask ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAccessControlListMask (
  pUserId	uuid DEFAULT current_userid()
) RETURNS	bit varying
AS $$
  SELECT mask FROM acl(pUserId)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckAccessControlList ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckAccessControlList (
  pMask		bit,
  pUserId	uuid DEFAULT current_userid()
) RETURNS	boolean
AS $$
BEGIN
  RETURN coalesce(GetAccessControlListMask(pUserId) & pMask = pMask, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- chmod -----------------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 * Устанавливает битовую маску доступа для пользователя.
 * @param {bit varying} pMask - Маска доступа. (d:{sLlEIDUCpducoi}a:{sLlEIDUCpducoi})
 Где: d - запрещающие биты; a - разрешающие биты:
   s - substitute user;
   L - unlock user;
   l - lock user;
   E - exclude user from group;
   I - include user to group;
   D - delete group;
   U - update group;
   C - create group;
   p - set user password;
   d - delete user;
   u - update user;
   c - create user;
   o - logout;
   i - login
 * @param {uuid} pUserId - Идентификатор пользователя/группы
 * @return {void}
*/
CREATE OR REPLACE FUNCTION chmod (
  pMask         bit varying,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       void
AS $$
DECLARE
  nSize         integer;
  bDeny         bit varying;
  bAllow        bit varying;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  nSize := bit_length(pMask) / 2;

  pMask := NULLIF(pMask, dec_to_bin(0, nSize * 2)::varbit);

  IF pMask IS NOT NULL THEN
    bDeny := coalesce(SubString(pMask FROM 1 FOR nSize), dec_to_bin(0, nSize)::varbit);
    bAllow := coalesce(SubString(pMask FROM nSize + 1 FOR nSize), dec_to_bin(0, nSize)::varbit);

	INSERT INTO db.acl SELECT pUserId, bDeny, bAllow
	  ON CONFLICT (userid) DO UPDATE SET deny = bDeny, allow = bAllow;
  ELSE
    DELETE FROM db.acl WHERE userid = pUserId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SubstituteUser -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет идентификатор текущего пользователя в активном сеансе
 * @param {uuid} pUserId - Идентификатор нового пользователя
 * @param {text} pPassword - Пароль текущего пользователя
 * @param {varchar} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SubstituteUser (
  pUserId	uuid,
  pPassword	text,
  pSession	varchar DEFAULT current_session()
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'10000000000000', session_userid(pSession)) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF CheckPassword(session_username(pSession), pPassword) THEN

    UPDATE db.session
       SET userid = pUserId, area = GetDefaultArea(pUserId), interface = GetDefaultInterface(pUserId)
     WHERE code = pSession;

    IF FOUND THEN
      PERFORM SetCurrentUserId(pUserId);
    END IF;
  ELSE
    RAISE EXCEPTION 'ERR-40300: %', GetErrorMessage();
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SubstituteUser -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет текущего пользователя в активном сеансе на указанного пользователя
 * @param {text} pRoleName - Имя пользователь для подстановки
 * @param {text} pPassword - Пароль текущего пользователя
 * @param {varchar} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SubstituteUser (
  pRoleName	text,
  pPassword	text,
  pSession	varchar DEFAULT current_session()
) RETURNS	void
AS $$
BEGIN
  PERFORM SubstituteUser(GetUser(pRoleName), pPassword, pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsUserRole ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет роль пользователя.
 * @param {uuid} pRoleId - Идентификатор роли (группы)
 * @param {uuid} pUserId - Идентификатор пользователя (учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION IsUserRole (
  pRoleId	uuid,
  pUserId	uuid DEFAULT current_userid()
) RETURNS	boolean
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT member INTO uId FROM db.member_group WHERE userid = pRoleId AND member = pUserId;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsUserRole ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет роль пользователя.
 * @param {text} pRole - Код роли (группы)
 * @param {text} pUser - Код пользователя (учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION IsUserRole (
  pRole		text,
  pUser		text DEFAULT current_username()
) RETURNS	boolean
AS $$
DECLARE
  nUserId	uuid;
  nRoleId	uuid;
BEGIN
  SELECT id INTO nUserId FROM users WHERE username = lower(pUser);
  SELECT id INTO nRoleId FROM groups WHERE username = lower(pRole);

  RETURN IsUserRole(nRoleId, nUserId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт учётную запись пользователя.
 * @param {text} pRoleName - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pName - Полное имя
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @param {uuid} pArea - Область видимости
 * @param {uuid} pId - Идентификатор
 * @return {uuid} - Id учётной записи или ошибку
 */
CREATE OR REPLACE FUNCTION CreateUser (
  pRoleName             text,
  pPassword             text,
  pName                 text,
  pPhone                text DEFAULT null,
  pEmail                text DEFAULT null,
  pDescription          text DEFAULT null,
  pPasswordChange       boolean DEFAULT true,
  pPasswordNotChange    boolean DEFAULT false,
  pArea                 uuid DEFAULT current_area(),
  pId					uuid DEFAULT gen_kernel_uuid('a')
) RETURNS               uuid
AS $$
DECLARE
  uId					uuid;
  uArea                 uuid;
  vSecret               text;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT CheckAccessControlList(B'00000000000100') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  uArea := coalesce(pArea, GetArea('guest'));

  SELECT id INTO uId FROM users WHERE username = lower(pRoleName);

  IF found THEN
    PERFORM RoleExists(pRoleName);
  END IF;

  INSERT INTO db.user (id, type, username, name, phone, email, description, passwordchange, passwordnotchange)
  VALUES (pId, 'U', pRoleName, pName, pPhone, pEmail, pDescription, pPasswordChange, pPasswordNotChange)
  RETURNING secret INTO vSecret;

  PERFORM AddMemberToInterface(pId, GetInterface('all'));
  PERFORM AddMemberToArea(pId, uArea);

  INSERT INTO db.profile (userid, area) VALUES (pId, uArea);

  IF NULLIF(pPassword, '') IS NULL THEN
    pPassword := encode(hmac(vSecret, GetSecretKey(), 'sha1'), 'hex');
  END IF;

  PERFORM SetPassword(pId, pPassword);

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт группу.
 * @param {text} pRoleName - Группа
 * @param {text} pName - Полное имя
 * @param {text} pDescription - Описание
 * @return {uuid} - Id группы или ошибку
 * @param {uuid} pId - Идентификатор
*/
CREATE OR REPLACE FUNCTION CreateGroup (
  pRoleName     text,
  pName         text,
  pDescription	text,
  pId			uuid DEFAULT gen_kernel_uuid('a')
) RETURNS	    uuid
AS $$
DECLARE
  uId			uuid;
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00000001000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO uId FROM groups WHERE username = lower(pRoleName);

  IF found THEN
    PERFORM RoleExists(pRoleName);
  END IF;

  INSERT INTO db.user (id, type, username, name, description)
  VALUES (pId, 'G', pRoleName, pName, pDescription);

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет учётную запись пользователя.
 * @param {uuid} pId - Идентификатор учетной записи пользователя
 * @param {text} pRoleName - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pName - Полное имя
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @return {void}
 */
CREATE OR REPLACE FUNCTION UpdateUser (
  pId                   uuid,
  pRoleName             text,
  pPassword             text DEFAULT null,
  pName                 text DEFAULT null,
  pPhone                text DEFAULT null,
  pEmail                text DEFAULT null,
  pDescription          text DEFAULT null,
  pPasswordChange       boolean DEFAULT null,
  pPasswordNotChange    boolean DEFAULT null
) RETURNS		        void
AS $$
DECLARE
  r			            db.user%rowtype;
BEGIN
  SELECT * INTO r FROM db.user WHERE id = pId AND type = 'U';
  IF NOT FOUND THEN
    PERFORM UserNotFound(pId);
  END IF;

  IF session_user <> 'kernel' THEN
    IF pId <> current_userid() THEN
	  IF NOT CheckAccessControlList(B'00000000001000') THEN
		PERFORM AccessDenied();
	  END IF;
    END IF;
  END IF;

  IF coalesce((SELECT true FROM pg_roles WHERE rolname = lower(r.username)), false) THEN
    IF lower(r.username) <> lower(pRoleName) THEN
      PERFORM SystemRoleError();
    END IF;
  END IF;

  pName := coalesce(NULLIF(pName, ''), r.name);
  pPhone := coalesce(NULLIF(pPhone, ''), r.phone);
  pEmail := coalesce(NULLIF(pEmail, ''), r.email);
  pDescription := coalesce(NULLIF(pDescription, ''), r.description);
  pPasswordChange := coalesce(pPasswordChange, r.passwordchange);
  pPasswordNotChange := coalesce(pPasswordNotChange, r.passwordnotchange);

  UPDATE db.user
     SET username = coalesce(pRoleName, username),
         name = coalesce(pName, username),
         phone = CheckNull(pPhone),
         email = CheckNull(pEmail),
         description = CheckNull(pDescription),
         passwordchange = pPasswordChange,
         passwordnotchange = pPasswordNotChange
   WHERE id = pId;

  IF NULLIF(pPassword, '') IS NOT NULL THEN
    PERFORM SetPassword(pId, pPassword);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет учётные данные группы.
 * @param {id} pId - Идентификатор группы
 * @param {text} pRoleName - Группа
 * @param {text} pName - Полное имя
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION UpdateGroup (
  pId           uuid,
  pRoleName     text,
  pName         text,
  pDescription  text
) RETURNS       void
AS $$
DECLARE
  r             db.user%rowtype;
BEGIN
  SELECT * INTO r FROM db.user WHERE id = pId AND type = 'G';
  IF NOT FOUND THEN
    PERFORM UserNotFound(pId);
  END IF;

  IF session_user <> 'kernel' THEN
    IF NOT CheckAccessControlList(B'00000010000000') OR r.readonly THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF coalesce((SELECT true FROM pg_roles WHERE rolname = lower(r.username)), false) THEN
    IF lower(r.username) <> lower(pRoleName) THEN
      PERFORM SystemRoleError();
    END IF;
  END IF;

  UPDATE db.user
     SET username = coalesce(pRoleName, username),
         name = coalesce(pName, name),
         description = coalesce(pDescription, description)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет учётную запись пользователя.
 * @param {id} pId - Идентификатор учётной записи пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteUser (
  pId		uuid
) RETURNS	void
AS $$
DECLARE
  vUserName	text;
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00000000010000') THEN
	  PERFORM AccessDenied();
	END IF;
  END IF;

  IF pId = current_userid() THEN
    PERFORM DeleteUserError();
  END IF;

  SELECT username INTO vUserName FROM db.user WHERE id = pId;

  IF coalesce((SELECT true FROM pg_roles WHERE rolname = lower(vUserName)), false) THEN
    PERFORM SystemRoleError();
  END IF;

  IF FOUND THEN

    UPDATE db.object SET oper = GetUser('admin') WHERE oper = pId;
    UPDATE db.object SET owner = GetUser('admin') WHERE owner = pId;

    DELETE FROM db.acl WHERE userid = pId;
    DELETE FROM db.aou WHERE userid = pId;

    DELETE FROM db.member_area WHERE member = pId;
    DELETE FROM db.member_interface WHERE member = pId;
    DELETE FROM db.member_group WHERE member = pId;
    DELETE FROM db.session WHERE userid = pId;
    DELETE FROM db.profile WHERE userid = pId;
    DELETE FROM db.user WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет учётную запись пользователя.
 * @param {text} pRoleName - Пользователь (login)
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteUser (
  pRoleName	text
) RETURNS	void
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.user WHERE type = 'U' AND username = lower(pRoleName);

  IF NOT FOUND THEN
    PERFORM UserNotFound(pRoleName);
  END IF;

  PERFORM DeleteUser(uId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу.
 * @param {id} pId - Идентификатор группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteGroup (
  pId		    uuid
) RETURNS	    void
AS $$
DECLARE
  vGroupName    text;
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00000010000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT username INTO vGroupName FROM db.user WHERE id = pId;

  IF coalesce((SELECT true FROM pg_roles WHERE rolname = lower(vGroupName)), false) THEN
    PERFORM SystemRoleError();
  END IF;

  DELETE FROM db.member_area WHERE member = pId;
  DELETE FROM db.member_interface WHERE member = pId;
  DELETE FROM db.member_group WHERE userid = pId;
  DELETE FROM db.profile WHERE userid = pId;
  DELETE FROM db.user WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу.
 * @param {text} pRoleName - Группа
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteGroup (
  pRoleName     text
) RETURNS       void
AS $$
BEGIN
  PERFORM DeleteGroup(GetGroup(pRoleName));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetUser ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор пользователя по имени пользователя.
 * @param {text} pRoleName - Пользователь
 * @return {id}
 */
CREATE OR REPLACE FUNCTION GetUser (
  pRoleName	text
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.user WHERE type = 'U' AND username = pRoleName;

  IF NOT found THEN
    PERFORM UserNotFound(pRoleName);
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetGroup --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор группы по наименованию.
 * @param {text} pRoleName - Группа
 * @return {id}
 */
CREATE OR REPLACE FUNCTION GetGroup (
  pRoleName     text
) RETURNS	    uuid
AS $$
DECLARE
  uId		    uuid;
BEGIN
  SELECT id INTO uId FROM db.user WHERE type = 'G' AND username = pRoleName;

  IF NOT found THEN
    PERFORM UnknownRoleName(pRoleName);
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetPassword -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает пароль пользователя.
 * @param {id} pId - Идентификатор пользователя
 * @param {text} pPassword - Пароль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetPassword (
  pId			    uuid,
  pPassword		    text
) RETURNS		    void
AS $$
DECLARE
  nUserId		    uuid;
  bPasswordChange	boolean;
  r			        record;
BEGIN
  nUserId := current_userid();

  IF session_user <> 'kernel' THEN
    IF pId <> nUserId THEN
      IF NOT CheckAccessControlList(B'00000000100000') THEN
        PERFORM AccessDenied();
      END IF;
    END IF;
  END IF;

  SELECT username, passwordchange, passwordnotchange INTO r FROM users WHERE id = pId;

  IF found THEN
    bPasswordChange := r.PasswordChange;

    IF pId = nUserId THEN
      IF r.PasswordNotChange THEN
        PERFORM UserPasswordChange();
      END IF;

      IF r.PasswordChange THEN
        bPasswordChange := false;
      END IF;
    END IF;

    UPDATE db.user
       SET passwordchange = bPasswordChange,
           pswhash = crypt(pPassword, gen_salt('md5'))
     WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ChangePassword --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет пароль пользователя.
 * @param {uuid} pId - Идентификатор учетной записи
 * @param {text} pOldPass - Старый пароль
 * @param {text} pNewPass - Новый пароль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION ChangePassword (
  pId		uuid,
  pOldPass	text,
  pNewPass	text
) RETURNS	boolean
AS $$
DECLARE
  r		record;
BEGIN
  SELECT username, system INTO r FROM users WHERE id = pId;

  IF found THEN
    IF CheckPassword(r.username, pOldPass) THEN

      PERFORM SetPassword(pId, pNewPass);

      IF r.system THEN
        EXECUTE 'ALTER ROLE ' || r.username || ' WITH PASSWORD ' || quote_literal(pNewPass);
      END IF;

      RETURN true;
    END IF;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- UserLock --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Блокирует учётную запись пользователя.
 * @param {id} pId - Идентификатор учётной записи пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION UserLock (
  pId		uuid
) RETURNS	void
AS $$
DECLARE
  uId		uuid;
BEGIN
  IF session_user <> 'kernel' THEN
    IF pId <> current_userid() THEN
	  IF NOT CheckAccessControlList(B'00100000000000') THEN
		PERFORM AccessDenied();
	  END IF;
    END IF;
  END IF;

  SELECT id INTO uId FROM users WHERE id = pId;

  IF found THEN
    UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 1, 1), lock_date = now() WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UserUnLock ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Снимает блокировку с учётной записи пользователя.
 * @param {id} pId - Идентификатор учётной записи пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION UserUnLock (
  pId		uuid
) RETURNS	void
AS $$
DECLARE
  uId		uuid;
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'01000000000000') THEN
	  PERFORM AccessDenied();
	END IF;
  END IF;

  SELECT id INTO uId FROM users WHERE id = pId;

  IF found THEN
    UPDATE db.user SET status = B'0001', lock_date = null, expiry_date = null WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToGroup ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет пользователя в группу.
 * @param {uuid} pMember - Идентификатор пользователя
 * @param {uuid} pGroup - Идентификатор группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION AddMemberToGroup (
  pMember	uuid,
  pGroup	uuid
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00001000000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.member_group (userid, member) VALUES (pGroup, pMember) ON CONFLICT (userid, member) DO NOTHING;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteGroupForMember --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу для пользователя.
 * @param {uuid} pMember - Идентификатор пользователя
 * @param {uuid} pGroup - Идентификатор группы, при null удаляет все группы для указанного пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteGroupForMember (
  pMember	uuid,
  pGroup	uuid DEFAULT null
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00010000000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_group WHERE userid = coalesce(pGroup, userid) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromGroup -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из группу.
 * @param {uuid} pGroup - Идентификатор группы
 * @param {uuid} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанной группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteMemberFromGroup (
  pGroup	uuid,
  pMember	uuid DEFAULT null
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00010000000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_group WHERE userid = pGroup AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetUserName -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetUserName (
  pId		uuid
) RETURNS	text
AS $$
DECLARE
  vUserName	text;
BEGIN
  SELECT username INTO vUserName FROM db.user WHERE id = pId AND type = 'U';
  RETURN vUserName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetGroupName ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetGroupName (
  pId			uuid
) RETURNS		text
AS $$
DECLARE
  vGroupName	text;
BEGIN
  SELECT username INTO vGroupName FROM db.user WHERE id = pId AND type = 'G';
  RETURN vGroupName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateScope -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateScope (
  pCode		    text,
  pName		    text,
  pDescription	text DEFAULT null,
  pId			uuid DEFAULT gen_kernel_uuid('8')
) RETURNS 	    uuid
AS $$
DECLARE
  uId		    uuid;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO uId FROM db.scope WHERE code = pCode;
  IF FOUND THEN
    PERFORM RecordExists(pCode);
  END IF;

  INSERT INTO db.scope (id, code, name, description)
  VALUES (pId, pCode, pName, pDescription) RETURNING Id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditScope -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditScope (
  pId			    uuid,
  pCode			    text DEFAULT null,
  pName			    text DEFAULT null,
  pDescription		text DEFAULT null
) RETURNS void
AS $$
DECLARE
  vCode             text;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT code INTO vCode FROM db.scope WHERE id = pId;
  IF NOT FOUND THEN
    PERFORM AreaError();
  END IF;

  pCode := coalesce(pCode, vCode);
  IF pCode <> vCode THEN
    SELECT code INTO vCode FROM db.scope WHERE code = pCode;
    IF FOUND THEN
      PERFORM RecordExists(pCode);
    END IF;
  END IF;

  UPDATE db.scope
	 SET code = coalesce(pCode, code),
		 name = coalesce(pName, name),
		 description = CheckNull(coalesce(pDescription, description, '<null>'))
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteScope -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteScope (
  pId			uuid
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO uId FROM db.scope WHERE id = pId;
  IF NOT FOUND THEN
    PERFORM AreaError();
  END IF;

  DELETE FROM db.scope WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetScope --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetScope (
  pCode		text
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.scope WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetScopeName ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetScopeName (
  pId		uuid
) RETURNS	text
AS $$
DECLARE
  vName		text;
BEGIN
  SELECT name INTO vName FROM db.scope WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateArea ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateArea (
  pParent	    uuid,
  pType		    uuid,
  pScope	    uuid,
  pCode		    text,
  pName		    text,
  pDescription	text DEFAULT null,
  pId			uuid DEFAULT gen_kernel_uuid('8')
) RETURNS 	    uuid
AS $$
DECLARE
  uId		    uuid;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO uId FROM db.area WHERE code = pCode;
  IF FOUND THEN
    PERFORM RecordExists(pCode);
  END IF;

  INSERT INTO db.area (id, parent, type, scope, code, name, description)
  VALUES (pId, coalesce(pParent, GetArea('root')), pType, pScope, pCode, pName, pDescription) RETURNING Id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditArea --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditArea (
  pId			    uuid,
  pParent		    uuid DEFAULT null,
  pType			    uuid DEFAULT null,
  pScope		    uuid DEFAULT null,
  pCode			    text DEFAULT null,
  pName			    text DEFAULT null,
  pDescription		text DEFAULT null,
  pValidFromDate	timestamp DEFAULT null,
  pValidToDate		timestamp DEFAULT null
) RETURNS void
AS $$
DECLARE
  vCode             text;
  nType             uuid;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT type, code INTO nType, vCode FROM db.area WHERE id = pId;
  IF NOT FOUND THEN
    PERFORM AreaError();
  END IF;

  pCode := coalesce(pCode, vCode);
  IF pCode <> vCode THEN
    SELECT code INTO vCode FROM db.area WHERE code = pCode;
    IF FOUND THEN
      PERFORM RecordExists(pCode);
    END IF;
  END IF;

  UPDATE db.area
	 SET parent = coalesce(pParent, parent),
		 type = coalesce(pType, type),
	     scope = coalesce(pScope, scope),
		 code = coalesce(pCode, code),
		 name = coalesce(pName, name),
		 description = CheckNull(coalesce(pDescription, description, '<null>')),
		 validFromDate = coalesce(pValidFromDate, validFromDate),
		 validToDate = coalesce(pValidToDate, validToDate)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteArea ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteArea (
  pId			uuid
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO uId FROM db.area WHERE id = pId;
  IF NOT FOUND THEN
    PERFORM AreaError();
  END IF;

  DELETE FROM db.area WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetArea ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetArea (
  pCode		text
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.area WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaCode -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAreaCode (
  pId		uuid
) RETURNS	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.area WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaName -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAreaName (
  pId		uuid
) RETURNS	text
AS $$
DECLARE
  vName		text;
BEGIN
  SELECT name INTO vName FROM db.area WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToArea -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMemberToArea (
  pMember	uuid,
  pArea		uuid
) RETURNS   void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00001000000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.member_area (area, member) VALUES (pArea, pMember) ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteAreaForMember ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет подразделение для пользователя.
 * @param {id} pMember - Идентификатор пользователя
 * @param {id} pArea - Идентификатор подразделения, при null удаляет все подразделения для указанного пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteAreaForMember (
  pMember	uuid,
  pArea		uuid DEFAULT null
) RETURNS   void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00010000000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_area WHERE area = coalesce(pArea, area) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromArea --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из подразделения.
 * @param {id} pArea - Идентификатор подразделения
 * @param {id} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанного подразделения
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteMemberFromArea (
  pArea		uuid,
  pMember	uuid DEFAULT null
) RETURNS   void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00010000000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_area WHERE area = pArea AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetArea ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetArea (
  pArea	        uuid,
  pMember	    uuid DEFAULT current_userid(),
  pSession	    varchar DEFAULT current_session()
) RETURNS	    void
AS $$
DECLARE
  vUserName     text;
  vDepName      text;
BEGIN
  vDepName := GetAreaName(pArea);
  IF vDepName IS NULL THEN
    PERFORM AreaError();
  END IF;

  vUserName := GetUserName(pMember);
  IF vDepName IS NULL THEN
    PERFORM UserNotFound(pMember);
  END IF;

  IF NOT IsMemberArea(pArea, pMember) THEN
    PERFORM UserNotMemberArea(vUserName, vDepName);
  END IF;

  UPDATE db.session SET area = pArea WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsMemberArea ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет доступ к зоне.
 * @param {uuid} pArea - Идентификатор зоны
 * @param {uuid} pMember - Идентификатор роли (группы/учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION IsMemberArea (
  pArea		uuid,
  pMember   uuid DEFAULT current_userid()
) RETURNS	boolean
AS $$
DECLARE
  nCount    bigint;
BEGIN
  IF pArea IS NULL OR pMember IS NULL THEN
    RETURN false;
  END IF;

  WITH RECURSIVE area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE id = pArea
     UNION ALL
    SELECT a.id, a.parent
      FROM db.area a, area_tree t
     WHERE a.id = t.parent
  ) SELECT count(m.member) INTO nCount
      FROM db.member_area m INNER JOIN area_tree a ON m.area = a.id
       AND member IN (
         SELECT pMember
          UNION ALL
         SELECT userid FROM db.member_group WHERE member = pMember
       );

  RETURN coalesce(nCount, 0) <> 0;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetDefaultArea --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDefaultArea (
  pArea	    uuid DEFAULT current_area(),
  pMember	uuid DEFAULT current_userid()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.profile SET area = pArea WHERE userid = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultArea --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDefaultArea (
  pMember   uuid DEFAULT current_userid()
) RETURNS	uuid
AS $$
DECLARE
  uArea	    uuid;
BEGIN
  SELECT area INTO uArea FROM db.profile WHERE userid = pMember;
  RETURN uArea;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateInterface (
  pCode		    text,
  pName		    text,
  pDescription	text,
  pId		    uuid DEFAULT gen_kernel_uuid('8')
) RETURNS 	    uuid
AS $$
DECLARE
  uId		    uuid;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.interface (id, code, name, description)
  VALUES (pId, pCode, pName, pDescription) RETURNING Id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UpdateInterface (
  pId		    uuid,
  pCode		    text DEFAULT null,
  pName		    text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS 	    void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  UPDATE db.interface
     SET code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = CheckNull(coalesce(pDescription, description, '<null>'))
   WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteInterface (
  pId		uuid
) RETURNS 	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.interface WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToInterface --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMemberToInterface (
  pMember       uuid,
  pInterface    uuid
) RETURNS       void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00001000000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.member_interface (interface, member) VALUES (pInterface, pMember) ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteInterfaceForMember ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteInterfaceForMember (
  pMember	    uuid,
  pInterface	uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00010000000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_interface WHERE interface = coalesce(pInterface, interface) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromInterface ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteMemberFromInterface (
  pInterface	uuid,
  pMember	    uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00010000000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_interface WHERE interface = pInterface AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInterface ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetInterface (
  pCode		text
) RETURNS 	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.interface WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInterfaceName ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetInterfaceName (
  pId		uuid
) RETURNS 	text
AS $$
DECLARE
  vName		text;
BEGIN
  SELECT name INTO vName FROM db.interface WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetInterface ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetInterface (
  pInterface	uuid,
  pMember	    uuid DEFAULT current_userid(),
  pSession	    varchar DEFAULT current_session()
) RETURNS	    void
AS $$
DECLARE
  vUserName     text;
  vInterface    text;
BEGIN
  vInterface := GetInterfaceName(pInterface);
  IF vInterface IS NULL THEN
    PERFORM InterfaceError();
  END IF;

  vUserName := GetUserName(pMember);
  IF vUserName IS NULL THEN
    PERFORM UserNotFound(pMember);
  END IF;

  IF NOT IsMemberInterface(pInterface, pMember) THEN
    PERFORM UserNotMemberInterface(vUserName, vInterface);
  END IF;

  UPDATE db.session SET interface = pInterface WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsMemberInterface -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет доступ к интерфейсу.
 * @param {uuid} pInterface - Идентификатор интерфейса
 * @param {uuid} pMember - Идентификатор роли (группы/учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION IsMemberInterface (
  pInterface    uuid,
  pMember       uuid DEFAULT current_userid()
) RETURNS       boolean
AS $$
DECLARE
  nCount        bigint;
BEGIN
  IF pInterface IS NULL OR pMember IS NULL THEN
    RETURN false;
  END IF;

  SELECT count(member) INTO nCount
    FROM db.member_interface
   WHERE interface = pInterface
     AND member IN (
       SELECT pMember
        UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );

  RETURN coalesce(nCount, 0) <> 0;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetDefaultInterface ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDefaultInterface (
  pInterface	uuid DEFAULT current_interface(),
  pMember	    uuid DEFAULT current_userid()
) RETURNS	    void
AS $$
BEGIN
  UPDATE db.profile SET interface = pInterface WHERE userid = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultInterface ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDefaultInterface (
  pMember	    uuid DEFAULT current_userid()
) RETURNS	    uuid
AS $$
DECLARE
  uInterface	uuid;
BEGIN
  SELECT interface INTO uInterface FROM db.profile WHERE userid = pMember;
  RETURN uInterface;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckOffline ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckOffline (
  pOffTime	INTERVAL DEFAULT '5 minute'
) RETURNS	void
AS $$
BEGIN
  UPDATE db.profile
     SET state = B'000'
   WHERE state <> B'000'
     AND userid IN (
       SELECT userid FROM db.session
        WHERE userid <> (SELECT id FROM db.user WHERE username = session_user)
          AND updated < now() - pOffTime
     );
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AUTHENTICATE ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CheckPassword ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckPassword (
  pUserId	uuid,
  pPassword	text
) RETURNS 	boolean
AS $$
DECLARE
  passed 	boolean;
BEGIN
  SELECT (pswhash = crypt(pPassword, pswhash)) INTO passed
    FROM db.user
   WHERE id = pUserId;

  IF found THEN
    IF passed THEN
      PERFORM SetErrorMessage('Успешно.');
    ELSE
      PERFORM SetErrorMessage('Пароль не прошёл проверку.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Пользователь не найден.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckPassword ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckPassword (
  pRoleName	text,
  pPassword	text
) RETURNS 	boolean
AS $$
BEGIN
  RETURN CheckPassword(GetUser(pRoleName), pPassword);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ValidSession ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ValidSession (
  pSession	    varchar DEFAULT current_session()
) RETURNS 	    boolean
AS $$
DECLARE
  passed 	    boolean;
BEGIN
  SELECT (pwkey = crypt(StrPwKey(suid, secret, created), pwkey)) INTO passed
    FROM db.session
   WHERE code = pSession;

  IF found THEN
    IF coalesce(passed, false) THEN
      PERFORM SetErrorMessage('Успешно.');
    ELSE
      PERFORM SetErrorMessage('Код сессии не прошёл проверку.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Код сессии не найден.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ValidSecret -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ValidSecret (
  pSecret       text,
  pSession	    varchar DEFAULT current_session()
) RETURNS 	    boolean
AS $$
DECLARE
  passed 	    boolean;
BEGIN
  SELECT (pSecret = secret) INTO passed
    FROM db.session
   WHERE code = pSession;

  IF found THEN
    IF coalesce(passed, false) THEN
      PERFORM SetErrorMessage('Успешно.');
    ELSE
      PERFORM SetErrorMessage('Секретный код сессии не прошёл проверку.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Код сессии не найден.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SessionIn ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему по ключу сессии.
 * @param {varchar} pSession - Сессия
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @param {text} pSalt - Случайное значение соли для ключа аутентификации
 * @return {text} - Код авторизации. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION SessionIn (
  pSession      varchar,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pSalt         text DEFAULT null
)
RETURNS         text
AS $$
DECLARE
  up	        db.user%rowtype;

  nUserId       uuid DEFAULT null;

  nToken        bigint DEFAULT null;
  nOAuth2		bigint DEFAULT null;

  nAudience		integer DEFAULT null;
BEGIN
  IF ValidSession(pSession) THEN

	SELECT oauth2, userid INTO nOAuth2, nUserId
	  FROM db.session
	 WHERE code = pSession;

	SELECT * INTO up FROM db.user WHERE id = nUserId;

	IF NOT found THEN
	  PERFORM LoginError();
	END IF;

	IF get_bit(up.status, 1) = 1 THEN
	  PERFORM UserLockError();
	END IF;

	IF up.lock_date IS NOT NULL AND up.lock_date <= now() THEN
	  PERFORM UserLockError();
	END IF;

	IF get_bit(up.status, 0) = 1 THEN
	  PERFORM PasswordExpired();
	END IF;

	IF up.expiry_date IS NOT NULL AND up.expiry_date <= now() THEN
	  PERFORM PasswordExpired();
	END IF;

	IF NOT CheckIPTable(up.id, pHost) THEN
	  PERFORM LoginIPTableError(pHost);
	END IF;

	SELECT audience INTO nAudience FROM db.oauth2 WHERE id = nOAuth2;

	PERFORM SetCurrentSession(pSession);
	PERFORM SetCurrentUserId(up.id);
	PERFORM SetOAuth2ClientId(GetAudienceCode(nAudience));

	UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 2, 1) WHERE id = up.id;

	UPDATE db.profile
	   SET input_last = now(),
		   lc_ip = coalesce(pHost, lc_ip)
	 WHERE userid = up.id;

	UPDATE db.session
	   SET updated = localtimestamp,
		   agent = coalesce(pAgent, agent),
		   host = coalesce(pHost, host),
		   salt = coalesce(pSalt, salt)
	 WHERE code = pSession
    RETURNING token INTO nToken;

    RETURN GetToken(nToken);
  END IF;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Login -----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему по паре имя пользователя и пароль.
 * @param {bigint} pOAuth2 - Параметры авторизации через OAuth 2.0
 * @param {text} pRoleName - Пользователь (login)
 * @param {text} pPassword - Пароль
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {text} - Сессия. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION Login (
  pOAuth2       bigint,
  pRoleName     text,
  pPassword     text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       text
AS $$
DECLARE
  up            db.user%rowtype;
  nAudience		integer DEFAULT null;
  vSession      text DEFAULT null;
BEGIN
  IF NULLIF(pRoleName, '') IS NULL THEN
    PERFORM LoginError();
  END IF;

  IF NULLIF(pPassword, '') IS NULL THEN
    PERFORM LoginError();
  END IF;

  SELECT * INTO up FROM db.user WHERE type = 'U' AND username = pRoleName;

  IF NOT found THEN
    PERFORM LoginError();
  END IF;

  IF NOT CheckAccessControlList(B'00000000000001', up.id) THEN
    PERFORM AccessDenied();
  END IF;

  IF get_bit(up.status, 1) = 1 THEN
    PERFORM UserLockError();
  END IF;

  IF up.lock_date IS NOT NULL AND up.lock_date >= now() THEN
    PERFORM UserTempLockError(up.lock_date);
  END IF;

  IF get_bit(up.status, 0) = 1 THEN
    PERFORM PasswordExpired();
  END IF;

  IF up.expiry_date IS NOT NULL AND up.expiry_date <= now() THEN
    PERFORM PasswordExpired();
  END IF;

  IF NOT CheckIPTable(up.id, pHost) THEN
    PERFORM LoginIPTableError(pHost);
  END IF;

  IF CheckPassword(pRoleName, pPassword) THEN

    PERFORM CheckSessionLimit(up.id);

    INSERT INTO db.session (oauth2, userid, agent, host)
    VALUES (pOAuth2, up.id, pAgent, pHost)
    RETURNING code INTO vSession;

    IF vSession IS NULL THEN
      PERFORM AccessDenied();
    END IF;

    SELECT audience INTO nAudience FROM db.oauth2 WHERE id = pOAuth2;

    PERFORM SetCurrentSession(vSession);
    PERFORM SetCurrentUserId(up.id);
    PERFORM SetOAuth2ClientId(GetAudienceCode(nAudience));

    UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 2, 1), lock_date = null WHERE id = up.id;

    UPDATE db.profile
       SET input_error = 0,
           input_count = input_count + 1,
           input_last = now(),
           lc_ip = pHost
     WHERE userid = up.id;

  ELSE

    PERFORM SetCurrentSession(null);
    PERFORM SetCurrentUserId(null);
    PERFORM SetOAuth2ClientId(null);

    PERFORM LoginError();

  END IF;

  INSERT INTO db.log (type, code, username, session, event, text)
  VALUES ('M', 1100, pRoleName, vSession, 'login', 'Вход в систему.');

  RETURN vSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SignIn ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Вход в систему по имени и паролю пользователя.
 * @param {bigint} pOAuth2 - Параметры авторизации через OAuth 2.0
 * @param {text} pRoleName - Пользователь (login)
 * @param {text} pPassword - Пароль
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {text} - Сессия. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION SignIn (
  pOAuth2       bigint,
  pRoleName     text,
  pPassword     text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       text
AS $$
DECLARE
  up            db.user%rowtype;

  nInputError   integer;

  message       text;
BEGIN
  PERFORM SetErrorMessage('Успешно.');

  BEGIN
    RETURN Login(pOAuth2, pRoleName, pPassword, pAgent, pHost);
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;

    PERFORM SetErrorMessage(message);

    PERFORM SetCurrentSession(null);
    PERFORM SetCurrentUserId(null);
    PERFORM SetOAuth2ClientId(null);

    SELECT * INTO up FROM db.user WHERE type = 'U' AND username = pRoleName;

    IF found THEN
      UPDATE db.profile
         SET input_error = input_error + 1,
             input_error_last = now(),
             input_error_all = input_error_all + 1
       WHERE userid = up.id;

      SELECT input_error INTO nInputError FROM db.profile WHERE userid = up.id;

      IF found THEN
        IF nInputError >= 5 THEN
          UPDATE db.user SET lock_date = Now() + INTERVAL '1 min' WHERE id = up.id;
        END IF;
      END IF;

      INSERT INTO db.log (type, code, username, event, text)
      VALUES ('E', 3100, pRoleName, 'login', message);
    END IF;

    RETURN null;
  END;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SessionOut ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выход из системы по ключу сессии.
 * @param {varchar} pSession - Сессия
 * @param {boolean} pCloseAll - Закрыть все сессии
 * @param {text} pMessage - Сообщение
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SessionOut (
  pSession      varchar,
  pCloseAll     boolean,
  pMessage      text DEFAULT null
) RETURNS 	    boolean
AS $$
DECLARE
  nUserId	    uuid;
  nCount	    integer;

  message	    text;
BEGIN
  IF ValidSession(pSession) THEN

    message := 'Выход из системы';

    SELECT userid INTO nUserId FROM db.session WHERE code = pSession;

	IF NOT CheckAccessControlList(B'00000000000010', nUserId) THEN
	  PERFORM AccessDenied();
	END IF;

    IF pCloseAll THEN
      DELETE FROM db.session WHERE userid = nUserId;
      message := message || ' (с закрытием всех активных сессий)';
    ELSE
      DELETE FROM db.session WHERE code = pSession;
    END IF;

    SELECT count(code) INTO nCount FROM db.session WHERE userid = nUserId;

    IF nCount = 0 THEN
      UPDATE db.user SET status = set_bit(set_bit(status, 3, 1), 2, 0) WHERE id = nUserId;
    END IF;

    UPDATE db.profile SET state = B'000' WHERE userid = nUserId;

    message := message || coalesce('. ' || pMessage, '.');

    INSERT INTO db.log (type, code, username, session, event, text)
    VALUES ('M', 1100, GetUserName(nUserId), pSession, 'logout', message);

    PERFORM SetErrorMessage(message);

    PERFORM SetCurrentSession(null);
    PERFORM SetCurrentUserId(null);
    PERFORM SetOAuth2ClientId(null);

    RETURN true;
  END IF;

  RAISE EXCEPTION 'ERR-40000: %', GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SignOut ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выход из системы по ключу сессии.
 * @param {varchar} pSession - Сессия
 * @param {boolean} pCloseAll - Закрыть все сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SignOut (
  pSession      varchar DEFAULT current_session(),
  pCloseAll     boolean DEFAULT false
) RETURNS       boolean
AS $$
DECLARE
  nUserId       uuid;
  message       text;
BEGIN
  RETURN SessionOut(pSession, pCloseAll);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;

  PERFORM SetCurrentSession(null);
  PERFORM SetCurrentUserId(null);
  PERFORM SetOAuth2ClientId(null);

  PERFORM SetErrorMessage(message);

  IF pSession IS NOT NULL THEN
	SELECT userid INTO nUserId FROM db.session WHERE code = pSession;

	IF found THEN
	  INSERT INTO db.log (type, code, username, session, event, text)
	  VALUES ('E', 3100, GetUserName(nUserId), pSession, 'logout', 'Выход из системы. ' || message);
	END IF;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION Authenticate -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Аутентификация.
 * @param {varchar} pSession - Сессия
 * @param {text} pSecret - Секретный код
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {text} - Новый код аутентификации. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION Authenticate (
  pSession      varchar,
  pSecret       text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
)
RETURNS         text
AS $$
DECLARE
  vCode         text;
BEGIN
  IF ValidSecret(pSecret, pSession) THEN
    vCode := SessionIn(pSession, pAgent, pHost, gen_salt('md5'));
  ELSE
    PERFORM SessionOut(pSession, false, GetErrorMessage());
  END IF;

  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION Authorize ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Авторизовать.
 * @param {varchar} pSession - Сессия
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {boolean} Если вернёт false вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION Authorize (
  pSession      varchar,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
)
RETURNS         boolean
AS $$
BEGIN
  RETURN SessionIn(pSession, pAgent, pHost) IS NOT NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetSession ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSession (
  pUserId       uuid,
  pOAuth2       bigint DEFAULT CreateSystemOAuth2(),
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pNew          bool DEFAULT false
) RETURNS       text
AS $$
DECLARE
  up            db.user%rowtype;
  uSUID         uuid;
  nAudience		integer;
  vSession      text;
BEGIN
  IF session_user <> 'kernel' THEN
    uSUID := coalesce(session_userid(), GetUser(session_user));
	IF NOT CheckAccessControlList(B'10000000000001', uSUID) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT * INTO up FROM db.user WHERE id = pUserId;

  IF NOT found THEN
    PERFORM LoginError();
  END IF;

  IF get_bit(up.status, 1) = 1 THEN
    PERFORM UserLockError();
  END IF;

  IF up.lock_date IS NOT NULL AND up.lock_date <= now() THEN
    PERFORM UserLockError();
  END IF;

  IF get_bit(up.status, 0) = 1 THEN
    PERFORM PasswordExpired();
  END IF;

  IF up.expiry_date IS NOT NULL AND up.expiry_date <= now() THEN
    PERFORM PasswordExpired();
  END IF;

  IF NOT CheckIPTable(up.id, pHost) THEN
    PERFORM LoginIPTableError(pHost);
  END IF;

  SELECT code INTO vSession FROM db.session WHERE userid = up.id;

  IF NOT FOUND OR pNew THEN
    INSERT INTO db.session (oauth2, suid, userid, agent, host)
    VALUES (pOAuth2, uSUID, up.id, pAgent, pHost)
    RETURNING code INTO vSession;
  END IF;

  SELECT audience INTO nAudience FROM db.oauth2 WHERE id = pOAuth2;

  PERFORM SetCurrentSession(vSession);
  PERFORM SetCurrentUserId(up.id);
  PERFORM SetOAuth2ClientId(GetAudienceCode(nAudience));

  RETURN vSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
