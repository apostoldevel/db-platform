--------------------------------------------------------------------------------
-- EXCEPTION -------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Parse a structured error message into its numeric code, text, and error identifier.
 * @param {text} pMessage - Raw error string, optionally prefixed with "ERR-GGG-CCC" or legacy "ERR-GGGCC"
 * @return {record} code (int), message (text), and error (text) — the structured identifier (e.g., ERR-400-001)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ParseMessage (
  pMessage      text,
  OUT code      int,
  OUT message   text,
  OUT error     text
) RETURNS       record
AS $$
BEGIN
  IF SubStr(pMessage, 1, 4) = 'ERR-' THEN
    -- New format: ERR-GGG-CCC: message (e.g., ERR-400-001: Access denied.)
    IF SubStr(pMessage, 8, 1) = '-' AND SubStr(pMessage, 12, 2) = ': ' THEN
      code := SubStr(pMessage, 5, 3)::int;
      error := SubStr(pMessage, 1, 11);
      message := SubStr(pMessage, 14);
    -- Old format: ERR-GGGCC: message (e.g., ERR-40001: Access denied.)
    ELSIF SubStr(pMessage, 10, 2) = ': ' THEN
      code := SubStr(pMessage, 5, 3)::int;
      error := format('ERR-%s-%s', SubStr(pMessage, 5, 3), lpad(SubStr(pMessage, 8, 2), 3, '0'));
      message := SubStr(pMessage, 12);
    ELSE
      code := -1;
      error := null;
      message := pMessage;
    END IF;
  ELSE
    code := -1;
    error := null;
    message := pMessage;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Generate a deterministic UUID for an exception identified by group and code.
 * @param {integer} pErrGroup - Error group (maps to HTTP-style status category)
 * @param {integer} pErrCode - Unique error code within the group
 * @return {uuid} Deterministic UUID encoding the error group and code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetExceptionUUID (
  pErrGroup       integer,
  pErrCode        integer
) RETURNS         uuid
AS $$
BEGIN
  RETURN format('00000000-0000-4000-9%s-%s', coalesce(NULLIF(IntToStr(pErrGroup, 'FM000'), '###'), '400'), IntToStr(pErrCode, 'FM000000000000'));
END;
$$ LANGUAGE plpgsql STRICT;

--------------------------------------------------------------------------------

/**
 * @brief Build the localized error string for a given exception group and code.
 * @param {integer} pErrGroup - Error group (maps to HTTP-style status category)
 * @param {integer} pErrCode - Unique error code within the group
 * @return {text} Formatted error string "ERR-GGG-CCC: <message>."
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetExceptionStr (
  pErrGroup      integer,
  pErrCode       integer
) RETURNS        text
AS $$
DECLARE
  vCode          text;
  vMessage       text;
BEGIN
  vCode := format('ERR-%s-%s',
    coalesce(NULLIF(IntToStr(pErrGroup, 'FM000'), '###'), '400'),
    coalesce(NULLIF(IntToStr(pErrCode, 'FM000'), '###'), '000'));

  -- Try error_catalog first (current locale)
  SELECT ect.message INTO vMessage
    FROM db.error_catalog ec
    JOIN db.error_catalog_text ect ON ect.error_id = ec.id
   WHERE ec.code = vCode
     AND ect.locale = coalesce(current_locale(), GetLocale('en'));

  -- Fallback to en locale
  IF vMessage IS NULL THEN
    SELECT ect.message INTO vMessage
      FROM db.error_catalog ec
      JOIN db.error_catalog_text ect ON ect.error_id = ec.id
     WHERE ec.code = vCode
       AND ect.locale = GetLocale('en');
  END IF;

  -- Fallback to resource tree (backward compat)
  IF vMessage IS NULL THEN
    vMessage := GetResource(GetExceptionUUID(pErrGroup, pErrCode));
  END IF;

  RETURN format('%s: %s.', vCode, coalesce(vMessage, 'Unknown error'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Register a localized resource string for an exception code.
 * @param {uuid} pId - Exception UUID (from GetExceptionUUID)
 * @param {text} pLocaleCode - Locale code (e.g. 'en', 'ru')
 * @param {text} pName - Short resource name / exception identifier
 * @param {text} pDescription - Localized error message template
 * @param {uuid} pRoot - Parent resource UUID; defaults to the root error-codes node
 * @return {uuid} Newly created or updated resource UUID
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateExceptionResource (
  pId            uuid,
  pLocaleCode    text,
  pName          text,
  pDescription   text,
  pRoot          uuid DEFAULT null
) RETURNS        uuid
AS $$
DECLARE
  uLocale        uuid;
  uResource      uuid;

  vCharSet       text;
BEGIN
  uLocale := GetLocale(pLocaleCode);

  IF uLocale IS NOT NULL THEN
    pRoot := NULLIF(coalesce(pRoot, GetExceptionUUID(0, 0)), null_uuid());

    -- Bootstrap: create root node if it doesn't exist yet
    IF pRoot IS NOT NULL AND NOT EXISTS (SELECT 1 FROM db.resource WHERE id = pRoot) THEN
      INSERT INTO db.resource (id, root, node, type, level, sequence)
      VALUES (pRoot, pRoot, null, 'text/plain', 0, 1);
    END IF;

    vCharSet := coalesce(nullif(pg_client_encoding(), 'UTF8'), 'UTF-8');
    uResource := SetResource(pId, pRoot, pRoot, 'text/plain', pName, pDescription, vCharSet, pDescription, null, uLocale);
  END IF;

  RETURN uResource;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

/**
 * @brief Raise an error when the login attempt fails.
 * @return {void}
 * @since 1.0.0
 * @see AuthenticateError, LoginError
 */
CREATE OR REPLACE FUNCTION LoginFailed() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(401, 1);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

/**
 * @brief Raise an authentication error with a custom detail message.
 * @param {text} pMessage - Explanation of the authentication failure
 * @return {void}
 * @since 1.0.0
 * @see LoginFailed, LoginError
 */
CREATE OR REPLACE FUNCTION AuthenticateError (
  pMessage    text
) RETURNS     void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(401, 2), pMessage);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error advising the user to check credentials and retry.
 * @return {void}
 * @since 1.0.0
 * @see LoginFailed, AuthenticateError
 */
CREATE OR REPLACE FUNCTION LoginError() RETURNS void
AS $$
BEGIN
  PERFORM AuthenticateError(GetResource(GetExceptionUUID(401, 3)));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the user account is permanently blocked.
 * @return {void}
 * @since 1.0.0
 * @see UserTempLockError
 */
CREATE OR REPLACE FUNCTION UserLockError() RETURNS void
AS $$
BEGIN
  PERFORM AuthenticateError(GetResource(GetExceptionUUID(401, 4)));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the user account is temporarily locked until a given date.
 * @param {timestamptz} pDate - Date/time when the lock expires
 * @return {void}
 * @since 1.0.0
 * @see UserLockError
 */
CREATE OR REPLACE FUNCTION UserTempLockError (
  pDate      timestamptz
) RETURNS    void
AS $$
BEGIN
  PERFORM AuthenticateError(format(GetResource(GetExceptionUUID(401, 5)), DateToStr(pDate)));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the user's password has expired.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION PasswordExpired() RETURNS void
AS $$
BEGIN
  PERFORM AuthenticateError(GetResource(GetExceptionUUID(401, 6)));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the request signature is incorrect or missing.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SignatureError () RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(401, 7);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the token is not found or has expired.
 * @return {void}
 * @since 1.0.0
 * @see TokenError, TokenBelong
 */
CREATE OR REPLACE FUNCTION TokenExpired() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(403, 1);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when access to the requested resource is denied.
 * @return {void}
 * @since 1.0.0
 * @see AccessDeniedForUser, ExecuteMethodError
 */
CREATE OR REPLACE FUNCTION AccessDenied (
) RETURNS     void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 1);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a specific user is denied access.
 * @param {text} pUserName - Username that was denied
 * @return {void}
 * @since 1.0.0
 * @see AccessDenied
 */
CREATE OR REPLACE FUNCTION AccessDeniedForUser (
  pUserName  text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 2), pUserName);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the caller has insufficient rights to execute a method.
 * @param {text} pMessage - Name or description of the method that was denied
 * @return {void}
 * @since 1.0.0
 * @see AccessDenied
 */
CREATE OR REPLACE FUNCTION ExecuteMethodError (
  pMessage    text
) RETURNS     void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 3), pMessage);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the request nonce has expired (timed out).
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NonceExpired() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 4);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the provided token is invalid.
 * @return {void}
 * @since 1.0.0
 * @see TokenExpired, TokenBelong
 */
CREATE OR REPLACE FUNCTION TokenError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 5);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the token belongs to a different client.
 * @return {void}
 * @since 1.0.0
 * @see TokenError, TokenExpired
 */
CREATE OR REPLACE FUNCTION TokenBelong() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 6);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when some requested OAuth scopes are invalid.
 * @param {text[]} pValid - Array of valid scope names
 * @param {text[]} pInvalid - Array of invalid scope names
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION InvalidScope (
  pValid    text[],
  pInvalid  text[]
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 7), array_to_string(pValid, ', '), array_to_string(pInvalid, ', '));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when attempting to instantiate an abstract class.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AbstractError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 8);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when an object's class change is not allowed.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ChangeClassError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 9);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when changing a document's area is not allowed.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ChangeAreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 10);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the object entity is set incorrectly.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IncorrectEntity() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 11);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the object type is invalid.
 * @return {void}
 * @since 1.0.0
 * @see IncorrectDocumentType
 */
CREATE OR REPLACE FUNCTION IncorrectClassType() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 12);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the document type is invalid.
 * @return {void}
 * @since 1.0.0
 * @see IncorrectClassType
 */
CREATE OR REPLACE FUNCTION IncorrectDocumentType() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 13);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a locale cannot be found by the given code.
 * @param {text} pCode - Locale code that was not found
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IncorrectLocaleCode (
  pCode      text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 14), pCode);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when operations on documents in the root area are attempted.
 * @return {void}
 * @since 1.0.0
 * @see GuestAreaError, ChangeAreaError
 */
CREATE OR REPLACE FUNCTION RootAreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 15);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when an area is not found by the specified identifier.
 * @return {void}
 * @since 1.0.0
 * @see IncorrectAreaCode
 */
CREATE OR REPLACE FUNCTION AreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 16);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when an area is not found by the given code.
 * @param {text} pCode - Area code that was not found
 * @return {void}
 * @since 1.0.0
 * @see AreaError
 */
CREATE OR REPLACE FUNCTION IncorrectAreaCode (
  pCode      text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 17), pCode);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a user does not have access to a specific area.
 * @param {text} pUser - Username lacking access
 * @param {text} pArea - Area name the user cannot access
 * @return {void}
 * @since 1.0.0
 * @see UserNotMemberInterface
 */
CREATE OR REPLACE FUNCTION UserNotMemberArea (
  pUser      text,
  pArea      text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 18), pUser, pArea);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when an interface is not found by the specified identifier.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION InterfaceError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 19);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a user does not have access to a specific interface.
 * @param {text} pUser - Username lacking access
 * @param {text} pInterface - Interface name the user cannot access
 * @return {void}
 * @since 1.0.0
 * @see UserNotMemberArea
 */
CREATE OR REPLACE FUNCTION UserNotMemberInterface (
  pUser         text,
  pInterface    text
) RETURNS       void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 20), pUser, pInterface);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the specified role name is not recognized.
 * @param {text} pRoleName - Role name that was not found
 * @return {void}
 * @since 1.0.0
 * @see RoleExists
 */
CREATE OR REPLACE FUNCTION UnknownRoleName (
  pRoleName     text
) RETURNS       void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 21), pRoleName);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the specified role already exists.
 * @param {text} pRoleName - Role name that already exists
 * @return {void}
 * @since 1.0.0
 * @see UnknownRoleName
 */
CREATE OR REPLACE FUNCTION RoleExists (
  pRoleName     text
) RETURNS       void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 22), pRoleName);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a user is not found by username.
 * @param {text} pUserName - Username that does not exist
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UserNotFound (
  pUserName     text
) RETURNS       void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 23), pUserName);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a user is not found by identifier.
 * @param {uuid} pId - User identifier that does not exist
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UserNotFound (
  pId           uuid
) RETURNS       void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 24), pId);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a user attempts to delete their own account.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteUserError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 25);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise a generic error when a named entity already exists.
 * @param {text} pWho - Description of the entity that already exists
 * @return {void}
 * @since 1.0.0
 * @see RecordExists
 */
CREATE OR REPLACE FUNCTION AlreadyExists (
  pWho       text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 26), pWho);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a record with the given code already exists.
 * @param {text} pCode - Code of the duplicate entry
 * @return {void}
 * @since 1.0.0
 * @see AlreadyExists
 */
CREATE OR REPLACE FUNCTION RecordExists (
  pCode     text
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 27), pCode);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error listing valid and invalid codes from a request.
 * @param {text[]} pValid - Array of accepted codes
 * @param {text[]} pInvalid - Array of rejected codes
 * @return {void}
 * @since 1.0.0
 * @see IncorrectCode
 */
CREATE OR REPLACE FUNCTION InvalidCodes (
  pValid    text[],
  pInvalid  text[]
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 28), array_to_string(pValid, ', '), array_to_string(pInvalid, ', '));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a single code is invalid, showing allowed values.
 * @param {text} pCode - The invalid code provided
 * @param {anyarray} pArray - Array of valid codes
 * @return {void}
 * @since 1.0.0
 * @see InvalidCodes
 */
CREATE OR REPLACE FUNCTION IncorrectCode (
  pCode     text,
  pArray    anyarray
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 29), pCode, pArray);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

/**
 * @brief Raise an error when an object is not found by a UUID parameter.
 * @param {text} pWho - Object type description
 * @param {text} pParam - Parameter name used for the lookup
 * @param {uuid} pId - Identifier value (NULL triggers a separate message)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ObjectNotFound (
  pWho      text,
  pParam    text,
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  IF pId IS NULL THEN
    RAISE EXCEPTION '%', format(GetExceptionStr(400, 31), pWho, pParam);
  ELSE
    RAISE EXCEPTION '%', format(GetExceptionStr(400, 30), pWho, pParam, pId);
  END IF;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

/**
 * @brief Raise an error when an object is not found by a text parameter.
 * @param {text} pWho - Object type description
 * @param {text} pParam - Parameter name used for the lookup
 * @param {text} pCode - Code value (NULL triggers a separate message)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ObjectNotFound (
  pWho      text,
  pParam    text,
  pCode     text
) RETURNS   void
AS $$
BEGIN
  IF pCode IS NULL THEN
    RAISE EXCEPTION '%', format(GetExceptionStr(400, 31), pWho, pParam);
  ELSE
    RAISE EXCEPTION '%', format(GetExceptionStr(400, 30), pWho, pParam, pCode);
  END IF;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when no method is found for the given object and action.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pAction - Action identifier that has no corresponding method
 * @return {void}
 * @since 1.0.0
 * @see MethodNotFound, MethodByCodeNotFound
 */
CREATE OR REPLACE FUNCTION MethodActionNotFound (
  pObject    uuid,
  pAction    uuid
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 32), pObject, GetActionCode(pAction), pAction, GetObjectStateCode(pObject), GetObjectState(pObject));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a method is not found for the given object.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pMethod - Method identifier that was not found
 * @return {void}
 * @since 1.0.0
 * @see MethodActionNotFound, MethodByCodeNotFound
 */
CREATE OR REPLACE FUNCTION MethodNotFound (
  pObject    uuid,
  pMethod    uuid
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 33), pMethod, pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when no method is found by code for the given object.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Method code that was not found
 * @return {void}
 * @since 1.0.0
 * @see MethodNotFound, MethodActionNotFound
 */
CREATE OR REPLACE FUNCTION MethodByCodeNotFound (
  pObject    uuid,
  pCode      text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 34), pCode, pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when changing the object's state fails.
 * @param {uuid} pObject - Object whose state change failed
 * @return {void}
 * @since 1.0.0
 * @see StateByCodeNotFound
 */
CREATE OR REPLACE FUNCTION ChangeObjectStateError (
  pObject    uuid
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 35), pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when modifications to the current entity are not allowed.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ChangesNotAllowed (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 36);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when no state is found by code for the given object.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - State code that was not found
 * @return {void}
 * @since 1.0.0
 * @see ChangeObjectStateError
 */
CREATE OR REPLACE FUNCTION StateByCodeNotFound (
  pObject   uuid,
  pCode     text
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 37), pCode, pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the method identifier is empty.
 * @return {void}
 * @since 1.0.0
 * @see ActionIsEmpty
 */
CREATE OR REPLACE FUNCTION MethodIsEmpty (
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 38);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the action identifier is empty.
 * @return {void}
 * @since 1.0.0
 * @see MethodIsEmpty
 */
CREATE OR REPLACE FUNCTION ActionIsEmpty (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 39);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the executor is not specified.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ExecutorIsEmpty (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 40);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the end date precedes the start date.
 * @return {void}
 * @since 1.0.0
 * @see DateValidityPeriod
 */
CREATE OR REPLACE FUNCTION IncorrectDateInterval (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 41);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when password change is prohibited for the user.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UserPasswordChange (
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 42);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when attempting to modify or delete a system role.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SystemRoleError (
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 43);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when login is denied due to IP address restrictions.
 * @param {inet} pHost - IP address that was blocked
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION LoginIpTableError (
  pHost   inet
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 44), host(pHost));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when an operation cannot proceed due to related documents.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION OperationNotPossible (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 45);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a database view is not found by schema and name.
 * @param {text} pScheme - Schema name
 * @param {text} pTable - View name
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ViewNotFound (
  pScheme   text,
  pTable    text
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 46), pScheme, pTable);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the verification type code is invalid.
 * @param {char} pType - Verification type code that was rejected
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION InvalidVerificationCodeType (
  pType     char
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 47), pType);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the provided phone number is invalid.
 * @param {text} pPhone - Phone number that failed validation
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION InvalidPhoneNumber (
  pPhone    text
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 48), pPhone);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

/**
 * @brief Raise an error when the object identifier is not specified (NULL).
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ObjectIsNull (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 49);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

/**
 * @brief Raise an error when the current user cannot perform the requested action.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION PerformActionError (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 50);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

/**
 * @brief Raise an error when the user's identity has not been confirmed.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IdentityNotConfirmed (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 51);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a modification is attempted on a read-only role.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ReadOnlyError (
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 52);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the action has already been completed.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ActionAlreadyCompleted (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 53);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the provided JSON payload is empty.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JsonIsEmpty (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 60);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a JSON key is not valid for the given route.
 * @param {text} pRoute - API route where the key was submitted
 * @param {text} pKey - The invalid JSON key
 * @param {anyarray} pArray - Array of valid keys
 * @return {void}
 * @since 1.0.0
 * @see JsonKeyNotFound
 */
CREATE OR REPLACE FUNCTION IncorrectJsonKey (
  pRoute    text,
  pKey      text,
  pArray    anyarray
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 61), pRoute, pKey, pArray);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a required JSON key is missing from the payload.
 * @param {text} pRoute - API route where the key was expected
 * @param {text} pKey - Name of the missing required key
 * @return {void}
 * @since 1.0.0
 * @see IncorrectJsonKey
 */
CREATE OR REPLACE FUNCTION JsonKeyNotFound (
  pRoute    text,
  pKey      text
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 62), pRoute, pKey);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a JSON value has an unexpected type.
 * @param {text} pType - Actual type received
 * @param {text} pExpected - Expected type
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IncorrectJsonType (
  pType      text,
  pExpected  text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 63), pType, pExpected);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when an invalid key is found inside a JSON array element.
 * @param {text} pKey - The invalid key
 * @param {text} pArrayName - Name of the containing array
 * @param {anyarray} pArray - Array of valid keys
 * @return {void}
 * @since 1.0.0
 * @see IncorrectValueInArray
 */
CREATE OR REPLACE FUNCTION IncorrectKeyInArray (
  pKey          text,
  pArrayName    text,
  pArray        anyarray
) RETURNS       void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 64), pKey, pArrayName, pArray);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when an invalid value is found inside a JSON array element.
 * @param {text} pValue - The invalid value
 * @param {text} pArrayName - Name of the containing array
 * @param {anyarray} pArray - Array of valid values
 * @return {void}
 * @since 1.0.0
 * @see IncorrectKeyInArray
 */
CREATE OR REPLACE FUNCTION IncorrectValueInArray (
  pValue        text,
  pArrayName    text,
  pArray        anyarray
) RETURNS       void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 65), pValue, pArrayName, pArray);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a numeric value is outside the allowed range.
 * @param {integer} pValue - The out-of-range value
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ValueOutOfRange (
  pValue        integer
) RETURNS       void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 66), pValue);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the start date exceeds the end date.
 * @return {void}
 * @since 1.0.0
 * @see IncorrectDateInterval
 */
CREATE OR REPLACE FUNCTION DateValidityPeriod() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 67);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
--- !!! Id: 68 is reserved. See ObjectNotFound
--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the OAuth 2.0 issuer is not found.
 * @param {text} pCode - Issuer identifier that was not found
 * @return {void}
 * @since 1.0.0
 * @see AudienceNotFound
 */
CREATE OR REPLACE FUNCTION IssuerNotFound (
  pCode     text
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 70), pCode);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the OAuth 2.0 client (audience) is not found.
 * @return {void}
 * @since 1.0.0
 * @see IssuerNotFound
 */
CREATE OR REPLACE FUNCTION AudienceNotFound()
RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 71);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when operations on documents in the guest area are attempted.
 * @return {void}
 * @since 1.0.0
 * @see RootAreaError
 */
CREATE OR REPLACE FUNCTION GuestAreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 72);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise a generic "not found" error.
 * @return {void}
 * @since 1.0.0
 * @see ObjectNotFound
 */
CREATE OR REPLACE FUNCTION NotFound() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 73);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a document can only be modified in the default area.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DefaultAreaDocumentError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 74);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a registry key is invalid, showing allowed keys.
 * @param {text} pKey - The invalid registry key
 * @param {anyarray} pArray - Array of valid keys
 * @return {void}
 * @since 1.0.0
 * @see IncorrectRegistryDataType
 */
CREATE OR REPLACE FUNCTION IncorrectRegistryKey (
  pKey       text,
  pArray     anyarray
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 80), pKey, pArray);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a registry data type identifier is invalid.
 * @param {integer} pType - The invalid data type code
 * @return {void}
 * @since 1.0.0
 * @see IncorrectRegistryKey
 */
CREATE OR REPLACE FUNCTION IncorrectRegistryDataType (
  pType      integer
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 81), pType);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the route path is empty.
 * @return {void}
 * @since 1.0.0
 * @see RouteNotFound
 */
CREATE OR REPLACE FUNCTION RouteIsEmpty (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 90);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when the specified route is not found.
 * @param {text} pRoute - Route path that was not found
 * @return {void}
 * @since 1.0.0
 * @see RouteIsEmpty, EndPointNotSet
 */
CREATE OR REPLACE FUNCTION RouteNotFound (
  pRoute     text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 91), pRoute);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise an error when no endpoint is configured for the given path.
 * @param {text} pPath - Path missing an endpoint
 * @return {void}
 * @since 1.0.0
 * @see RouteNotFound
 */
CREATE OR REPLACE FUNCTION EndPointNotSet (
  pPath      text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 92), pPath);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
/**
 * @brief Raise a generic unexpected-error message for end users.
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SomethingWentWrong (
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 100);
END;
$$ LANGUAGE plpgsql;
