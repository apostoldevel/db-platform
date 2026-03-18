--------------------------------------------------------------------------------
-- SECURITY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- GetAreaType -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve an area type code to its identifier.
 * @param {text} pCode - Area type code
 * @return {uuid} Area type identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAreaType (
  pCode       text
) RETURNS     uuid
AS $$
  SELECT id FROM db.area_type WHERE code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaTypeCode -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the area type code by its identifier.
 * @param {uuid} pId - Area type identifier
 * @return {text} Area type code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAreaTypeCode (
  pId       uuid
) RETURNS   text
AS $$
  SELECT code FROM db.area_type WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaTypeName -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the area type name by its identifier.
 * @param {uuid} pId - Area type identifier
 * @return {text} Area type name
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAreaTypeName (
  pId       uuid
) RETURNS   text
AS $$
  SELECT name FROM db.area_type WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateProfile ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a user profile record for the given scope.
 * @param {uuid} pUserId - User identifier
 * @param {uuid} pScope - Scope identifier
 * @param {text} pFamilyName - Family (last) name
 * @param {text} pGivenName - Given (first) name
 * @param {text} pPatronymicName - Patronymic (middle) name
 * @param {uuid} pLocale - Locale identifier
 * @param {uuid} pArea - Area identifier
 * @param {uuid} pInterface - Interface identifier
 * @param {bool} pEmailVerified - Whether the email is verified
 * @param {bool} pPhoneVerified - Whether the phone is verified
 * @param {text} pPicture - URL to user avatar/picture
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateProfile (
  pUserId           uuid,
  pScope            uuid,
  pFamilyName       text,
  pGivenName        text,
  pPatronymicName   text,
  pLocale           uuid,
  pArea             uuid,
  pInterface        uuid,
  pEmailVerified    bool,
  pPhoneVerified    bool,
  pPicture          text
) RETURNS           void
AS $$
BEGIN
  INSERT INTO db.profile (userid, scope, family_name, given_name, patronymic_name, locale, area, interface, email_verified, phone_verified, picture)
  VALUES (pUserId, pScope, pFamilyName, pGivenName, pPatronymicName, pLocale, pArea, pInterface, pEmailVerified, pPhoneVerified, pPicture);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateProfile ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates an existing user profile. NULL parameters are left unchanged.
 * @param {uuid} pUserId - User identifier
 * @param {uuid} pScope - Scope identifier
 * @param {text} pFamilyName - Family (last) name
 * @param {text} pGivenName - Given (first) name
 * @param {text} pPatronymicName - Patronymic (middle) name
 * @param {uuid} pLocale - Locale identifier
 * @param {uuid} pArea - Area identifier
 * @param {uuid} pInterface - Interface identifier
 * @param {bool} pEmailVerified - Whether the email is verified
 * @param {bool} pPhoneVerified - Whether the phone is verified
 * @param {text} pPicture - URL to user avatar/picture
 * @return {boolean} true if a row was updated
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UpdateProfile (
  pUserId           uuid,
  pScope            uuid,
  pFamilyName       text DEFAULT null,
  pGivenName        text DEFAULT null,
  pPatronymicName   text DEFAULT null,
  pLocale           uuid DEFAULT null,
  pArea             uuid DEFAULT null,
  pInterface        uuid DEFAULT null,
  pEmailVerified    bool DEFAULT null,
  pPhoneVerified    bool DEFAULT null,
  pPicture          text DEFAULT null
) RETURNS           boolean
AS $$
BEGIN
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
   WHERE userid = pUserId AND scope = pScope;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckUserProfile ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Ensures the user has a profile in one of the OAuth 2.0 scopes.
 *        If no profile exists, creates an area, interface membership, and profile.
 * @param {bigint} pOAuth2 - OAuth 2.0 session parameters identifier
 * @param {uuid} pUserId - User identifier
 * @return {uuid} Scope identifier for the matched or newly created profile
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckUserProfile (
  pOAuth2       bigint,
  pUserId       uuid
) RETURNS       uuid
AS $$
DECLARE
  r             record;
  e             record;

  uRoot         uuid;
  uArea         uuid;
  uScope        uuid;
  uLocale       uuid;
  uInterface    uuid;

  arTypes       uuid[];
BEGIN
  FOR r IN SELECT GetOAuth2Scopes(pOAuth2) AS id
  LOOP
    SELECT scope INTO uScope FROM db.profile WHERE userid = pUserId AND scope = r.id;
    EXIT WHEN uScope IS NOT NULL;
  END LOOP;

  IF uScope IS NULL THEN
    uScope := r.id;
    uLocale := GetLocale(locale_code());

    IF IsUserRole('00000000-0000-4000-a000-000000000001'::uuid, pUserId) THEN -- administrator
      arTypes := ARRAY['00000000-0000-4002-a001-000000000001'::uuid, '00000000-0000-4002-a001-000000000002'::uuid, '00000000-0000-4002-a001-000000000003'::uuid, '00000000-0000-4002-a001-000000000000'::uuid, '00000000-0000-4002-a000-000000000002'::uuid];
      uInterface := '00000000-0000-4004-a000-000000000001'::uuid; -- administrator
    ELSE
      arTypes := ARRAY['00000000-0000-4002-a000-000000000002'::uuid]; -- guest
      uInterface := '00000000-0000-4004-a000-000000000003'::uuid; -- guest
    END IF;

    FOR e IN SELECT unnest(arTypes) AS type
    LOOP
      SELECT id INTO uArea FROM db.area WHERE type = e.type AND scope = uScope;
      EXIT WHEN uArea IS NOT NULL;
    END LOOP;

    IF uArea IS NULL THEN
      uRoot := GetAreaRoot(uScope);

      IF uRoot IS NULL THEN
        INSERT INTO db.area (id, parent, type, code, name, description, validfromdate, validtodate, scope, level, sequence)
        VALUES (gen_kernel_uuid('8'), null, '00000000-0000-4002-a000-000000000000', 'R-' || uScope, 'Root', null, Now(), MAXDATE(), uScope, 0, 1);
      END IF;

      INSERT INTO db.area (id, parent, type, code, name, description, validfromdate, validtodate, scope, level, sequence)
      VALUES (gen_kernel_uuid('8'), uRoot, '00000000-0000-4002-a000-000000000002', 'G-' || uScope, 'Guest', null, Now(), MAXDATE(), uScope, 1, 1);
    END IF;

    INSERT INTO db.member_area (area, member) VALUES (uArea, pUserId) ON CONFLICT DO NOTHING;
    INSERT INTO db.member_interface (interface, member) VALUES (uInterface, pUserId) ON CONFLICT DO NOTHING;
    INSERT INTO db.profile (userid, scope, locale, area, interface) VALUES (pUserId, uScope, uLocale, uArea, uInterface);
  END IF;

  RETURN uScope;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddRecoveryTicket -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Inserts a new password recovery ticket for a user.
 * @param {uuid} pUserId - User identifier
 * @param {text} pSecurityAnswer - Hashed security answer
 * @param {text} pInitiator - Who initiated the recovery (e.g. 'system', 'user')
 * @param {timestamptz} pDateFrom - Validity start (defaults to now)
 * @param {timestamptz} pDateTo - Validity end (defaults to max date)
 * @return {uuid} Newly created ticket identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddRecoveryTicket (
  pUserId           uuid,
  pSecurityAnswer   text,
  pInitiator        text,
  pDateFrom         timestamptz DEFAULT null,
  pDateTo           timestamptz DEFAULT null
) RETURNS           uuid
AS $$
DECLARE
  uTicket           uuid;
BEGIN
  uTicket := gen_random_uuid();

  INSERT INTO db.recovery_ticket (ticket, userid, securityAnswer, initiator, validFromDate, validtodate)
  VALUES (uTicket, pUserId, pSecurityAnswer, pInitiator, coalesce(pDateFrom, Now()), coalesce(pDateTo, MAXDATE()));

  RETURN uTicket;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- NewRecoveryTicket -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a recovery ticket with a bcrypt-hashed security answer and 1-hour validity.
 * @param {uuid} pUserId - User identifier
 * @param {text} pSecurityAnswer - Plain-text security answer (will be hashed)
 * @param {text} pInitiator - Who initiated the recovery
 * @param {timestamptz} pDateFrom - Validity start (defaults to now)
 * @param {timestamptz} pDateTo - Validity end (defaults to now + 1 hour)
 * @return {uuid} Newly created ticket identifier
 * @see AddRecoveryTicket
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewRecoveryTicket (
  pUserId           uuid,
  pSecurityAnswer   text,
  pInitiator        text,
  pDateFrom         timestamptz DEFAULT Now(),
  pDateTo           timestamptz DEFAULT Now() + INTERVAL '1 hour'
) RETURNS           uuid
AS $$
BEGIN
  RETURN AddRecoveryTicket(pUserId, crypt(pSecurityAnswer, gen_salt('bf')), pInitiator, pDateFrom, pDateTo);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- GetRecoveryTicket -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieves a valid recovery ticket for the given user at the specified time.
 * @param {uuid} pUserId - User identifier
 * @param {timestamptz} pDateFrom - Point in time to check validity (defaults to now)
 * @return {uuid} Ticket identifier, or NULL if none found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetRecoveryTicket (
  pUserId           uuid,
  pDateFrom         timestamptz DEFAULT Now()
) RETURNS           uuid
AS $$
DECLARE
  uTicket           uuid;
BEGIN
  SELECT ticket INTO uTicket
    FROM db.recovery_ticket
   WHERE userid = pUserId
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  RETURN uTicket;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckRecoveryTicket ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validates a recovery ticket against a security answer.
 *        Returns the user id on success, NULL on failure. Sets an error message.
 * @param {uuid} pTicket - Recovery ticket identifier
 * @param {text} pSecurityAnswer - Plain-text security answer to verify
 * @return {uuid} User identifier on success, NULL on failure
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckRecoveryTicket (
  pTicket           uuid,
  pSecurityAnswer   text
) RETURNS           uuid
AS $$
DECLARE
  uUserId           uuid;
  passed            boolean;
  utilized          boolean;
  messages          text[];
BEGIN
  IF locale_code() = 'ru' THEN
    messages[1] := 'Секретный код уже был использован.';
    messages[2] := 'Успешно.';
    messages[3] := 'Секретный код не прошёл проверку.';
    messages[4] := 'Талон не найден.';
    messages[5] := 'Превышено количество попыток. Запросите новый код.';
  ELSE
    messages[1] := 'The secret code has already been used.';
    messages[2] := 'Successful.';
    messages[3] := 'Secret code failed verification.';
    messages[4] := 'Ticket not found.';
    messages[5] := 'Too many attempts. Please request a new code.';
  END IF;

  SELECT userId, (securityAnswer = crypt(pSecurityAnswer, securityAnswer)), used IS NOT NULL INTO uUserId, passed, utilized
    FROM db.recovery_ticket
   WHERE ticket = pTicket
     AND validFromDate <= Now()
     AND validtoDate > Now()
     AND attempts < 5;

  IF FOUND THEN
    IF utilized THEN
      PERFORM SetErrorMessage(messages[1]);
    ELSE
      IF passed THEN
        PERFORM SetErrorMessage(messages[2]);
        RETURN uUserId;
      ELSE
        UPDATE db.recovery_ticket SET attempts = attempts + 1 WHERE ticket = pTicket;
        PERFORM SetErrorMessage(messages[3]);
      END IF;
    END IF;
  ELSE
    -- Check if ticket exists but exceeded attempts
    PERFORM FROM db.recovery_ticket WHERE ticket = pTicket AND attempts >= 5;
    IF FOUND THEN
      PERFORM SetErrorMessage(messages[5]);
    ELSE
      PERFORM SetErrorMessage(messages[4]);
    END IF;
  END IF;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- CreateAuth ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates an authorization record binding a user to an OAuth 2.0 audience.
 *        Requires administrator role unless called by the kernel.
 * @param {uuid} pUserId - User identifier
 * @param {integer} pAudience - OAuth 2.0 audience identifier
 * @param {text} pCode - Authorization code
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks administrator role
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateAuth (
  pUserId           uuid,
  pAudience         integer,
  pCode             text
) RETURNS           void
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
/**
 * @brief Retrieve the IP access list for a user as a comma-separated string.
 *        Formats CIDR, range, and wildcard notations for display.
 * @param {uuid} pUserId - User identifier
 * @param {char} pType - List type: 'A' = allow, 'D' = deny (defaults to 'A')
 * @return {text} Comma-separated IP addresses/ranges, or NULL if empty
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetIPTableStr (
  pUserId       uuid,
  pType         char DEFAULT 'A'
) RETURNS       text
AS $$
DECLARE
  r             record;
  ip            integer[4];
  vHost         text;
  aResult       text[];
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
/**
 * @brief Replaces the IP access list for a user from a comma-separated string.
 *        Deletes all existing entries of the given type, then parses and inserts new ones.
 * @param {uuid} pUserId - User identifier
 * @param {char} pType - List type: 'A' = allow, 'D' = deny
 * @param {text} pIpTable - Comma-separated IP addresses/ranges/CIDRs
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetIPTableStr (
  pUserId       uuid,
  pType         char,
  pIpTable      text
) RETURNS       void
AS $$
DECLARE
  i             int;

  vStr          text;
  arrIp         text[];

  iHost         inet;
  nRange        int;
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
/**
 * @brief Checks whether a host IP matches any entry in the user's IP table of the given type.
 * @param {uuid} pUserId - User identifier
 * @param {char} pType - List type: 'A' = allow, 'D' = deny
 * @param {inet} pHost - IP address to check
 * @return {boolean} true if the host matches at least one entry
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckIPTable (
  pUserId       uuid,
  pType         char,
  pHost         inet
) RETURNS       boolean
AS $$
DECLARE
  r             record;
  passed        boolean;
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
/**
 * @brief Checks IP access for a user: deny list takes precedence over allow list.
 *        Sets an error message if access is restricted.
 * @param {uuid} pUserId - User identifier
 * @param {inet} pHost - IP address to check
 * @return {boolean} true if access is allowed
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckIPTable (
  pUserId       uuid,
  pHost         inet
) RETURNS       boolean
AS $$
DECLARE
  denied        boolean;
  allow         boolean;
BEGIN
  denied := coalesce(CheckIPTable(pUserId, 'D', pHost), false);

  IF NOT denied THEN
    allow := coalesce(CheckIPTable(pUserId, 'A', pHost), true);
  ELSE
    allow := NOT denied;
  END IF;

  IF NOT allow THEN
    PERFORM SetErrorMessage('Access denied by IP address.');
  END IF;

  RETURN allow;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckSessionLimit -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Enforces the per-user session limit by closing the oldest sessions that exceed the threshold.
 * @param {uuid} pUserId - User identifier
 * @return {void}
 * @see SessionOut
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckSessionLimit (
  pUserId       uuid
) RETURNS       void
AS $$
DECLARE
  nCount        integer;
  nLimit        integer;

  r             record;
BEGIN
  SELECT session_limit INTO nLimit FROM db.profile WHERE userid = pUserId AND scope = current_scope();

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
/**
 * @brief Builds a password key string from user hash, secret, database name, and timestamp,
 *        then returns its SHA-1 digest as a hex string.
 * @param {uuid} pUserId - User identifier
 * @param {text} pSecret - Session secret
 * @param {timestamptz} pCreated - Session creation timestamp
 * @return {text} SHA-1 hex digest of the password key
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION StrPwKey (
  pUserId       uuid,
  pSecret       text,
  pCreated      timestamptz
) RETURNS       text
AS $$
DECLARE
  vHash         text;
  vStrPwKey     text DEFAULT null;
BEGIN
  SELECT hash INTO vHash FROM db.user WHERE id = pUserId;

  IF FOUND THEN
    vStrPwKey := '{' || pUserId::text || '-' || vHash || '-' || pSecret || '-' || current_database() || '-' || DateToStr(pCreated, 'YYYYMMDDHH24MISS') || '}';
  END IF;

  RETURN encode(digest(vStrPwKey, 'sha1'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CreateAccessToken --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a signed JWT access token for the given audience and subject.
 * @param {integer} pAudience - OAuth 2.0 audience identifier
 * @param {text} pSubject - Token subject (typically the session code)
 * @param {timestamptz} pDateFrom - Token validity start (defaults to now)
 * @param {timestamptz} pDateTo - Token validity end (defaults to now + 60 min)
 * @return {text} Signed JWT access token
 * @throws IssuerNotFound if the issuer for the audience is not configured
 * @since 1.0.0
 */
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

  IF NOT FOUND THEN
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
/**
 * @brief Creates a signed JWT ID token containing user profile claims.
 *        Includes profile data when the 'profile' scope is requested.
 * @param {integer} pAudience - OAuth 2.0 audience identifier
 * @param {uuid} pUserId - User identifier
 * @param {text[]} pScopes - Requested OAuth 2.0 scopes
 * @param {timestamptz} pDateFrom - Token validity start (defaults to now)
 * @param {timestamptz} pDateTo - Token validity end (defaults to now + 60 min)
 * @return {text} Signed JWT ID token
 * @throws UserNotFound if the user is not found in the requested scopes
 * @since 1.0.0
 */
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
    FROM users WHERE id = pUserId AND array_position(pScopes, scope_code) IS NOT NULL;

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
/**
 * @brief Create a signed JWT ID token by resolving the user from a session code.
 * @param {integer} pAudience - OAuth 2.0 audience identifier
 * @param {varchar} pSession - Session code to resolve the user
 * @param {text[]} pScopes - Requested OAuth 2.0 scopes
 * @param {timestamptz} pDateFrom - Token validity start (defaults to now)
 * @param {timestamptz} pDateTo - Token validity end (defaults to now + 1 hour)
 * @return {text} Signed JWT ID token
 * @see CreateIdToken(integer, uuid, text[], timestamptz, timestamptz)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateIdToken (
  pAudience     integer,
  pSession      varchar,
  pScopes       text[],
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT Now() + INTERVAL '1 hour'
) RETURNS       text
AS $$
DECLARE
  uUserId       uuid;
BEGIN
  SELECT userId INTO uUserId FROM db.session WHERE code = pSession;
  RETURN CreateIdToken(pAudience, uUserId, pScopes, pDateFrom, pDateTo);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoubleSHA256 -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Computes a double SHA-256 hash (SHA-256 of SHA-256) on binary data.
 * @param {bytea} pData - Binary data to hash
 * @return {bytea} Double SHA-256 digest
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoubleSHA256 (
  pData         bytea
) RETURNS       bytea
AS $$
BEGIN
  RETURN digest(digest(pData, 'sha256'), 'sha256');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoubleSHA256 -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Compute a double SHA-256 on text data, returning hex.
 * @param {text} pData - Text data to hash
 * @return {text} Hex-encoded double SHA-256 digest
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoubleSHA256 (
  pData         text
) RETURNS       text
AS $$
BEGIN
  RETURN encode(DoubleSHA256(pData), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetHashCash --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Computes a HashCash proof-of-work digest (double SHA-256 in little-endian byte order).
 * @param {bytea} pData - Binary data to hash
 * @return {bytea} Little-endian double SHA-256 digest
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetHashCash (
  pData         bytea
) RETURNS       bytea
AS $$
BEGIN
  RETURN to_little_endian(DoubleSHA256(pData));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION HashCash -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Performs a HashCash proof-of-work search: increments a nonce until the hash
 *        meets the difficulty target defined by pBits.
 * @param {bytea} pData - Base data to hash
 * @param {integer} pBits - Compact difficulty target (exponent + mantissa)
 * @param {integer} pNonce - Starting nonce value
 * @param {text} hash - (OUT) Hex-encoded hash that meets the target
 * @param {integer} nonce - (OUT) Nonce value that produced the valid hash
 * @return {record} (hash text, nonce integer)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION HashCash (
  pData         bytea,
  pBits         integer,
  pNonce        integer,
  OUT hash      text,
  OUT nonce     integer
) RETURNS       record
AS $$
DECLARE
  tmp           bytea;
  exp           numeric;
  mnt           numeric;
  trg           numeric;
BEGIN
  nonce := pNonce;

  exp := bit_copy(pBits, 24, 8);
  mnt := pBits & 16777215; -- 0xffffff
  trg := mnt * power(2::numeric, 8 * (exp - 3));

  WHILE nonce < 4294967296
  LOOP
    tmp := pData || decode(dec_to_hex(pBits, 8), 'hex') || decode(dec_to_hex(nonce, 8), 'hex');
    hash := encode(GetHashCash(tmp), 'hex');
    EXIT WHEN hex_to_dec(hash) <= trg;
    nonce := nonce + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SessionKey ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Derives a session key using HMAC-SHA1 from a password key and a pass key.
 * @param {text} pPwKey - Password key (output of StrPwKey)
 * @param {text} pPassKey - Encryption pass key (salt)
 * @return {text} Hex-encoded HMAC-SHA1 session key, or NULL if pPwKey is NULL
 * @since 1.0.0
 */
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
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetTokenHash -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Computes the HMAC-SHA1 hash of a token using the given pass key.
 *        Used for token lookup by hash instead of raw token value.
 * @param {text} pToken - Token string to hash
 * @param {text} pPassKey - Secret key for HMAC
 * @return {text} Hex-encoded HMAC-SHA1 digest
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetTokenHash (
  pToken        text,
  pPassKey      text
) RETURNS       text
AS $$
BEGIN
  RETURN encode(hmac(pToken, pPassKey, 'sha1'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GenSecretKey -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Generates a cryptographically random secret key encoded in base64.
 * @param {integer} pSize - Number of random bytes (defaults to 48)
 * @return {text} Base64-encoded random key
 * @since 1.0.0
 */
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
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GenTokenKey --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Generates a token key by HMAC-SHA256 signing a random secret with the pass key.
 * @param {text} pPassKey - Secret key for HMAC-SHA256
 * @return {text} Hex-encoded HMAC-SHA256 token key
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GenTokenKey (
  pPassKey      text
) RETURNS       text
AS $$
BEGIN
  RETURN encode(hmac(GenSecretKey(), pPassKey, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- GetSignature ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Computes an HMAC-SHA256 request signature from path, nonce, JSON body, and secret.
 * @param {text} pPath - Request path
 * @param {double precision} pNonce - Timestamp in milliseconds (replay protection)
 * @param {json} pJson - Request body (or NULL)
 * @param {text} pSecret - Secret key for HMAC
 * @return {text} Hex-encoded HMAC-SHA256 signature
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetSignature (
  pPath         text,
  pNonce        double precision,
  pJson         json,
  pSecret       text
) RETURNS       text
AS $$
BEGIN
  RETURN encode(hmac(pPath || trim(to_char(pNonce, '9999999999999999')) || coalesce(pJson, 'null'), pSecret, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- ScopeToArray ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Parses a space-separated scope string into a validated array of scope codes.
 *        Includes scope aliases. Raises InvalidScope if any scope is unrecognized.
 *        If pScope is empty/NULL, returns all available scopes.
 * @param {text} pScope - Space-separated scope codes (e.g. 'openid profile')
 * @return {text[]} Array of valid scope codes
 * @throws InvalidScope if any requested scope is not recognized
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ScopeToArray (
  pScope        text
) RETURNS       text[]
AS $$
DECLARE
  r             record;
  e             record;

  scopes        text[];
  arValid       text[];
  arInvalid     text[];
  arScopes      text[];
BEGIN
  IF NULLIF(pScope, '') IS NOT NULL THEN

    arScopes := array_cat(arScopes, ARRAY[current_database()::text]);

    FOR r IN SELECT id, code FROM db.scope
    LOOP
      arScopes := array_append(arScopes, r.code);

      FOR e IN SELECT code FROM db.scope_alias WHERE scope = r.id
      LOOP
        arScopes := array_append(arScopes, e.code);
      END LOOP;
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
    FOR r IN SELECT id, code FROM db.scope
    LOOP
      arValid := array_append(arValid, r.code);

      FOR e IN SELECT code FROM db.scope_alias WHERE scope = r.id
      LOOP
        arValid := array_append(arValid, e.code);
      END LOOP;
    END LOOP;
  END IF;

  RETURN arValid;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateOAuth2 ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates an OAuth 2.0 session record with the given audience, scopes, and parameters.
 * @param {integer} pAudience - OAuth 2.0 audience identifier
 * @param {text[]} pScopes - Array of scope codes
 * @param {text} pAccessType - 'online' or 'offline' (defaults to 'online')
 * @param {text} pRedirectURI - OAuth 2.0 redirect URI
 * @param {text} pState - OAuth 2.0 state parameter for CSRF protection
 * @return {bigint} Newly created OAuth 2.0 session identifier
 * @since 1.0.0
 */
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
/**
 * @brief Create an OAuth 2.0 session from a space-separated scope string.
 * @param {integer} pAudience - OAuth 2.0 audience identifier
 * @param {text} pScope - Space-separated scope codes
 * @param {text} pAccessType - 'online' or 'offline' (defaults to 'online')
 * @param {text} pRedirectURI - OAuth 2.0 redirect URI
 * @param {text} pState - OAuth 2.0 state parameter
 * @return {bigint} Newly created OAuth 2.0 session identifier
 * @see ScopeToArray
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateOAuth2 (
  pAudience     integer,
  pScope        text,
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
/**
 * @brief Creates an OAuth 2.0 session using the system client ID and default scope.
 * @param {text} pScope - Scope code (defaults to the primary scope or database name)
 * @return {bigint} Newly created OAuth 2.0 session identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateSystemOAuth2 (
  pScope        text DEFAULT null
) RETURNS       bigint
AS $$
BEGIN
  IF pScope IS NULL THEN
    SELECT code INTO pScope FROM db.scope WHERE id = '00000000-0000-4006-a000-000000000000';
  END IF;

  RETURN CreateOAuth2(GetAudience(oauth2_system_client_id()), coalesce(pScope, current_database()));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateTokenHeader -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a token header record linking an OAuth 2.0 session to a client session.
 * @param {bigint} pOAuth2 - OAuth 2.0 session identifier
 * @param {varchar} pSession - Client session code
 * @param {text} pSalt - Authentication salt
 * @param {text} pAgent - User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {bigint} Newly created token header identifier
 * @since 1.0.0
 */
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
/**
 * @brief Adds or updates a token in the temporal token store.
 *        If the current date range matches, updates the token value in place;
 *        otherwise closes the old range and inserts a new record.
 * @param {bigint} pHeader - Token header identifier
 * @param {char} pType - Token type: 'C' = authorization code, 'A' = access, 'R' = refresh, 'I' = id
 * @param {text} pToken - Token string value
 * @param {timestamptz} pDateFrom - Validity start
 * @param {timestamptz} pDateTo - Validity end
 * @return {bigint} Token record identifier
 * @since 1.0.0
 */
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
  dtDateFrom    timestamptz;
  dtDateTo      timestamptz;
BEGIN
  -- Find the existing token record in the current date range
  SELECT id, validFromDate, validToDate INTO nId, dtDateFrom, dtDateTo
    FROM db.token
   WHERE header = pHeader
     AND type = pType
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- Update the token value within the current date range
    UPDATE db.token SET token = pToken
     WHERE header = pHeader
       AND type = pType
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- Close the current date range and insert a new record
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
/**
 * @brief Creates a new authorization code token with a header and random 48-byte secret.
 * @param {bigint} pOAuth2 - OAuth 2.0 session identifier
 * @param {varchar} pSession - Client session code
 * @param {text} pSalt - Authentication salt
 * @param {text} pAgent - User-Agent string
 * @param {inet} pHost - Client IP address
 * @param {timestamptz} pCreated - Token creation timestamp
 * @return {bigint} Token header identifier
 * @since 1.0.0
 */
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
/**
 * @brief Issues a full OAuth 2.0 token set (access, optional refresh, optional id_token)
 *        for the given token header and audience.
 * @param {integer} pAudience - OAuth 2.0 audience identifier
 * @param {bigint} pHeader - Token header identifier
 * @param {timestamptz} pDateFrom - Token validity start (defaults to now)
 * @param {timestamptz} pDateTo - Token validity end (defaults to now + 1 hour)
 * @return {jsonb} JSON object with session, secret, access_token, token_type, expires_in, scope,
 *                 and optionally refresh_token, id_token, state
 * @since 1.0.0
 */
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
    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'The OAuth 2.0 params was not FOUND.'));
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
/**
 * @brief Exchanges an authorization code or refresh token for a new token set.
 *        Marks single-use tokens (code, refresh) as used.
 * @param {integer} pAudience - OAuth 2.0 audience identifier
 * @param {text} pToken - Token string to exchange
 * @param {interval} pInterval - Validity duration for new tokens (defaults to '1 hour')
 * @param {char} pType - Token type to exchange: 'A', 'C', 'R', or 'I' (defaults to 'A')
 * @return {json} New token set or error JSON object
 * @since 1.0.0
 */
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
  vHash         text;
BEGIN
  vHash := GetTokenHash(pToken, GetSecretKey());

  SELECT h.id, t.id INTO nHeader, nToken
    FROM db.token t INNER JOIN db.token_header h ON h.id = t.header AND t.type = pType AND NOT (pType = 'C' AND t.used IS NOT NULL)
   WHERE t.hash = vHash
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

    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_grant', 'message', format('Malformed %s', vType)));
  END IF;

  IF pType IN ('C', 'R') THEN
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
/**
 * @brief Exchanges an authorization code for a full token set.
 * @param {integer} pAudience - OAuth 2.0 audience identifier
 * @param {text} pCode - Authorization code to exchange
 * @param {interval} pInterval - Token validity duration (defaults to '1 hour')
 * @return {jsonb} Token set JSON
 * @see ExchangeToken
 * @since 1.0.0
 */
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
/**
 * @brief Exchanges a refresh token for a new token set.
 * @param {integer} pAudience - OAuth 2.0 audience identifier
 * @param {text} pRefresh - Refresh token to exchange
 * @param {interval} pInterval - Token validity duration (defaults to '1 hour')
 * @return {json} New token set JSON
 * @see ExchangeToken
 * @since 1.0.0
 */
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
/**
 * @brief Retrieve a token string by its record identifier.
 * @param {bigint} pId - Token record identifier
 * @return {text} Token string value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetToken (
  pId       bigint
) RETURNS   text
AS $$
  SELECT token FROM db.token WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAccessToken --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieves a valid access token for the user, or creates a new one via SignIn
 *        if no active token exists and the user has an OAuth 2.0 audience configured.
 * @param {text} pUserName - Username (login)
 * @param {text} pPassword - Password
 * @return {text} JWT access token, or NULL on failure
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAccessToken (
  pUserName     text,
  pPassword     text
) RETURNS       text
AS $$
DECLARE
  uUserId       uuid;

  vToken        text;
  vSession      text;

  nAudience     int;
BEGIN
  uUserId := GetUser(pUserName);

  SELECT code INTO vSession FROM db.session WHERE userid = uUserId ORDER BY created DESC LIMIT 1;

  SELECT token INTO vToken
    FROM db.token_header h INNER JOIN db.token t ON h.id = t.header AND t.type = 'A'
   WHERE h.session = vSession
     AND t.validFromDate <= Now()
     AND t.validtoDate > Now();

  IF vToken IS NULL THEN
    SELECT id INTO nAudience FROM oauth2.audience WHERE code = pUserName;
    IF FOUND THEN
      vSession := SignIn(CreateOAuth2(nAudience, ScopeToArray(null), 'offline'), pUserName, pPassword);
      SELECT t->>'access_token' INTO vToken FROM CreateToken(nAudience, oauth2_current_code(vSession), INTERVAL '1 day') AS t;
    END IF;
  END IF;

  RETURN vToken;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SafeSetVar ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Safely sets a session-level configuration variable under the 'current.' namespace.
 * @param {text} pName - Variable name (without 'current.' prefix)
 * @param {text} pValue - Value to set
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SafeSetVar (
  pName         text,
  pValue        text
) RETURNS       void
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
/**
 * @brief Safely retrieves a session-level configuration variable from the 'current.' namespace.
 *        Returns NULL if the variable does not exist or is empty.
 * @param {text} pName - Variable name (without 'current.' prefix)
 * @return {text} Variable value, or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SafeGetVar (
  pName     text
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
/**
 * @brief Retrieve the secret key from session variables, falling back to a default key.
 * @param {text} pName - Variable name (defaults to 'key')
 * @return {text} Secret key string
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetSecretKey (
  pName         text DEFAULT 'key'
) RETURNS       text
AS $$
DECLARE
  vDefaultKey   text DEFAULT 'MYXIWngoebYUkOPlGYdXuy6n';
  vSecretKey    text DEFAULT SafeGetVar(pName);
BEGIN
  RETURN coalesce(vSecretKey, vDefaultKey);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   IMMUTABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oauth2_system_client_id --------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the system OAuth 2.0 client identifier (equals the current database name).
 * @return {text} OAuth 2.0 client_id
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION oauth2_system_client_id()
RETURNS         text
AS $$
BEGIN
  RETURN current_database();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetOAuth2ClientId --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Stores the OAuth 2.0 client_id in the session variable.
 * @param {text} pClientId - OAuth 2.0 client_id
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetOAuth2ClientId (
  pClientId     text
) RETURNS       void
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
/**
 * @brief Retrieve the OAuth 2.0 client_id stored in the session variable.
 * @return {text} OAuth 2.0 client_id
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetOAuth2ClientId()
RETURNS         text
AS $$
BEGIN
  RETURN SafeGetVar('client_id');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oauth2_current_client_id -------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current OAuth 2.0 client identifier from the session.
 * @return {text} OAuth 2.0 client_id
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION oauth2_current_client_id()
RETURNS         text
AS $$
BEGIN
  RETURN GetOAuth2ClientId();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetLogMode ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Enables or disables logging mode for the current session.
 * @param {boolean} pValue - true to enable, false to disable
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetLogMode (
  pValue        boolean
) RETURNS       void
AS $$
BEGIN
  PERFORM SafeSetVar('log', pValue::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetLogMode ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current logging mode (defaults to true).
 * @return {boolean} true if logging is enabled
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetLogMode()
RETURNS         boolean
AS $$
BEGIN
  RETURN coalesce(SafeGetVar('log')::boolean, true);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetDebugMode -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Enables or disables debug mode for the current session.
 * @param {boolean} pValue - true to enable, false to disable
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetDebugMode (
  pValue        boolean
) RETURNS       void
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
/**
 * @brief Retrieve the current debug mode (defaults to false).
 * @return {boolean} true if debug mode is enabled
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetDebugMode()
RETURNS         boolean
AS $$
BEGIN
  RETURN coalesce(SafeGetVar('debug')::boolean, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetCurrentSession --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Stores the current session code in a session variable.
 * @param {text} pValue - Session code
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetCurrentSession (
  pValue        text
) RETURNS       void
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
/**
 * @brief Retrieve the current session code from the session variable.
 * @return {text} Session code, or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetCurrentSession()
RETURNS         text
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
/**
 * @brief Stores the current user identifier in a session variable.
 * @param {uuid} pValue - User identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetCurrentUserId (
  pValue        uuid
) RETURNS       void
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
/**
 * @brief Retrieve the current user identifier from the session variable.
 * @return {uuid} User identifier, or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetCurrentUserId()
RETURNS         uuid
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
 * @brief Retrieve the current session code, validated against the session table.
 * @return {text} Session code, or NULL if no valid session exists
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_session()
RETURNS         text
AS $$
DECLARE
  vCode         text;
  vSession      text;
BEGIN
  vCode := GetCurrentSession();
  IF vCode IS NOT NULL THEN
    SELECT code INTO vSession FROM db.session WHERE code = vCode;
    IF FOUND THEN
      RETURN vSession;
    END IF;
  END IF;
  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_secret -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the secret key for a session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {text} Session secret key
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION session_secret (
  pSession      varchar DEFAULT current_session()
)
RETURNS         text
AS $$
DECLARE
  vSecret       text;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT secret INTO vSecret FROM db.session WHERE code = pSession;
  END IF;
  RETURN vSecret;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_scope ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the scope identifier for the current session's area.
 *        Falls back to the default scope if no session is active.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {uuid} Scope identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_scope (
  pSession      varchar DEFAULT current_session()
)
RETURNS         uuid
AS $$
DECLARE
  uArea         uuid;
  uScope        uuid;
BEGIN
  SELECT area INTO uArea FROM db.session WHERE code = pSession;

  IF FOUND THEN
    SELECT scope INTO uScope FROM db.area WHERE id = uArea;
  ELSE
    uScope := '00000000-0000-4006-a000-000000000000';
  END IF;

  RETURN uScope;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_scope_code -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the scope code for the current session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {text} Scope code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_scope_code (
  pSession      varchar DEFAULT current_session()
)
RETURNS         text
AS $$
  SELECT code FROM db.scope WHERE id = current_scope(pSession);
$$ LANGUAGE sql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetOAuth2Scopes ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolves OAuth 2.0 scope codes to scope UUIDs, including aliases.
 * @param {bigint} pOAuth2 - OAuth 2.0 session identifier
 * @return {SETOF uuid} Set of scope identifiers
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetOAuth2Scopes (
  pOAuth2       bigint
)
RETURNS         SETOF uuid
AS $$
DECLARE
  i             integer;
  uScope        uuid;
  arScopes      text[];
BEGIN
  SELECT scopes INTO arScopes FROM db.oauth2 WHERE id = pOAuth2;

  IF arScopes IS NOT NULL THEN
    FOR i IN 1..array_length(arScopes, 1)
    LOOP
      SELECT id INTO uScope FROM db.scope WHERE code = arScopes[i];
      IF FOUND THEN
        RETURN NEXT uScope;
      ELSE
        SELECT scope INTO uScope FROM db.scope_alias WHERE code = arScopes[i];
        IF FOUND THEN
          RETURN NEXT uScope;
        END IF;
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
/**
 * @brief Fetch all scope identifiers for the current session's OAuth 2.0 parameters.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {SETOF uuid} Set of scope identifiers
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_scopes (
  pSession      varchar DEFAULT current_session()
)
RETURNS         SETOF uuid
AS $$
DECLARE
  nOAuth2       bigint;
BEGIN
  SELECT oauth2 INTO nOAuth2 FROM db.session WHERE code = pSession;
  RETURN QUERY SELECT * FROM GetOAuth2Scopes(nOAuth2);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_area -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the area identifier for the given session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {text} Area identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION session_area (
  pSession      varchar DEFAULT current_session()
)
RETURNS         text
AS $$
DECLARE
  vArea         text;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT area INTO vArea FROM db.session WHERE code = pSession;
  END IF;
  RETURN vArea;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_agent ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the User-Agent string for the given session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {text} User-Agent string
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION session_agent (
  pSession      varchar DEFAULT current_session()
)
RETURNS         text
AS $$
DECLARE
  vAgent        text;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT agent INTO vAgent FROM db.session WHERE code = pSession;
  END IF;
  RETURN vAgent;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_host -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the client IP address for the given session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {text} IP address as text
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION session_host (
  pSession      varchar DEFAULT current_session()
)
RETURNS         text
AS $$
DECLARE
  iHost         inet;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT host INTO iHost FROM db.session WHERE code = pSession;
  END IF;
  RETURN host(iHost);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_userid -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the original (substitute-aware) user identifier for the session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {uuid} User identifier (suid field)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION session_userid (
  pSession      varchar DEFAULT current_session()
)
RETURNS         uuid
AS $$
DECLARE
  uUserId       uuid;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT suid INTO uUserId FROM db.session WHERE code = pSession;
  END IF;
  RETURN uUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_userid -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the current user identifier from session if not cached.
 * @return {uuid} Current user identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_userid()
RETURNS         uuid
AS $$
DECLARE
  uUserId       uuid;
  vSession      text;
BEGIN
  uUserId := GetCurrentUserId();
  IF uUserId IS NULL THEN
    vSession := current_session();
    IF vSession IS NOT NULL THEN
      SELECT userid INTO uUserId FROM db.session WHERE code = vSession;
      PERFORM SetCurrentUserId(uUserId);
    END IF;
  END IF;
  RETURN uUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_username ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the username for the given session's user.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {text} Username
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION session_username (
  pSession      varchar DEFAULT current_session()
)
RETURNS         text
AS $$
  SELECT username FROM db.user WHERE id = session_userid(pSession) AND type = 'U';
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_username ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the username of the currently authenticated user.
 * @return {text} Username
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_username ()
RETURNS         text
AS $$
  SELECT username FROM db.user WHERE id = current_userid();
$$ LANGUAGE sql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oauth2_current_code ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current valid OAuth 2.0 authorization code for the session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {text} Authorization code token, or NULL if expired/absent
 * @since 1.0.0
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
/**
 * @brief Updates the area for the given session.
 * @param {uuid} pArea - Area identifier
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetSessionArea (
  pArea         uuid,
  pSession      varchar DEFAULT current_session()
) RETURNS       void
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
/**
 * @brief Retrieve the area identifier for the given session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {uuid} Area identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetSessionArea (
  pSession      varchar DEFAULT current_session()
)
RETURNS         uuid
AS $$
  SELECT area FROM db.session WHERE code = pSession;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_area_type --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the area type for the current session's area.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {uuid} Area type identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_area_type (
  pSession      varchar DEFAULT current_session()
)
RETURNS         uuid
AS $$
  SELECT type FROM db.area WHERE id = GetSessionArea(pSession);
$$ LANGUAGE sql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_area -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the current area, falling back to the default guest area.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {uuid} Area identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_area (
  pSession      varchar DEFAULT current_session()
)
RETURNS         uuid
AS $$
BEGIN
  RETURN coalesce(GetSessionArea(pSession), '00000000-0000-4003-a000-000000000002');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionInterface ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates the interface for the given session.
 * @param {uuid} pInterface - Interface identifier
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetSessionInterface (
  pInterface    uuid,
  pSession      varchar DEFAULT current_session()
) RETURNS       void
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
/**
 * @brief Retrieve the interface identifier for the given session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {uuid} Interface identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetSessionInterface (
  pSession      varchar DEFAULT current_session()
)
RETURNS         uuid
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
/**
 * @brief Resolve the current interface, falling back to the default guest interface.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {uuid} Interface identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_interface (
  pSession      varchar DEFAULT current_session()
)
RETURNS         uuid
AS $$
BEGIN
  RETURN coalesce(GetSessionInterface(pSession), '00000000-0000-4004-a000-000000000003');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetOperDate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sets the operational date for the given session.
 * @param {timestamptz} pOperDate - Operational (business) date
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetOperDate (
  pOperDate     timestamptz,
  pSession      varchar DEFAULT current_session()
) RETURNS       void
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
 * @brief Retrieve the operational date for the given session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {timestamptz} Operational date, or NULL if not set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetOperDate (
  pSession      varchar DEFAULT current_session()
)
RETURNS         timestamptz
AS $$
DECLARE
  dtOperDate    timestamptz;
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
 * @brief Resolve the operational date, falling back to now() if not set.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {timestamptz} Operational date
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION oper_date (
  pSession      varchar DEFAULT current_session()
)
RETURNS         timestamptz
AS $$
DECLARE
  dtOperDate    timestamptz;
BEGIN
  dtOperDate := GetOperDate(pSession);
  IF dtOperDate IS NULL THEN
    dtOperDate := now();
  END IF;
  RETURN dtOperDate;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionLocale ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sets the session locale by identifier and persists it as the user's default.
 * @param {uuid} pLocale - Locale identifier
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetSessionLocale (
  pLocale       uuid,
  pSession      varchar DEFAULT current_session()
) RETURNS       void
AS $$
DECLARE
  uUserId       uuid;
BEGIN
  UPDATE db.session SET locale = pLocale WHERE code = pSession;
  SELECT userid INTO uUserId FROM db.session WHERE code = pSession;
  PERFORM SetDefaultLocale(pLocale, uUserId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionLocale ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the session locale by language code (e.g. 'en', 'ru').
 * @param {text} pCode - Locale code (defaults to 'ru')
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetSessionLocale (
  pCode         text DEFAULT 'ru',
  pSession      varchar DEFAULT current_session()
) RETURNS       void
AS $$
DECLARE
  uLocale       uuid;
BEGIN
  SELECT id INTO uLocale FROM db.locale WHERE code = pCode;
  IF FOUND THEN
    PERFORM SetSessionLocale(uLocale, pSession);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionLocale ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the locale identifier for the given session.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {uuid} Locale identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetSessionLocale (
  pSession      varchar DEFAULT current_session()
) RETURNS       uuid
AS $$
  SELECT locale FROM db.session WHERE code = pSession;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION locale_code --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the locale code for the current session, falling back to system config then 'ru'.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {text} Locale code (e.g. 'en', 'ru')
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION locale_code (
  pSession      varchar DEFAULT current_session()
) RETURNS       text
AS $$
DECLARE
  vCode         text;
BEGIN
  SELECT code INTO vCode FROM db.locale WHERE id = GetSessionLocale(pSession);

  IF vCode IS NULL THEN
    vCode := RegGetValueString('CURRENT_CONFIG', 'CONFIG\System', 'LocaleCode');
  END IF;

  RETURN coalesce(vCode, 'ru');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_locale -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the current locale identifier, falling back to the default Russian locale.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {uuid} Locale identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_locale (
  pSession      varchar DEFAULT current_session()
)
RETURNS         uuid
AS $$
BEGIN
  RETURN coalesce(GetSessionLocale(pSession), '00000000-0000-4001-a000-000000000002');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetDefaultLocale ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Persists the locale as the user's default in the current scope profile.
 * @param {uuid} pLocale - Locale identifier (defaults to current locale)
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetDefaultLocale (
  pLocale       uuid DEFAULT current_locale(),
  pUserId       uuid DEFAULT current_userid()
) RETURNS       void
AS $$
BEGIN
  UPDATE db.profile SET locale = pLocale WHERE userid = pUserId AND scope = current_scope();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultLocale ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the user's default locale from the current scope profile.
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @return {uuid} Locale identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetDefaultLocale (
  pUserId       uuid DEFAULT current_userid()
) RETURNS       uuid
AS $$
DECLARE
  uLocale       uuid;
BEGIN
  SELECT locale INTO uLocale FROM db.profile WHERE userid = pUserId AND scope = current_scope();

  IF NOT FOUND THEN
    uLocale := current_locale();
  END IF;

  RETURN uLocale;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetLocale -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sets the locale for both the session and the user's profile in the current scope.
 * @param {uuid} pLocale - Locale identifier
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetLocale (
  pLocale       uuid,
  pUserId       uuid DEFAULT current_userid(),
  pSession      varchar DEFAULT current_session()
) RETURNS       void
AS $$
BEGIN
  UPDATE db.session SET locale = pLocale WHERE code = pSession;
  UPDATE db.profile SET locale = pLocale WHERE userid = pUserId AND scope = current_scope();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_application ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the application identifier for the current session's OAuth 2.0 audience.
 * @param {text} pSession - Session code (defaults to current session)
 * @return {integer} Application identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_application (
  pSession      text DEFAULT current_session()
) RETURNS       integer
AS $$
DECLARE
  nOAuth2       bigint;
  nAudience     integer;
  nApplication  integer;
BEGIN
  SELECT oauth2 INTO nOAuth2 FROM db.session WHERE code = pSession;
  SELECT audience INTO nAudience FROM db.oauth2 WHERE id = nOAuth2;
  SELECT application INTO nApplication FROM oauth2.audience WHERE id = nAudience;

  RETURN nApplication;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_application_code -------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the application code for the current session.
 * @param {integer} pApplication - Application identifier (defaults to current application)
 * @return {text} Application code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION current_application_code (
  pApplication  integer DEFAULT current_application()
) RETURNS       text
AS $$
BEGIN
  RETURN GetApplicationCode(pApplication);
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION acl ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Computes the aggregated ACL bitmask for a user, including inherited group permissions.
 *        Returns deny, allow, and effective mask (allow AND NOT deny).
 * @param {uuid} pUserId - User identifier
 * @param {bit varying} deny - (OUT) Aggregated deny bits
 * @param {bit varying} allow - (OUT) Aggregated allow bits
 * @param {bit varying} mask - (OUT) Effective permission mask
 * @return {SETOF record} Single row with (deny, allow, mask)
 * @since 1.0.0
 */
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
  SELECT bit_or(a.deny), bit_or(a.allow), bit_or(a.allow) & ~bit_or(a.deny)
    FROM db.acl a INNER JOIN mg ON a.userid = mg.userid;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAccessControlListMask ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the effective ACL bitmask for the given user.
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @return {bit varying} Effective permission mask
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAccessControlListMask (
  pUserId       uuid DEFAULT current_userid()
) RETURNS       bit varying
AS $$
  SELECT mask FROM acl(pUserId)
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckAccessControlList ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Checks whether the user has the required ACL permission bits set.
 * @param {bit} pMask - Required permission bits
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @return {boolean} true if all required bits are present in the effective mask
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckAccessControlList (
  pMask         bit,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       boolean
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
/**
 * @brief Sets the ACL bitmask for a user or group.
 *        Requires administrator role unless called by the kernel.
 *        Passing an all-zero mask deletes the ACL entry.
 * @param {bit varying} pMask - Access mask (d:{sLlEIDUCpducoi}a:{sLlEIDUCpducoi})
 *   where d = deny bits, a = allow bits:
 *   13: s - substitute user
 *   12: L - unlock user
 *   11: l - lock user
 *   10: E - exclude user from group
 *   09: I - include user to group
 *   08: D - delete group
 *   07: U - update group
 *   06: C - create group
 *   05: p - set user password
 *   04: d - delete user
 *   03: u - update user
 *   02: c - create user
 *   01: o - logout
 *   00: i - login
 * @param {uuid} pUserId - User or group identifier (defaults to current user)
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks administrator role
 * @since 1.0.0
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
 * @brief Substitutes the active user in the current session with another user.
 *        Requires the 'substitute user' ACL bit and the current user's password.
 * @param {uuid} pUserId - Target user identifier to switch to
 * @param {text} pPassword - Current user's password for verification
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks substitute permission
 * @throws ERR-40300 if password verification fails
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SubstituteUser (
  pUserId       uuid,
  pPassword     text,
  pSession      varchar DEFAULT current_session()
) RETURNS       void
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
 * @brief Substitute the active user by username.
 * @param {text} pRoleName - Target username to switch to
 * @param {text} pPassword - Current user's password for verification
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {void}
 * @see SubstituteUser(uuid, text, varchar)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SubstituteUser (
  pRoleName     text,
  pPassword     text,
  pSession      varchar DEFAULT current_session()
) RETURNS       void
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
 * @brief Checks whether a user belongs to a given role (group).
 * @param {uuid} pRoleId - Role (group) identifier
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @return {boolean} true if the user is a member of the role
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsUserRole (
  pRoleId       uuid,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       boolean
AS $$
DECLARE
  uId           uuid;
BEGIN
  SELECT member INTO uId FROM db.member_group WHERE userid = pRoleId AND member = pUserId;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE STRICT
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsUserRole ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check role membership by username strings.
 * @param {text} pRole - Role (group) username
 * @param {text} pUser - User username (defaults to current username)
 * @return {boolean} true if the user is a member of the role
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsUserRole (
  pRole         text,
  pUser         text DEFAULT current_username()
) RETURNS       boolean
AS $$
DECLARE
  uUserId       uuid;
  nRoleId       uuid;
BEGIN
  SELECT id INTO uUserId FROM db.user WHERE username = pUser AND type = 'U';
  SELECT id INTO nRoleId FROM db.user WHERE username = pRole AND type = 'G';

  RETURN IsUserRole(nRoleId, uUserId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE STRICT
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsAdmin ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Checks whether the user is a member of the 'administrator' group.
 * @param {uuid} pMember - User identifier (defaults to current user)
 * @return {boolean} true if the user is an administrator
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsAdmin (
  pMember       uuid DEFAULT current_userid()
) RETURNS       boolean
AS $$
BEGIN
  PERFORM FROM db.member_group WHERE userid = '00000000-0000-4000-a000-000000000001'::uuid AND member = pMember;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE STRICT
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- is_admin --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Checks whether the user is an administrator or the apibot service account.
 * @param {uuid} pMember - User identifier (defaults to current user)
 * @return {boolean} true if admin or apibot
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION is_admin (
  pMember       uuid DEFAULT current_userid()
) RETURNS       boolean
AS $$
BEGIN
  IF pMember IS NULL THEN
    RETURN false;
  END IF;

  RETURN IsAdmin(pMember) OR current_userid() = '00000000-0000-4000-a002-000000000001'::uuid;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a new user account with profile, default interface memberships, and password.
 *        Requires the 'create user' ACL bit.
 * @param {text} pRoleName - Username (login)
 * @param {text} pPassword - Password (if NULL, an auto-generated password is used)
 * @param {text} pName - Full display name
 * @param {text} pPhone - Phone number
 * @param {text} pEmail - Email address
 * @param {text} pDescription - Description
 * @param {boolean} pPasswordChange - Force password change on next login
 * @param {boolean} pPasswordNotChange - Prevent user from changing own password
 * @param {uuid} pId - User identifier (defaults to auto-generated)
 * @return {uuid} Newly created user identifier
 * @throws ACCESS_DENIED if caller lacks create user permission
 * @throws RoleExists if username already exists
 * @since 1.0.0
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
  pId                   uuid DEFAULT gen_kernel_uuid('a')
) RETURNS               uuid
AS $$
DECLARE
  uId                   uuid;
  uScope                uuid;
  vSecret               text;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT CheckAccessControlList(B'00000000000100') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO uId FROM db.user WHERE username = lower(pRoleName) AND type = 'U';

  IF FOUND THEN
    PERFORM RoleExists(pRoleName);
  END IF;

  INSERT INTO db.user (id, type, username, name, phone, email, description, passwordchange, passwordnotchange)
  VALUES (pId, 'U', pRoleName, pName, pPhone, pEmail, pDescription, pPasswordChange, pPasswordNotChange)
  RETURNING secret INTO vSecret;

  PERFORM AddMemberToInterface(pId, '00000000-0000-4004-a000-000000000000'); -- all
  PERFORM AddMemberToInterface(pId, '00000000-0000-4004-a000-000000000003'); -- guest

  SELECT scope INTO uScope FROM db.area WHERE id = current_area();

  INSERT INTO db.profile (userid, scope, locale, area, interface)
  VALUES (pId, uScope, current_locale(), current_area(), '00000000-0000-4004-a000-000000000003');

  IF NULLIF(pPassword, '') IS NULL THEN
    pPassword := encode(hmac(vSecret, GetSecretKey(), 'sha1'), 'hex');
  END IF;

  PERFORM SetPassword(pId, pPassword);

  PERFORM DoCreateRole(pId);

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- CreateGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a new group. Requires the 'create group' ACL bit.
 * @param {text} pRoleName - Group username
 * @param {text} pName - Group display name
 * @param {text} pDescription - Description
 * @param {uuid} pId - Group identifier (defaults to auto-generated)
 * @return {uuid} Newly created group identifier
 * @throws ACCESS_DENIED if caller lacks create group permission
 * @throws RoleExists if group name already exists
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateGroup (
  pRoleName     text,
  pName         text,
  pDescription  text,
  pId           uuid DEFAULT gen_kernel_uuid('a')
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT CheckAccessControlList(B'00000001000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO uId FROM groups WHERE username = lower(pRoleName);

  IF FOUND THEN
    PERFORM RoleExists(pRoleName);
  END IF;

  INSERT INTO db.user (id, type, username, name, description)
  VALUES (pId, 'G', pRoleName, pName, pDescription);

  PERFORM DoCreateRole(pId);

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates a user account. NULL parameters are left unchanged.
 *        Requires the 'update user' ACL bit when updating another user.
 * @param {uuid} pId - User identifier
 * @param {text} pRoleName - New username
 * @param {text} pPassword - New password
 * @param {text} pName - Full display name
 * @param {text} pPhone - Phone number
 * @param {text} pEmail - Email address
 * @param {text} pDescription - Description
 * @param {boolean} pPasswordChange - Force password change on next login
 * @param {boolean} pPasswordNotChange - Prevent user from changing own password
 * @return {void}
 * @throws UserNotFound if user does not exist
 * @throws ACCESS_DENIED if caller lacks update permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UpdateUser (
  pId                   uuid,
  pRoleName             text DEFAULT null,
  pPassword             text DEFAULT null,
  pName                 text DEFAULT null,
  pPhone                text DEFAULT null,
  pEmail                text DEFAULT null,
  pDescription          text DEFAULT null,
  pPasswordChange       boolean DEFAULT null,
  pPasswordNotChange    boolean DEFAULT null
) RETURNS               void
AS $$
DECLARE
  r                        db.user%rowtype;
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

    IF r.readonly THEN
      PERFORM ReadOnlyError();
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

  pPasswordChange := coalesce(pPasswordChange, r.passwordchange);
  pPasswordNotChange := coalesce(pPasswordNotChange, r.passwordnotchange);

  UPDATE db.user
     SET username = coalesce(pRoleName, username),
         name = coalesce(pName, username),
         phone = CheckNull(pPhone),
         email = CheckNull(pEmail),
         description = CheckNull(coalesce(pDescription, r.description, '')),
         passwordchange = pPasswordChange,
         passwordnotchange = pPasswordNotChange
   WHERE id = pId;

  IF NULLIF(pPassword, '') IS NOT NULL THEN
    PERFORM SetPassword(pId, pPassword);
  END IF;

  PERFORM DoUpdateRole(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates a group record. Requires the 'update group' ACL bit.
 * @param {uuid} pId - Group identifier
 * @param {text} pRoleName - New group username
 * @param {text} pName - New display name
 * @param {text} pDescription - New description
 * @return {void}
 * @throws UserNotFound if group does not exist
 * @throws ACCESS_DENIED if caller lacks update group permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UpdateGroup (
  pId           uuid,
  pRoleName     text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
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

  PERFORM DoUpdateRole(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Deletes a user account and all related data (sessions, profiles, memberships, ACL).
 *        Reassigns owned objects to the administrator. Requires the 'delete user' ACL bit.
 * @param {uuid} pId - User identifier
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks delete user permission
 * @throws DeleteUserError if trying to delete the current user
 * @throws SystemRoleError if user corresponds to a PostgreSQL system role
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteUser (
  pId           uuid
) RETURNS       void
AS $$
DECLARE
  vUserName     text;
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

    PERFORM DoDeleteRole(pId);

    UPDATE db.object SET oper = '00000000-0000-4000-a000-000000000001' WHERE oper = pId;
    UPDATE db.object SET owner = '00000000-0000-4000-a000-000000000001' WHERE owner = pId;
    UPDATE db.object SET suid = '00000000-0000-4000-a000-000000000001' WHERE suid = pId;

    UPDATE db.file SET owner = '00000000-0000-4000-a000-000000000001' WHERE owner = pId;

    DELETE FROM db.acl WHERE userid = pId;
    DELETE FROM db.aou WHERE userid = pId;

    DELETE FROM db.member_area WHERE member = pId;
    DELETE FROM db.member_interface WHERE member = pId;
    DELETE FROM db.member_group WHERE member = pId;
    DELETE FROM db.notice WHERE userid = pId;
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
 * @brief Delete a user account by username.
 * @param {text} pRoleName - Username (login)
 * @return {void}
 * @see DeleteUser(uuid)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteUser (
  pRoleName     text
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
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
 * @brief Deletes a group and all its memberships. Requires the 'delete group' ACL bit.
 * @param {uuid} pId - Group identifier
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks delete group permission
 * @throws SystemRoleError if group corresponds to a PostgreSQL system role
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteGroup (
  pId           uuid
) RETURNS       void
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
 * @brief Delete a group by username.
 * @param {text} pRoleName - Group username
 * @return {void}
 * @see DeleteGroup(uuid)
 * @since 1.0.0
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
 * @brief Look up the user identifier by username. Raises an error if not found.
 * @param {text} pRoleName - Username (login)
 * @return {uuid} User identifier
 * @throws UserNotFound if the user does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetUser (
  pRoleName     text
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
BEGIN
  SELECT id INTO uId FROM db.user WHERE type = 'U' AND username = pRoleName;

  IF NOT FOUND THEN
    PERFORM UserNotFound(pRoleName);
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetGroup --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the group identifier by group name. Raises an error if not found.
 * @param {text} pRoleName - Group username
 * @return {uuid} Group identifier
 * @throws UnknownRoleName if the group does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetGroup (
  pRoleName     text
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
BEGIN
  SELECT id INTO uId FROM db.user WHERE type = 'G' AND username = pRoleName;

  IF NOT FOUND THEN
    PERFORM UnknownRoleName(pRoleName);
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetPassword -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sets the password for a user (bcrypt hash with md5 salt).
 *        Requires 'set password' ACL bit when setting another user's password.
 *        Logs the password change event.
 * @param {uuid} pId - User identifier
 * @param {text} pPassword - New password in plain text
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks set password permission
 * @throws UserPasswordChange if user is not allowed to change own password
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetPassword (
  pId               uuid,
  pPassword         text
) RETURNS           void
AS $$
DECLARE
  uUserId           uuid;
  bPasswordChange   boolean;
  r                 record;
BEGIN
  uUserId := current_userid();

  SELECT username, passwordchange, passwordnotchange, readonly INTO r FROM db.user WHERE id = pId AND type = 'U';

  IF session_user <> 'kernel' THEN
    IF pId <> uUserId THEN
      IF NOT CheckAccessControlList(B'00000000100000') THEN
        PERFORM AccessDenied();
      END IF;
    END IF;

    IF r.readonly THEN
      PERFORM ReadOnlyError();
    END IF;
  END IF;

  IF FOUND THEN
    bPasswordChange := r.PasswordChange;

    IF pId = uUserId THEN
      IF r.PasswordNotChange THEN
        PERFORM UserPasswordChange();
      END IF;

      IF r.PasswordChange THEN
        bPasswordChange := false;
      END IF;
    END IF;

    UPDATE db.user
       SET passwordchange = bPasswordChange,
           pswhash = crypt(pPassword, gen_salt('bf'))
     WHERE id = pId;

    -- Invalidate all other sessions for this user (security: prevent stolen token reuse)
    DELETE FROM db.session WHERE userid = pId AND code <> current_session();

    IF session_user <> 'kernel' THEN
      INSERT INTO db.log (type, code, username, session, event, text)
      VALUES ('W', 2222, r.username, current_session(), 'password', 'Смена пароля.');
    END IF;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- ChangePassword --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Changes a user's password after verifying the old password.
 *        Also updates the PostgreSQL role password if the user has a system role.
 * @param {uuid} pId - User identifier
 * @param {text} pOldPass - Current password for verification
 * @param {text} pNewPass - New password
 * @return {boolean} true on success, false if verification failed
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ChangePassword (
  pId           uuid,
  pOldPass      text,
  pNewPass      text
) RETURNS       boolean
AS $$
DECLARE
  r             record;
BEGIN
  SELECT username, system INTO r FROM users WHERE id = pId AND scope = current_scope();

  IF FOUND THEN
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
 * @brief Locks a user account by setting the locked status bit.
 *        Requires the 'lock user' ACL bit when locking another user.
 * @param {uuid} pId - User identifier
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks lock user permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UserLock (
  pId           uuid
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
BEGIN
  IF session_user <> 'kernel' THEN
    IF pId <> current_userid() THEN
      IF NOT CheckAccessControlList(B'00100000000000') THEN
        PERFORM AccessDenied();
      END IF;
    END IF;
  END IF;

  SELECT id INTO uId FROM db.user WHERE id = pId AND type = 'U';

  IF FOUND THEN
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
 * @brief Unlocks a user account by resetting the status to 'open'.
 *        Requires the 'unlock user' ACL bit.
 * @param {uuid} pId - User identifier
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks unlock user permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UserUnLock (
  pId           uuid
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT CheckAccessControlList(B'01000000000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO uId FROM db.user WHERE id = pId AND type = 'U';

  IF FOUND THEN
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
 * @brief Adds a user to a group. Requires the 'include user to group' ACL bit.
 * @param {uuid} pMember - User identifier
 * @param {uuid} pGroup - Group identifier
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks membership permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddMemberToGroup (
  pMember       uuid,
  pGroup        uuid
) RETURNS       void
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
 * @brief Removes a user from a group, or from all groups if pGroup is NULL.
 *        Requires the 'exclude user from group' ACL bit.
 * @param {uuid} pMember - User identifier
 * @param {uuid} pGroup - Group identifier (NULL = remove from all groups)
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks membership permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteGroupForMember (
  pMember       uuid,
  pGroup        uuid DEFAULT null
) RETURNS       void
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
 * @brief Removes a member from a group, or all members if pMember is NULL.
 *        Requires the 'exclude user from group' ACL bit.
 * @param {uuid} pGroup - Group identifier
 * @param {uuid} pMember - User identifier (NULL = remove all members)
 * @return {void}
 * @throws ACCESS_DENIED if caller lacks membership permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteMemberFromGroup (
  pGroup        uuid,
  pMember       uuid DEFAULT null
) RETURNS       void
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
-- GetUsername -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a user's username by identifier.
 * @param {uuid} pId - User identifier
 * @return {text} Username, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetUsername (
  pId           uuid
) RETURNS       text
AS $$
  SELECT username FROM db.user WHERE id = pId AND type = 'U';
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetUserFullName -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a user's full display name by identifier.
 * @param {uuid} pId - User identifier
 * @return {text} Full name, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetUserFullName (
  pId           uuid
) RETURNS       text
AS $$
  SELECT name FROM db.user WHERE id = pId AND type = 'U';
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetGroupUsername ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a group's username by identifier.
 * @param {uuid} pId - Group identifier
 * @return {text} Group username, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetGroupUsername (
  pId           uuid
) RETURNS       text
AS $$
  SELECT username FROM db.user WHERE id = pId AND type = 'G';
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetGroupName ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a group's display name by identifier.
 * @param {uuid} pId - Group identifier
 * @return {text} Group name, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetGroupName (
  pId           uuid
) RETURNS       text
AS $$
  SELECT name FROM db.user WHERE id = pId AND type = 'G';
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateScope -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a new scope. Requires administrator role.
 * @param {text} pCode - Unique scope code
 * @param {text} pName - Scope display name
 * @param {text} pDescription - Description
 * @param {uuid} pId - Scope identifier (defaults to auto-generated)
 * @return {uuid} Newly created scope identifier
 * @throws ACCESS_DENIED if caller is not an administrator
 * @throws RecordExists if scope code already exists
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateScope (
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null,
  pId           uuid DEFAULT gen_kernel_uuid('8')
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
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
/**
 * @brief Updates a scope record. Requires administrator role. NULL params are left unchanged.
 * @param {uuid} pId - Scope identifier
 * @param {text} pCode - New scope code
 * @param {text} pName - New display name
 * @param {text} pDescription - New description
 * @return {void}
 * @throws ACCESS_DENIED if caller is not an administrator
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditScope (
  pId           uuid,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS void
AS $$
DECLARE
  vCode         text;
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
         description = CheckNull(coalesce(pDescription, description, ''))
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteScope -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Deletes a scope. Requires administrator role.
 * @param {uuid} pId - Scope identifier
 * @return {void}
 * @throws ACCESS_DENIED if caller is not an administrator
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteScope (
  pId           uuid
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
/**
 * @brief Resolve a scope code to its identifier.
 * @param {text} pCode - Scope code
 * @return {uuid} Scope identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetScope (
  pCode         text
) RETURNS       uuid
AS $$
  SELECT id FROM db.scope WHERE code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetScopeName ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a scope name by its identifier.
 * @param {uuid} pId - Scope identifier
 * @return {text} Scope name
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetScopeName (
  pId           uuid
) RETURNS       text
AS $$
  SELECT name FROM db.scope WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetAreaSequence ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Recursively sets the display sequence of an area, shifting siblings as needed.
 * @param {uuid} pId - Area identifier
 * @param {integer} pSequence - Target sequence number
 * @param {integer} pDelta - Shift direction for colliding siblings (+1 or -1; 0 = no shift)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetAreaSequence (
  pId           uuid,
  pSequence     integer,
  pDelta        integer
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
  uParent       uuid;
BEGIN
  IF pDelta <> 0 THEN
    SELECT parent INTO uParent FROM db.area WHERE id = pId;
    SELECT id INTO uId
      FROM db.area
     WHERE parent IS NOT DISTINCT FROM uParent
       AND sequence = pSequence
       AND id <> pId;

    IF FOUND THEN
      PERFORM SetAreaSequence(uId, pSequence + pDelta, pDelta);
    END IF;
  END IF;

  UPDATE db.area SET sequence = pSequence WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SortArea -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Re-numbers the sequence of all child areas under the given parent.
 * @param {uuid} pParent - Parent area identifier (NULL for root-level areas)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SortArea (
  pParent       uuid
) RETURNS       void
AS $$
DECLARE
  r             record;
BEGIN
  FOR r IN
    SELECT id, (row_number() OVER(order by sequence))::int as newsequence
      FROM db.area
     WHERE parent IS NOT DISTINCT FROM pParent
  LOOP
    PERFORM SetAreaSequence(r.id, r.newsequence, 0);
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateArea ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a new area in the hierarchy. Requires administrator role.
 * @param {uuid} pId - Area identifier (defaults to auto-generated)
 * @param {uuid} pParent - Parent area identifier (NULL for root children)
 * @param {uuid} pType - Area type identifier
 * @param {uuid} pScope - Scope identifier (defaults to current scope)
 * @param {text} pCode - Unique area code within the scope
 * @param {text} pName - Area display name
 * @param {text} pDescription - Description
 * @param {integer} pSequence - Display sequence (auto-assigned if NULL/0)
 * @return {uuid} Newly created area identifier
 * @throws ACCESS_DENIED if caller is not an administrator
 * @throws RecordExists if area code already exists in the scope
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateArea (
  pId           uuid,
  pParent       uuid,
  pType         uuid,
  pScope        uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null,
  pSequence     integer DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  nLevel        integer;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  nLevel := 0;
  pParent := CheckNull(pParent);
  pScope := coalesce(pScope, current_scope());

  SELECT id INTO uId FROM db.area WHERE scope = pScope AND code = pCode;
  IF FOUND THEN
    PERFORM RecordExists(pCode);
  END IF;

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.area WHERE id = pParent;
  END IF;

  IF NULLIF(pSequence, 0) IS NULL THEN
    SELECT max(sequence) + 1 INTO pSequence FROM db.area WHERE parent IS NOT DISTINCT FROM pParent;
  ELSE
    PERFORM SetAreaSequence(pParent, pSequence, 1);
  END IF;

  INSERT INTO db.area (id, parent, type, scope, code, name, description, level, sequence)
  VALUES (coalesce(pId, gen_kernel_uuid('8')), coalesce(pParent, GetAreaRoot()), pType, pScope, pCode, pName, pDescription, nLevel, coalesce(pSequence, 1))
  RETURNING Id INTO uId;

  PERFORM DoCreateArea(uId);

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditArea --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates an area record. Requires administrator role. NULL params are left unchanged.
 *        Re-sorts sibling areas when parent or sequence changes.
 * @param {uuid} pId - Area identifier
 * @param {uuid} pParent - New parent area
 * @param {uuid} pType - New area type
 * @param {uuid} pScope - New scope
 * @param {text} pCode - New area code
 * @param {text} pName - New display name
 * @param {text} pDescription - New description
 * @param {integer} pSequence - New display sequence
 * @param {timestamptz} pValidFromDate - Validity start
 * @param {timestamptz} pValidToDate - Validity end
 * @return {void}
 * @throws ACCESS_DENIED if caller is not an administrator
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditArea (
  pId               uuid,
  pParent           uuid DEFAULT null,
  pType             uuid DEFAULT null,
  pScope            uuid DEFAULT null,
  pCode             text DEFAULT null,
  pName             text DEFAULT null,
  pDescription      text DEFAULT null,
  pSequence         integer DEFAULT null,
  pValidFromDate    timestamptz DEFAULT null,
  pValidToDate      timestamptz DEFAULT null
) RETURNS void
AS $$
DECLARE
  vCode             text;
  uType             uuid;
  uParent           uuid;
  uScope            uuid;

  nLevel            integer;
  nSequence         integer;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT parent, type, code, level, scope, sequence INTO uParent, uType, vCode, nLevel, uScope, nSequence FROM db.area WHERE id = pId;
  IF NOT FOUND THEN
    PERFORM AreaError();
  END IF;

  pCode := coalesce(pCode, vCode);
  IF pCode <> vCode THEN
    SELECT code INTO vCode FROM db.area WHERE scope = coalesce(pScope, uScope, current_scope()) AND code = pCode;
    IF FOUND THEN
      PERFORM RecordExists(pCode);
    END IF;
  END IF;

  pParent := coalesce(CheckNull(pParent), uParent);
  pSequence := coalesce(pSequence, nSequence);

  UPDATE db.area
     SET parent = coalesce(pParent, parent),
         type = coalesce(pType, type),
         scope = coalesce(pScope, scope),
         code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = CheckNull(coalesce(pDescription, description, '')),
         level = coalesce(nLevel, level),
         sequence = pSequence,
         validFromDate = coalesce(pValidFromDate, validFromDate),
         validToDate = coalesce(pValidToDate, validToDate)
   WHERE id = pId;

  IF uParent IS DISTINCT FROM pParent THEN
    SELECT max(sequence) + 1 INTO nSequence FROM db.area WHERE parent IS NOT DISTINCT FROM pParent;
    PERFORM SortArea(uParent);
  END IF;

  IF pSequence < nSequence THEN
    PERFORM SetAreaSequence(pId, pSequence, 1);
  END IF;

  IF pSequence > nSequence THEN
    PERFORM SetAreaSequence(pId, pSequence, -1);
  END IF;

  PERFORM DoUpdateArea(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteArea ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Deletes an area. Requires administrator role.
 * @param {uuid} pId - Area identifier
 * @return {void}
 * @throws ACCESS_DENIED if caller is not an administrator
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteArea (
  pId           uuid
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

  PERFORM DoDeleteArea(pId);

  DELETE FROM db.area WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaScope ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the scope for the given area.
 * @param {uuid} pArea - Area identifier
 * @return {uuid} Scope identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAreaScope (
  pArea         uuid
) RETURNS       uuid
AS $$
  SELECT scope FROM db.area WHERE id = pArea;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetArea ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up an area identifier by code within a scope.
 * @param {text} pCode - Area code
 * @param {uuid} pScope - Scope identifier (defaults to current scope)
 * @return {uuid} Area identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetArea (
  pCode         text,
  pScope        uuid default current_scope()
) RETURNS       uuid
AS $$
  SELECT id FROM db.area WHERE scope = pScope AND code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaRoot -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the root area for the given scope.
 * @param {uuid} pScope - Scope identifier (defaults to current scope)
 * @return {uuid} Root area identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAreaRoot (
  pScope        uuid default current_scope()
) RETURNS       uuid
AS $$
  SELECT id FROM db.area WHERE scope = pScope AND type = '00000000-0000-4002-a000-000000000000';
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaSystem ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the system area for the given scope.
 * @param {uuid} pScope - Scope identifier (defaults to current scope)
 * @return {uuid} System area identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAreaSystem (
  pScope        uuid default current_scope()
) RETURNS       uuid
AS $$
  SELECT id FROM db.area WHERE scope = pScope AND type = '00000000-0000-4002-a000-000000000001';
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaGuest ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the guest area for the given scope.
 * @param {uuid} pScope - Scope identifier (defaults to current scope)
 * @return {uuid} Guest area identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAreaGuest (
  pScope        uuid default current_scope()
) RETURNS       uuid
AS $$
  SELECT id FROM db.area WHERE scope = pScope AND type = '00000000-0000-4002-a000-000000000002';
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaDefault --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the default area for the given scope.
 * @param {uuid} pScope - Scope identifier (defaults to current scope)
 * @return {uuid} Default area identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAreaDefault (
  pScope        uuid default current_scope()
) RETURNS       uuid
AS $$
  SELECT id FROM db.area WHERE scope = pScope AND type = '00000000-0000-4002-a001-000000000000';
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaCode -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve an area code by its identifier.
 * @param {uuid} pId - Area identifier
 * @return {text} Area code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAreaCode (
  pId           uuid
) RETURNS       text
AS $$
  SELECT code FROM db.area WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaName -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve an area name by its identifier.
 * @param {uuid} pId - Area identifier
 * @return {text} Area name
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAreaName (
  pId           uuid
) RETURNS       text
AS $$
  SELECT name FROM db.area WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AreaTree --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a recursive area tree starting from the given area, filtered by current scopes.
 * @param {uuid} pArea - Root area identifier
 * @return {SETOF AreaTree} Sorted hierarchical area records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AreaTree (
  pArea         uuid
) RETURNS       SETOF AreaTree
AS $$
  WITH RECURSIVE tree AS (
    SELECT *, ARRAY[row_number() OVER (ORDER BY level, sequence)] AS sortlist FROM Area WHERE id IS NOT DISTINCT FROM pArea
    UNION ALL
      SELECT a.*, array_append(t.sortlist, row_number() OVER (ORDER BY a.level, a.sequence))
        FROM Area a INNER JOIN tree t ON a.parent = t.id
    )
    SELECT *
      FROM tree
     WHERE scope IN (SELECT current_scopes())
     ORDER BY sortlist;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToArea -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Adds a user to an area membership. Requires the 'include to group' ACL bit.
 * @param {uuid} pMember - User identifier
 * @param {uuid} pArea - Area identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddMemberToArea (
  pMember       uuid,
  pArea         uuid
) RETURNS       void
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
 * @brief Removes an area membership for a user, or all areas if pArea is NULL.
 *        Requires the 'exclude from group' ACL bit.
 * @param {uuid} pMember - User identifier
 * @param {uuid} pArea - Area identifier (NULL = remove from all areas)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteAreaForMember (
  pMember       uuid,
  pArea         uuid DEFAULT null
) RETURNS       void
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
 * @brief Removes a member from an area, or all members if pMember is NULL.
 *        Requires the 'exclude from group' ACL bit.
 * @param {uuid} pArea - Area identifier
 * @param {uuid} pMember - User identifier (NULL = remove all members)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteMemberFromArea (
  pArea         uuid,
  pMember       uuid DEFAULT null
) RETURNS       void
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
/**
 * @brief Switches the active area for a session and persists it as the user's default.
 *        Validates that the user is a member of the target area.
 * @param {uuid} pArea - Target area identifier
 * @param {uuid} pMember - User identifier (defaults to current user)
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {void}
 * @throws AreaError if area does not exist
 * @throws UserNotMemberArea if user is not a member of the area
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetArea (
  pArea         uuid,
  pMember       uuid DEFAULT current_userid(),
  pSession      varchar DEFAULT current_session()
) RETURNS       void
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
  UPDATE db.profile SET area = pArea WHERE userid = pMember AND scope = current_scope();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsMemberArea ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Checks whether a user has access to an area (including inherited parent areas
 *        and group memberships).
 * @param {uuid} pArea - Area identifier
 * @param {uuid} pMember - User or group identifier (defaults to current user)
 * @return {boolean} true if the user has area access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsMemberArea (
  pArea         uuid,
  pMember       uuid DEFAULT current_userid()
) RETURNS       boolean
AS $$
DECLARE
  nCount        bigint;
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
/**
 * @brief Persists the area as the user's default in the current scope profile.
 * @param {uuid} pArea - Area identifier (defaults to current area)
 * @param {uuid} pMember - User identifier (defaults to current user)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetDefaultArea (
  pArea         uuid DEFAULT current_area(),
  pMember       uuid DEFAULT current_userid()
) RETURNS       void
AS $$
BEGIN
  UPDATE db.profile SET area = pArea WHERE userid = pMember AND scope = current_scope();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultArea --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the user's default area from the current scope profile.
 *        Falls back to the guest area if no profile is found.
 * @param {uuid} pMember - User identifier (defaults to current user)
 * @return {uuid} Default area identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetDefaultArea (
  pMember       uuid DEFAULT current_userid()
) RETURNS       uuid
AS $$
DECLARE
  uArea         uuid;
BEGIN
  SELECT area INTO uArea FROM db.profile WHERE userid = pMember AND scope = current_scope();

  IF NOT FOUND THEN
    SELECT id INTO uArea FROM db.area WHERE scope = current_scope() AND type = '00000000-0000-4002-a000-000000000002'; -- guest
  END IF;

  RETURN uArea;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateInterface -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a new interface. Requires administrator role.
 * @param {text} pCode - Unique interface code
 * @param {text} pName - Interface display name
 * @param {text} pDescription - Description
 * @param {uuid} pId - Interface identifier (defaults to auto-generated)
 * @return {uuid} Newly created interface identifier
 * @throws ACCESS_DENIED if caller is not an administrator
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateInterface (
  pCode         text,
  pName         text,
  pDescription  text,
  pId           uuid DEFAULT gen_kernel_uuid('8')
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
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
/**
 * @brief Updates an interface record. Requires administrator role.
 * @param {uuid} pId - Interface identifier
 * @param {text} pCode - New interface code
 * @param {text} pName - New display name
 * @param {text} pDescription - New description
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UpdateInterface (
  pId           uuid,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
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
         description = CheckNull(coalesce(pDescription, description, ''))
   WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteInterface -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Deletes an interface. Requires administrator role.
 * @param {uuid} pId - Interface identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteInterface (
  pId           uuid
) RETURNS       void
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
/**
 * @brief Adds a user to an interface membership. Requires the 'include to group' ACL bit.
 * @param {uuid} pMember - User identifier
 * @param {uuid} pInterface - Interface identifier
 * @return {void}
 * @since 1.0.0
 */
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
/**
 * @brief Removes interface membership for a user, or all interfaces if pInterface is NULL.
 * @param {uuid} pMember - User identifier
 * @param {uuid} pInterface - Interface identifier (NULL = remove from all interfaces)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteInterfaceForMember (
  pMember       uuid,
  pInterface    uuid DEFAULT null
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
/**
 * @brief Removes a member from an interface, or all members if pMember is NULL.
 * @param {uuid} pInterface - Interface identifier
 * @param {uuid} pMember - User identifier (NULL = remove all members)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteMemberFromInterface (
  pInterface    uuid,
  pMember       uuid DEFAULT null
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
/**
 * @brief Resolve an interface code to its identifier.
 * @param {text} pCode - Interface code
 * @return {uuid} Interface identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetInterface (
  pCode         text
) RETURNS       uuid
AS $$
  SELECT id FROM db.interface WHERE code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInterfaceName ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve an interface name by its identifier.
 * @param {uuid} pId - Interface identifier
 * @return {text} Interface name
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetInterfaceName (
  pId           uuid
) RETURNS       text
AS $$
  SELECT name FROM db.interface WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetInterface ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Switches the active interface for a session. Validates user membership.
 * @param {uuid} pInterface - Target interface identifier
 * @param {uuid} pMember - User identifier (defaults to current user)
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {void}
 * @throws InterfaceError if interface does not exist
 * @throws UserNotMemberInterface if user is not a member of the interface
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetInterface (
  pInterface    uuid,
  pMember       uuid DEFAULT current_userid(),
  pSession      varchar DEFAULT current_session()
) RETURNS       void
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
 * @brief Checks whether a user has access to an interface (including group memberships).
 * @param {uuid} pInterface - Interface identifier
 * @param {uuid} pMember - User or group identifier (defaults to current user)
 * @return {boolean} true if the user has interface access
 * @since 1.0.0
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
/**
 * @brief Persists the interface as the user's default in the current scope profile.
 * @param {uuid} pInterface - Interface identifier (defaults to current interface)
 * @param {uuid} pMember - User identifier (defaults to current user)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetDefaultInterface (
  pInterface    uuid DEFAULT current_interface(),
  pMember       uuid DEFAULT current_userid()
) RETURNS       void
AS $$
BEGIN
  UPDATE db.profile SET interface = pInterface WHERE userid = pMember AND scope = current_scope();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultInterface ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the user's default interface from the current scope profile.
 *        Falls back to the guest interface if no profile is found.
 * @param {uuid} pMember - User identifier (defaults to current user)
 * @return {uuid} Default interface identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetDefaultInterface (
  pMember       uuid DEFAULT current_userid()
) RETURNS       uuid
AS $$
DECLARE
  uInterface    uuid;
BEGIN
  SELECT interface INTO uInterface FROM db.profile WHERE userid = pMember AND scope = current_scope();

  IF NOT FOUND THEN
    uInterface := '00000000-0000-4004-a000-000000000003'::uuid;
  END IF;

  RETURN uInterface;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckOffline ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Marks users as offline if their sessions have not been updated within the given interval.
 * @param {interval} pOffTime - Inactivity threshold (defaults to '5 minute')
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckOffline (
  pOffTime      interval DEFAULT '5 minute'
) RETURNS       void
AS $$
DECLARE
  r             record;
BEGIN
  FOR r IN
    SELECT userid
      FROM db.session s INNER JOIN db.user u ON s.userid = u.id
     WHERE userid <> current_userid()
       AND updated < now() - pOffTime
       AND status & B'0010' = B'0010'
     GROUP BY userid
  LOOP
    UPDATE db.user SET status = set_bit(set_bit(status, 3, 1), 2, 0) WHERE id = r.userid;
    UPDATE db.profile SET state = B'000' WHERE userid = r.userid AND scope = current_scope();
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckSession ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Cleans up stale sessions: signs out sessions older than pOffTime,
 *        web-* sessions older than 10 days, and all python-* agent sessions.
 * @param {interval} pOffTime - Inactivity threshold (defaults to '3 month')
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckSession (
  pOffTime      interval DEFAULT '3 month'
) RETURNS       void
AS $$
DECLARE
  r             record;
BEGIN
  FOR r IN
    SELECT code
      FROM Session
     WHERE username NOT IN (session_user, 'admin')
       AND code IS DISTINCT FROM current_session()
       AND input_last < Now() - pOffTime
  LOOP
    PERFORM SignOut(r.code);
  END LOOP;

  FOR r IN
    SELECT code
      FROM Session
     WHERE username LIKE 'web-%'
       AND code IS DISTINCT FROM current_session()
       AND input_last < Now() - INTERVAL '10 day'
     LIMIT 5000
  LOOP
    PERFORM SignOut(r.code);
  END LOOP;

  FOR r IN
    SELECT code
      FROM db.session
     WHERE code IS DISTINCT FROM current_session()
       AND agent LIKE 'python-%'
  LOOP
    PERFORM SignOut(r.code);
  END LOOP;
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
/**
 * @brief Verifies a user's password against the stored bcrypt hash.
 *        Sets an error message with the result.
 * @param {uuid} pUserId - User identifier
 * @param {text} pPassword - Password to verify
 * @return {boolean} true if the password matches
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckPassword (
  pUserId       uuid,
  pPassword     text
) RETURNS       boolean
AS $$
DECLARE
  passed        boolean;
BEGIN
  SELECT (pswhash = crypt(pPassword, pswhash)) INTO passed
    FROM db.user
   WHERE id = pUserId;

  IF FOUND THEN
    IF passed THEN
      PERFORM SetErrorMessage('Success.');
    ELSE
      PERFORM SetErrorMessage('Password verification failed.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('User not found.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- CheckPassword ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Verify a password by username.
 * @param {text} pRoleName - Username
 * @param {text} pPassword - Password to verify
 * @return {boolean} true if the password matches
 * @see CheckPassword(uuid, text)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckPassword (
  pRoleName     text,
  pPassword     text
) RETURNS       boolean
AS $$
BEGIN
  RETURN CheckPassword(GetUser(pRoleName), pPassword);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TokenValidation -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validates a JWT token: verifies signature, checks expiry, and confirms audience ownership.
 * @param {text} pToken - JWT token string to validate
 * @return {jsonb} Decoded JWT payload on success
 * @throws IssuerNotFound if the issuer is not configured
 * @throws AudienceNotFound if the audience is not found
 * @throws TokenError if the signature is invalid
 * @throws TokenExpired if the token has expired
 * @throws TokenBelong if the token does not belong to the expected audience
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION TokenValidation (
  pToken        text
) RETURNS       jsonb
AS $$
DECLARE
  r             record;

  payload       jsonb;

  vHash         text;
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

  SELECT * INTO r FROM verify(pToken, vSecret);

  IF NOT coalesce(r.valid, false) THEN
    PERFORM TokenError();
  END IF;

  vHash := GetTokenHash(pToken, GetSecretKey());

  SELECT h.oauth2 INTO nOauth2
    FROM db.token t INNER JOIN db.token_header h ON h.id = t.header
   WHERE t.hash = vHash
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
-- RefreshToken ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Refreshes an access token: if still valid returns it, otherwise exchanges the refresh token.
 * @param {text} pToken - Current JWT access token
 * @param {text} pRefresh - Refresh token
 * @return {json} Token set JSON or error object
 * @throws IssuerNotFound, AudienceNotFound, TokenError, TokenExpired, TokenBelong on validation failure
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RefreshToken (
  pToken        text,
  pRefresh      text
) RETURNS       json
AS $$
DECLARE
  r             record;

  payload       jsonb;
  token         jsonb;

  vHash         text;
  vSecret       text;

  iss           text;
  aud           text;

  nOauth2       bigint;
  nProvider     integer;
  nAudience     integer;

  belong        boolean;

  expires_in    double precision;

  dtValidToDate timestamptz;
BEGIN
  IF pRefresh IS NULL THEN
    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'Missing parameter: refresh_token'));
  END IF;

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

  SELECT * INTO r FROM verify(pToken, vSecret);

  IF NOT coalesce(r.valid, false) THEN
    PERFORM TokenError();
  END IF;

  vHash := GetTokenHash(pToken, GetSecretKey());

  SELECT h.oauth2, t.validtodate INTO nOauth2, dtValidToDate
    FROM db.token t INNER JOIN db.token_header h ON h.id = t.header
   WHERE t.hash = vHash;

  IF NOT FOUND THEN
    PERFORM TokenExpired();
  END IF;

  SELECT (audience = nAudience) INTO belong FROM db.oauth2 WHERE id = nOauth2;

  IF NOT coalesce(belong, false) THEN
    PERFORM TokenBelong();
  END IF;

  IF dtValidToDate > Now() THEN
    expires_in := trunc(extract(EPOCH FROM dtValidToDate)) - trunc(extract(EPOCH FROM Now()));

    token := jsonb_build_object('session', payload->>'sub', 'access_token', pToken, 'token_type', 'Bearer', 'expires_in', expires_in);

    IF NULLIF(pRefresh, '') IS NOT NULL THEN
      token := token || jsonb_build_object('refresh_token', pRefresh);
    END IF;

    RETURN token;
  END IF;

  RETURN UpdateToken(nAudience, NULLIF(pRefresh, ''));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ValidSession ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validates a session by checking its password key hash.
 *        Sets an error message with the result.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {boolean} true if the session is valid
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ValidSession (
  pSession      varchar DEFAULT current_session()
) RETURNS       boolean
AS $$
DECLARE
  passed        boolean;
BEGIN
  SELECT (pwkey = crypt(StrPwKey(suid, secret, created), pwkey)) INTO passed
    FROM db.session
   WHERE code = pSession;

  IF FOUND THEN
    IF coalesce(passed, false) THEN
      PERFORM SetErrorMessage('Success.');
    ELSE
      PERFORM SetErrorMessage('Session code verification failed.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Session code not found.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- ValidSecret -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validates a session secret by comparing it with the stored secret.
 *        Sets an error message with the result.
 * @param {text} pSecret - Secret to validate
 * @param {varchar} pSession - Session code (defaults to current session)
 * @return {boolean} true if the secret matches
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ValidSecret (
  pSecret       text,
  pSession      varchar DEFAULT current_session()
) RETURNS       boolean
AS $$
DECLARE
  passed        boolean;
BEGIN
  SELECT (pSecret = secret) INTO passed
    FROM db.session
   WHERE code = pSession;

  IF FOUND THEN
    IF coalesce(passed, false) THEN
      PERFORM SetErrorMessage('Success.');
    ELSE
      PERFORM SetErrorMessage('Session secret verification failed.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Session code not found.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION UpdateSessionStats -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates session activity statistics: marks user as online, updates last input time and IP.
 * @param {varchar} pSession - Session code
 * @param {text} pAgent - User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UpdateSessionStats (
  pSession      varchar,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
)
RETURNS         void
AS $$
DECLARE
  uUserId       uuid;
  uScope        uuid;
BEGIN
  SELECT s.userid, a.scope INTO uUserId, uScope
    FROM db.session s INNER JOIN db.area a ON s.area = a.id
   WHERE s.code = pSession;

  IF FOUND THEN
    UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 2, 1) WHERE id = uUserId;

    UPDATE db.profile
       SET input_last = now(),
           lc_ip = coalesce(pHost, lc_ip)
     WHERE userid = uUserId AND scope = uScope;

    UPDATE db.session
       SET updated = localtimestamp,
           agent = coalesce(pAgent, agent),
           host = coalesce(pHost, host)
     WHERE code = pSession;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SessionIn ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resumes a session by session key. Validates the session, checks user status and IP,
 *        updates session stats, and returns the current authorization token.
 * @param {varchar} pSession - Session code
 * @param {text} pAgent - User-Agent string
 * @param {inet} pHost - Client IP address
 * @param {text} pSalt - New authentication salt (if provided, refreshes the session)
 * @return {text} Authorization token, or NULL on failure (call GetErrorMessage for details)
 * @since 1.0.0
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
  up            db.user%rowtype;

  uUserId       uuid;
  uScope        uuid;

  nToken        bigint;
  nOAuth2       bigint;

  nAudience     integer;
BEGIN
  IF ValidSession(pSession) THEN

    SELECT s.oauth2, s.token, s.userid, a.scope INTO nOAuth2, nToken, uUserId, uScope
      FROM db.session s INNER JOIN db.area a ON s.area = a.id
     WHERE s.code = pSession;

    SELECT * INTO up FROM db.user WHERE id = uUserId;

    IF NOT FOUND THEN
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

    IF pSalt IS NOT NULL THEN
      UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 2, 1) WHERE id = up.id;

      UPDATE db.profile
         SET input_last = now(),
             lc_ip = coalesce(pHost, lc_ip)
       WHERE userid = up.id AND scope = uScope;

      UPDATE db.session
         SET updated = localtimestamp,
             agent = coalesce(pAgent, agent),
             host = coalesce(pHost, host),
             salt = coalesce(pSalt, salt)
       WHERE code = pSession
      RETURNING token INTO nToken;
    END IF;

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
 * @brief Authenticates a user by username and password. Creates a new session,
 *        checks all pre-conditions (lock, expiry, IP), and logs the event.
 * @param {bigint} pOAuth2 - OAuth 2.0 session parameters identifier
 * @param {text} pRoleName - Username (login)
 * @param {text} pPassword - Password
 * @param {text} pAgent - User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {text} Session code, or NULL on failure (call GetErrorMessage for details)
 * @since 1.0.0
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

  uArea         uuid;
  uScope        uuid;
  uLocale       uuid;
  uInterface    uuid;

  nAudience     integer DEFAULT null;
  vSession      text DEFAULT null;
BEGIN
  IF NULLIF(pRoleName, '') IS NULL THEN
    PERFORM LoginError();
  END IF;

  IF NULLIF(pPassword, '') IS NULL THEN
    PERFORM LoginError();
  END IF;

  SELECT * INTO up FROM db.user WHERE type = 'U' AND username = pRoleName;

  IF NOT FOUND THEN
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

    uScope := CheckUserProfile(pOAuth2, up.id);

    SELECT locale, area, interface INTO uLocale, uArea, uInterface FROM db.profile WHERE userid = up.id AND scope = uScope;

    IF NOT FOUND THEN
      RAISE EXCEPTION '[%] [%] Not found scope: %', pOAuth2, pRoleName, uScope;
    END IF;

    INSERT INTO db.session (oauth2, userid, locale, area, interface, scope, agent, host)
    VALUES (pOAuth2, up.id, uLocale, uArea, uInterface, uScope, pAgent, pHost)
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
     WHERE userid = up.id AND scope = uScope;

    PERFORM DoLogin(up.id);

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
 * @brief Safe login wrapper: calls Login and catches exceptions.
 *        On failure, increments error counters and temporarily locks after 5 failed attempts.
 * @param {bigint} pOAuth2 - OAuth 2.0 session parameters identifier
 * @param {text} pRoleName - Username (login)
 * @param {text} pPassword - Password
 * @param {text} pAgent - User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {text} Session code, or NULL on failure (call GetErrorMessage for details)
 * @see Login
 * @since 1.0.0
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

  vMessage      text;
  vContext      text;
BEGIN
  PERFORM SetErrorMessage('Success.');

  BEGIN
    RETURN Login(pOAuth2, pRoleName, pPassword, pAgent, pHost);
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

    PERFORM SetErrorMessage(vMessage);

    PERFORM SetCurrentSession(null);
    PERFORM SetCurrentUserId(null);
    PERFORM SetOAuth2ClientId(null);

    SELECT * INTO up FROM db.user WHERE type = 'U' AND username = pRoleName;

    IF FOUND THEN
      UPDATE db.profile
         SET input_error = input_error + 1,
             input_error_last = now(),
             input_error_all = input_error_all + 1
       WHERE userid = up.id;

      SELECT max(input_error) INTO nInputError FROM db.profile WHERE userid = up.id GROUP BY userid;

      IF FOUND THEN
        IF nInputError >= 5 AND pRoleName != 'demo' THEN
          -- Exponential backoff: 1m, 5m, 25m, 2h, 10h (capped)
          UPDATE db.user SET lock_date = Now() + least(INTERVAL '1 min' * power(5, (nInputError / 5) - 1), INTERVAL '10 hour') WHERE id = up.id;
        END IF;
      END IF;
    END IF;

    INSERT INTO db.log (type, code, username, event, text)
    VALUES ('E', 3100, coalesce(pRoleName, session_user), 'login', vMessage);

    INSERT INTO db.log (type, code, username, event, text)
    VALUES ('D', 9100, coalesce(pRoleName, session_user), 'login', vContext);

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
 * @brief Signs out by session key. Optionally closes all user sessions.
 *        Requires the 'logout' ACL bit. Marks the user as offline when no sessions remain.
 * @param {varchar} pSession - Session code
 * @param {boolean} pCloseAll - true to close all sessions for the user
 * @param {text} pMessage - Optional log message
 * @return {boolean} true on success
 * @throws ACCESS_DENIED if caller lacks logout permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SessionOut (
  pSession      varchar,
  pCloseAll     boolean,
  pMessage      text DEFAULT null
) RETURNS       boolean
AS $$
DECLARE
  uUserId       uuid;
  nCount        integer;

  message       text;
BEGIN
  IF ValidSession(pSession) THEN

    message := 'Выход из системы';

    SELECT userid INTO uUserId FROM db.session WHERE code = pSession;

    IF NOT CheckAccessControlList(B'00000000000010', uUserId) THEN
      PERFORM AccessDenied();
    END IF;

    PERFORM DoLogout(uUserId);

    IF pCloseAll THEN
      DELETE FROM db.session WHERE userid = uUserId;
      -- Revoke orphaned tokens (session deleted, token_header remains)
      DELETE FROM db.token WHERE header IN (SELECT h.id FROM db.token_header h LEFT JOIN db.session s ON h.session = s.code WHERE s.code IS NULL AND h.session IS NOT NULL);
      DELETE FROM db.token_header h WHERE NOT EXISTS (SELECT 1 FROM db.session s WHERE s.code = h.session) AND h.session IS NOT NULL;
      message := message || ' (с закрытием всех активных сессий)';
    ELSE
      DELETE FROM db.session WHERE code = pSession;
      -- Revoke orphaned tokens for this session
      DELETE FROM db.token WHERE header IN (SELECT id FROM db.token_header WHERE session = pSession);
      DELETE FROM db.token_header WHERE session = pSession;
    END IF;

    SELECT count(code) INTO nCount FROM db.session WHERE userid = uUserId;

    IF nCount = 0 THEN
      UPDATE db.user SET status = set_bit(set_bit(status, 3, 1), 2, 0) WHERE id = uUserId;
      UPDATE db.profile SET state = B'000' WHERE userid = uUserId AND scope = current_scope();
    END IF;

    message := message || coalesce('. ' || pMessage, '.');

    INSERT INTO db.log (type, code, username, session, event, text)
    VALUES ('M', 1100, GetUserName(uUserId), pSession, 'logout', message);

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
 * @brief Safe sign-out wrapper: calls SessionOut and catches exceptions. Logs errors.
 * @param {varchar} pSession - Session code (defaults to current session)
 * @param {boolean} pCloseAll - true to close all sessions (defaults to false)
 * @return {boolean} true on success, false on failure
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SignOut (
  pSession      varchar DEFAULT current_session(),
  pCloseAll     boolean DEFAULT false
) RETURNS       boolean
AS $$
DECLARE
  uUserId       uuid;

  vMessage      text;
  vContext      text;
BEGIN
  RETURN SessionOut(pSession, pCloseAll);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  PERFORM SetCurrentSession(null);
  PERFORM SetCurrentUserId(null);
  PERFORM SetOAuth2ClientId(null);

  IF pSession IS NOT NULL THEN
    SELECT userid INTO uUserId FROM db.session WHERE code = pSession;
  END IF;

  INSERT INTO db.log (type, code, username, session, event, text)
  VALUES ('E', 3100, coalesce(GetUserName(uUserId), session_user), pSession, 'logout', 'Выход из системы. ' || vMessage);

  INSERT INTO db.log (type, code, username, session, event, text)
  VALUES ('D', 9100, coalesce(GetUserName(uUserId), session_user), pSession, 'logout', vContext);

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION Authenticate -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Authenticates a session using its secret key. On success, refreshes the session
 *        with a new salt and returns a new authorization token. On failure, terminates the session.
 * @param {varchar} pSession - Session code
 * @param {text} pSecret - Session secret for verification
 * @param {text} pAgent - User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {text} New authorization token, or NULL on failure
 * @since 1.0.0
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
    vCode := SessionIn(pSession, pAgent, pHost, gen_salt('bf'));
  ELSE
    PERFORM SessionOut(pSession, false, GetErrorMessage());
  END IF;

  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION Authorize ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Authorizes a session (validates it and resumes). Returns boolean indicating success.
 * @param {varchar} pSession - Session code
 * @param {text} pAgent - User-Agent string
 * @param {inet} pHost - Client IP address
 * @return {boolean} true if authorization succeeded
 * @since 1.0.0
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
/**
 * @brief Creates or reuses a session for the given user programmatically (e.g. for service accounts).
 *        Requires the 'substitute user' ACL bit unless called by the kernel or apibot.
 * @param {uuid} pUserId - User identifier
 * @param {bigint} pOAuth2 - OAuth 2.0 session parameters (defaults to system OAuth2)
 * @param {text} pAgent - User-Agent string
 * @param {inet} pHost - Client IP address
 * @param {bool} pNew - Force create a new session (defaults to false)
 * @param {bool} pLogin - Set session context after creation (defaults to true)
 * @return {text} Session code
 * @throws ACCESS_DENIED if caller lacks substitute permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetSession (
  pUserId       uuid,
  pOAuth2       bigint DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pNew          bool DEFAULT null,
  pLogin        bool DEFAULT null
) RETURNS       text
AS $$
DECLARE
  up            db.user%rowtype;

  uSUID         uuid;
  uArea         uuid;
  uScope        uuid;
  uLocale       uuid;
  uInterface    uuid;

  nAudience     integer;

  vSession      text;
BEGIN
  pOAuth2 := coalesce(pOAuth2, CreateSystemOAuth2());
  pNew := coalesce(pNew, false);
  pLogin := coalesce(pLogin, true);

  IF session_user <> 'kernel' AND NOT (session_user = 'apibot' AND pUserId = '00000000-0000-4000-a002-000000000001'::uuid) THEN
    uSUID := coalesce(session_userid(), GetUser(session_user));
    IF NOT CheckAccessControlList(B'10000000000000', uSUID) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT * INTO up FROM db.user WHERE id = pUserId;

  IF NOT FOUND THEN
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

  IF pAgent IS NULL THEN
    SELECT coalesce(application_name, current_database()) INTO pAgent FROM pg_stat_activity WHERE pid = pg_backend_pid();
  END IF;

  uScope := CheckUserProfile(pOAuth2, up.id);

  IF NOT pNew THEN
    SELECT code INTO vSession
      FROM db.session
     WHERE suid = up.id
       AND suid = userid
       AND scope = uScope
       AND agent IS NOT DISTINCT FROM pAgent
     ORDER BY created DESC
     LIMIT 1;

    pNew := NOT FOUND;
  END IF;

  IF pNew THEN
    SELECT locale, area, interface INTO uLocale, uArea, uInterface FROM db.profile WHERE userid = up.id AND scope = uScope;

    IF NOT FOUND THEN
      PERFORM AccessDenied();
    END IF;

    INSERT INTO db.session (oauth2, userid, locale, area, interface, scope, agent, host)
    VALUES (pOAuth2, up.id, uLocale, uArea, uInterface, uScope, pAgent, pHost)
    RETURNING code INTO vSession;
  END IF;

  IF pLogin THEN
    SELECT audience INTO nAudience FROM db.oauth2 WHERE id = pOAuth2;

    PERFORM SetCurrentSession(vSession);
    PERFORM SetCurrentUserId(up.id);
    PERFORM SetOAuth2ClientId(GetAudienceCode(nAudience));
  END IF;

  RETURN vSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
