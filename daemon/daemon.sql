--------------------------------------------------------------------------------
-- DAEMON API ------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- daemon.validation -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validate a JWT access token and return its claims.
 * @param {text} pToken - JWT access token
 * @return {jsonb} - Token claims on success, or error object on failure
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.validation (
  pToken        text
) RETURNS       jsonb
AS $$
DECLARE
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
  vErrorId      text;
BEGIN
  RETURN TokenValidation(pToken);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.refresh_token --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Refresh an expired JWT access token using a refresh token.
 * @param {text} pToken - Current JWT access token
 * @param {text} pRefresh - Refresh token for obtaining a new access token
 * @return {json} - New token pair on success, or error object on failure
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.refresh_token (
  pToken        text,
  pRefresh      text
) RETURNS       json
AS $$
DECLARE
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
  vErrorId      text;
BEGIN
  RETURN RefreshToken(pToken, pRefresh);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.identifier -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a user by username, email, or phone and return their profile summary.
 * @param {text} pToken - JWT access token for authorization
 * @param {text} pValue - User identifier (username, email, or phone number)
 * @return {json} - User profile with matched identifiers, or error object on failure
 * @since 1.0.0
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
  vErrorId      text;
BEGIN
  PERFORM TokenValidation(pToken);

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

  SELECT username INTO profile FROM db.user WHERE id = uId AND type = 'U';

  RETURN json_build_object('id', uId, 'username', profile.username, 'identifiers', array_to_json(arResult));
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.observer -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Process an observer (event listener) request within a session context.
 * @param {text} pPublisher - Event publisher channel name
 * @param {varchar} pSession - Session code for authentication
 * @param {text} pIdentity - Client-side identity within the session (e.g. WebSocket connection ID)
 * @param {jsonb} pData - Event payload
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {SETOF json} - Event listener response data
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.observer (
  pPublisher    text,
  pSession      varchar,
  pIdentity     text,
  pData         jsonb,
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
  vErrorId      text;
BEGIN
  SELECT userId INTO uUserId FROM db.session WHERE code = pSession;

  IF NOT FOUND OR current_userid() IS DISTINCT FROM uUserId THEN
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

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.init_listen ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Initialize PostgreSQL LISTEN channels for the C++ daemon process.
 * @return {SETOF json} - Error object on failure, empty on success
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.init_listen (
) RETURNS       SETOF json
AS $$
DECLARE
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
  vErrorId      text;
BEGIN
  PERFORM InitListen();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.login ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sign in using an external JWT token, creating a local session.
 *
 * The token must be signed with the secret of the audience it names, so a
 * foreign provider's token reaches this only after the caller has verified it
 * and re-signed the payload -- which is also where the token is proved to have
 * been issued to us, and not to some other client of the same provider.
 *
 * Claim names are read through oauth2.provider_claim. A provider with no rule
 * there is read by the OpenID Connect names, which is right for every provider
 * that follows the specification.
 *
 * An existing account is reached by e-mail address only where the provider
 * confirmed the address -- through its own email_verified claim, or through
 * oauth2.provider_claim.email_trusted for a provider that sends none. Where the
 * address is taken but unconfirmed, the account is created without it.
 *
 * @param {text} pToken - External JWT access token
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @param {text} pScope - Scope code to sign into
 * @return {SETOF json} - Token pair on success, or error object on failure
 * @since 1.0.0
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
  signup        record;

  account       db.user%rowtype;
  profile       db.profile%rowtype;

  uUserId       uuid;
  uScope        uuid;

  nProvider     integer;
  nAudience     integer;
  nApplication  integer;

  jName         jsonb;

  jPayload      jsonb;
  jClaims       jsonb;

  bEmailTrusted boolean;

  vEmailVerified text;
  vLocale       text;

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
  vErrorId      text;
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

      -- Claim names come from oauth2.provider_claim. A provider with no rule is
      -- read by the OpenID Connect names: they are right for everyone who
      -- follows the specification -- Google among them, which is why the rule
      -- table can stay empty and its fields are still read -- and wrong only
      -- where a provider invented its own, which is when a rule is written.
      jPayload := token.payload::jsonb;

      SELECT c.claims, c.email_trusted INTO jClaims, bEmailTrusted
        FROM oauth2.provider_claim c WHERE c.provider = nProvider;

      jClaims := coalesce(jClaims, '{}'::jsonb);

      account.email := jPayload->>coalesce(jClaims->>'email', 'email');
      account.name  := jPayload->>coalesce(jClaims->>'name', 'name');

      profile.given_name  := jPayload->>coalesce(jClaims->>'given_name', 'given_name');
      profile.family_name := jPayload->>coalesce(jClaims->>'family_name', 'family_name');
      profile.picture     := jPayload->>coalesce(jClaims->>'picture', 'picture');

      -- Read without a cast. With one provider the claim was always a JSON
      -- boolean; with any provider it is whatever that provider sends, and
      -- 'verified'::boolean raises -- landing in the handler at the bottom as a
      -- 500 on a login that should simply have treated the address as
      -- unconfirmed.
      --
      -- Absent and unreadable are answered differently, and the difference
      -- matters: this value is the only thing standing between a token and an
      -- account that already holds the same address. No claim at all is what
      -- the provider-level flag is for -- Yandex sends none, and without the
      -- flag its users could never reach an account they already own. A claim
      -- that is there but says something unrecognised is not a confirmation of
      -- anything, and the flag does not get to override it.
      vEmailVerified := lower(jPayload->>coalesce(jClaims->>'email_verified', 'email_verified'));

      IF vEmailVerified IS NULL THEN
        profile.email_verified := coalesce(bEmailTrusted, false);
      ELSE
        profile.email_verified := vEmailVerified IN ('true', 't', '1', 'yes', 'on');
      END IF;

      -- Locale arrives as `ru`, as `ru-RU`, or not at all. GetLocale answers
      -- NULL to a code it does not know, which would leave the profile without
      -- one -- so fall back to the scope's.
      vLocale := jPayload->>coalesce(jClaims->>'locale', 'locale');

      profile.scope     := uScope;
      profile.locale    := coalesce(GetLocale(vLocale), current_locale());
      profile.area      := GetAreaGuest(uScope);
      profile.interface := '00000000-0000-4004-a000-000000000003'::uuid;

      -- Account name: the local part of the address, or -- with no address --
      -- the provider's identifier for the user. The second reads badly, but
      -- inventing a name for a person is not the system's to do.
      IF account.email IS NOT NULL AND strpos(account.email, '@') > 1 THEN
        account.username := substr(account.email, 1, strpos(account.email, '@') - 1);
      ELSE
        account.username := claim.sub;
      END IF;

      account.name := coalesce(
        account.name,
        nullif(trim(concat_ws(' ', profile.family_name, profile.given_name)), ''),
        account.username
      );

      SELECT a.userid INTO uUserId FROM db.auth a WHERE a.audience = nAudience AND a.code = claim.sub;

      IF NOT FOUND THEN
        -- Linking to an existing account by address happens only where the
        -- provider CONFIRMED that address. Without this, a token carrying
        -- somebody else's unconfirmed address takes over the local account that
        -- holds it -- the whole point of the check, and the reason it is the
        -- only gate to the SELECT below.
        IF profile.email_verified THEN
          SELECT id INTO uUserId FROM db.user WHERE email = account.email;
        END IF;

        -- Tested on uUserId rather than FOUND: the SELECT above is conditional,
        -- and would leave FOUND from whatever ran before it.
        IF uUserId IS NULL THEN
          -- An unconfirmed address is not stored either. Checking only the
          -- address arriving now would be half the invariant: an unconfirmed
          -- address written to db.user becomes, from that moment, a row that
          -- the confirmed branch above links to. Someone signing up through a
          -- provider we do not trust with addresses could claim anyone's, wait,
          -- and collect them when the owner arrives through a provider we do
          -- trust. db.user has nowhere to record that an address was never
          -- confirmed -- email_verified lives on db.profile, per scope -- so
          -- the address is simply not written.
          --
          -- Which also covers the constraint: db.user(email) is unique, and a
          -- confirmed address that is already taken was linked above rather
          -- than reaching this point.
          --
          -- The person gets in, and attaches the address later by signing in as
          -- its owner. That last part is policy rather than invariant -- a
          -- deployment would be within its rights to refuse the login outright
          -- instead, and the place for that switch is a column on
          -- oauth2.provider_claim. Not built until something needs it.
          IF NOT profile.email_verified THEN
            account.email := null;
          END IF;

          -- db.user(type, username) is unique too, and the local part of an
          -- address is a poor unique key across providers: alice@one and
          -- alice@two are both "alice". With one provider this took two
          -- accounts under the same domain rules to hit; with two it is
          -- ordinary, and api.signup would raise on the second -- leaving that
          -- person unable to sign in at all, ever. The provider's own
          -- identifier is unique within the provider, so fall back to it.
          IF EXISTS (SELECT FROM db.user WHERE type = 'U' AND username = account.username) THEN
            account.username := vProviderCode || '-' || claim.sub;
          END IF;

          jName := jsonb_build_object('name', account.name, 'first', profile.given_name, 'last', profile.family_name);

          SELECT * INTO signup FROM api.signup(null, account.username, null, jName, account.phone, account.email, jsonb_build_object('provider', vProviderCode) || row_to_json(profile)::jsonb);

          uUserId := signup.userid;
        END IF;

        INSERT INTO db.auth (userId, audience, code) VALUES (uUserId, nAudience, claim.sub);
      END IF;

      PERFORM FROM db.profile WHERE userid = uUserId AND scope = uScope;

      IF NOT FOUND THEN
        PERFORM CreateProfile(uUserId, uScope, profile.family_name, profile.given_name, null, profile.locale, profile.area, profile.interface, profile.email_verified, profile.phone_verified, profile.picture);
      END IF;

      SELECT id INTO nAudience FROM oauth2.audience WHERE provider = GetProvider('default') AND application = nApplication;

      vSession := GetSession(uUserId, CreateOAuth2(nAudience, pScope, 'offline'), pAgent, pHost, true, false);

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

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.authorize ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Authorize by session code and return an active access token.
 * @param {varchar} pSession - Session code
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {json} - Access token with expiry, or error object on failure
 * @throws AuthenticateError - When session authentication fails
 * @throws TokenExpired - When no valid access token exists for the session
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.authorize (
  pSession      varchar,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       json
AS $$
DECLARE
  r             record;

  nToken        bigint;

  expires_in    double precision;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
  vErrorId      text;
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
    PERFORM TokenExpired();
  END IF;

  SELECT * INTO r FROM db.token WHERE id = nToken;

  expires_in := trunc(extract(EPOCH FROM r.validToDate)) - trunc(extract(EPOCH FROM Now()));

  RETURN json_build_object('access_token', r.token, 'token_type', 'Bearer', 'expires_in', expires_in, 'session', pSession);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.authorization_code ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Issue an OAuth 2.0 authorization code to a client on behalf of a user who
 *        is already signed in (the "session exists" branch of GET /oauth2/authorize).
 *        The caller proves possession of the user's session code; no credentials are
 *        re-entered and no password is required.
 *
 *        Two things gate the issue, because a signed-in browser carries its cookies
 *        wherever a third-party page sends it:
 *
 *          - the client must belong to an *internal* provider. Membership in
 *            oauth2.audience under an external provider (google, yandex) is
 *            registration for verifying that provider's tokens, not a client of
 *            ours, and must not yield codes for our users;
 *
 *          - the user must have granted this client consent covering the requested
 *            scopes. Registration is not permission. Without a standing consent the
 *            function refuses with consent_required, and the caller shows the consent
 *            screen; the answer comes back with pConsent := true.
 *
 *          - the client must be one that can host a user agent — an application of
 *            type 'W' or 'N'. A service client has no browser to sign a user in to,
 *            and the elevation below, running under the system client, says nothing
 *            about who asked.
 *
 *          - the user must already have a profile in one of the requested scopes.
 *            CheckUserProfile would otherwise create one, and for an administrator
 *            it creates an administrative one; a request arriving as a redirect
 *            from another site must not provision access.
 *
 *        Substitution is performed under the *system* OAuth 2.0 client rather than
 *        under the requesting client, so a client registered by an oauth2.audience
 *        row alone — with no matching db.user — is supported. The issued code is
 *        bound to pClientId, pRedirectURI and pScope; daemon.token verifies all
 *        three on exchange.
 *
 *        Note: pRedirectURI is *not* validated against a whitelist here — the
 *        platform keeps no per-client redirect URI list. The caller (AuthServer)
 *        must validate it against its own client registry before calling.
 * @param {varchar} pSession - Session code of the signed-in user
 * @param {text} pClientId - Client identifier the code is issued to (oauth2.audience.code)
 * @param {text} pRedirectURI - Redirect URI the code is bound to; must be replayed on exchange
 * @param {text} pScope - Space-separated scope codes
 * @param {text} pState - OAuth 2.0 state parameter, echoed back on success
 * @param {text} pAccessType - 'online' or 'offline' ('offline' yields a refresh token)
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @param {boolean} pConsent - true when the user has just answered the consent screen; records the consent and proceeds
 * @param {integer} pMaxAge - OpenID Connect max_age: refuse with login_required when the session was authenticated longer ago than this many seconds
 * @return {json} - {"code": ..., "state": ...} on success, or error object on failure
 * @see daemon.token, daemon.authorize, CheckOAuth2Consent, SetOAuth2Consent, GetInternalAudience
 * @since 1.2.11
 */
CREATE OR REPLACE FUNCTION daemon.authorization_code (
  pSession      varchar,
  pClientId     text,
  pRedirectURI  text,
  pScope        text DEFAULT null,
  pState        text DEFAULT null,
  pAccessType   text DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pConsent      boolean DEFAULT false,
  pMaxAge       integer DEFAULT null
) RETURNS       json
AS $$
DECLARE
  result        jsonb;

  uUserId       uuid;

  nAudience     integer;
  nOAuth2       bigint;

  vApplicationType char;

  arScopes      text[];

  vSystemId     text;
  vSystemSecret text;
  vSystemSession text;

  vSession      text;
  vCode         text;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
  vErrorId      text;
BEGIN
  IF NULLIF(pClientId, '') IS NULL THEN
  -- The "error" field here is an RFC 6749 §5.2 code, not a catalogue identifier:
  -- this is a protocol response, and the protocol says what belongs in it. The
  -- exception handlers of this file put vErrorId in the same field, which is the
  -- other shape daemon.* answers with — see api.* for the same convention. Where a
  -- handler ends in a response like this one, vErrorId is read from ParseMessage
  -- and deliberately not used.
    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'Missing parameter: client_id'));
  END IF;

  IF NULLIF(pRedirectURI, '') IS NULL THEN
    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'Missing parameter: redirect_uri'));
  END IF;

  pAccessType := coalesce(pAccessType, 'online');

  IF SessionIn(pSession, pAgent, pHost) IS NULL THEN
    SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(GetErrorMessage());
    RETURN json_build_object('error', json_build_object('code', 401, 'error', 'access_denied', 'message', ErrorMessage));
  END IF;

  uUserId := current_userid();

  -- OpenID Connect max_age: "Maximum Authentication Age … If the elapsed time is
  -- greater than this value, the OP MUST attempt to actively re-authenticate the
  -- End-User."
  --
  -- Measured from db.session.created, which is when the user actually
  -- authenticated, not from updated, which every request moves. Without this a
  -- relying party had no way to ask for a fresh sign-in: a session left open on a
  -- shared browser answered exactly like one opened a moment ago, and the caller
  -- could only take it or leave it. login_required is the answer the specification
  -- names, and the caller turns it into the sign-in page.
  IF pMaxAge IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM db.session
                WHERE code = pSession
                  AND created < Now() - make_interval(secs => greatest(pMaxAge, 0))) THEN
      RETURN json_build_object('error', json_build_object('code', 401, 'error', 'login_required', 'message', 'The session is older than the requested max_age.'));
    END IF;
  END IF;

  pConsent := coalesce(pConsent, false);

  -- Internal providers only: an audience row under google or yandex registers that
  -- provider's tokens for verification, and must not be able to collect codes for
  -- our users. Resolving by code alone would also be ambiguous — oauth2.audience is
  -- unique by (provider, code), so SELECT ... INTO would pick an arbitrary row.
  nAudience := GetInternalAudience(pClientId);

  IF nAudience IS NULL THEN
    RETURN json_build_object('error', json_build_object('code', 401, 'error', 'invalid_client', 'message', 'The OAuth 2.0 client was not FOUND.'));
  END IF;

  -- The requesting client's own right to ask, checked apart from the elevation
  -- below. The elevation runs under the system client and therefore proves nothing
  -- about who asked: without this, any audience row at all would do.
  --
  -- What is asked for here is an authorization code for a user who is signed in to
  -- a browser. Only a client that can host a user agent has any use for one, and
  -- oauth2.application already records which those are: 'W' web and 'N' native. A
  -- service client ('S') has no browser and no user — a code issued to one would be
  -- a user's session handed to a machine-to-machine account.
  --
  -- Compare the ticket grant below, which reaches the same conclusion differently:
  -- it signs in as the requesting client with that client's own secret, which is
  -- possible there and not here, because the caller is a browser that cannot hold
  -- one.
  SELECT p.type INTO vApplicationType
    FROM oauth2.audience a
         INNER JOIN oauth2.application p ON p.id = a.application
   WHERE a.id = nAudience;

  IF coalesce(vApplicationType, 'S') NOT IN ('W', 'N') THEN
    RETURN json_build_object('error', json_build_object('code', 401, 'error', 'unauthorized_client', 'message', 'The client is not authorized to obtain an authorization code.'));
  END IF;

  -- The consent gate needs its table. Without this check a database updated with
  -- routines but not patches (runme.sh --update, no --patch) fails inside
  -- CheckOAuth2Consent and surfaces as an anonymous 500 from the handler below,
  -- with nothing in the log to say which step is missing.
  IF to_regclass('db.oauth2_consent') IS NULL THEN
    PERFORM WriteToEventLog('E', 5000, 'exception', 'error', 'db.oauth2_consent is missing: apply patch P00000011 before serving authorization codes.');
    RETURN json_build_object('error', json_build_object('code', 500, 'error', 'server_error', 'message', 'The authorization server is not fully migrated.'));
  END IF;

  -- Normalised the same way CreateOAuth2 will normalise it below, so that what the
  -- user consented to and what the code actually carries cannot drift apart.
  arScopes := ScopeToArray(pScope);

  -- The user must already have a profile in one of the scopes asked for.
  --
  -- GetSession calls CheckUserProfile, which creates one when there is none — and
  -- for a member of the administrator group it creates it with an administrative
  -- area and the administrator interface. That is reasonable where it was written,
  -- on a login the user initiated. Here the request arrives as a redirect from
  -- somebody else's site naming whichever scope it likes, so provisioning would
  -- mean a third party deciding this user now has access to that scope — and for an
  -- administrator, privileged access. Granting access is not something an
  -- authorization request should do as a side effect.
  --
  -- Scope codes are matched through db.scope_alias as well: ScopeToArray accepts an
  -- alias and returns it unchanged, so comparing against db.scope.code alone would
  -- refuse a request that names a scope by its other name.
  IF NOT EXISTS (
      SELECT 1
        FROM db.profile p
       WHERE p.userid = uUserId
         AND p.scope IN (SELECT s.id FROM db.scope s WHERE s.code = ANY(arScopes)
                          UNION
                         SELECT a.scope FROM db.scope_alias a WHERE a.code = ANY(arScopes)))
  THEN
    PERFORM WriteToEventLog('E', 4003, 'auth', 'error',
      format('No profile for this user in the requested scope; refused to create one from an authorization request (client %s).', pClientId));
    RETURN json_build_object('error', json_build_object('code', 401, 'error', 'access_denied', 'message', 'The user has no profile in the requested scope.'));
  END IF;

  IF pConsent THEN
    -- An empty scope expands to *every* scope in db.scope. Recording that as consent
    -- would turn one click under a short list of permissions into a standing grant
    -- over everything, and every later request by this client would pass silently.
    -- The caller is expected to have resolved the scope to something explicit — the
    -- consent screen shows the user what they are agreeing to, and this is the same
    -- list.
    IF NULLIF(pScope, '') IS NULL THEN
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_scope', 'message', 'Consent requires an explicit scope.'));
    END IF;

    PERFORM SetOAuth2Consent(uUserId, nAudience, arScopes);
  ELSIF NOT CheckOAuth2Consent(uUserId, nAudience, arScopes) THEN
    -- Registration is not permission. Ask the user before handing out a code —
    -- refused here, before the elevation below, so that a request that will not be
    -- served costs no system login at all.
    RETURN json_build_object('error', json_build_object('code', 403, 'error', 'consent_required', 'message', 'The user has not granted this client access.'));
  END IF;

  -- Elevate: GetSession requires the "substitute user" ACL bit, which the signed-in
  -- user does not have. The system client does — and it exists in every database.
  vSystemId := oauth2_system_client_id();

  SELECT a.secret INTO vSystemSecret FROM oauth2.audience a WHERE a.code = vSystemId;

  IF NOT FOUND THEN
    RETURN json_build_object('error', json_build_object('code', 500, 'error', 'server_error', 'message', 'The system OAuth 2.0 client was not FOUND.'));
  END IF;

  -- The elevation session is a throwaway: give it the system client's own scope,
  -- not the one the client asked for, which the system user may have no profile in.
  -- Checked before signing in, and this is not belt-and-braces.
  --
  -- SignIn counts a failure against the user: input_error goes up, and at five it
  -- writes lock_date up to ten hours ahead. The system user is the one messaging and
  -- verification codes run as. So a secret rotated in oauth2.audience without
  -- re-running CreateUser used to turn every request that got this far into a failed
  -- login of that user, and five of them took the whole system's outbound mail down
  -- for the rest of the working day — from a mismatch that hurts nothing else.
  --
  -- CheckPassword answers the same question and touches neither counter.
  IF NOT CheckPassword(vSystemId, vSystemSecret) THEN
    PERFORM WriteToEventLog('E', 5000, 'exception', 'error',
      format('The system OAuth 2.0 client "%s" cannot sign in: %s. The db.user password and the oauth2.audience secret have diverged; re-run CreateUser for that client.',
             vSystemId, GetErrorMessage()));
    RETURN json_build_object('error', json_build_object('code', 500, 'error', 'server_error', 'message', 'The authorization server is not configured correctly.'));
  END IF;

  vSystemSession := SignIn(CreateSystemOAuth2(), vSystemId, vSystemSecret, pAgent, pHost);

  IF vSystemSession IS NULL THEN
    SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(GetErrorMessage());
    PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
    RETURN json_build_object('error', json_build_object('code', 500, 'error', 'server_error', 'message', 'The system OAuth 2.0 client is not authorized.'));
  END IF;

  nOAuth2 := CreateOAuth2(nAudience, arScopes, pAccessType, pRedirectURI, pState);

  vSession := GetSession(uUserId, nOAuth2, pAgent, pHost, true, false);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(GetErrorMessage());

  PERFORM SignOut(vSystemSession);

  IF vSession IS NULL THEN
    PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
    RETURN json_build_object('error', json_build_object('code', 401, 'error', 'access_denied', 'message', 'The user could not be signed in to this client.'));
  END IF;

  vCode := oauth2_current_code(vSession);

  IF vCode IS NULL THEN
    RETURN json_build_object('error', json_build_object('code', 500, 'error', 'server_error', 'message', 'Authorization code was not issued.'));
  END IF;

  result := jsonb_build_object('code', vCode);

  IF pState IS NOT NULL THEN
    result := result || jsonb_build_object('state', pState);
  END IF;

  RETURN result;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  -- GetSession refuses by raising, not by returning NULL — AccessDenied,
  -- LoginError, UserLockError, PasswordExpired and LoginIPTableError all land here.
  -- Reporting them as server_error told the client the server had broken when in
  -- fact it had decided, and RFC 6749 §4.1.2.1 asks for access_denied. Worse, the
  -- reason travelled with it: the caller puts error_description into a redirect, so
  -- "the account is locked until 14:20" ended up in the address bar, the Referer
  -- and the browser history.
  --
  -- Mapped by the code ParseMessage already extracted, rather than by matching the
  -- message, which is localised, or the raising function, which the handler cannot
  -- see. 4xx is a decision about this request; anything else is the server failing.
  -- The reason itself stays in the event log, written just above.
  IF ErrorCode BETWEEN 400 AND 499 THEN
    RETURN json_build_object('error', json_build_object('code', 401, 'error', 'access_denied', 'message', 'The user could not be signed in to this client.'));
  END IF;

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', 'server_error', 'message', 'The authorization server could not complete the request.'));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- daemon.token ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Exchange an authorization code, credentials, or refresh token for an access token (OAuth 2.0 token endpoint).
 * @param {text} pClientId - OAuth 2.0 client identifier (oauth2.audience.code)
 * @param {text} pSecret - OAuth 2.0 client secret
 * @param {jsonb} pPayload - Grant-specific payload (grant_type, code, username/password, refresh_token, etc.)
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {json} - Token response on success, or error object on failure
 * @since 1.0.0
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

  uUserId               uuid;
  uTicket               uuid;

  nAudience             integer;
  nCodeAudience         integer;
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

  vCode                 text;

  vOAuthSession         text;
  vSession              text;
  vSecret               text;
  vHash                 text;

  vRedirectURI          text;

  arResponses           text[];

  vMessage              text;
  vContext              text;

  ErrorCode             int;
  ErrorMessage          text;
  vErrorId              text;
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

    vHash := GetTokenHash(auth_code, GetSecretKey());

    SELECT h.oauth2 INTO nOauth2
      FROM db.token t INNER JOIN db.token_header h ON h.id = t.header AND t.type = 'C'
     WHERE t.hash = vHash
       AND t.validFromDate <= Now()
       AND t.validtoDate > Now();

    IF NOT FOUND THEN
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_grant', 'message', 'Malformed auth code.'));
    END IF;

    SELECT a.audience, a.redirect_uri INTO nCodeAudience, vRedirectURI FROM db.oauth2 a WHERE id = nOauth2;

    IF NOT FOUND THEN
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'The OAuth 2.0 params was not FOUND.'));
    END IF;

    -- The code belongs to the client it was issued to and to no one else.
    IF nCodeAudience IS DISTINCT FROM nAudience THEN
      RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_grant', 'message', 'Malformed auth code.'));
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
      SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(GetErrorMessage());
      PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
      RETURN json_build_object('error', json_build_object('code', 401, 'error', 'access_denied', 'message', ErrorMessage));
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

  ELSIF grant_type = 'ticket' THEN

    uTicket := pPayload->>'ticket';
    vCode := pPayload->>'code';

    uUserId := CheckRecoveryTicket(uTicket, vCode);

    IF uUserId IS NULL THEN
      SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(GetErrorMessage());
      RETURN json_build_object('error', json_build_object('code', 401, 'error', 'access_denied', 'message', ErrorMessage));
    END IF;

    response_type := pPayload->>'response_type';
    redirect_uri := pPayload->>'redirect_uri';

    scope := pPayload->>'scope';
    state := pPayload->>'state';

    arResponses := string_to_array(coalesce(response_type, 'token'), ' ');

    nOAuth2 := CreateOAuth2(nAudience, scope, 'offline');

    vOAuthSession := SignIn(nOAuth2, pClientId, pSecret, pAgent, pHost);

    IF vOAuthSession IS NULL THEN
      RETURN json_build_object('error', json_build_object('code', 401, 'error', 'unauthorized_client', 'message', 'The client is not authorized.'));
    END IF;

    nOAuth2 := CreateOAuth2(nAudience, scope, access_type, redirect_uri, state);

    vSession := GetSession(uUserId, nOAuth2, pAgent, pHost, true, true);

    SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(GetErrorMessage());

    PERFORM SignOut(vOAuthSession);

    IF vSession IS NULL THEN
      PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
      RETURN json_build_object('error', json_build_object('code', 401, 'error', 'access_denied', 'message', ErrorMessage));
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

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', 'server_error', 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- daemon.session_open ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Open (resume) a session by validating a JWT token and entering the session context.
 * @param {text} pToken - JWT access token
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {SETOF json} - Token claims on success, or error object on failure
 * @since 1.0.0
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
  vErrorId      text;
BEGIN
  token := TokenValidation(pToken);

  IF SessionIn(token->>'sub', pAgent, pHost) IS NULL THEN
    PERFORM AuthenticateError(GetErrorMessage());
  END IF;

  RETURN NEXT token;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.session_close --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Close (sign out) a session, optionally closing all sessions for the user.
 * @param {text} pToken - JWT access token identifying the session
 * @param {boolean} pCloseAll - TRUE to close all sessions for this user
 * @param {text} pMessage - Optional sign-out reason message
 * @return {SETOF json} - Token claims on success, or error object on failure
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.session_close (
  pToken        text,
  pCloseAll     boolean DEFAULT false,
  pMessage      text DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  token         jsonb;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
  vErrorId      text;
BEGIN
  token := TokenValidation(pToken);

  PERFORM SessionOut(token->>'sub', pCloseAll, pMessage);

  RETURN NEXT token;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.unauthorized_fetch ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute an unauthenticated REST JSON API request (public endpoints only).
 * @param {text} pMethod - HTTP method (GET, POST, etc.)
 * @param {text} pPath - REST route path
 * @param {jsonb} pPayload - Request payload
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {SETOF json} - JSON response rows
 * @throws RouteIsEmpty - When pPath is empty or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.unauthorized_fetch (
  pMethod       text,
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
  vErrorId      text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  pPath := lower(pPath);

  IF pPath = ANY (string_to_array(RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject\API\Route', 'Blacklist'), ',')) THEN
    -- Identified like every other error object this file returns. Without it this
    -- was the one 401 from daemon.* a caller could not name, and so could not tell
    -- from an expired token — which is the distinction the identifier exists for.
    -- ERR-401-001 is the catalogue's "Login failed": the route is closed to an
    -- unauthenticated caller, which is what happened.
    RETURN NEXT json_build_object('error', json_build_object('code', 401, 'error', 'ERR-401-001', 'message', 'Unauthorized'));
    RETURN;
  END IF;

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

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.authorized_fetch -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute an authenticated REST JSON API request using username/password credentials.
 * @param {text} pUsername - Login username
 * @param {text} pPassword - Login password
 * @param {text} pMethod - HTTP method (GET, POST, etc.)
 * @param {text} pPath - REST route path
 * @param {jsonb} pPayload - Request payload
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {SETOF json} - JSON response rows
 * @throws RouteIsEmpty - When pPath is empty or NULL
 * @throws AuthenticateError - When authentication fails
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.authorized_fetch (
  pUsername     text,
  pPassword     text,
  pMethod       text,
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
  vErrorId      text;
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

  IF vSession IS NULL THEN
    PERFORM AuthenticateError(GetErrorMessage());
  END IF;

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

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.session_fetch --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute an authenticated REST JSON API request using session code and secret.
 * @param {varchar} pSession - Session code
 * @param {text} pSecret - Session secret for authentication
 * @param {text} pMethod - HTTP method (GET, POST, etc.)
 * @param {text} pPath - REST route path
 * @param {jsonb} pPayload - Request payload
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {SETOF json} - JSON response rows
 * @throws RouteIsEmpty - When pPath is empty or NULL
 * @throws AuthenticateError - When session authentication fails
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.session_fetch (
  pSession      varchar,
  pSecret       text,
  pMethod       text,
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
  vErrorId      text;
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

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.signed_fetch ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute an HMAC-SHA256 signed REST JSON API request with replay protection.
 * @param {text} pMethod - HTTP method (GET, POST, etc.)
 * @param {text} pPath - REST route path
 * @param {json} pJson - Request payload as JSON
 * @param {varchar} pSession - Session code
 * @param {double precision} pNonce - Request timestamp in microseconds for replay protection
 * @param {text} pSignature - HMAC-SHA256 signature of the request
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @param {interval} pTimeWindow - Maximum age of the nonce (capped at 1 minute)
 * @return {SETOF json} - JSON response rows
 * @throws RouteIsEmpty - When pPath is empty or NULL
 * @throws SignatureError - When HMAC signature verification fails
 * @throws NonceExpired - When the nonce is outside the allowed time window
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.signed_fetch (
  pMethod       text,
  pPath         text,
  pJson         json DEFAULT null,
  pSession      varchar DEFAULT null,
  pNonce        double precision DEFAULT null,
  pSignature    text DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pTimeWindow   INTERVAL DEFAULT '1 min'
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
  vErrorId      text;
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

  IF (dtTimeStamp < (Now() + INTERVAL '15 sec') AND (Now() - dtTimeStamp) <= pTimeWindow) THEN

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

    PERFORM UpdateSessionStats(pSession, pAgent, pHost);
  ELSE
    PERFORM NonceExpired();
  END IF;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.fetch ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute an authenticated REST JSON API request using a JWT access token.
 * @param {text} pToken - JWT access token
 * @param {text} pMethod - HTTP method (GET, POST, etc.)
 * @param {text} pPath - REST route path
 * @param {jsonb} pPayload - Request payload
 * @param {text} pAgent - HTTP User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {SETOF json} - JSON response rows
 * @throws RouteIsEmpty - When pPath is empty or NULL
 * @throws AuthenticateError - When session authentication fails
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION daemon.fetch (
  pToken        text,
  pMethod       text,
  pPath         text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  token         jsonb;

  vSession      text;
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
  vErrorId      text;
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

  token := TokenValidation(pToken);

  vSession := token->>'sub';

  IF SessionIn(vSession, pAgent, pHost) IS NULL THEN
    PERFORM AuthenticateError(GetErrorMessage());
  END IF;

  FOR r IN SELECT * FROM api.run(pMethod, pPath, pPayload)
  LOOP
    RETURN NEXT r.run;
  END LOOP;

  PERFORM UpdateSessionStats(vSession, pAgent, pHost);

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, 'exception', 'error', ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, 'exception', 'context', vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'error', vErrorId, 'message', ErrorMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
