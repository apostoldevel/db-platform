--------------------------------------------------------------------------------
-- DAEMON API ------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- daemon.identifier -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверить идентификатор пользователя.
 * @param {text} pValue - Идентификатор пользователя (Логин или адрес электронной почты)
 * @return {json}
 */
CREATE OR REPLACE FUNCTION daemon.identifier (
  pValue        text
) RETURNS       json
AS $$
DECLARE
  r             record;
  profile       record;
  nId           numeric;
  arResult      text[];
BEGIN
  FOR r IN
    SELECT id, 'username' AS identifier FROM db.user WHERE username = pValue AND type = 'U'
    UNION
    SELECT id, 'email' AS identifier FROM db.user WHERE email = pValue AND type = 'U'
    UNION
    SELECT id, 'phone' AS identifier FROM db.user WHERE phone = pValue AND type = 'U'
  LOOP
    nId := r.id;
    arResult := array_append(arResult, r.identifier);
  END LOOP;

  SELECT * INTO profile FROM users WHERE id = nId;

  RETURN json_build_object('id', nId, 'username', profile.username, 'name', profile.name, 'email', profile.email, 'phone', profile.phone, 'status', profile.status, 'identifiers', array_to_json(arResult));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.authorize ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Авторизоваться по коду сессии.
 * @param {text} pSession - Сессия
 * @return {record}
 */
CREATE OR REPLACE FUNCTION daemon.authorize (
  pSession      text
) RETURNS       json
AS $$
DECLARE
  t             record;

  nToken        numeric;

  expires_in    double precision;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  IF NOT kernel.Authorize(pSession) THEN
    PERFORM AuthenticateError(GetErrorMessage());
  END IF;

  SELECT t.id INTO nToken
    FROM db.token_header h INNER JOIN db.token t ON h.id = t.header AND t.type = 'A'
   WHERE h.session = pSession
     AND t.validFromDate <= Now()
     AND t.validToDate > Now();

  IF NOT FOUND THEN
    PERFORM SessionOut(pSession, false, 'Маркер не найден.');
    RAISE EXCEPTION '%', GetErrorMessage();
  END IF;

  SELECT * INTO t FROM db.token WHERE id = nToken;

  expires_in := trunc(extract(EPOCH FROM t.validToDate)) - trunc(extract(EPOCH FROM Now()));

  RETURN json_build_object('access_token', t.token, 'token_type', 'Bearer', 'expires_in', expires_in, 'session', pSession);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  RAISE NOTICE '%', vContext;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
  RETURN json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.signin ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Вход в систему по маркеру JWT (Из внешних систем).
 * @param {text} pToken - JWT
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.signin (
  pToken        text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  payload       jsonb;

  token         record;
  claim         record;
  google        record;
  signup        record;

  account       db.user%rowtype;
  profile       db.profile%rowtype;
  session       text;

  nUserId       numeric;
  nProvider     numeric;
  nAudience     numeric;
  nApplication  numeric;

  jName         jsonb;

  vSecret       text;
  vCode         text;

  iss           text;
  aud           text;

  vSession      text;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  SELECT convert_from(url_decode(r[2]), 'utf8')::jsonb INTO payload FROM regexp_split_to_array(pToken, '\.') r;

  iss := coalesce(payload->>'iss', 'null');
  aud := payload->>'aud';

  SELECT i.provider INTO nProvider FROM oauth2.issuer i WHERE i.code = iss;

  IF NOT found THEN
    PERFORM IssuerNotFound(iss);
  END IF;

  SELECT a.id, a.secret, a.application INTO nAudience, vSecret, nApplication FROM oauth2.audience a WHERE a.provider = nProvider AND a.code = aud;

  IF NOT found THEN
    PERFORM AudienceNotFound();
  END IF;

  SELECT * INTO token FROM verify(pToken, vSecret);

  IF NOT coalesce(token.valid, false) THEN
    PERFORM TokenError();
  END IF;

  FOR claim IN SELECT * FROM json_to_record(token.payload) AS x(iss text, aud text, sub text, exp double precision, nbf double precision, iat double precision, jti text)
  LOOP
    IF claim.exp <= trunc(extract(EPOCH FROM Now())) THEN
      PERFORM TokenExpired();
    END IF;

    vSession := SignIn(CreateOAuth2(nAudience, ARRAY['api']), claim.aud, vSecret, pAgent, pHost);

    IF vSession IS NULL THEN
      RAISE EXCEPTION '%', GetErrorMessage();
    END IF;

    account.username := claim.sub;

    SELECT p.code INTO vCode FROM oauth2.provider p WHERE p.id = nProvider;

    IF vCode = 'google' THEN
      FOR google IN SELECT * FROM json_to_record(token.payload) AS x(email text, email_verified bool, name text, given_name text, family_name text, locale text, picture text)
      LOOP
        account.name := google.name;
        account.email := google.email;

        profile.locale := GetLocale(google.locale);
        profile.given_name := google.given_name;
        profile.family_name := google.family_name;
        profile.email_verified := google.email_verified;
        profile.picture := google.picture;
      END LOOP;
    END IF;

    SELECT a.userid INTO nUserId FROM db.auth a WHERE a.audience = nAudience AND a.code = account.username;

    IF NOT FOUND THEN
      jName := jsonb_build_object('name', account.name, 'first', profile.given_name, 'last', profile.family_name);

      SELECT * INTO signup FROM api.signup(null, account.username, null, jName, account.phone, account.email, token.payload::jsonb);

      nUserId := signup.userid;

      INSERT INTO db.auth (userId, audience, code) VALUES (nUserId, nAudience, account.username);

      UPDATE db.profile p
         SET locale = coalesce(profile.locale, p.locale),
             given_name = coalesce(profile.given_name, p.given_name),
             family_name = coalesce(profile.family_name, p.family_name),
             email_verified = coalesce(profile.email_verified, p.email_verified),
             picture = coalesce(profile.picture, p.picture)
       WHERE p.userid = nUserId;
    END IF;

    SELECT id INTO nAudience FROM oauth2.audience WHERE provider = GetProvider('default') AND application = nApplication;

    session := GetSession(nUserId, CreateOAuth2(nAudience, ARRAY['api']), pAgent, pHost, true);

    IF session IS NULL THEN
      RAISE EXCEPTION '%', GetErrorMessage();
    END IF;

    RETURN NEXT CreateToken(nAudience, oauth2_current_code(session));
  END LOOP;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  RAISE NOTICE '%', vContext;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
  RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.token ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет код авторизации на маркер.
 * @param {text} pClientId - Клиент OAuth 2.0 (oauth2.audience.code)
 * @param {text} pSecret - Секрет (oauth2.audience.secret)
 * @param {text} pPayload - Полезные данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
* @return {json}
 */
CREATE OR REPLACE FUNCTION daemon.token (
  pClientId     text,
  pSecret       text,
  pPayload      jsonb,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       json
AS $$
DECLARE
  result        jsonb;

  nAudience     numeric;
  nOauth2       numeric;

  grant_type    text;
  response_type text;
  access_type   text;
  redirect_uri  text;
  refresh_token text;
  auth_code     text;
  scope         text;
  state         text;

  assertion             text;
  subject_token         text;
  subject_token_type    text;

  vType         char;

  vUsername     text;
  vPassword     text;

  vSession      text;
  VSecret       text;

  vRedirectURI  text;

  arResponses   text[];

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;

  passed        boolean;
BEGIN
  SELECT a.id INTO nAudience FROM oauth2.audience a WHERE a.code = pClientId;

  IF NOT found THEN
    RETURN json_build_object('error', json_build_object('code', 401, 'error', 'invalid_client', 'message', 'The OAuth 2.0 client was not found.'));
  END IF;

  SELECT (hash = crypt(pSecret, hash)) INTO passed
    FROM oauth2.audience
   WHERE id = nAudience;

  IF NOT coalesce(passed, false) THEN
    RETURN json_build_object('error', json_build_object('code', 401, 'error', 'unauthorized_client', 'message', 'The client is not authorized.'));
  END IF;

  access_type := coalesce(pPayload->>'access_type', 'online');

  grant_type := pPayload->>'grant_type';

  IF grant_type IS NULL THEN
    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'unsupported_grant_type', 'message', 'Missing parameter: grant_type'));
  END IF;

  PERFORM SafeSetVar('client_id', pClientId);

  IF grant_type = 'authorization_code' THEN

    auth_code := pPayload->>'code';

    IF auth_code IS NULL THEN
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'Missing parameter: code'));
    END IF;

    redirect_uri := pPayload->>'redirect_uri';

    IF redirect_uri IS NULL THEN
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'Missing parameter: redirect_uri'));
    END IF;

    SELECT h.oauth2 INTO nOauth2
      FROM db.token_header h INNER JOIN db.token t ON h.id = t.header AND t.type = 'C'
     WHERE t.hash = GetTokenHash(auth_code, GetSecretKey())
       AND t.validFromDate <= Now()
       AND t.validtoDate > Now();

    IF NOT FOUND THEN
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_grant', 'message', 'Malformed auth code.'));
    END IF;

    SELECT a.redirect_uri INTO vRedirectURI FROM db.oauth2 a WHERE id = nOauth2;

    IF NOT FOUND THEN
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'The OAuth 2.0 params was not found.'));
    END IF;

    IF vRedirectURI != redirect_uri THEN
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_grant', 'message', 'Redirect URI mismatch.'));
    END IF;

    RETURN CreateToken(nAudience, auth_code);

  ELSIF grant_type = 'refresh_token' THEN

    refresh_token := pPayload->>'refresh_token';

    IF refresh_token IS NULL THEN
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'Missing parameter: refresh_token'));
    END IF;

    RETURN UpdateToken(nAudience, refresh_token);

  ELSIF grant_type = 'password' THEN

    vSecret := pPayload->>'secret';

    IF vSecret IS NOT NULL THEN
      SELECT username, encode(hmac(secret::text, GetSecretKey(), 'sha1'), 'hex') INTO vUsername, vPassword
        FROM db.user
       WHERE hash = encode(digest(vSecret, 'sha1'), 'hex');
    ELSE
      vUsername := pPayload->>'username';
      vPassword := pPayload->>'password';
    END IF;

    response_type := pPayload->>'response_type';
    redirect_uri := pPayload->>'redirect_uri';

    scope := pPayload->>'scope';
    state := pPayload->>'state';

    arResponses := string_to_array(coalesce(response_type, 'token'), ' ');

    nOAuth2 := CreateOAuth2(nAudience, ScopeToArray(scope), access_type, redirect_uri, state);

    vSession := SignIn(nOAuth2, vUsername, vPassword, pAgent, pHost);

    IF vSession IS NULL THEN
      SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(GetErrorMessage());
      RETURN json_build_object('error', json_build_object('code', 403, 'error', 'access_denied', 'message', ErrorMessage));
    END IF;

    auth_code := oauth2_current_code(vSession);

    result := '{}'::jsonb;

    IF arResponses && ARRAY['code'] THEN
      result := result || jsonb_build_object('session', vSession, 'secret', session_secret(vSession), 'code', auth_code);
    END IF;

    IF arResponses && ARRAY['token'] THEN
      result := result || CreateToken(nAudience, auth_code);
    END IF;

    IF state IS NOT NULL THEN
      result := result || jsonb_build_object('state', state);
    END IF;

    RETURN result;

  ELSIF grant_type = 'client_credentials' THEN

    nOAuth2 := CreateOAuth2(nAudience, ARRAY['api'], 'offline');

    vSession := SignIn(nOAuth2, pClientId, pSecret, pAgent, pHost);

    IF vSession IS NULL THEN
      RETURN json_build_object('error', json_build_object('code', 401, 'error', 'unauthorized_client', 'message', 'The client is not authorized.'));
    END IF;

    RETURN CreateToken(nAudience, oauth2_current_code(vSession), INTERVAL '1 day');

  ELSIF grant_type = 'urn:ietf:params:oauth:grant-type:token-exchange' THEN

    subject_token := pPayload->>'subject_token';
    subject_token_type := coalesce(pPayload->>'subject_token_type', 'urn:ietf:params:oauth:token-type:jwt');

    CASE subject_token_type
    WHEN 'urn:ietf:params:oauth:token-type:jwt' THEN
      vType := 'A';
    WHEN 'urn:ietf:params:oauth:token-type:access_token' THEN
      vType := 'A';
    WHEN 'urn:ietf:params:oauth:token-type:refresh_token' THEN
      vType := 'R';
    WHEN 'urn:ietf:params:oauth:token-type:id_token' THEN
      vType := 'I';
    ELSE
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'unsupported_token_type', 'message', format('Invalid parameter "subject_token_type": %s.', subject_token_type)));
    END CASE;

    RETURN ExchangeToken(nAudience, subject_token, INTERVAL '1 hour', vType);

  ELSIF grant_type = 'urn:ietf:params:oauth:grant-type:jwt-bearer' THEN

    assertion := pPayload->>'assertion';

    RETURN daemon.signin(assertion, pAgent, pHost);

  ELSE
    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'unsupported_grant_type', 'message', format('Invalid parameter "grant_type": %s.', grant_type)));
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  RAISE NOTICE '%', vContext;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
  RETURN json_build_object('error', json_build_object('code', 500, 'error', 'server_error', 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.unauthorized_fetch ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Неавторизованный запрос данных в формате REST JSON API.
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.unauthorized_fetch (
  pPath         text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  nApiId        numeric;
  dtBegin       timestamptz;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  pPath := lower(pPath);

  PERFORM SetCurrentSession(null);
  PERFORM SetCurrentUserId(null);

  IF pPath = '/sign/in' OR pPath = '/authenticate' THEN
    pPayload := pPayload - 'agent';
    pPayload := pPayload - 'host';
    pPayload := pPayload || jsonb_build_object('agent', pAgent, 'host', pHost);
  END IF;

  nApiId := AddApiLog(pPath, pPayload);

  BEGIN
    dtBegin := clock_timestamp();

    FOR r IN SELECT * FROM rest.api(pPath, pPayload)
    LOOP
      RETURN NEXT r.api;
    END LOOP;

    UPDATE api.log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

    RAISE NOTICE '%', vContext;

    PERFORM SetErrorMessage(vMessage);

    SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
    RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

    IF current_session() IS NOT NULL THEN
      UPDATE api.log SET eventid = AddEventLog('E', ErrorCode, ErrorMessage) WHERE id = nApiId;
    END IF;
  END;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  RAISE NOTICE '%', vContext;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
  RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.authorized_fetch -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Авторизованный запрос данных в формате REST JSON API с аутентификацией по имени пользователя и паролю.
 * @param {text} pUsername - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.authorized_fetch (
  pUsername     text,
  pPassword     text,
  pPath         text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  nApiId        numeric;
  dtBegin       timestamptz;

  vSession      text;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  pPath := lower(pPath);

  IF pPath = '/sign/in' OR pPath = '/authenticate' THEN
    pPayload := pPayload - 'agent';
    pPayload := pPayload - 'host';
    pPayload := pPayload || jsonb_build_object('agent', pAgent, 'host', pHost);
  END IF;

  vSession := SignIn(CreateSystemOAuth2(), pUsername, pPassword, pAgent, pHost);

  nApiId := AddApiLog(pPath, pPayload);

  BEGIN
    dtBegin := clock_timestamp();

    FOR r IN SELECT * FROM rest.api(pPath, pPayload)
    LOOP
      RETURN NEXT r.api;
    END LOOP;

    UPDATE api.log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

    RAISE NOTICE '%', vContext;

    PERFORM SetErrorMessage(vMessage);

    SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
    RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

    IF current_session() IS NOT NULL THEN
      UPDATE api.log SET eventid = AddEventLog('E', ErrorCode, ErrorMessage) WHERE id = nApiId;
    END IF;
  END;

  PERFORM SessionOut(vSession, false);

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  RAISE NOTICE '%', vContext;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
  RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.session_fetch --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Авторизованный запрос данных в формате REST JSON API с аутентификацией по сессии и секретному коду.
 * @param {text} pSession - Сессия
 * @param {text} pSecret - Секрет
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.session_fetch (
  pSession      text,
  pSecret       text,
  pPath         text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  nApiId        numeric;
  dtBegin       timestamptz;

  vCode         text;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  pPath := lower(pPath);

  IF pPath = '/sign/in' OR pPath = '/authenticate' THEN
    pPayload := pPayload - 'agent';
    pPayload := pPayload - 'host';
    pPayload := pPayload || jsonb_build_object('agent', pAgent, 'host', pHost);
  END IF;

  nApiId := AddApiLog(pPath, pPayload);

  BEGIN
    vCode := Authenticate(pSession, pSecret, pAgent, pHost);

    IF vCode IS NULL THEN
      PERFORM AuthenticateError(GetErrorMessage());
    END IF;

    dtBegin := clock_timestamp();

    FOR r IN SELECT * FROM rest.api(pPath, pPayload)
    LOOP
      RETURN NEXT r.api;
    END LOOP;

    UPDATE api.log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

    RAISE NOTICE '%', vContext;

    PERFORM SetErrorMessage(vMessage);

    SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
    RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

    IF current_session() IS NOT NULL THEN
      UPDATE api.log SET eventid = AddEventLog('E', ErrorCode, ErrorMessage) WHERE id = nApiId;
    END IF;
  END;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  RAISE NOTICE '%', vContext;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
  RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.fetch ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Авторизованный запрос данных в формате REST JSON API.
 * @param {text} pToken - Маркер JWT
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.fetch (
  pToken        text,
  pPath         text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;
  token         record;

  payload       jsonb;

  nApiId        numeric;

  dtBegin       timestamptz;

  vSecret       text;

  iss           text;
  aud           text;
  sub           text;

  nOauth2       numeric;
  nProvider     numeric;
  nAudience     numeric;

  belong        boolean;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  pPath := lower(pPath);

  IF pPath = '/sign/in' OR pPath = '/authenticate' THEN
    pPayload := pPayload - 'agent';
    pPayload := pPayload - 'host';
    pPayload := pPayload || jsonb_build_object('agent', pAgent, 'host', pHost);
  END IF;

  nApiId := AddApiLog(pPath, pPayload);

  BEGIN
    SELECT convert_from(url_decode(data[2]), 'utf8')::jsonb INTO payload FROM regexp_split_to_array(pToken, '\.') data;

    iss := payload->>'iss';

    SELECT i.provider INTO nProvider FROM oauth2.issuer i WHERE i.code = iss;

    IF NOT found THEN
      PERFORM IssuerNotFound(coalesce(iss, 'null'));
    END IF;

    aud := payload->>'aud';

    SELECT a.id, a.secret INTO nAudience, vSecret FROM oauth2.audience a WHERE a.provider = nProvider AND a.code = aud;

    IF NOT found THEN
      PERFORM AudienceNotFound();
    END IF;

    SELECT * INTO token FROM verify(pToken, vSecret);

    IF NOT coalesce(token.valid, false) THEN
      PERFORM TokenError();
    END IF;

    SELECT h.oauth2 INTO nOauth2
      FROM db.token_header h INNER JOIN db.token t ON h.id = t.header
     WHERE t.hash = GetTokenHash(pToken, GetSecretKey())
       AND t.validFromDate <= Now()
       AND t.validtoDate > Now();

    IF NOT FOUND THEN
      PERFORM TokenExpired();
    END IF;

    SELECT (audience = nAudience) INTO belong FROM db.oauth2 WHERE id = nOauth2;

    IF NOT coalesce(belong, false) THEN
      PERFORM TokenBelong();
    END IF;

    sub := payload->>'sub';

    IF SessionIn(sub, pAgent, pHost) IS NULL THEN
      PERFORM AuthenticateError(GetErrorMessage());
    END IF;

    dtBegin := clock_timestamp();

    FOR r IN SELECT * FROM rest.api(pPath, pPayload)
    LOOP
      RETURN NEXT r.api;
    END LOOP;

    UPDATE api.log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

    RAISE NOTICE '%', vContext;

    PERFORM SetErrorMessage(vMessage);

    SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
    RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

    IF current_session() IS NOT NULL THEN
      UPDATE api.log SET eventid = AddEventLog('E', ErrorCode, ErrorMessage) WHERE id = nApiId;
    END IF;
  END;

  RETURN;
EXCEPTION
WHEN others THEN
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  RAISE NOTICE '%', vContext;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
  RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.signed_fetch ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API с проверкой подписи методом HMAC-SHA256.
 * @param {text} pPath - Путь
 * @param {json} pJson - Данные в JSON
 * @param {text} pSession - Сессия
 * @param {double precision} pNonce - Время в миллисекундах
 * @param {text} pSignature - Подпись
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @param {interval} pTimeWindow - Временное окно
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.signed_fetch (
  pPath         text,
  pJson         json DEFAULT null,
  pSession      text DEFAULT null,
  pNonce        double precision DEFAULT null,
  pSignature    text DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pTimeWindow   INTERVAL DEFAULT '5 sec'
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  Payload       jsonb;

  nApiId        numeric;

  dtBegin       timestamptz;
  dtTimeStamp   timestamptz;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;

  passed        boolean;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  pPath := lower(pPath);
  pJson := NULLIF(pJson::text, '{}');

  Payload := pJson::jsonb;

  IF pTimeWindow > INTERVAL '1 min' THEN
    pTimeWindow := INTERVAL '1 min';
  END IF;

  IF pPath = '/sign/in' OR pPath = '/authenticate' THEN
    Payload := Payload - 'agent';
    Payload := Payload - 'host';
    Payload := Payload || jsonb_build_object('agent', pAgent, 'host', pHost);
  END IF;

  nApiId := AddApiLog(pPath, Payload, pNonce, pSignature);

  BEGIN
    dtTimeStamp := coalesce(to_timestamp(pNonce / 1000000), Now());

    IF (dtTimeStamp < (Now() + INTERVAL '5 sec') AND (Now() - dtTimeStamp) <= pTimeWindow) THEN

      SELECT (pSignature = GetSignature(pPath, pNonce, pJson, secret)) INTO passed
        FROM db.session
       WHERE code = pSession;

      IF NOT coalesce(passed, false) THEN
        PERFORM SignatureError();
      END IF;

      IF SessionIn(pSession, pAgent, pHost) IS NULL THEN
        PERFORM AuthenticateError(GetErrorMessage());
      END IF;

      dtBegin := clock_timestamp();

      FOR r IN SELECT * FROM rest.api(pPath, Payload)
      LOOP
        RETURN NEXT r.api;
      END LOOP;

      UPDATE api.log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;
    ELSE
      PERFORM NonceExpired();
    END IF;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

    RAISE NOTICE '%', vContext;

    PERFORM SetErrorMessage(vMessage);

    SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
    RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

    IF current_session() IS NOT NULL THEN
      UPDATE api.log SET eventid = AddEventLog('E', ErrorCode, ErrorMessage) WHERE id = nApiId;
    END IF;
  END;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  RAISE NOTICE '%', vContext;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);
  RETURN NEXT json_build_object('error', json_build_object('code', ErrorCode, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
