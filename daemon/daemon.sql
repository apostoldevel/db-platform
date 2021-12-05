--------------------------------------------------------------------------------
-- DAEMON API ------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- daemon.validation -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет маркет доступа.
 * @param {text} pToken - Маркер JWT
 * @return {bool}
 */
CREATE OR REPLACE FUNCTION daemon.validation (
  pToken        text
) RETURNS       jsonb
AS $$
DECLARE
  token         record;

  payload       jsonb;

  vSecret       text;

  iss           text;
  aud           text;

  nOauth2       bigint;
  nProvider     integer;
  nAudience     integer;

  belong        boolean;
BEGIN
  SELECT convert_from(url_decode(data[2]), 'utf8')::jsonb INTO payload FROM regexp_split_to_array(pToken, '\.') data;

  iss := payload->>'iss';

  SELECT i.provider INTO nProvider FROM oauth2.issuer i WHERE i.code = iss;

  IF NOT FOUND THEN
	PERFORM IssuerNotFound(coalesce(iss, 'null'));
  END IF;

  aud := payload->>'aud';

  SELECT a.id, a.secret INTO nAudience, vSecret FROM oauth2.audience a WHERE a.provider = nProvider AND a.code = aud;

  IF NOT FOUND THEN
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

  RETURN payload;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.identifier -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверить идентификатор пользователя.
 * @param {text} pToken - Маркер JWT
 * @param {text} pValue - Идентификатор пользователя (Логин или адрес электронной почты)
 * @return {json}
 */
CREATE OR REPLACE FUNCTION daemon.identifier (
  pToken        text,
  pValue        text
) RETURNS       json
AS $$
DECLARE
  r             record;
  profile       record;
  uId           uuid;
  arResult      text[];

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  PERFORM daemon.validation(pToken);

  FOR r IN
    SELECT id, 'username' AS identifier FROM db.user WHERE username = pValue AND type = 'U'
    UNION
    SELECT id, 'email' AS identifier FROM db.user WHERE email = pValue AND type = 'U'
    UNION
    SELECT id, 'phone' AS identifier FROM db.user WHERE phone = pValue AND type = 'U'
  LOOP
    uId := r.id;
    arResult := array_append(arResult, r.identifier);
  END LOOP;

  SELECT username, name, email, phone, status,
         CASE
         WHEN status & B'1100' = B'1100' THEN 'expired & locked'
         WHEN status & B'1000' = B'1000' THEN 'expired'
         WHEN status & B'0100' = B'0100' THEN 'locked'
         WHEN status & B'0010' = B'0010' THEN 'active'
         WHEN status & B'0001' = B'0001' THEN 'open'
         ELSE 'undefined'
         END AS status_text
  INTO profile FROM db.user WHERE id = uId AND type = 'U';

  RETURN json_build_object('id', uId, 'username', profile.username, 'name', profile.name, 'email', profile.email, 'phone', profile.phone, 'status', profile.status::int, 'status_text', profile.status_text, 'identifiers', array_to_json(arResult));
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.observer -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные наблюдателя.
 * @param {text} pPublisher - Издатель
 * @param {varchar} pSession - Сессия
 * @param {text} pIdentity -  Идентификатор в рамках сессии
 * @param {json} pData - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json}
 */
CREATE OR REPLACE FUNCTION daemon.observer (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text,
  pData			jsonb,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  uUserId       uuid;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  SELECT userId INTo uUserId FROM db.session WHERE code = pSession;

  IF NOT FOUND OR current_userid() IS DISTINCT FROM uUserId THEN -- Обход блокировки
	IF SessionIn(pSession, pAgent, pHost) IS NULL THEN
	  PERFORM AuthenticateError(GetErrorMessage());
	END IF;
  END IF;

  FOR r IN SELECT * FROM EventListener(pPublisher, pSession, pIdentity, pData) AS data
  LOOP
	RETURN NEXT r.data;
  END LOOP;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.init_listen ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Инициализация слушателей.
 * @return {void}
 */
CREATE OR REPLACE FUNCTION daemon.init_listen (
) RETURNS       SETOF json
AS $$
DECLARE
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  PERFORM InitListen();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.login ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Вход в систему по маркеру JWT (Из внешних систем).
 * @param {text} pToken - JWT
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @param {text} pScope - Область видимости
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.login (
  pToken        text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pScope        text DEFAULT null
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

  uUserId       uuid;
  uScope        uuid;

  nProvider     integer;
  nAudience     integer;
  nApplication  integer;

  jName         jsonb;

  vProviderType char;
  vProviderCode text;

  iss           text;
  aud           text;

  vSecret       text;
  vSession      text;
  vOAuthSession text;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  SELECT convert_from(url_decode(r[2]), 'utf8')::jsonb INTO payload FROM regexp_split_to_array(pToken, '\.') r;

  iss := coalesce(payload->>'iss', 'null');
  aud := payload->>'aud';

  SELECT i.provider INTO nProvider FROM oauth2.issuer i WHERE i.code = iss;

  IF NOT FOUND THEN
    PERFORM IssuerNotFound(iss);
  END IF;

  SELECT a.id, a.application, a.secret INTO nAudience, nApplication, vSecret FROM oauth2.audience a WHERE a.provider = nProvider AND a.code = aud;

  IF NOT FOUND THEN
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

    vOAuthSession := SignIn(CreateOAuth2(nAudience, pScope), claim.aud, vSecret, pAgent, pHost);

    IF vOAuthSession IS NULL THEN
      RAISE EXCEPTION '%', GetErrorMessage();
    END IF;

    SELECT p.type, p.code INTO vProviderType, vProviderCode FROM oauth2.provider p WHERE p.id = nProvider;

    IF vProviderType = 'E' THEN

      uScope := current_scope();

      account.username := claim.sub;

      IF vProviderCode = 'google' THEN
        FOR google IN SELECT * FROM json_to_record(token.payload) AS x(email text, email_verified bool, name text, given_name text, family_name text, locale text, picture text)
        LOOP
          account.name := google.name;
          account.email := google.email;

          profile.scope := uScope;
          profile.locale := GetLocale(google.locale);
          profile.area := GetAreaGuest(uScope);
          profile.interface := '00000000-0000-4004-a000-000000000003'::uuid;
          profile.given_name := google.given_name;
          profile.family_name := google.family_name;
          profile.email_verified := google.email_verified;
          profile.picture := google.picture;
        END LOOP;
      END IF;

      SELECT a.userid INTO uUserId FROM db.auth a WHERE a.audience = nAudience AND a.code = account.username;

      IF NOT FOUND THEN
        jName := jsonb_build_object('name', account.name, 'first', profile.given_name, 'last', profile.family_name);

        SELECT * INTO signup FROM api.signup(null, account.username, null, jName, account.phone, account.email, row_to_json(profile)::jsonb);

        uUserId := signup.userid;

        INSERT INTO db.auth (userId, audience, code) VALUES (uUserId, nAudience, account.username);
      END IF;

      PERFORM FROM db.profile WHERE userid = uUserId AND scope = uScope;

      IF NOT FOUND THEN
        PERFORM CreateProfile(uUserId, uScope, profile.family_name, profile.given_name, null, profile.locale, profile.area, profile.interface, profile.email_verified, profile.phone_verified, profile.picture);
      END IF;

      SELECT id INTO nAudience FROM oauth2.audience WHERE provider = GetProvider('default') AND application = nApplication;

      vSession := GetSession(uUserId, CreateOAuth2(nAudience, pScope), pAgent, pHost, false, false);

      IF vSession IS NULL THEN
        RAISE EXCEPTION '%', GetErrorMessage();
      END IF;

      PERFORM SignOut(vOAuthSession);

      RETURN NEXT CreateToken(nAudience, oauth2_current_code(vSession));
    ELSE
      RETURN NEXT CreateToken(nAudience, oauth2_current_code(vOAuthSession));
    END IF;
  END LOOP;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.authorize ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Авторизоваться по коду сессии.
 * @param {varchar} pSession - Сессия
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {record}
 */
CREATE OR REPLACE FUNCTION daemon.authorize (
  pSession      varchar,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       json
AS $$
DECLARE
  t             record;

  nToken        bigint;

  expires_in    double precision;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  IF SessionIn(pSession, pAgent, pHost) IS NULL THEN
    PERFORM AuthenticateError(GetErrorMessage());
  END IF;

  SELECT t.id INTO nToken
    FROM db.token_header h INNER JOIN db.token t ON h.id = t.header AND t.type = 'A'
   WHERE h.session = pSession
     AND t.validFromDate <= Now()
     AND t.validToDate > Now();

  IF NOT FOUND THEN
    PERFORM SessionOut(pSession, false, 'Маркер не найден или истек срок его действия.');
    RAISE EXCEPTION '%', GetErrorMessage();
  END IF;

  SELECT * INTO t FROM db.token WHERE id = nToken;

  expires_in := trunc(extract(EPOCH FROM t.validToDate)) - trunc(extract(EPOCH FROM Now()));

  RETURN json_build_object('access_token', t.token, 'token_type', 'Bearer', 'expires_in', expires_in, 'session', pSession);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));
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
  pClientId             text,
  pSecret               text,
  pPayload              jsonb,
  pAgent                text DEFAULT null,
  pHost                 inet DEFAULT null
) RETURNS               json
AS $$
DECLARE
  result                jsonb;

  nAudience             integer;
  nOauth2               bigint;

  grant_type            text;
  response_type         text;
  access_type           text;
  redirect_uri          text;
  refresh_token         text;
  auth_code             text;
  scope                 text;
  state                 text;

  assertion             text;
  subject_token         text;
  subject_token_type    text;

  vType                 char;

  vUsername             text;
  vPassword             text;

  vSession              text;
  VSecret               text;

  vRedirectURI          text;

  arResponses           text[];

  vMessage              text;
  vContext              text;

  ErrorCode             int;
  ErrorMessage          text;

  passed                boolean;
BEGIN
  grant_type := pPayload->>'grant_type';

  IF grant_type IS NULL THEN
    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'unsupported_grant_type', 'message', 'Missing parameter: grant_type'));
  END IF;

  IF grant_type = 'urn:ietf:params:oauth:grant-type:jwt-bearer' THEN
    assertion := pPayload->>'assertion';
    scope := pPayload->>'scope';
    RETURN daemon.login(assertion, pAgent, pHost, scope);
  END IF;

  SELECT a.id INTO nAudience FROM oauth2.audience a WHERE a.code = pClientId;

  IF NOT FOUND THEN
    RETURN json_build_object('error', json_build_object('code', 401, 'error', 'invalid_client', 'message', 'The OAuth 2.0 client was not FOUND.'));
  END IF;

  SELECT (hash = crypt(pSecret, hash)) INTO passed
    FROM oauth2.audience
   WHERE id = nAudience;

  IF NOT coalesce(passed, false) THEN
    RETURN json_build_object('error', json_build_object('code', 401, 'error', 'unauthorized_client', 'message', 'The client is not authorized.'));
  END IF;

  PERFORM SetOAuth2ClientId(pClientId);

  access_type := coalesce(pPayload->>'access_type', 'online');

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
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'The OAuth 2.0 params was not FOUND.'));
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

    nOAuth2 := CreateOAuth2(nAudience, scope, access_type, redirect_uri, state);

    vSession := SignIn(nOAuth2, vUsername, vPassword, pAgent, pHost);

    IF vSession IS NULL THEN
      SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(GetErrorMessage());
      PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
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

    scope := pPayload->>'scope';

    nOAuth2 := CreateOAuth2(nAudience, scope, 'offline');

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

  ELSE
    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'unsupported_grant_type', 'message', format('Invalid parameter "grant_type": %s.', grant_type)));
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', 'server_error', 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.session_open ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Открывает сесиию.
 * @param {text} pToken - Маркер JWT
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF jsonb}
 */
CREATE OR REPLACE FUNCTION daemon.session_open (
  pToken        text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  token         jsonb;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  token := daemon.validation(pToken);

  IF SessionIn(token->>'sub', pAgent, pHost) IS NULL THEN
	PERFORM AuthenticateError(GetErrorMessage());
  END IF;

  RETURN NEXT token;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.session_close --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Закрывает сесиию.
 * @param {text} pToken - Маркер JWT
 * @param {boolean} pCloseAll - Закрыть все сессии
 * @param {text} pMessage - Сообщение
 * @return {SETOF jsonb}
 */
CREATE OR REPLACE FUNCTION daemon.session_close (
  pToken        text,
  pCloseAll		boolean DEFAULT false,
  pMessage		text DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  token         jsonb;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  token := daemon.validation(pToken);

  PERFORM SessionOut(token->>'sub', pCloseAll, pMessage);

  RETURN NEXT token;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.unauthorized_fetch ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Неавторизованный запрос данных в формате REST JSON API.
 * @param {text} pMethod - HTTP-Метод
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.unauthorized_fetch (
  pMethod		text,
  pPath         text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

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
  PERFORM SetOAuth2ClientId(null);

  IF pPath = '/sign/in' OR pPath = '/authenticate' THEN
    pPayload := pPayload - 'agent';
    pPayload := pPayload - 'host';
    pPayload := pPayload || jsonb_build_object('agent', pAgent, 'host', pHost);
  END IF;

  FOR r IN SELECT * FROM api.run(pMethod, pPath, pPayload)
  LOOP
	RETURN NEXT r.run;
  END LOOP;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

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
 * @param {text} pMethod - HTTP-Метод
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.authorized_fetch (
  pUsername     text,
  pPassword     text,
  pMethod		text,
  pPath         text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

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

  FOR r IN SELECT * FROM api.run(pMethod, pPath, pPayload)
  LOOP
	RETURN NEXT r.run;
  END LOOP;

  PERFORM SessionOut(vSession, false);

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

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
 * @param {varchar} pSession - Сессия
 * @param {text} pSecret - Секрет
 * @param {text} pMethod - HTTP-Метод
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.session_fetch (
  pSession      varchar,
  pSecret       text,
  pMethod		text,
  pPath         text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

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

  vCode := Authenticate(pSession, pSecret, pAgent, pHost);

  IF vCode IS NULL THEN
	PERFORM AuthenticateError(GetErrorMessage());
  END IF;

  FOR r IN SELECT * FROM api.run(pMethod, pPath, pPayload)
  LOOP
	RETURN NEXT r.run;
  END LOOP;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

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
 * @param {text} pMethod - HTTP-Метод
 * @param {text} pPath - Путь
 * @param {json} pJson - Данные в JSON
 * @param {varchar} pSession - Сессия
 * @param {double precision} pNonce - Время в миллисекундах
 * @param {text} pSignature - Подпись
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @param {interval} pTimeWindow - Временное окно
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.signed_fetch (
  pMethod		text,
  pPath         text,
  pJson         json DEFAULT null,
  pSession      varchar DEFAULT null,
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

	FOR r IN SELECT * FROM api.run(pMethod, pPath, Payload)
	LOOP
	  RETURN NEXT r.run;
	END LOOP;
  ELSE
	PERFORM NonceExpired();
  END IF;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

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
 * @param {text} pMethod - HTTP-Метод
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.fetch (
  pToken        text,
  pMethod		text,
  pPath         text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  token         jsonb;

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

  token := daemon.validation(pToken);

  IF SessionIn(token->>'sub', pAgent, pHost) IS NULL THEN
	PERFORM AuthenticateError(GetErrorMessage());
  END IF;

  FOR r IN SELECT * FROM api.run(pMethod, pPath, pPayload)
  LOOP
	RETURN NEXT r.run;
  END LOOP;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
