--------------------------------------------------------------------------------
-- ADMIN API -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.login -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Log in by virtual user name and password.
 * @param {text} pUserName - User name (login)
 * @param {text} pPassword - User password
 * @param {text} pAgent - User agent string
 * @param {inet} pHost - Client IP address
 * @param {text} pScope - Database scope code
 * @out param {text} session - Session key
 * @out param {text} secret - HMAC-256 signing secret
 * @out param {text} code - One-time authorization code for obtaining a token (OAuth 2.0)
 * @return {record} - Session record for the authenticated user
 * @see SignIn, CreateSystemOAuth2
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.login (
  pUserName     text,
  pPassword     text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pScope        text DEFAULT null,
  OUT session   text,
  OUT secret    text,
  OUT code      text
) RETURNS       record
AS $$
BEGIN
  session := Login(CreateSystemOAuth2(pScope), pUserName, pPassword, pAgent, pHost);

  IF session IS NULL THEN
    PERFORM AuthenticateError(GetErrorMessage());
  END IF;

  code := oauth2_current_code(session);
  secret := session_secret(session);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.signin ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sign in by user name and password. Requires prior OAuth 2.0 client authorization.
 * @param {text} pUserName - User name (login)
 * @param {text} pPassword - Password
 * @param {text} pAgent - User agent string
 * @param {inet} pHost - Client IP address
 * @out param {text} session - Session key
 * @out param {text} secret - HMAC-256 signing secret
 * @out param {text} code - One-time authorization code for obtaining a token (OAuth 2.0)
 * @return {record}
 * @see SignIn, CreateOAuth2
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.signin (
  pUserName     text,
  pPassword     text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  OUT session   text,
  OUT secret    text,
  OUT code      text
) RETURNS       record
AS $$
DECLARE
  nAudience     integer;
BEGIN
  SELECT a.id INTO nAudience FROM oauth2.audience a WHERE a.code = oauth2_current_client_id();

  IF NOT FOUND THEN
    PERFORM AudienceNotFound();
  END IF;

  session := SignIn(CreateOAuth2(nAudience, current_scope_code()), pUserName, pPassword, pAgent, pHost);

  IF session IS NULL THEN
    PERFORM AuthenticateError(GetErrorMessage());
  END IF;

  code := oauth2_current_code(session);
  secret := session_secret(session);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.signout -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sign out of the system.
 * @param {varchar} pSession - Session key
 * @param {boolean} pCloseAll - Close all sessions for this user
 * @return {boolean} - TRUE on success
 * @see SignOut
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.signout (
  pSession      varchar DEFAULT current_session(),
  pCloseAll     boolean DEFAULT false
) RETURNS       boolean
AS $$
BEGIN
  RETURN SignOut(coalesce(pSession, current_session()), coalesce(pCloseAll, false));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.authenticate ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Authenticate a session using a secret key.
 * @param {varchar} pSession - Session key
 * @param {text} pSecret - Session secret
 * @param {text} pAgent - User agent string
 * @param {inet} pHost - Client IP address
 * @out param {boolean} authorized - Authentication result
 * @out param {uuid} userid - Authenticated user identifier
 * @out param {text} code - Authorization code (OAuth 2.0 authorization grant)
 * @out param {text} message - Error or status message
 * @return {record}
 * @see Authenticate
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.authenticate (
  pSession          varchar,
  pSecret           text,
  pAgent            text DEFAULT null,
  pHost             inet DEFAULT null,
  OUT authorized    boolean,
  OUT userid        uuid,
  OUT code          text,
  OUT message       text
) RETURNS           record
AS $$
BEGIN
  code := Authenticate(pSession, pSecret, pAgent, pHost);
  authorized := code IS NOT NULL;
  userid := current_userid();
  message := GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.authorize ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Authorize an existing session.
 * @param {varchar} pSession - Session key
 * @param {text} pAgent - User agent string
 * @param {inet} pHost - Client IP address
 * @out param {boolean} authorized - Authorization result
 * @out param {uuid} userid - Authorized user identifier
 * @out param {text} message - Error or status message
 * @return {record}
 * @see Authorize
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.authorize (
  pSession          varchar,
  pAgent            text DEFAULT null,
  pHost             inet DEFAULT null,
  OUT authorized    boolean,
  OUT userid        uuid,
  OUT message       text
) RETURNS           record
AS $$
BEGIN
  authorized := Authorize(pSession, pAgent, pHost);
  userid := current_userid();
  message := GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.su ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Substitute user. Switches the current user in the active session to the specified user.
 * @param {text} pUserName - User name to substitute
 * @param {text} pPassword - Current user password
 * @return {void}
 * @see SubstituteUser
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.su (
  pUserName     text,
  pPassword     text
) RETURNS       void
AS $$
BEGIN
  PERFORM SubstituteUser(pUserName, pPassword);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_session -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve or create a session for the specified user.
 * @param {text} pUserName - User name (login)
 * @param {text} pAgent - User agent string
 * @param {inet} pHost - Client IP address
 * @param {text} pScope - Database scope code
 * @param {bool} pNew - Create a new session
 * @param {bool} pLogin - Log the user in
 * @return {text} - Session key
 * @see GetSession
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_session (
  pUserName     text,
  pAgent        text,
  pHost         inet,
  pScope        text DEFAULT null,
  pNew          bool DEFAULT null,
  pLogin        bool DEFAULT null
) RETURNS       text
AS $$
BEGIN
  RETURN GetSession(GetUser(pUserName), CreateSystemOAuth2(pScope), pAgent, pHost, coalesce(pNew, false), coalesce(pLogin, false));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_sessions ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a session for the specified user in each available scope.
 * @param {text} pUserName - User name (login)
 * @param {text} pAgent - User agent string
 * @param {inet} pHost - Client IP address
 * @param {bool} pNew - Create new sessions
 * @param {bool} pLogin - Log the user in
 * @return {SETOF text} - Session keys, one per scope
 * @see GetSession
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_sessions (
  pUserName     text,
  pAgent        text,
  pHost         inet,
  pNew          bool default null,
  pLogin        bool default null
) RETURNS       SETOF text
AS $$
DECLARE
  r             record;
  uUserId       uuid;
BEGIN
  uUserId := GetUser(pUserName);

  FOR r IN SELECT code FROM db.scope ORDER BY code
  LOOP
    RETURN NEXT GetSession(uUserId, CreateSystemOAuth2(r.code), pAgent, pHost, coalesce(pNew, false), coalesce(pLogin, false));
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- LOCALE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.locale ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Locale (language) reference view.
 * @since 1.0.0
 */
CREATE OR REPLACE VIEW api.locale
AS
  SELECT * FROM Locale;

GRANT SELECT ON api.locale TO administrator;

--------------------------------------------------------------------------------
-- SESSION ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.session
AS
  SELECT s.code, s.userid, s.suid, u.username, u.name,
         s.locale, s.area, s.interface,
         s.created, s.updated, u.input_last, s.host, u.lc_ip,
         u.status, u.statustext, u.state, u.statetext, u.session_limit, mg.userid IS NOT NULL AS system
    FROM db.session s INNER JOIN db.area a ON s.area = a.id
                      INNER JOIN users   u ON s.userid = u.id AND u.scope = a.scope
                       LEFT JOIN db.member_group mg ON mg.member = u.id AND mg.userid = '00000000-0000-4000-a000-000000000000'::uuid;

GRANT SELECT ON api.session TO administrator;

--------------------------------------------------------------------------------
-- api.session -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List active sessions, optionally filtered by user.
 * @param {uuid} pUserId - User identifier
 * @param {text} pUsername - User name (login)
 * @return {SETOF api.session} - Session records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.session (
  pUserId       uuid DEFAULT null,
  pUsername     text DEFAULT null
) RETURNS       SETOF api.session
AS $$
  SELECT *
    FROM api.session
   WHERE userid = coalesce(pUserId, userid)
     AND username = coalesce(pUsername, username)
   ORDER BY created DESC, userid
   LIMIT 500
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_session -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single session by its code.
 * @param {varchar} pCode - Session code
 * @return {SETOF api.session}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_session (
  pCode     varchar
) RETURNS   SETOF api.session
AS $$
  SELECT * FROM api.session WHERE code = pCode
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_session -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count session records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_session (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'session', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_session ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List sessions with optional filters.
 * @param {jsonb} pSearch - Search conditions: '[{"condition": "AND|OR", "field": "<field>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<value>"}, ...]'
 * @param {jsonb} pFilter - Filter: '{"<field>": "<value>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort by the fields specified in the array
 * @return {SETOF api.session}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_session (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.session
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'session', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- USER ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.user
AS
  SELECT * FROM users WHERE scope = current_scope();

GRANT SELECT ON api.user TO administrator;

--------------------------------------------------------------------------------
-- USERS -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.users
AS
  SELECT * FROM users;

GRANT SELECT ON api.user TO administrator;

--------------------------------------------------------------------------------
-- api.add_user ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a new user account.
 * @param {text} pUserName - User name (login)
 * @param {text} pPassword - Password
 * @param {text} pName - Full name
 * @param {text} pPhone - Phone number
 * @param {text} pEmail - Email address
 * @param {text} pDescription - Description
 * @param {boolean} pPasswordChange - Require password change on next login
 * @param {boolean} pPasswordNotChange - Prohibit the user from changing their own password
 * @return {uuid} - New user identifier
 * @see CreateUser
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_user (
  pUserName             text,
  pPassword             text,
  pName                 text,
  pPhone                text DEFAULT null,
  pEmail                text DEFAULT null,
  pDescription          text DEFAULT null,
  pPasswordChange       boolean DEFAULT true,
  pPasswordNotChange    boolean DEFAULT false
) RETURNS               uuid
AS $$
BEGIN
  RETURN CreateUser(pUserName, pPassword, pName, pPhone, pEmail, pDescription, pPasswordChange, pPasswordNotChange);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_user -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates an existing user account.
 * @param {uuid} pId - User account identifier
 * @param {text} pUserName - User name (login)
 * @param {text} pPassword - Password
 * @param {text} pName - Full name
 * @param {text} pPhone - Phone number
 * @param {text} pEmail - Email address
 * @param {text} pDescription - Description
 * @param {boolean} pPasswordChange - Require password change on next login
 * @param {boolean} pPasswordNotChange - Prohibit the user from changing their own password
 * @return {void}
 * @see UpdateUser
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_user (
  pId                   uuid,
  pUserName             text DEFAULT null,
  pPassword             text DEFAULT null,
  pName                 text DEFAULT null,
  pPhone                text DEFAULT null,
  pEmail                text DEFAULT null,
  pDescription          text DEFAULT null,
  pPasswordChange       boolean DEFAULT null,
  pPasswordNotChange    boolean DEFAULT null
) RETURNS               void
AS $$
BEGIN
  PERFORM UpdateUser(pId, pUserName, pPassword, pName, pPhone, pEmail, pDescription, pPasswordChange, pPasswordNotChange);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_user ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates or updates a user account (upsert). Returns the resulting record.
 * @param {uuid} pId - User identifier (NULL to create)
 * @param {text} pUserName - User name (login)
 * @param {text} pPassword - Password
 * @param {text} pName - Full name
 * @param {text} pPhone - Phone number
 * @param {text} pEmail - Email address
 * @param {text} pDescription - Description
 * @param {boolean} pPasswordChange - Require password change on next login
 * @param {boolean} pPasswordNotChange - Prohibit the user from changing their own password
 * @return {SETOF api.user}
 * @see api.add_user, api.update_user
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_user (
  pId                   uuid,
  pUserName             text DEFAULT null,
  pPassword             text DEFAULT null,
  pName                 text DEFAULT null,
  pPhone                text DEFAULT null,
  pEmail                text DEFAULT null,
  pDescription          text DEFAULT null,
  pPasswordChange       boolean DEFAULT null,
  pPasswordNotChange    boolean DEFAULT null
) RETURNS               SETOF api.user
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_user(pUserName, pPassword, pName, pPhone, pEmail, pDescription, pPasswordChange, pPasswordNotChange);
  ELSE
    PERFORM api.update_user(pId, pUserName, pPassword, pName, pPhone, pEmail, pDescription, pPasswordChange, pPasswordNotChange);
  END IF;

  RETURN QUERY SELECT * FROM api.user WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_user -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Deletes a user account.
 * @param {uuid} pId - User account identifier
 * @return {void}
 * @see DeleteUser
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_user (
  pId         uuid
) RETURNS     void
AS $$
BEGIN
  PERFORM DeleteUser(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_user ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a user account record.
 * @param {uuid} pId - User identifier (defaults to current user)
 * @return {SETOF api.user} - User account record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_user (
  pId       uuid DEFAULT current_userid()
) RETURNS   SETOF api.user
AS $$
  SELECT * FROM api.user WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_user --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count user records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_user (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  IF NOT IsAdmin() THEN
    pFilter := coalesce(pFilter, '{}'::jsonb) || jsonb_build_object('id', current_userid());
  END IF;

  RETURN QUERY EXECUTE api.sql('api', 'user', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_user ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List users with optional filters. Non-admins see only their own record.
 * @param {jsonb} pSearch - Search conditions: '[{"condition": "AND|OR", "field": "<field>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<value>"}, ...]'
 * @param {jsonb} pFilter - Filter: '{"<field>": "<value>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort by the fields specified in the array
 * @return {SETOF api.user}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_user (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.user
AS $$
BEGIN
  IF NOT IsAdmin() THEN
    pFilter := coalesce(pFilter, '{}'::jsonb) || jsonb_build_object('id', current_userid());
  END IF;

  RETURN QUERY EXECUTE api.sql('api', 'user', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_profile ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates user profile fields (name parts, locale, area, interface, verification flags, picture).
 * @param {uuid} pUserId - User identifier
 * @param {text} pFamilyName - Family name (surname)
 * @param {text} pGivenName - Given name (first name)
 * @param {text} pPatronymicName - Patronymic name
 * @param {uuid} pLocale - Locale identifier
 * @param {uuid} pArea - Area identifier
 * @param {uuid} pInterface - Interface identifier
 * @param {bool} pEmailVerified - Email verified flag
 * @param {bool} pPhoneVerified - Phone verified flag
 * @param {text} pPicture - Profile picture URL
 * @return {void}
 * @see UpdateProfile
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_profile (
  pUserId           uuid,
  pFamilyName       text DEFAULT null,
  pGivenName        text DEFAULT null,
  pPatronymicName   text DEFAULT null,
  pLocale           uuid DEFAULT null,
  pArea             uuid DEFAULT null,
  pInterface        uuid DEFAULT null,
  pEmailVerified    bool DEFAULT null,
  pPhoneVerified    bool DEFAULT null,
  pPicture          text DEFAULT null
) RETURNS           void
AS $$
BEGIN
  PERFORM UpdateProfile(pUserId, current_scope(), pFamilyName, pGivenName, pPatronymicName, pLocale, pArea, pInterface, pEmailVerified, pPhoneVerified, pPicture);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_user_profile --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates user profile by code-based lookups and returns the updated user record.
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @param {text} pFamilyName - Family name (surname)
 * @param {text} pGivenName - Given name (first name)
 * @param {text} pPatronymicName - Patronymic name
 * @param {text} pLocale - Locale code
 * @param {text} pArea - Area code
 * @param {text} pInterface - Interface code
 * @param {text} pPicture - Profile picture URL
 * @return {SETOF api.user}
 * @see api.update_profile
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_user_profile (
  pUserId           uuid,
  pFamilyName       text DEFAULT null,
  pGivenName        text DEFAULT null,
  pPatronymicName   text DEFAULT null,
  pLocale           text DEFAULT null,
  pArea             text DEFAULT null,
  pInterface        text DEFAULT null,
  pPicture          text DEFAULT null
) RETURNS           SETOF api.user
AS $$
BEGIN
  pUserId := coalesce(pUserId, current_userid());

  PERFORM api.update_profile(pUserId, pFamilyName, pGivenName, pPatronymicName, GetLocale(pLocale), GetArea(pArea), GetInterface(pInterface), null::bool, null::bool, pPicture);

  RETURN QUERY SELECT * FROM api.user WHERE id = pUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.change_password ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Changes the user password after verifying the old one.
 * @param {uuid} pId - User account identifier
 * @param {text} pOldPass - Current (old) password
 * @param {text} pNewPass - New password
 * @return {void}
 * @throws ERR-40000 if the old password is incorrect
 * @see CheckPassword, SetPassword
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.change_password (
  pId           uuid,
  pOldPass      text,
  pNewPass      text
) RETURNS       void
AS $$
DECLARE
  vPassword     text;
BEGIN
  IF length(pOldPass) = 128 THEN
    SELECT encode(hmac(secret::text, GetSecretKey(), 'sha1'), 'hex') INTO vPassword
      FROM db.user
     WHERE hash = encode(digest(pOldPass, 'sha1'), 'hex');

    IF FOUND THEN
      pOldPass := vPassword;
    END IF;
  END IF;

  IF NOT CheckPassword(pId, pOldPass) THEN
    RAISE EXCEPTION 'ERR-40000: %', GetErrorMessage();
  END IF;

  PERFORM SetPassword(pId, pNewPass);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- api.recovery_password -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Initiates the password recovery procedure for a user identified by email or phone.
 * @param {text} pIdentifier - User identifier (username, email, or phone)
 * @param {text} pHashCode - HashCash proof-of-work code
 * @return {uuid} - Recovery ticket (returns a random UUID if user not found, to prevent enumeration)
 * @see RecoveryPasswordByEmail, RecoveryPasswordByPhone
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.recovery_password (
  pIdentifier       text,
  pHashCode         text DEFAULT null
) RETURNS           uuid
AS $$
DECLARE
  uTicket           uuid;
  uUserId           uuid;

  vInitiator        text;
  vOAuthSecret      text;
BEGIN
  IF NULLIF(StrPos(pIdentifier, '@'), 0) IS NOT NULL THEN
    SELECT id INTO uUserId FROM db.user WHERE email = pIdentifier AND type = 'U';
  
    IF FOUND THEN
      IF IsUserRole(GetGroup('system'), session_userid()) THEN
        SELECT a.secret INTO vOAuthSecret FROM oauth2.audience a WHERE a.code = session_username();
        IF FOUND THEN
          PERFORM SubstituteUser(GetUser('apibot'), vOAuthSecret);
          uTicket := RecoveryPasswordByEmail(uUserId);
          PERFORM SubstituteUser(session_userid(), vOAuthSecret);
        END IF;
      ELSE
        uTicket := RecoveryPasswordByEmail(uUserId);
      END IF;
    END IF;
  ELSE
    SELECT id INTO uUserId FROM db.user WHERE phone = TrimPhone(pIdentifier) AND type = 'U';
  
    IF FOUND THEN
      vInitiator := encode(digest(pIdentifier, 'sha1'), 'hex');
    
      PERFORM
        FROM db.recovery_ticket
       WHERE initiator = vInitiator
         AND validFromDate <= Now()
         AND validtoDate - interval '4 min' > Now();
      
      IF NOT FOUND THEN
        IF IsUserRole(GetGroup('system'), session_userid()) THEN
          SELECT a.secret INTO vOAuthSecret FROM oauth2.audience a WHERE a.code = session_username();
          IF FOUND THEN
            PERFORM SubstituteUser(GetUser('apibot'), vOAuthSecret);
            uTicket := RecoveryPasswordByPhone(uUserId, vInitiator, pHashCode);
            PERFORM SubstituteUser(session_userid(), vOAuthSecret);
          END IF;
        ELSE
          uTicket := RecoveryPasswordByPhone(uUserId, vInitiator, pHashCode);
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN coalesce(uTicket, gen_random_uuid());
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- api.check_recovery_ticket ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validates the security answer for a password recovery ticket.
 * @param {uuid} pTicket - Recovery ticket identifier
 * @param {text} vSecurityAnswer - Security answer (verification code)
 * @out param {bool} result - TRUE if the answer is correct
 * @out param {text} message - Error or status message
 * @return {record}
 * @see CheckRecoveryTicket
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.check_recovery_ticket (
  pTicket           uuid,
  vSecurityAnswer   text,
  OUT result        bool,
  OUT message       text
) RETURNS           record
AS $$
DECLARE
  uUserId           uuid;
BEGIN
  uUserId := CheckRecoveryTicket(pTicket, vSecurityAnswer);

  result := uUserId IS NOT NULL;
  message := GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.reset_password ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resets the user password after verifying the recovery ticket and security answer.
 * @param {uuid} pTicket - Recovery ticket identifier
 * @param {text} vSecurityAnswer - Security answer (verification code)
 * @param {text} pPassword - New password
 * @out param {bool} result - TRUE on success
 * @out param {text} message - Error or status message
 * @return {record}
 * @see CheckRecoveryTicket, SetPassword
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.reset_password (
  pTicket           uuid,
  vSecurityAnswer   text,
  pPassword         text,
  OUT result        bool,
  OUT message       text
) RETURNS           record
AS $$
DECLARE
  uUserId           uuid;
  vOAuthSecret      text;
BEGIN
  uUserId := CheckRecoveryTicket(pTicket, vSecurityAnswer);

  result := uUserId IS NOT NULL;
  message := GetErrorMessage();

  IF result THEN
    SELECT a.secret INTO vOAuthSecret FROM oauth2.audience a WHERE a.code = session_username();

    IF FOUND THEN
      PERFORM SubstituteUser(GetUser('admin'), vOAuthSecret);
      PERFORM SetPassword(uUserId, pPassword);
      PERFORM SubstituteUser(session_userid(), vOAuthSecret);
    ELSE
      PERFORM SetPassword(uUserId, pPassword);
    END IF;

    UPDATE db.recovery_ticket SET used = Now() WHERE ticket = pTicket;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registration_code_by_email ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Initiates email address verification during user registration.
 * @param {text} pEmail - Email address
 * @return {uuid} - Registration ticket (returns a random UUID if not initiated, to prevent enumeration)
 * @see RegistrationCodeByEmail
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registration_code_by_email (
  pEmail            text
) RETURNS           uuid
AS $$
DECLARE
  uTicket           uuid;
  vOAuthSecret      text;
BEGIN
  IF IsUserRole(GetGroup('system'), session_userid()) THEN
    SELECT a.secret INTO vOAuthSecret FROM oauth2.audience a WHERE a.code = session_username();
    IF FOUND THEN
      PERFORM SubstituteUser(GetUser('apibot'), vOAuthSecret);
      uTicket := RegistrationCodeByEmail(pEmail);
      PERFORM SubstituteUser(session_userid(), vOAuthSecret);
    END IF;
  ELSE
    uTicket := RegistrationCodeByEmail(pEmail);
  END IF;

  RETURN coalesce(uTicket, gen_random_uuid());
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- api.registration_code_by_phone ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Initiates phone number verification during user registration. Includes rate-limiting and anti-abuse checks.
 * @param {text} pPhone - Phone number
 * @param {text} pHashCode - HashCash proof-of-work code
 * @return {uuid} - Registration ticket (returns a random UUID if rate-limited, to prevent enumeration)
 * @see RegistrationCodeByPhone
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registration_code_by_phone (
  pPhone            text,
  pHashCode         text DEFAULT null
) RETURNS           uuid
AS $$
DECLARE
  uTicket           uuid;

  nCount            int;

  vInitiator        text;
  vOAuthSecret      text;
BEGIN
  vInitiator := encode(digest(pPhone, 'sha1'), 'hex');

  PERFORM
    FROM db.recovery_ticket
   WHERE initiator = vInitiator
     AND validFromDate <= Now()
     AND validtoDate - interval '4 min' > Now();

  IF NOT FOUND THEN

    PERFORM
      FROM db.api_log
     WHERE path = '/user/registration/code'
       AND session = current_session()
       AND json->>'phone' != pPhone;

    IF FOUND THEN
      PERFORM WriteToEventLog('W', 2003, 'registration_code_by_phone', format('Обнаружена попытка регистрации разных номеров телефона c одной и той же сессии. Телефон: "%s". Сессия "%s" закрыта.', pPhone, current_session()));
      PERFORM SessionOut(current_session(), false);
      RETURN gen_random_uuid();
    END IF;

    SELECT count(id) INTO nCount
      FROM db.api_log
     WHERE path = '/user/registration/code'
       AND session = current_session()
       AND json->>'phone' = pPhone;

    IF nCount > 3 THEN
      PERFORM WriteToEventLog('W', 2004, 'registration_code_by_phone', format('Превышено количество регистраций по номеру телефона "%s" с одной и той же сессии. Сессия "%s" закрыта.', pPhone, current_session()));
      PERFORM SessionOut(current_session(), false);
      RETURN gen_random_uuid();
    END IF;

    IF IsUserRole(GetGroup('system'), session_userid()) THEN
      SELECT a.secret INTO vOAuthSecret FROM oauth2.audience a WHERE a.code = session_username();
      IF FOUND THEN
        PERFORM SubstituteUser(GetUser('apibot'), vOAuthSecret);
        uTicket := RegistrationCodeByPhone(pPhone, pHashCode);
        PERFORM SubstituteUser(session_userid(), vOAuthSecret);
      END IF;
    ELSE
      uTicket := RegistrationCodeByPhone(pPhone, pHashCode);
    END IF;
  END IF;

  RETURN coalesce(uTicket, gen_random_uuid());
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- api.registration_code -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Alias for api.registration_code_by_phone. Initiates phone number verification during registration.
 * @param {text} pPhone - Phone number
 * @param {text} pHashCode - HashCash proof-of-work code
 * @return {uuid} - Registration ticket
 * @see api.registration_code_by_phone
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registration_code (
  pPhone            text,
  pHashCode         text DEFAULT null
) RETURNS           uuid
AS $$
BEGIN
  RETURN api.registration_code_by_phone(pPhone, pHashCode);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.check_registration_code -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validates a registration code against its ticket. On success, stores a verification code.
 * @param {uuid} pTicket - Registration ticket identifier
 * @param {text} vCode - Registration code to verify
 * @out param {bool} result - TRUE if the code is correct
 * @out param {text} message - Error or status message
 * @return {record}
 * @see CheckRecoveryTicket, AddVerificationCode
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.check_registration_code (
  pTicket           uuid,
  vCode             text,
  OUT result        bool,
  OUT message       text
) RETURNS           record
AS $$
DECLARE
  uUserId           uuid;
BEGIN
  uUserId := CheckRecoveryTicket(pTicket, vCode);

  result := uUserId IS NOT NULL;

  IF result THEN
    PERFORM AddVerificationCode(uUserId, 'P', vCode);
  END IF;

  message := GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.user_member -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List the groups the specified user belongs to.
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @return {TABLE} - Group records (id, username, name, description)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.user_member (
  pUserId uuid DEFAULT current_userid()
) RETURNS TABLE (id uuid, username text, name text, description text)
AS $$
  SELECT g.id, g.username, g.name, g.description
    FROM db.member_group m INNER JOIN groups g ON g.id = m.userid
   WHERE member = pUserId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_user -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Alias for api.user_member. Returns the list of groups the specified user belongs to.
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @return {TABLE} - Group records (id, username, name, description)
 * @see api.user_member
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.member_user (
  pUserId uuid DEFAULT current_userid()
) RETURNS TABLE (id uuid, username text, name text, description text)
AS $$
  SELECT * FROM api.user_member(pUserId);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.user_lock ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Locks a user account.
 * @param {uuid} pId - User account identifier
 * @return {void}
 * @see UserLock
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.user_lock (
  pId           uuid
) RETURNS       void
AS $$
BEGIN
  PERFORM UserLock(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.user_unlock -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Unlocks a user account.
 * @param {uuid} pId - User account identifier
 * @return {void}
 * @see UserUnlock
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.user_unlock (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM UserUnlock(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_user_iptable --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the IP address table for a user as a single string.
 * @param {uuid} pId - User account identifier
 * @param {char} pType - Type: 'A' = allow, 'D' = deny
 * @return {TABLE} - (id, type, iptable) where iptable is a comma-separated IP list
 * @see GetIPTableStr
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_user_iptable (
  pId       uuid,
  pType     char
) RETURNS TABLE (id uuid, type char, iptable text)
AS $$
  SELECT pId, pType, GetIPTableStr(pId, pType);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_user_iptable --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sets the IP address table for a user from a string.
 * @param {uuid} pId - User account identifier
 * @param {char} pType - Type: 'A' = allow, 'D' = deny
 * @param {text} pIpTable - Comma-separated IP addresses
 * @return {void}
 * @see SetIPTableStr
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_user_iptable (
  pId           uuid,
  pType         char,
  pIpTable      text
) RETURNS       void
AS $$
BEGIN
  PERFORM SetIPTableStr(pId, pType, pIpTable);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GROUP -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.group
AS
  SELECT * FROM groups;

GRANT SELECT ON api.group TO administrator;

--------------------------------------------------------------------------------
-- api.add_group ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a new user group.
 * @param {text} pUserName - Group code (login name)
 * @param {text} pName - Full display name
 * @param {text} pDescription - Description
 * @return {uuid} - New group identifier
 * @see CreateGroup
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_group (
  pUserName     text,
  pName         text,
  pDescription  text
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateGroup(pUserName, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_group ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates an existing user group.
 * @param {uuid} pId - Group identifier
 * @param {text} pUserName - Group code (login name)
 * @param {text} pName - Full display name
 * @param {text} pDescription - Description
 * @return {void}
 * @see UpdateGroup
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_group (
  pId           uuid,
  pUserName     text,
  pName         text,
  pDescription  text
) RETURNS       void
AS $$
BEGIN
  PERFORM UpdateGroup(pId, pUserName, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_group ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates or updates a user group (upsert). Returns the resulting record.
 * @param {uuid} pId - Group identifier (NULL to create)
 * @param {text} pUserName - Group code (login name)
 * @param {text} pName - Full display name
 * @param {text} pDescription - Description
 * @return {SETOF api.group}
 * @see api.add_group, api.update_group
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_group (
  pId           uuid,
  pUserName     text,
  pName         text,
  pDescription  text
) RETURNS       SETOF api.group
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_group(pUserName, pName, pDescription);
  ELSE
    PERFORM api.update_group(pId, pUserName, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.group WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_group ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Deletes a user group.
 * @param {uuid} pId - Group identifier
 * @return {void}
 * @see DeleteGroup
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_group (
  pId           uuid
) RETURNS       void
AS $$
BEGIN
  PERFORM DeleteGroup(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_group ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single group record by identifier.
 * @param {uuid} pId - Group identifier
 * @return {SETOF api.group}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_group (
  pId       uuid
) RETURNS   SETOF api.group
AS $$
  SELECT * FROM api.group WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_group -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count group records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_group (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'group', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_group --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List groups with optional filters.
 * @param {jsonb} pSearch - Search conditions: '[{"condition": "AND|OR", "field": "<field>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<value>"}, ...]'
 * @param {jsonb} pFilter - Filter: '{"<field>": "<value>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort by the fields specified in the array
 * @return {SETOF api.group}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_group (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.group
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'group', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.group_member_add --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Adds a user to a group (group-first parameter order).
 * @param {uuid} pGroup - Group identifier
 * @param {uuid} pMember - User identifier
 * @return {void}
 * @see AddMemberToGroup
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.group_member_add (
  pGroup        uuid,
  pMember       uuid
) RETURNS       void
AS $$
BEGIN
  PERFORM AddMemberToGroup(pMember, pGroup);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_group_add --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Adds a user to a group (member-first parameter order).
 * @param {uuid} pMember - User identifier
 * @param {uuid} pGroup - Group identifier
 * @return {void}
 * @see AddMemberToGroup
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.member_group_add (
  pMember       uuid,
  pGroup        uuid
) RETURNS       void
AS $$
BEGIN
  PERFORM AddMemberToGroup(pMember, pGroup);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.group_member_delete -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Removes a user from a group. If pMember is NULL, removes all members from the group.
 * @param {uuid} pGroup - Group identifier
 * @param {uuid} pMember - User identifier (NULL to remove all members)
 * @return {void}
 * @see DeleteMemberFromGroup
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.group_member_delete (
  pGroup        uuid,
  pMember       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM DeleteMemberFromGroup(pGroup, pMember);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_group_delete -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Removes a group from a user. If pGroup is NULL, removes all groups for the user.
 * @param {uuid} pMember - User identifier
 * @param {uuid} pGroup - Group identifier (NULL to remove all groups)
 * @return {void}
 * @see DeleteGroupForMember
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.member_group_delete (
  pMember       uuid,
  pGroup        uuid
) RETURNS       void
AS $$
BEGIN
  PERFORM DeleteGroupForMember(pMember, pGroup);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_group ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.member_group
AS
  SELECT * FROM MemberGroup;

GRANT SELECT ON api.member_group TO administrator;

--------------------------------------------------------------------------------
-- api.group_member ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List the users belonging to the specified group.
 * @param {uuid} pGroupId - Group identifier
 * @return {TABLE} - User records (id, username, name, email, phone, description)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.group_member (
  pGroupId    uuid
) RETURNS TABLE (
  id          uuid,
  username    text,
  name        text,
  email       text,
  phone       text,
  description text
)
AS $$
  SELECT u.id, u.username, u.name, u.email, u.phone, u.description
    FROM db.member_group m INNER JOIN db.user u ON u.id = m.member
   WHERE m.userid = pGroupId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_group ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List the groups the specified user belongs to.
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @return {TABLE} - Group records (id, username, name, description)
 * @see api.member_user
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.member_group (
  pUserId     uuid DEFAULT current_userid()
) RETURNS TABLE (
  id          uuid,
  username    text,
  name        text,
  description text
)
AS $$
  SELECT id, username, name, description FROM api.member_user(pUserId)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_groups_json ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the groups of a member as a JSON array.
 * @param {uuid} pMember - User identifier
 * @return {json} - JSON array of group records
 * @see api.member_user
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_groups_json (
  pMember       uuid
) RETURNS       json
AS $$
DECLARE
  arResult      json[];
  r             record;
BEGIN
  FOR r IN SELECT * FROM api.member_user(pMember)
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.is_user_role ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Checks whether a user belongs to a role (group) by UUID.
 * @param {uuid} pRole - Role (group) identifier
 * @param {uuid} pUser - User account identifier (defaults to current user)
 * @return {boolean} - TRUE if the user belongs to the role
 * @see IsUserRole
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.is_user_role (
  pRole         uuid,
  pUser         uuid DEFAULT current_userid()
) RETURNS       boolean
AS $$
BEGIN
  RETURN IsUserRole(pRole, pUser);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.is_user_role ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Checks whether a user belongs to a role (group) by code.
 * @param {text} pRole - Role (group) code
 * @param {text} pUser - User name (defaults to session user)
 * @return {boolean} - TRUE if the user belongs to the role
 * @see IsUserRole
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.is_user_role (
  pRole         text,
  pUser         text DEFAULT session_username()
) RETURNS       boolean
AS $$
BEGIN
  RETURN IsUserRole(pRole, pUser);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AREA ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.area_type
AS
  SELECT * FROM AreaType;

GRANT SELECT ON api.area_type TO administrator;

--------------------------------------------------------------------------------
-- api.get_area_type -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve an area type record by identifier.
 * @param {uuid} pId - Area type identifier
 * @return {SETOF api.area_type}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_area_type (
  pId        uuid
) RETURNS    SETOF api.area_type
AS $$
  SELECT * FROM api.area_type WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.area
AS
  SELECT * FROM AreaTree(GetAreaRoot());

GRANT SELECT ON api.area TO administrator;

--------------------------------------------------------------------------------
-- api.add_area ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a new area.
 * @param {uuid} pParent - Parent area identifier
 * @param {uuid} pType - Area type identifier
 * @param {uuid} pScope - Scope identifier
 * @param {text} pCode - Code
 * @param {text} pName - Name
 * @param {text} pDescription - Description
 * @param {integer} pSequence - Sort order
 * @return {uuid} - New area identifier
 * @see CreateArea
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_area (
  pParent       uuid,
  pType         uuid,
  pScope        uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null,
  pSequence     integer DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateArea(null, pParent, coalesce(pType, GetAreaType('default')), pScope, pCode, pName, pDescription, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_area -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates an existing area.
 * @param {uuid} pId - Area identifier
 * @param {uuid} pParent - Parent area identifier
 * @param {uuid} pType - Area type identifier
 * @param {uuid} pScope - Scope identifier
 * @param {text} pCode - Code
 * @param {text} pName - Name
 * @param {text} pDescription - Description
 * @param {integer} pSequence - Sort order
 * @param {timestamptz} pValidFromDate - Valid from date
 * @param {timestamptz} pValidToDate - Valid to date
 * @return {void}
 * @see EditArea
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_area (
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
) RETURNS           void
AS $$
BEGIN
  PERFORM EditArea(pId, pParent, pType, pScope, pCode, pName, pDescription, pSequence, pValidFromDate, pValidToDate);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_area ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates or updates an area (upsert). Returns the resulting record.
 * @param {uuid} pId - Area identifier (NULL to create)
 * @param {uuid} pParent - Parent area identifier
 * @param {uuid} pType - Area type identifier
 * @param {uuid} pScope - Scope identifier
 * @param {text} pCode - Code
 * @param {text} pName - Name
 * @param {text} pDescription - Description
 * @param {integer} pSequence - Sort order
 * @param {timestamptz} pValidFromDate - Valid from date
 * @param {timestamptz} pValidToDate - Valid to date
 * @return {SETOF api.area}
 * @see api.add_area, api.update_area
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_area (
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
) RETURNS           SETOF api.area
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_area(pParent, pType, pScope, pCode, pName, pDescription, pSequence);
  ELSE
    PERFORM api.update_area(pId, pParent, pType, pScope, pCode, pName, pDescription, pSequence, pValidFromDate, pValidToDate);
  END IF;

  RETURN QUERY SELECT * FROM api.area WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_area -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Deletes an area.
 * @param {uuid} pId - Area identifier
 * @return {void}
 * @see DeleteArea
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_area (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM DeleteArea(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.safely_delete_area ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Safely deletes an area, catching and reporting errors instead of raising them.
 * @param {uuid} pId - Area identifier
 * @return {bool} - TRUE if deleted, FALSE on error
 * @see api.delete_area
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.safely_delete_area (
  pId       uuid
) RETURNS   bool
AS $$
DECLARE
  vMessage  text;
BEGIN
  PERFORM SetErrorMessage('Success.');
  PERFORM api.delete_area(pId);
  RETURN true;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;
  PERFORM SetErrorMessage(vMessage);
  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.clear_area --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Deletes all expired areas that have no associated documents.
 * @return {int} - Number of areas deleted
 * @see api.safely_delete_area
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.clear_area (
) RETURNS   int
AS $$
DECLARE
  r         record;
  nDeleted  int;
BEGIN
  nDeleted := 0;
  FOR r IN
    SELECT a.id
      FROM db.area a
     WHERE a.validtodate IS NOT NULL
       AND NOT EXISTS (SELECT id FROM db.document WHERE area = a.id)
  LOOP
    IF api.safely_delete_area(r.id) THEN
      nDeleted := nDeleted + 1;
    END IF;
  END LOOP;

  RETURN nDeleted;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_area ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve an area record by identifier.
 * @param {uuid} pId - Area identifier
 * @return {SETOF api.area}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_area (
  pId         uuid
) RETURNS     SETOF api.area
AS $$
  SELECT * FROM api.area WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_area_id -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve an area identifier by code. Accepts both UUID strings and area codes.
 * @param {text} pCode - Area code or UUID
 * @return {uuid} - Area identifier
 * @see GetArea
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_area_id (
  pCode     text
) RETURNS   uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetArea(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_area --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count area records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_area (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'area', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_area ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List areas with optional filters.
 * @param {jsonb} pSearch - Search conditions: '[{"condition": "AND|OR", "field": "<field>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<value>"}, ...]'
 * @param {jsonb} pFilter - Filter: '{"<field>": "<value>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort by the fields specified in the array
 * @return {SETOF api.area}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_area (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.area
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'area', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.area_member_add ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Adds a user or group to an area (area-first parameter order).
 * @param {uuid} pArea - Area identifier
 * @param {uuid} pMember - User or group identifier
 * @return {void}
 * @see AddMemberToArea
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.area_member_add (
  pArea       uuid,
  pMember     uuid
) RETURNS     void
AS $$
BEGIN
  PERFORM AddMemberToArea(pMember, pArea);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_area_add ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Adds a user or group to an area (member-first parameter order).
 * @param {uuid} pMember - User or group identifier
 * @param {uuid} pArea - Area identifier
 * @return {void}
 * @see AddMemberToArea
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.member_area_add (
  pMember     uuid,
  pArea       uuid
) RETURNS     void
AS $$
BEGIN
  PERFORM AddMemberToArea(pMember, pArea);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.area_member_delete ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Removes a member from an area. If pMember is NULL, removes all members from the area.
 * @param {uuid} pArea - Area identifier
 * @param {uuid} pMember - User or group identifier (NULL to remove all)
 * @return {void}
 * @see DeleteMemberFromArea
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.area_member_delete (
  pArea       uuid,
  pMember     uuid DEFAULT null
) RETURNS     void
AS $$
BEGIN
  PERFORM DeleteMemberFromArea(pArea, pMember);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_area_delete ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Removes an area from a member. If pArea is NULL, removes all areas for the member.
 * @param {uuid} pMember - User or group identifier
 * @param {uuid} pArea - Area identifier (NULL to remove all)
 * @return {void}
 * @see DeleteAreaForMember
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.member_area_delete (
  pMember     uuid,
  pArea       uuid
) RETURNS     void
AS $$
BEGIN
  PERFORM DeleteAreaForMember(pMember, pArea);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW api.member_area --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.member_area
AS
  SELECT * FROM MemberArea;

GRANT SELECT ON api.member_area TO administrator;

--------------------------------------------------------------------------------
-- api.area_member -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List the members (users/groups) of the specified area.
 * @param {uuid} pAreaId - Area identifier
 * @return {TABLE} - Member records (id, type, username, name, description)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.area_member (
  pAreaId     uuid
) RETURNS TABLE (
  id          uuid,
  type        char,
  username    text,
  name        text,
  description text
)
AS $$
  SELECT u.id, u.type, u.username, u.name, u.description
    FROM api.member_area m INNER JOIN db.user u ON u.id = m.memberid
   WHERE m.area = pAreaId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_area -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch areas accessible to the specified user (including inherited via groups and child areas).
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @return {SETOF api.area}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.member_area (
  pUserId   uuid DEFAULT current_userid()
) RETURNS   SETOF api.area
AS $$
  WITH RECURSIVE area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE id IN (
      SELECT area FROM db.member_area WHERE member IN (
        SELECT pUserId
         UNION
        SELECT userid FROM db.member_group WHERE member = pUserId
      )
    )
    UNION
    SELECT a.id, a.parent
      FROM db.area a, area_tree t
     WHERE t.id = a.parent
    ) SELECT a.* FROM api.area a INNER JOIN area_tree USING (id);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- INTERFACE -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.interface
AS
  SELECT * FROM Interface;

GRANT SELECT ON api.interface TO administrator;

--------------------------------------------------------------------------------
-- api.add_interface -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates a new interface.
 * @param {text} pCode - Code
 * @param {text} pName - Name
 * @param {text} pDescription - Description
 * @return {uuid} - New interface identifier
 * @see CreateInterface
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_interface (
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateInterface(pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_interface --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Updates an existing interface.
 * @param {uuid} pId - Interface identifier
 * @param {text} pCode - Code
 * @param {text} pName - Name
 * @param {text} pDescription - Description
 * @return {void}
 * @see UpdateInterface
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_interface (
  pId           uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM UpdateInterface(pId, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_interface -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Creates or updates an interface (upsert). Returns the resulting record.
 * @param {uuid} pId - Interface identifier (NULL to create)
 * @param {text} pCode - Code
 * @param {text} pName - Name
 * @param {text} pDescription - Description
 * @return {SETOF api.interface}
 * @see api.add_interface, api.update_interface
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_interface (
  pId           uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       SETOF api.interface
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_interface(pCode, pName, pDescription);
  ELSE
    PERFORM api.update_interface(pId, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.interface WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_interface --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Deletes an interface.
 * @param {uuid} pId - Interface identifier
 * @return {void}
 * @see DeleteInterface
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_interface (
  pId         uuid
) RETURNS     void
AS $$
BEGIN
  PERFORM DeleteInterface(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_interface -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve an interface record by identifier.
 * @param {uuid} pId - Interface identifier
 * @return {SETOF api.interface}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_interface (
  pId        uuid
) RETURNS    SETOF api.interface
AS $$
  SELECT * FROM api.interface WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_interface ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count interface records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_interface (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'interface', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_interface ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List interfaces with optional filters.
 * @param {jsonb} pSearch - Search conditions: '[{"condition": "AND|OR", "field": "<field>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<value>"}, ...]'
 * @param {jsonb} pFilter - Filter: '{"<field>": "<value>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort by the fields specified in the array
 * @return {SETOF api.interface}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_interface (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.interface
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'interface', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.interface_member_add ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Adds a user or group to an interface.
 * @param {uuid} pMember - User or group identifier
 * @param {uuid} pInterface - Interface identifier
 * @return {void}
 * @see AddMemberToInterface
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.interface_member_add (
  pMember       uuid,
  pInterface    uuid
) RETURNS       void
AS $$
BEGIN
  PERFORM AddMemberToInterface(pMember, pInterface);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_interface_add ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Adds a user or group to an interface (alias with same parameter order).
 * @param {uuid} pMember - User or group identifier
 * @param {uuid} pInterface - Interface identifier
 * @return {void}
 * @see AddMemberToInterface
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.member_interface_add (
  pMember       uuid,
  pInterface    uuid
) RETURNS       void
AS $$
BEGIN
  PERFORM AddMemberToInterface(pMember, pInterface);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.interface_member_delete -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Removes a member from an interface. If pMember is NULL, removes all members.
 * @param {uuid} pInterface - Interface identifier
 * @param {uuid} pMember - User or group identifier (NULL to remove all)
 * @return {void}
 * @see DeleteMemberFromInterface
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.interface_member_delete (
  pInterface    uuid,
  pMember       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM DeleteMemberFromInterface(pInterface, pMember);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_interface_delete -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Removes an interface from a member. If pInterface is NULL, removes all interfaces for the member.
 * @param {uuid} pMember - User or group identifier
 * @param {uuid} pInterface - Interface identifier (NULL to remove all)
 * @return {void}
 * @see DeleteInterfaceForMember
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.member_interface_delete (
  pMember       uuid,
  pInterface    uuid
) RETURNS       void
AS $$
BEGIN
  PERFORM DeleteInterfaceForMember(pMember, pInterface);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_interface --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.member_interface
AS
  SELECT * FROM MemberInterface;

GRANT SELECT ON api.member_interface TO administrator;

--------------------------------------------------------------------------------
-- api.interface_member --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List the members (users/groups) of the specified interface.
 * @param {uuid} pInterfaceId - Interface identifier
 * @return {TABLE} - Member records (id, type, username, name, description)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.interface_member (
  pInterfaceId  uuid
) RETURNS TABLE (
  id            uuid,
  type          char,
  username      text,
  name          text,
  description   text
)
AS $$
  SELECT u.id, u.type, u.username, u.name, u.description
    FROM api.member_interface m INNER JOIN db.user u ON u.id = m.memberid
   WHERE m.interface = pInterfaceId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_interface --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch interfaces accessible to the specified user (including inherited via groups).
 * @param {uuid} pUserId - User identifier (defaults to current user)
 * @return {SETOF api.interface}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.member_interface (
  pUserId   uuid DEFAULT current_userid()
) RETURNS   SETOF api.interface
AS $$
  SELECT *
    FROM api.interface
   WHERE id IN (
     SELECT interface FROM db.member_interface WHERE member IN (
         SELECT pUserId
         UNION ALL
         SELECT userid FROM db.member_group WHERE member = pUserId
     )
   )
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.chmodc ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sets the access bitmask for a class and user/group.
 * @param {uuid} pClass - Class identifier
 * @param {int} pMask - Access mask. Ten bits (d:{acsud}a:{acsud}) where: d = deny bits, a = allow bits: {a=access, c=create, s=select, u=update, d=delete}
 * @param {uuid} pUserId - User or group identifier (defaults to current user)
 * @param {boolean} pRecursive - Recursively set permissions for all child classes
 * @param {boolean} pObjectSet - Set permissions on objects (documents) belonging to the class
 * @return {void}
 * @see kernel.chmodc
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.chmodc (
  pClass        uuid,
  pMask         int,
  pUserId       uuid default current_userid(),
  pRecursive    boolean default true,
  pObjectSet    boolean default false
) RETURNS       void
AS $$
BEGIN
  PERFORM kernel.chmodc(pClass, pMask::bit(10), pUserId, pRecursive, pObjectSet);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.chmodm ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sets the access bitmask for a method and user/group.
 * @param {uuid} pMethod - Method identifier
 * @param {int} pMask - Access mask. Six bits where: x=execute, v=visible, e=enable
 * @param {uuid} pUserId - User or group identifier (defaults to current user)
 * @return {void}
 * @see kernel.chmodm
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.chmodm (
  pMethod   uuid,
  pMask     int,
  pUserId   uuid default current_userid()
) RETURNS   void
AS $$
BEGIN
  PERFORM kernel.chmodm(pMethod, pMask::bit(6), pUserId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.chmodo ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Sets the access bitmask for an object and user/group.
 * @param {uuid} pObject - Object identifier
 * @param {int} pMask - Access mask. Six bits where: s=select, u=update, d=delete
 * @param {uuid} pUserId - User or group identifier (defaults to current user)
 * @return {void}
 * @see kernel.chmodo
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.chmodo (
  pObject   uuid,
  pMask     int,
  pUserId   uuid default current_userid()
) RETURNS   void
AS $$
BEGIN
  PERFORM kernel.chmodo(pObject, pMask::bit(6), pUserId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.check_offline -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Marks users as offline if their last activity exceeds the specified interval.
 * @param {interval} pOffTime - Inactivity threshold (default '5 minute')
 * @return {void}
 * @see CheckOffline
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.check_offline (
  pOffTime      interval DEFAULT '5 minute'
) RETURNS       void
AS $$
DECLARE
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  PERFORM CheckOffline(pOffTime);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.check_session -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Closes sessions that have been inactive for longer than the specified interval.
 * @param {interval} pOffTime - Inactivity threshold (default '3 month')
 * @return {void}
 * @see CheckSession
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.check_session (
  pOffTime      interval DEFAULT '3 month'
) RETURNS       void
AS $$
DECLARE
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  PERFORM CheckSession(pOffTime);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
