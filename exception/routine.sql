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
    vCharSet := coalesce(nullif(pg_client_encoding(), 'UTF8'), 'UTF-8');
    uResource := SetResource(pId, pRoot, pRoot, 'text/plain', pName, pDescription, vCharSet, pDescription, null, uLocale);
  END IF;

  RETURN uResource;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(0, 0), 'ru', 'ErrorCodes', 'Коды системных ошибок', null_uuid());
SELECT CreateExceptionResource(GetExceptionUUID(0, 0), 'en', 'ErrorCodes', 'System error codes', null_uuid());
SELECT CreateExceptionResource(GetExceptionUUID(0, 0), 'nl', 'ErrorCodes', 'Systeemfoutcodes', null_uuid());
SELECT CreateExceptionResource(GetExceptionUUID(0, 0), 'fr', 'ErrorCodes', 'Codes d''erreur système', null_uuid());
SELECT CreateExceptionResource(GetExceptionUUID(0, 0), 'it', 'ErrorCodes', 'Codici di errore di sistema', null_uuid());

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(401, 1), 'ru', 'LoginFailed', 'Не выполнен вход в систему');
SELECT CreateExceptionResource(GetExceptionUUID(401, 1), 'en', 'LoginFailed', 'Login failed');
SELECT CreateExceptionResource(GetExceptionUUID(401, 1), 'nl', 'LoginFailed', 'Inloggen mislukt');
SELECT CreateExceptionResource(GetExceptionUUID(401, 1), 'fr', 'LoginFailed', 'Échec de la connexion');
SELECT CreateExceptionResource(GetExceptionUUID(401, 1), 'it', 'LoginFailed', 'Accesso non riuscito');

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

SELECT CreateExceptionResource(GetExceptionUUID(401, 2), 'ru', 'AuthenticateError', 'Вход в систему невозможен. %s');
SELECT CreateExceptionResource(GetExceptionUUID(401, 2), 'en', 'AuthenticateError', 'Authenticate Error. %s');
SELECT CreateExceptionResource(GetExceptionUUID(401, 2), 'nl', 'AuthenticateError', 'Authenticatiefout. %s');
SELECT CreateExceptionResource(GetExceptionUUID(401, 2), 'fr', 'AuthenticateError', 'Erreur d''authentification. %s');
SELECT CreateExceptionResource(GetExceptionUUID(401, 2), 'it', 'AuthenticateError', 'Errore di autenticazione. %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(401, 3), 'ru', 'LoginError', 'Проверьте правильность имени пользователя и повторите ввод пароля', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 3), 'en', 'LoginError', 'Check the username is correct and enter the password again', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 3), 'nl', 'LoginError', 'Controleer of de gebruikersnaam correct is en voer het wachtwoord opnieuw in', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 3), 'fr', 'LoginError', 'Vérifiez que le nom d''utilisateur est correct et entrez à nouveau le mot de passe', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 3), 'it', 'LoginError', 'Verifica che il nome utente sia corretto e inserisci nuovamente la password', GetExceptionUUID(401, 2));

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

SELECT CreateExceptionResource(GetExceptionUUID(401, 4), 'ru', 'UserLockError', 'Учетная запись заблокирована', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 4), 'en', 'UserLockError', 'Account is blocked', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 4), 'nl', 'UserLockError', 'Account is geblokkeerd', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 4), 'fr', 'UserLockError', 'Le compte est bloqué', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 4), 'it', 'UserLockError', 'L''account è bloccato', GetExceptionUUID(401, 2));

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

SELECT CreateExceptionResource(GetExceptionUUID(401, 5), 'ru', 'UserTempLockError', 'Учетная запись временно заблокирована до %s', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 5), 'en', 'UserTempLockError', 'Account is temporarily locked until %s', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 5), 'nl', 'UserTempLockError', 'Account is tijdelijk geblokkeerd tot %s', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 5), 'fr', 'UserTempLockError', 'Le compte est temporairement bloqué jusqu''à %s', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 5), 'it', 'UserTempLockError', 'L''account è temporaneamente bloccato fino a %s', GetExceptionUUID(401, 2));

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

SELECT CreateExceptionResource(GetExceptionUUID(401, 6), 'ru', 'PasswordExpired', 'Истек срок действия пароля', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 6), 'en', 'PasswordExpired', 'Password expired', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 6), 'nl', 'PasswordExpired', 'Wachtwoord is verlopen', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 6), 'fr', 'PasswordExpired', 'Mot de passe expiré', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 6), 'it', 'PasswordExpired', 'Password scaduta', GetExceptionUUID(401, 2));

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

SELECT CreateExceptionResource(GetExceptionUUID(401, 7), 'ru', 'SignatureError', 'Подпись не верна или отсутствует');
SELECT CreateExceptionResource(GetExceptionUUID(401, 7), 'en', 'SignatureError', 'Signature is incorrect or missing');
SELECT CreateExceptionResource(GetExceptionUUID(401, 7), 'nl', 'SignatureError', 'Handtekening is onjuist of ontbreekt');
SELECT CreateExceptionResource(GetExceptionUUID(401, 7), 'fr', 'SignatureError', 'La signature est incorrecte ou manquante');
SELECT CreateExceptionResource(GetExceptionUUID(401, 7), 'it', 'SignatureError', 'La firma è errata o mancante');

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

SELECT CreateExceptionResource(GetExceptionUUID(403, 1), 'ru', 'TokenExpired', 'Маркер не найден или истек срок его действия');
SELECT CreateExceptionResource(GetExceptionUUID(403, 1), 'en', 'TokenExpired', 'Token not FOUND or has expired');
SELECT CreateExceptionResource(GetExceptionUUID(403, 1), 'nl', 'TokenExpired', 'Token is niet gevonden of is verlopen');
SELECT CreateExceptionResource(GetExceptionUUID(403, 1), 'fr', 'TokenExpired', 'Le jeton est introuvable ou a expiré');
SELECT CreateExceptionResource(GetExceptionUUID(403, 1), 'it', 'TokenExpired', 'Il token non è stato trovato o è scaduto');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 1), 'ru', 'AccessDenied', 'Доступ запрещен');
SELECT CreateExceptionResource(GetExceptionUUID(400, 1), 'en', 'AccessDenied', 'Access denied');
SELECT CreateExceptionResource(GetExceptionUUID(400, 1), 'nl', 'AccessDenied', 'Toegang geweigerd');
SELECT CreateExceptionResource(GetExceptionUUID(400, 1), 'fr', 'AccessDenied', 'Accès refusé');
SELECT CreateExceptionResource(GetExceptionUUID(400, 1), 'it', 'AccessDenied', 'Accesso negato');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 2), 'ru', 'AccessDeniedForUser', 'Для пользователя %s данное действие запрещено');
SELECT CreateExceptionResource(GetExceptionUUID(400, 2), 'en', 'AccessDeniedForUser', 'Access denied for user %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 2), 'nl', 'AccessDeniedForUser', 'Toegang geweigerd voor gebruiker %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 2), 'fr', 'AccessDeniedForUser', 'Accès refusé pour l''utilisateur %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 2), 'it', 'AccessDeniedForUser', 'Accesso negato per l''utente %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 3), 'ru', 'ExecuteMethodError', 'Недостаточно прав для выполнения метода: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 3), 'en', 'ExecuteMethodError', 'Insufficient rights to execute method: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 3), 'nl', 'ExecuteMethodError', 'Onvoldoende rechten om methode uit te voeren: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 3), 'fr', 'ExecuteMethodError', 'Droits insuffisants pour exécuter la méthode: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 3), 'it', 'ExecuteMethodError', 'Diritti insufficienti per eseguire il metodo: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 4), 'ru', 'NonceExpired', 'Истекло время запроса');
SELECT CreateExceptionResource(GetExceptionUUID(400, 4), 'en', 'NonceExpired', 'Request timed out');
SELECT CreateExceptionResource(GetExceptionUUID(400, 4), 'nl', 'NonceExpired', 'Het verzoek is verlopen');
SELECT CreateExceptionResource(GetExceptionUUID(400, 4), 'fr', 'NonceExpired', 'La requête a expiré');
SELECT CreateExceptionResource(GetExceptionUUID(400, 4), 'it', 'NonceExpired', 'La richiesta è scaduta');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 5), 'ru', 'TokenError', 'Маркер недействителен');
SELECT CreateExceptionResource(GetExceptionUUID(400, 5), 'en', 'TokenError', 'Token invalid');
SELECT CreateExceptionResource(GetExceptionUUID(400, 5), 'nl', 'TokenError', 'Token is ongeldig');
SELECT CreateExceptionResource(GetExceptionUUID(400, 5), 'fr', 'TokenError', 'Jeton invalide');
SELECT CreateExceptionResource(GetExceptionUUID(400, 5), 'it', 'TokenError', 'Token non valido');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 6), 'ru', 'TokenBelong', 'Маркер принадлежит другому клиенту');
SELECT CreateExceptionResource(GetExceptionUUID(400, 6), 'en', 'TokenBelong', 'Token belongs to the other client');
SELECT CreateExceptionResource(GetExceptionUUID(400, 6), 'nl', 'TokenBelong', 'Token behoort tot een andere client'); 
SELECT CreateExceptionResource(GetExceptionUUID(400, 6), 'fr', 'TokenBelong', 'Le jeton appartient à un autre client');
SELECT CreateExceptionResource(GetExceptionUUID(400, 6), 'it', 'TokenBelong', 'Il token appartiene a un altro client');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 7), 'ru', 'InvalidScope', 'Некоторые из запрошенных областей недействительны: {верные=[%s], неверные=[%s]}');
SELECT CreateExceptionResource(GetExceptionUUID(400, 7), 'en', 'InvalidScope', 'Some requested areas were invalid: {valid=[%s], invalid=[%s]}');
SELECT CreateExceptionResource(GetExceptionUUID(400, 7), 'nl', 'InvalidScope', 'Enkele gevraagde scopes zijn ongeldig: {geldig=[%s], ongeldig=[%s]}');
SELECT CreateExceptionResource(GetExceptionUUID(400, 7), 'fr', 'InvalidScope', 'Certaines des étendues demandées n''étaient pas valides: {valide=[%s], invalide=[%s]}');
SELECT CreateExceptionResource(GetExceptionUUID(400, 7), 'it', 'InvalidScope', 'Alcuni ambiti richiesti non erano validi: {valido=[%s], non valido=[%s]}');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 8), 'ru', 'AbstractError', 'У абстрактного класса не может быть объектов');
SELECT CreateExceptionResource(GetExceptionUUID(400, 8), 'en', 'AbstractError', 'An abstract class cannot have objects');
SELECT CreateExceptionResource(GetExceptionUUID(400, 8), 'nl', 'AbstractError', 'Een abstracte klasse kan geen objecten hebben');
SELECT CreateExceptionResource(GetExceptionUUID(400, 8), 'fr', 'AbstractError', 'Une classe abstraite ne peut pas avoir d''objets');
SELECT CreateExceptionResource(GetExceptionUUID(400, 8), 'it', 'AbstractError', 'Una classe astratta non può avere oggetti');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 9), 'ru', 'ChangeClassError', 'Изменение класса объекта не допускается');
SELECT CreateExceptionResource(GetExceptionUUID(400, 9), 'en', 'ChangeClassError', 'Object class change is not allowed');
SELECT CreateExceptionResource(GetExceptionUUID(400, 9), 'nl', 'ChangeClassError', 'Het wijzigen van de klasse van een object is niet toegestaan');
SELECT CreateExceptionResource(GetExceptionUUID(400, 9), 'fr', 'ChangeClassError', 'La modification de la classe d''un objet n''est pas autorisée');
SELECT CreateExceptionResource(GetExceptionUUID(400, 9), 'it', 'ChangeClassError', 'La modifica della classe di un oggetto non è consentita');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 10), 'ru', 'ChangeAreaError', 'Недопустимо изменение области видимости документа');
SELECT CreateExceptionResource(GetExceptionUUID(400, 10), 'en', 'ChangeAreaError', 'Changing document area is not allowed');
SELECT CreateExceptionResource(GetExceptionUUID(400, 10), 'nl', 'ChangeAreaError', 'Het wijzigen van het gebied van een document is niet toegestaan');
SELECT CreateExceptionResource(GetExceptionUUID(400, 10), 'fr', 'ChangeAreaError', 'La modification de la zone d''un document n''est pas autorisée');
SELECT CreateExceptionResource(GetExceptionUUID(400, 10), 'it', 'ChangeAreaError', 'La modifica dell''area di un documento non è consentita');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 11), 'ru', 'IncorrectEntity', 'Неверно задана сущность объекта');
SELECT CreateExceptionResource(GetExceptionUUID(400, 11), 'en', 'IncorrectEntity', 'Object entity is set incorrectly');
SELECT CreateExceptionResource(GetExceptionUUID(400, 11), 'nl', 'IncorrectEntity', 'De entiteit van het object is onjuist ingesteld');
SELECT CreateExceptionResource(GetExceptionUUID(400, 11), 'fr', 'IncorrectEntity', 'L''entité de l''objet est mal définie');
SELECT CreateExceptionResource(GetExceptionUUID(400, 11), 'it', 'IncorrectEntity', 'L''entità dell''oggetto non è impostata correttamente');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 12), 'ru', 'IncorrectClassType', 'Неверно задан тип объекта');
SELECT CreateExceptionResource(GetExceptionUUID(400, 12), 'en', 'IncorrectClassType', 'Invalid object type');
SELECT CreateExceptionResource(GetExceptionUUID(400, 12), 'nl', 'IncorrectClassType', 'Ongeldig objecttype');
SELECT CreateExceptionResource(GetExceptionUUID(400, 12), 'fr', 'IncorrectClassType', 'Type d''objet invalide');
SELECT CreateExceptionResource(GetExceptionUUID(400, 12), 'it', 'IncorrectClassType', 'Tipo di oggetto non valido');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 13), 'ru', 'IncorrectDocumentType', 'Неверно задан тип документа');
SELECT CreateExceptionResource(GetExceptionUUID(400, 13), 'en', 'IncorrectDocumentType', 'Invalid document type');
SELECT CreateExceptionResource(GetExceptionUUID(400, 13), 'nl', 'IncorrectDocumentType', 'Ongeldig documenttype');
SELECT CreateExceptionResource(GetExceptionUUID(400, 13), 'fr', 'IncorrectDocumentType', 'Type de document invalide');
SELECT CreateExceptionResource(GetExceptionUUID(400, 13), 'it', 'IncorrectDocumentType', 'Tipo di documento non valido');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 14), 'ru', 'IncorrectLocaleCode', 'Не найден идентификатор языка по коду: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 14), 'en', 'IncorrectLocaleCode', 'Locale not FOUND by code: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 14), 'nl', 'IncorrectLocaleCode', 'Taal niet gevonden met code: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 14), 'fr', 'IncorrectLocaleCode', 'Langue non trouvée par code: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 14), 'it', 'IncorrectLocaleCode', 'Lingua non trovata per codice: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 15), 'ru', 'RootAreaError', 'Запрещены операции с документами в корневой области.');
SELECT CreateExceptionResource(GetExceptionUUID(400, 15), 'en', 'RootAreaError', 'Operations with documents in root area are prohibited');
SELECT CreateExceptionResource(GetExceptionUUID(400, 15), 'nl', 'RootAreaError', ' Bewerkingen met documenten in het rootgebied zijn verboden');
SELECT CreateExceptionResource(GetExceptionUUID(400, 15), 'fr', 'RootAreaError', 'Les opérations sur les documents dans la zone racine sont interdites');
SELECT CreateExceptionResource(GetExceptionUUID(400, 15), 'it', 'RootAreaError', 'Le operazioni con i documenti nell''area root sono vietate');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 16), 'ru', 'AreaError', 'Область с указанным идентификатором не найдена');
SELECT CreateExceptionResource(GetExceptionUUID(400, 16), 'en', 'AreaError', 'Area not FOUND by specified identifier');
SELECT CreateExceptionResource(GetExceptionUUID(400, 16), 'nl', 'AreaError', 'Gebied niet gevonden met de opgegeven identifier');
SELECT CreateExceptionResource(GetExceptionUUID(400, 16), 'fr', 'AreaError', 'Zone non trouvée par l''identifiant spécifié');
SELECT CreateExceptionResource(GetExceptionUUID(400, 16), 'it', 'AreaError', 'Area non trovata dall''identificatore specificato');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 17), 'ru', 'IncorrectAreaCode', 'Область не найдена по коду: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 17), 'en', 'IncorrectAreaCode', 'Area not FOUND by code: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 17), 'nl', 'IncorrectAreaCode', 'Gebied niet gevonden met code: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 17), 'fr', 'IncorrectAreaCode', 'Zone non trouvée par code: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 17), 'it', 'IncorrectAreaCode', 'Area non trovata per codice: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 18), 'ru', 'UserNotMemberArea', 'Пользователь "%s" не имеет доступа к области "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 18), 'en', 'UserNotMemberArea', 'User "%s" does not have access to area "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 18), 'nl', 'UserNotMemberArea', 'Gebruiker "%s" heeft geen toegang tot gebied "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 18), 'fr', 'UserNotMemberArea', 'L''utilisateur "%s" n''a pas accès à la zone "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 18), 'it', 'UserNotMemberArea', 'L''utente "%s" non ha accesso all''area "%s"');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 19), 'ru', 'InterfaceError', 'Не найден интерфейс с указанным идентификатором');
SELECT CreateExceptionResource(GetExceptionUUID(400, 19), 'en', 'InterfaceError', 'Interface not FOUND by specified identifier');
SELECT CreateExceptionResource(GetExceptionUUID(400, 19), 'nl', 'InterfaceError', 'Interface niet gevonden met de opgegeven identifier');
SELECT CreateExceptionResource(GetExceptionUUID(400, 19), 'fr', 'InterfaceError', 'Interface non trouvée par l''identifiant spécifié');
SELECT CreateExceptionResource(GetExceptionUUID(400, 19), 'it', 'InterfaceError', 'Interfaccia non trovata dall''identificatore specificato');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 20), 'ru', 'UserNotMemberInterface', 'У пользователя "%s" нет доступа к интерфейсу "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 20), 'en', 'UserNotMemberInterface', 'User "%s" does not have access to interface "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 20), 'nl', 'UserNotMemberInterface', 'Gebruiker "%s" heeft geen toegang tot interface "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 20), 'fr', 'UserNotMemberInterface', 'L''utilisateur "%s" n''a pas accès à l''interface "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 20), 'it', 'UserNotMemberInterface', 'L''utente "%s" non ha accesso all''interfaccia "%s"');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 21), 'ru', 'UnknownRoleName', 'Неизвестное имя роли: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 21), 'en', 'UnknownRoleName', 'Unknown role name: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 21), 'nl', 'UnknownRoleName', 'Onbekende rolnaam: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 21), 'fr', 'UnknownRoleName', 'Nom de rôle inconnu: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 21), 'it', 'UnknownRoleName', 'Nome ruolo sconosciuto: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 22), 'ru', 'RoleExists', 'Роль "%s" уже существует');
SELECT CreateExceptionResource(GetExceptionUUID(400, 22), 'en', 'RoleExists', 'Role "%s" already exists');
SELECT CreateExceptionResource(GetExceptionUUID(400, 22), 'nl', 'RoleExists', 'Rol "%s" bestaat al');
SELECT CreateExceptionResource(GetExceptionUUID(400, 22), 'fr', 'RoleExists', 'Le rôle "%s" existe déjà');
SELECT CreateExceptionResource(GetExceptionUUID(400, 22), 'it', 'RoleExists', 'Il ruolo "%s" esiste già');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 23), 'ru', 'UserNotFound', 'Пользователь "%s" не существует');
SELECT CreateExceptionResource(GetExceptionUUID(400, 23), 'en', 'UserNotFound', 'User "%s" does not exist');
SELECT CreateExceptionResource(GetExceptionUUID(400, 23), 'nl', 'UserNotFound', 'Gebruiker "%s" bestaat niet');
SELECT CreateExceptionResource(GetExceptionUUID(400, 23), 'fr', 'UserNotFound', 'L''utilisateur "%s" n''existe pas');
SELECT CreateExceptionResource(GetExceptionUUID(400, 23), 'it', 'UserNotFound', 'L''utente "%s" non esiste');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 24), 'ru', 'UserIdNotFound', 'Пользователь с идентификатором "%s" не существует');
SELECT CreateExceptionResource(GetExceptionUUID(400, 24), 'en', 'UserIdNotFound', 'User with id "%s" does not exist');
SELECT CreateExceptionResource(GetExceptionUUID(400, 24), 'nl', 'UserIdNotFound', 'Gebruiker met id "%s" bestaat niet');
SELECT CreateExceptionResource(GetExceptionUUID(400, 24), 'fr', 'UserIdNotFound', 'Utilisateur avec id "%s" n''existe pas');
SELECT CreateExceptionResource(GetExceptionUUID(400, 24), 'it', 'UserIdNotFound', 'Utente con id "%s" non esiste');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 25), 'ru', 'DeleteUserError', 'Вы не можете удалить себя');
SELECT CreateExceptionResource(GetExceptionUUID(400, 25), 'en', 'DeleteUserError', 'You cannot delete yourself');
SELECT CreateExceptionResource(GetExceptionUUID(400, 25), 'nl', 'DeleteUserError', 'Je kunt jezelf niet verwijderen');
SELECT CreateExceptionResource(GetExceptionUUID(400, 25), 'fr', 'DeleteUserError', 'Vous ne pouvez pas vous supprimer');
SELECT CreateExceptionResource(GetExceptionUUID(400, 25), 'it', 'DeleteUserError', 'Non puoi eliminare te stesso');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 26), 'ru', 'AlreadyExists', '%s уже существует');
SELECT CreateExceptionResource(GetExceptionUUID(400, 26), 'en', 'AlreadyExists', '%s already exists');
SELECT CreateExceptionResource(GetExceptionUUID(400, 26), 'nl', 'AlreadyExists', '%s bestaat al');
SELECT CreateExceptionResource(GetExceptionUUID(400, 26), 'fr', 'AlreadyExists', '%s existe déjà');
SELECT CreateExceptionResource(GetExceptionUUID(400, 26), 'it', 'AlreadyExists', '%s esiste già');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 27), 'ru', 'RecordExists', 'Запись с кодом "%s" уже существует');
SELECT CreateExceptionResource(GetExceptionUUID(400, 27), 'en', 'RecordExists', 'Entry with code "%s" already exists');
SELECT CreateExceptionResource(GetExceptionUUID(400, 27), 'nl', 'RecordExists', 'Record met code "%s" bestaat al');
SELECT CreateExceptionResource(GetExceptionUUID(400, 27), 'fr', 'RecordExists', 'L''entrée avec le code "%s" existe déjà');
SELECT CreateExceptionResource(GetExceptionUUID(400, 27), 'it', 'RecordExists', 'La voce con codice "%s" esiste già');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 28), 'ru', 'InvalidCodes', 'Некоторые коды недействительны: {верные=[%s], неверные=[%s]}');
SELECT CreateExceptionResource(GetExceptionUUID(400, 28), 'en', 'InvalidCodes', 'Some codes were invalid: {valid=[%s], invalid=[%s]}');
SELECT CreateExceptionResource(GetExceptionUUID(400, 28), 'nl', 'InvalidCodes', 'Enkele codes zijn ongeldig: {geldig=[%s], ongeldig=[%s]}');
SELECT CreateExceptionResource(GetExceptionUUID(400, 28), 'fr', 'InvalidCodes', 'Certains codes n''étaient pas valides: {valide=[%s], invalide=[%s]}');
SELECT CreateExceptionResource(GetExceptionUUID(400, 28), 'it', 'InvalidCodes', 'Alcuni codici non erano validi: {valido=[%s], non valido=[%s]}');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 29), 'ru', 'IncorrectCode', 'Недопустимый код "%s". Допустимые коды: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 29), 'en', 'IncorrectCode', 'Invalid code "%s". Valid codes: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 29), 'nl', 'IncorrectCode', 'Ongeldige code "%s". Geldige codes: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 29), 'fr', 'IncorrectCode', 'Code incorrect "%s". Codes valides: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 29), 'it', 'IncorrectCode', 'Codice non valido "%s". Codici validi: [%s]');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 30), 'ru', 'ObjectNotFound', 'Не найден(а/о) %s по %s: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 30), 'en', 'ObjectNotFound', 'Not FOUND %s with %s: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 30), 'nl', 'ObjectNotFound', 'Niet gevonden %s met %s: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 30), 'fr', 'ObjectNotFound', 'Non trouvé %s avec %s: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 30), 'it', 'ObjectNotFound', 'Non trovato %s con %s: %s');

SELECT CreateExceptionResource(GetExceptionUUID(400, 31), 'ru', 'ObjectIdIsNull', 'Не найден(а/о) %s по %s: <null>');
SELECT CreateExceptionResource(GetExceptionUUID(400, 31), 'en', 'ObjectIdIsNull', 'Not FOUND %s with %s: <null>');
SELECT CreateExceptionResource(GetExceptionUUID(400, 31), 'nl', 'ObjectIdIsNull', 'Niet gevonden %s met %s: <null>');
SELECT CreateExceptionResource(GetExceptionUUID(400, 31), 'fr', 'ObjectIdIsNull', 'Non trouvé %s avec %s: <null>');
SELECT CreateExceptionResource(GetExceptionUUID(400, 31), 'it', 'ObjectIdIsNull', 'Non trovato %s con %s: <null>');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 32), 'ru', 'MethodActionNotFound', 'Не найден метод объекта [%s], для действия: %s [%s]. Текущее состояние: %s [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 32), 'en', 'MethodActionNotFound', 'Object [%s] method not FOUND, for action: %s [%s]. Current state: %s [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 32), 'nl', 'MethodActionNotFound', 'Methode van object [%s] niet gevonden, voor actie: %s [%s]. Huidige status: %s [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 32), 'fr', 'MethodActionNotFound', 'Méthode de l''objet [%s] non trouvée, pour l''action: %s [%s]. État actuel: %s [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 32), 'it', 'MethodActionNotFound', 'Metodo dell''oggetto [%s] non trovato, per azione: %s [%s]. Stato attuale: %s [%s]');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 33), 'ru', 'MethodNotFound', 'Не найден метод "%s" объекта "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 33), 'en', 'MethodNotFound', 'Method "%s" of object "%s" not FOUND');
SELECT CreateExceptionResource(GetExceptionUUID(400, 33), 'nl', 'MethodNotFound', 'Methode "%s" van object "%s" niet gevonden');
SELECT CreateExceptionResource(GetExceptionUUID(400, 33), 'fr', 'MethodNotFound', 'Méthode "%s" de l''objet "%s" non trouvée');
SELECT CreateExceptionResource(GetExceptionUUID(400, 33), 'it', 'MethodNotFound', 'Metodo "%s" dell''oggetto "%s" non trovato');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 34), 'ru', 'MethodByCodeNotFound', 'Не найден метод по коду "%s" для объекта "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 34), 'en', 'MethodByCodeNotFound', 'No method FOUND by code "%s" for object "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 34), 'nl', 'MethodByCodeNotFound', 'Geen methode gevonden met code "%s" voor object "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 34), 'fr', 'MethodByCodeNotFound', 'Aucune méthode trouvée par code "%s" pour l''objet "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 34), 'it', 'MethodByCodeNotFound', 'Nessun metodo trovato per codice "%s" per oggetto "%s"');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 35), 'ru', 'ChangeObjectStateError', 'Не удалось изменить состояние объекта: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 35), 'en', 'ChangeObjectStateError', 'Failed to change object state: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 35), 'nl', 'ChangeObjectStateError', 'Kan de status van het object niet wijzigen: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 35), 'fr', 'ChangeObjectStateError', 'Échec de la modification de l''état de l''objet: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 35), 'it', 'ChangeObjectStateError', 'Impossibile modificare lo stato dell''oggetto: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 36), 'ru', 'ChangesNotAllowed', 'Изменения не допускаются');
SELECT CreateExceptionResource(GetExceptionUUID(400, 36), 'en', 'ChangesNotAllowed', 'Changes are not allowed');
SELECT CreateExceptionResource(GetExceptionUUID(400, 36), 'nl', 'ChangesNotAllowed', 'Wijzigingen zijn niet toegestaan');
SELECT CreateExceptionResource(GetExceptionUUID(400, 36), 'fr', 'ChangesNotAllowed', 'Les modifications ne sont pas autorisées');
SELECT CreateExceptionResource(GetExceptionUUID(400, 36), 'it', 'ChangesNotAllowed', 'Le modifiche non sono consentite');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 37), 'ru', 'StateByCodeNotFound', 'Не найдено состояние по коду "%s" для объекта "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 37), 'en', 'StateByCodeNotFound', 'No state FOUND by code "%s" for object "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 37), 'nl', 'StateByCodeNotFound', 'Geen status gevonden met code "%s" voor object "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 37), 'fr', 'StateByCodeNotFound', 'Aucun état trouvé par code "%s" pour l''objet "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 37), 'it', 'StateByCodeNotFound', 'Nessuno stato trovato per codice "%s" per oggetto "%s"');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 38), 'ru', 'MethodIsEmpty', 'Идентификатор метода не должен быть пустым');
SELECT CreateExceptionResource(GetExceptionUUID(400, 38), 'en', 'MethodIsEmpty', 'Method ID must not be empty');
SELECT CreateExceptionResource(GetExceptionUUID(400, 38), 'nl', 'MethodIsEmpty', 'Methode-ID mag niet leeg zijn');
SELECT CreateExceptionResource(GetExceptionUUID(400, 38), 'fr', 'MethodIsEmpty', 'L''ID de la méthode ne doit pas être vide');
SELECT CreateExceptionResource(GetExceptionUUID(400, 38), 'it', 'MethodIsEmpty', 'L''ID del metodo non deve essere vuoto');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 39), 'ru', 'ActionIsEmpty', 'Идентификатор действия не должен быть пустым');
SELECT CreateExceptionResource(GetExceptionUUID(400, 39), 'en', 'ActionIsEmpty', 'Action ID must not be empty');
SELECT CreateExceptionResource(GetExceptionUUID(400, 39), 'nl', 'ActionIsEmpty', 'Actie-ID mag niet leeg zijn');
SELECT CreateExceptionResource(GetExceptionUUID(400, 39), 'fr', 'ActionIsEmpty', 'L''ID de l''action ne doit pas être vide');
SELECT CreateExceptionResource(GetExceptionUUID(400, 39), 'it', 'ActionIsEmpty', 'L''ID dell''azione non deve essere vuoto');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 40), 'ru', 'ExecutorIsEmpty', 'Исполнитель не должен быть пустым');
SELECT CreateExceptionResource(GetExceptionUUID(400, 40), 'en', 'ExecutorIsEmpty', 'The executor must not be empty');
SELECT CreateExceptionResource(GetExceptionUUID(400, 40), 'nl', 'ExecutorIsEmpty', 'De uitvoerder mag niet leeg zijn');
SELECT CreateExceptionResource(GetExceptionUUID(400, 40), 'fr', 'ExecutorIsEmpty', 'L''exécuteur ne doit pas être vide');
SELECT CreateExceptionResource(GetExceptionUUID(400, 40), 'it', 'ExecutorIsEmpty', 'L''esecutore non deve essere vuoto');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 41), 'ru', 'IncorrectDateInterval', 'Дата окончания периода не может быть меньше даты начала периода');
SELECT CreateExceptionResource(GetExceptionUUID(400, 41), 'en', 'IncorrectDateInterval', 'The end date of the period cannot be less than the start date of the period');
SELECT CreateExceptionResource(GetExceptionUUID(400, 41), 'nl', 'IncorrectDateInterval', 'De einddatum van de periode kan niet eerder zijn dan de begindatum van de periode');
SELECT CreateExceptionResource(GetExceptionUUID(400, 41), 'fr', 'IncorrectDateInterval', 'La date de fin de la période ne peut pas être antérieure à la date de début de la période');
SELECT CreateExceptionResource(GetExceptionUUID(400, 41), 'it', 'IncorrectDateInterval', 'La data di fine del periodo non può essere inferiore alla data di inizio del periodo');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 42), 'ru', 'UserPasswordChange', 'Не удалось изменить пароль, установлен запрет на изменение пароля');
SELECT CreateExceptionResource(GetExceptionUUID(400, 42), 'en', 'UserPasswordChange', 'Password change failed, password change is prohibited');
SELECT CreateExceptionResource(GetExceptionUUID(400, 42), 'nl', 'UserPasswordChange', 'Wachtwoord wijzigen mislukt, wachtwoord wijzigen is verboden');
SELECT CreateExceptionResource(GetExceptionUUID(400, 42), 'fr', 'UserPasswordChange', 'Échec de la modification du mot de passe, la modification du mot de passe est interdite');
SELECT CreateExceptionResource(GetExceptionUUID(400, 42), 'it', 'UserPasswordChange', 'Modifica password non riuscita, la modifica della password è vietata');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 43), 'ru', 'SystemRoleError', 'Операции изменения, удаления для системных ролей запрещены');
SELECT CreateExceptionResource(GetExceptionUUID(400, 43), 'en', 'SystemRoleError', 'Change, delete operations for system roles are prohibited');
SELECT CreateExceptionResource(GetExceptionUUID(400, 43), 'nl', 'SystemRoleError', ' Bewerkingen voor wijzigen, verwijderen voor systeemrollen zijn verboden');
SELECT CreateExceptionResource(GetExceptionUUID(400, 43), 'fr', 'SystemRoleError', 'Les opérations de modification, de suppression des rôles système sont interdites');
SELECT CreateExceptionResource(GetExceptionUUID(400, 43), 'it', 'SystemRoleError', 'Le operazioni di modifica, eliminazione per i ruoli di sistema sono vietate');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 44), 'ru', 'LoginIpTableError', 'Вход в систему невозможен. Ограничен доступ по IP-адресу: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 44), 'en', 'LoginIpTableError', 'Login is not possible. Limited access by IP-address: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 44), 'nl', 'LoginIpTableError', 'Inloggen is niet mogelijk. Beperkte toegang via IP-adres: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 44), 'fr', 'LoginIpTableError', 'La connexion n''est pas possible. Accès limité par adresse IP: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 44), 'it', 'LoginIpTableError', 'Accesso non possibile. Accesso limitato tramite indirizzo IP: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 45), 'ru', 'OperationNotPossible', 'Операция невозможна, есть связанные документы');
SELECT CreateExceptionResource(GetExceptionUUID(400, 45), 'en', 'OperationNotPossible', 'Operation is not possible, there are related documents');
SELECT CreateExceptionResource(GetExceptionUUID(400, 45), 'nl', 'OperationNotPossible', 'Bewerking is niet mogelijk, er zijn gerelateerde documenten');
SELECT CreateExceptionResource(GetExceptionUUID(400, 45), 'fr', 'OperationNotPossible', 'L''opération n''est pas possible, il existe des documents associés');
SELECT CreateExceptionResource(GetExceptionUUID(400, 45), 'it', 'OperationNotPossible', 'Operazione non possibile, sono presenti documenti correlati');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 46), 'ru', 'ViewNotFound', 'Представление "%s.%s" не найдено');
SELECT CreateExceptionResource(GetExceptionUUID(400, 46), 'en', 'ViewNotFound', 'View "%s.%s" not FOUND');
SELECT CreateExceptionResource(GetExceptionUUID(400, 46), 'nl', 'ViewNotFound', 'View "%s.%s" niet gevonden');
SELECT CreateExceptionResource(GetExceptionUUID(400, 46), 'fr', 'ViewNotFound', 'Vue "%s.%s" non trouvée');
SELECT CreateExceptionResource(GetExceptionUUID(400, 46), 'it', 'ViewNotFound', 'Vista "%s.%s" non trovata');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 47), 'ru', 'InvalidVerificationCodeType', 'Недопустимый код типа верификации: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 47), 'en', 'InvalidVerificationCodeType', 'Invalid verification type code: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 47), 'nl', 'InvalidVerificationCodeType', 'Ongeldige verificatietypecode: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 47), 'fr', 'InvalidVerificationCodeType', 'Code de type de vérification non valide: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 47), 'it', 'InvalidVerificationCodeType', 'Codice tipo verifica non valido: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 48), 'ru', 'InvalidPhoneNumber', 'Неправильный номер телефона: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 48), 'en', 'InvalidPhoneNumber', 'Invalid phone number: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 48), 'nl', 'InvalidPhoneNumber', 'Ongeldig telefoonnummer: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 48), 'fr', 'InvalidPhoneNumber', 'Numéro de téléphone non valide: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 48), 'it', 'InvalidPhoneNumber', 'Numero di telefono non valido: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 49), 'ru', 'ObjectIsNull', 'Не указан идентификатор объекта');
SELECT CreateExceptionResource(GetExceptionUUID(400, 49), 'en', 'ObjectIsNull', 'Object id not specified');
SELECT CreateExceptionResource(GetExceptionUUID(400, 49), 'nl', 'ObjectIsNull', 'Object-ID niet opgegeven');
SELECT CreateExceptionResource(GetExceptionUUID(400, 49), 'fr', 'ObjectIsNull', 'ID d''objet non spécifié');
SELECT CreateExceptionResource(GetExceptionUUID(400, 49), 'it', 'ObjectIsNull', 'ID oggetto non specificato');


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

SELECT CreateExceptionResource(GetExceptionUUID(400, 50), 'ru', 'PerformActionError', 'Вы не можете выполнить данное действие');
SELECT CreateExceptionResource(GetExceptionUUID(400, 50), 'en', 'PerformActionError', 'You cannot perform this action');
SELECT CreateExceptionResource(GetExceptionUUID(400, 50), 'nl', 'PerformActionError', 'Je kunt deze actie niet uitvoeren');
SELECT CreateExceptionResource(GetExceptionUUID(400, 50), 'fr', 'PerformActionError', 'Vous ne pouvez pas effectuer cette action');
SELECT CreateExceptionResource(GetExceptionUUID(400, 50), 'it', 'PerformActionError', 'Non puoi eseguire questa azione');


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

SELECT CreateExceptionResource(GetExceptionUUID(400, 51), 'ru', 'IdentityNotConfirmed', 'Личность не подтверждена');
SELECT CreateExceptionResource(GetExceptionUUID(400, 51), 'en', 'IdentityNotConfirmed', 'Identity not confirmed');
SELECT CreateExceptionResource(GetExceptionUUID(400, 51), 'nl', 'IdentityNotConfirmed', 'Identiteit niet bevestigd');
SELECT CreateExceptionResource(GetExceptionUUID(400, 51), 'fr', 'IdentityNotConfirmed', 'Identité non confirmée');
SELECT CreateExceptionResource(GetExceptionUUID(400, 51), 'it', 'IdentityNotConfirmed', 'Identità non confermata');


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

SELECT CreateExceptionResource(GetExceptionUUID(400, 52), 'ru', 'ReadOnlyError', 'Операции изменения для ролей только для чтения запрещены');
SELECT CreateExceptionResource(GetExceptionUUID(400, 52), 'en', 'ReadOnlyError', 'Modify operations for read-only roles are not allowed');
SELECT CreateExceptionResource(GetExceptionUUID(400, 52), 'nl', 'ReadOnlyError', 'Wijzigingsbewerkingen voor alleen-lezen rollen zijn niet toegestaan');
SELECT CreateExceptionResource(GetExceptionUUID(400, 52), 'fr', 'ReadOnlyError', 'Les opérations de modification pour les rôles en lecture seule ne sont pas autorisées');
SELECT CreateExceptionResource(GetExceptionUUID(400, 52), 'it', 'ReadOnlyError', 'Le operazioni di modifica per i ruoli di sola lettura non sono consentite');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 53), 'ru', 'ActionAlreadyCompleted', 'Вы уже выполнили это действие');
SELECT CreateExceptionResource(GetExceptionUUID(400, 53), 'en', 'ActionAlreadyCompleted', 'You have already completed this action');
SELECT CreateExceptionResource(GetExceptionUUID(400, 53), 'nl', 'ActionAlreadyCompleted', 'Je hebt deze actie al voltooid');
SELECT CreateExceptionResource(GetExceptionUUID(400, 53), 'fr', 'ActionAlreadyCompleted', 'Vous avez déjà terminé cette action');
SELECT CreateExceptionResource(GetExceptionUUID(400, 53), 'it', 'ActionAlreadyCompleted', 'Hai già completato questa azione');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 60), 'ru', 'JsonIsEmpty', 'JSON не должен быть пустым');
SELECT CreateExceptionResource(GetExceptionUUID(400, 60), 'en', 'JsonIsEmpty', 'JSON must not be empty');
SELECT CreateExceptionResource(GetExceptionUUID(400, 60), 'nl', 'JsonIsEmpty', 'JSON mag niet leeg zijn');
SELECT CreateExceptionResource(GetExceptionUUID(400, 60), 'fr', 'JsonIsEmpty', 'JSON ne doit pas être vide');
SELECT CreateExceptionResource(GetExceptionUUID(400, 60), 'it', 'JsonIsEmpty', 'JSON non deve essere vuoto');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 61), 'ru', 'IncorrectJsonKey', '(%s) Недопустимый ключ "%s". Допустимые ключи: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 61), 'en', 'IncorrectJsonKey', '(%s) Invalid key "%s". Valid keys: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 61), 'nl', 'IncorrectJsonKey', '(%s) Ongeldige sleutel "%s". Geldige sleutels: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 61), 'fr', 'IncorrectJsonKey', '(%s) Clé non valide "%s". Clés valides: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 61), 'it', 'IncorrectJsonKey', '(%s) Chiave non valida "%s". Chiavi valide: [%s]');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 62), 'ru', 'JsonKeyNotFound', '(%s) Не найден обязательный ключ: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 62), 'en', 'JsonKeyNotFound', '(%s) Required key not FOUND: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 62), 'nl', 'JsonKeyNotFound', '(%s) Vereiste sleutel niet gevonden: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 62), 'fr', 'JsonKeyNotFound', '(%s) Clé requise non trouvée: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 62), 'it', 'JsonKeyNotFound', '(%s) Chiave richiesta non trovata: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 63), 'ru', 'IncorrectJsonType', 'Неверный тип "%s", ожидается "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 63), 'en', 'IncorrectJsonType', 'Invalid type "%s", expected "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 63), 'nl', 'IncorrectJsonType', 'Ongeldig type "%s", verwacht "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 63), 'fr', 'IncorrectJsonType', 'Type non valide "%s", attendu "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 63), 'it', 'IncorrectJsonType', 'Tipo non valido "%s", previsto "%s"');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 64), 'ru', 'IncorrectKeyInArray', 'Недопустимый ключ "%s" в массиве "%s". Допустимые ключи: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 64), 'en', 'IncorrectKeyInArray', 'Invalid key "%s" in array "%s". Valid keys: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 64), 'nl', 'IncorrectKeyInArray', 'Ongeldige sleutel "%s" in array "%s". Geldige sleutels: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 64), 'fr', 'IncorrectKeyInArray', 'Clé non valide "%s" dans le tableau "%s". Clés valides: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 64), 'it', 'IncorrectKeyInArray', 'Chiave non valida "%s" nell''array "%s". Chiavi valide: [%s]');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 65), 'ru', 'IncorrectValueInArray', 'Недопустимое значение "%s" в массиве "%s". Допустимые значения: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 65), 'en', 'IncorrectValueInArray', 'Invalid value "%s" in array "%s". Valid values: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 65), 'nl', 'IncorrectValueInArray', 'Ongeldige waarde "%s" in array "%s". Geldige waarden: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 65), 'fr', 'IncorrectValueInArray', 'Valeur non valide "%s" dans le tableau "%s". Valeurs valides: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 65), 'it', 'IncorrectValueInArray', 'Valore non valido "%s" nell''array "%s". Valori validi: [%s]');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 66), 'ru', 'ValueOutOfRange', 'Значение [%s] выходит за пределы допустимого диапазона');
SELECT CreateExceptionResource(GetExceptionUUID(400, 66), 'en', 'ValueOutOfRange', 'Value [%s] is out of range');
SELECT CreateExceptionResource(GetExceptionUUID(400, 66), 'nl', 'ValueOutOfRange', 'Waarde [%s] valt buiten het geldige bereik');
SELECT CreateExceptionResource(GetExceptionUUID(400, 66), 'fr', 'ValueOutOfRange', 'La valeur [%s] est hors limites');
SELECT CreateExceptionResource(GetExceptionUUID(400, 66), 'it', 'ValueOutOfRange', 'Valore [%s] fuori intervallo');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 67), 'ru', 'DateValidityPeriod', 'Дата начала не должна превышать дату окончания');
SELECT CreateExceptionResource(GetExceptionUUID(400, 67), 'en', 'DateValidityPeriod', 'The start date must not exceed the end date');
SELECT CreateExceptionResource(GetExceptionUUID(400, 67), 'nl', 'DateValidityPeriod', 'De begindatum mag de einddatum niet overschrijden');
SELECT CreateExceptionResource(GetExceptionUUID(400, 67), 'fr', 'DateValidityPeriod', 'La date de début ne doit pas dépasser la date de fin');
SELECT CreateExceptionResource(GetExceptionUUID(400, 67), 'it', 'DateValidityPeriod', 'La data di inizio non deve superare la data di fine');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 70), 'ru', 'IssuerNotFound', 'OAuth 2.0: Не найден эмитент: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 70), 'en', 'IssuerNotFound', 'OAuth 2.0: Issuer not FOUND: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 70), 'nl', 'IssuerNotFound', 'OAuth 2.0: Issuer niet gevonden: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 70), 'fr', 'IssuerNotFound', 'OAuth 2.0: Émetteur non trouvé: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 70), 'it', 'IssuerNotFound', 'OAuth 2.0: Emittente non trovato: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 71), 'ru', 'AudienceNotFound', 'OAuth 2.0: Клиент не найден');
SELECT CreateExceptionResource(GetExceptionUUID(400, 71), 'en', 'AudienceNotFound', 'OAuth 2.0: Client not FOUND');
SELECT CreateExceptionResource(GetExceptionUUID(400, 71), 'nl', 'AudienceNotFound', 'OAuth 2.0: Client niet gevonden');
SELECT CreateExceptionResource(GetExceptionUUID(400, 71), 'fr', 'AudienceNotFound', 'OAuth 2.0: Client non trouvé');
SELECT CreateExceptionResource(GetExceptionUUID(400, 71), 'it', 'AudienceNotFound', 'OAuth 2.0: Client non trovato');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 72), 'ru', 'GuestAreaError', 'Запрещены операции с документами в гостевой области.');
SELECT CreateExceptionResource(GetExceptionUUID(400, 72), 'en', 'GuestAreaError', 'Operations with documents in guest area are prohibited');
SELECT CreateExceptionResource(GetExceptionUUID(400, 72), 'nl', 'GuestAreaError', ' Bewerkingen met documenten in het gastgebied zijn verboden');
SELECT CreateExceptionResource(GetExceptionUUID(400, 72), 'fr', 'GuestAreaError', 'Les opérations sur les documents dans la zone invité sont interdites');
SELECT CreateExceptionResource(GetExceptionUUID(400, 72), 'it', 'GuestAreaError', 'Le operazioni con i documenti nell''area ospiti sono vietate');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 73), 'ru', 'NotFound', 'Не найдено');
SELECT CreateExceptionResource(GetExceptionUUID(400, 73), 'en', 'NotFound', 'Not found');
SELECT CreateExceptionResource(GetExceptionUUID(400, 73), 'nl', 'NotFound', 'Niet gevonden');
SELECT CreateExceptionResource(GetExceptionUUID(400, 73), 'fr', 'NotFound', 'Non trouvé');
SELECT CreateExceptionResource(GetExceptionUUID(400, 73), 'it', 'NotFound', 'Non trovato');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 74), 'ru', 'DefaultAreaDocumentError', 'Документ можно изменить только в области «По умолчанию»');
SELECT CreateExceptionResource(GetExceptionUUID(400, 74), 'en', 'DefaultAreaDocumentError', 'The document can only be changed in the "Default" area');
SELECT CreateExceptionResource(GetExceptionUUID(400, 74), 'nl', 'DefaultAreaDocumentError', 'Het document kan alleen worden gewijzigd in het gebied ''Standaard''');
SELECT CreateExceptionResource(GetExceptionUUID(400, 74), 'fr', 'DefaultAreaDocumentError', 'Le document ne peut être modifié que dans la zone ''Par défaut''');
SELECT CreateExceptionResource(GetExceptionUUID(400, 74), 'it', 'DefaultAreaDocumentError', 'Il documento può essere modificato solo nell''area "Predefinito"');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 80), 'ru', 'IncorrectRegistryKey', 'Недопустимый ключ "%s". Допустимые ключи: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 80), 'en', 'IncorrectRegistryKey', 'Invalid key "%s". Valid keys: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 80), 'nl', 'IncorrectRegistryKey', 'Ongeldige sleutel "%s". Geldige sleutels: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 80), 'fr', 'IncorrectRegistryKey', 'Clé non valide "%s". Clés valides: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 80), 'it', 'IncorrectRegistryKey', 'Chiave non valida "%s". Chiavi valide: [%s]');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 81), 'ru', 'IncorrectRegistryDataType', 'Неверный тип данных: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 81), 'en', 'IncorrectRegistryDataType', 'Invalid data type: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 81), 'nl', 'IncorrectRegistryDataType', 'Ongeldig gegevenstype: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 81), 'fr', 'IncorrectRegistryDataType', 'Type de données non valide: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 81), 'it', 'IncorrectRegistryDataType', 'Tipo di dati non valido: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 90), 'ru', 'RouteIsEmpty', 'Путь не должен быть пустым');
SELECT CreateExceptionResource(GetExceptionUUID(400, 90), 'en', 'RouteIsEmpty', 'Path must not be empty');
SELECT CreateExceptionResource(GetExceptionUUID(400, 90), 'nl', 'RouteIsEmpty', 'Pad mag niet leeg zijn');
SELECT CreateExceptionResource(GetExceptionUUID(400, 90), 'fr', 'RouteIsEmpty', 'Le chemin ne doit pas être vide');
SELECT CreateExceptionResource(GetExceptionUUID(400, 90), 'it', 'RouteIsEmpty', 'Il percorso non deve essere vuoto');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 91), 'ru', 'RouteNotFound', 'Не найден маршрут: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 91), 'en', 'RouteNotFound', 'Route not found: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 91), 'nl', 'RouteNotFound', 'Route niet gevonden: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 91), 'fr', 'RouteNotFound', 'Route non trouvée: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 91), 'it', 'RouteNotFound', 'Route non trovata: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 92), 'ru', 'EndPointNotSet', 'Конечная точка не указана для пути: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 92), 'en', 'EndPointNotSet', 'Endpoint not set for path: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 92), 'nl', 'EndPointNotSet', 'Eindpunt niet ingesteld voor pad: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 92), 'fr', 'EndPointNotSet', 'Point de terminaison non défini pour le chemin: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 92), 'it', 'EndPointNotSet', 'Endpoint non impostato per percorso: %s');

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

SELECT CreateExceptionResource(GetExceptionUUID(400, 100), 'ru', 'SomethingWentWrong', 'Упс, что-то пошло не так. Наши инженеры уже работают над решением проблемы');
SELECT CreateExceptionResource(GetExceptionUUID(400, 100), 'en', 'SomethingWentWrong', 'Oops, something went wrong. Our engineers are already working on fixing the error');
SELECT CreateExceptionResource(GetExceptionUUID(400, 100), 'nl', 'SomethingWentWrong', 'Oeps, er is iets misgegaan. Onze technici werken al aan het oplossen van het probleem');
SELECT CreateExceptionResource(GetExceptionUUID(400, 100), 'fr', 'SomethingWentWrong', 'Oups, quelque chose s''est mal passé. Nos ingénieurs travaillent déjà à la résolution du problème');
SELECT CreateExceptionResource(GetExceptionUUID(400, 100), 'it', 'SomethingWentWrong', 'Ops, qualcosa è andato storto. I nostri ingegneri stanno già lavorando alla risoluzione del problema');

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
