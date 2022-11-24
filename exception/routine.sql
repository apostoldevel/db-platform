--------------------------------------------------------------------------------
-- EXCEPTION -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ParseMessage (
  pMessage      text,
  OUT code      int,
  OUT message   text
) RETURNS       record
AS $$
BEGIN
  IF SubStr(pMessage, 1, 4) = 'ERR-' THEN
    code := SubStr(pMessage, 5, 5);
    message := SubStr(pMessage, 12);
  ELSE
    code := -1;
    message := pMessage;
  END IF;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetExceptionUUID (
  pErrGroup		integer,
  pErrCode		integer
) RETURNS 		uuid
AS $$
BEGIN
  RETURN format('00000000-0000-4000-9%s-%s', coalesce(NULLIF(IntToStr(pErrGroup, 'FM000'), '###'), '400'), IntToStr(pErrCode, 'FM000000000000'));
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetExceptionStr (
  pErrGroup		integer,
  pErrCode		integer
) RETURNS		text
AS $$
BEGIN
  RETURN format('ERR-%s%s: %s.', coalesce(NULLIF(IntToStr(pErrGroup, 'FM000'), '###'), '400'), coalesce(NULLIF(IntToStr(pErrCode, 'FM00'), '##'), '00'), GetResource(GetExceptionUUID(pErrGroup, pErrCode)));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateExceptionResource (
  pId			uuid,
  pLocaleCode	text,
  pName			text,
  pDescription	text,
  pRoot			uuid DEFAULT null
) RETURNS		uuid
AS $$
DECLARE
  vCharSet		text;
BEGIN
  pRoot := NULLIF(coalesce(pRoot, GetExceptionUUID(0, 0)), null_uuid());
  vCharSet := coalesce(nullif(pg_client_encoding(), 'UTF8'), 'UTF-8');

  RETURN SetResource(pId, pRoot, pRoot, 'text/plain', pName, pDescription, vCharSet, pDescription, null, GetLocale(pLocaleCode));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(0, 0), 'ru', 'ErrorCodes', 'Коды системных ошибок', null_uuid());
SELECT CreateExceptionResource(GetExceptionUUID(0, 0), 'en', 'ErrorCodes', 'System error codes', null_uuid());

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(401, 1), 'ru', 'LoginFailed', 'Не выполнен вход в систему');
SELECT CreateExceptionResource(GetExceptionUUID(401, 1), 'en', 'LoginFailed', 'Login failed');

CREATE OR REPLACE FUNCTION LoginFailed() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(401, 1);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(401, 2), 'ru', 'AuthenticateError', 'Вход в систему невозможен. %s');
SELECT CreateExceptionResource(GetExceptionUUID(401, 2), 'en', 'AuthenticateError', 'Authenticate Error. %s');

CREATE OR REPLACE FUNCTION AuthenticateError (
  pMessage	text
) RETURNS 	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(401, 2), pMessage);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(401, 3), 'ru', 'LoginError', 'Проверьте правильность имени пользователя и повторите ввод пароля', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 3), 'en', 'LoginError', 'Check the username is correct and enter the password again', GetExceptionUUID(401, 2));

CREATE OR REPLACE FUNCTION LoginError() RETURNS void
AS $$
BEGIN
  PERFORM AuthenticateError(GetResource(GetExceptionUUID(401, 3)));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(401, 4), 'ru', 'UserLockError', 'Учетная запись заблокирована', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 4), 'en', 'UserLockError', 'Account is blocked', GetExceptionUUID(401, 2));

CREATE OR REPLACE FUNCTION UserLockError() RETURNS void
AS $$
BEGIN
  PERFORM AuthenticateError(GetResource(GetExceptionUUID(401, 4)));
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(401, 5), 'ru', 'UserTempLockError', 'Учетная запись временно заблокирована до %s', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 5), 'en', 'UserTempLockError', 'Account is temporarily locked until %s', GetExceptionUUID(401, 2));

CREATE OR REPLACE FUNCTION UserTempLockError (
  pDate		timestamptz
) RETURNS	void
AS $$
BEGIN
  PERFORM AuthenticateError(format(GetResource(GetExceptionUUID(401, 5)), DateToStr(pDate)));
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(401, 6), 'ru', 'PasswordExpired', 'Истек срок действия пароля', GetExceptionUUID(401, 2));
SELECT CreateExceptionResource(GetExceptionUUID(401, 6), 'en', 'PasswordExpired', 'Password expired', GetExceptionUUID(401, 2));

CREATE OR REPLACE FUNCTION PasswordExpired() RETURNS void
AS $$
BEGIN
  PERFORM AuthenticateError(GetResource(GetExceptionUUID(401, 6)));
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(401, 7), 'ru', 'SignatureError', 'Подпись не верна или отсутствует');
SELECT CreateExceptionResource(GetExceptionUUID(401, 7), 'en', 'SignatureError', 'Signature is incorrect or missing');

CREATE OR REPLACE FUNCTION SignatureError () RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(401, 7);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(403, 1), 'ru', 'TokenExpired', 'Маркер не найден или истек срок его действия');
SELECT CreateExceptionResource(GetExceptionUUID(403, 1), 'en', 'TokenExpired', 'Token not FOUND or has expired');

CREATE OR REPLACE FUNCTION TokenExpired() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(403, 1);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 1), 'ru', 'AccessDenied', 'Доступ запрещен');
SELECT CreateExceptionResource(GetExceptionUUID(400, 1), 'en', 'AccessDenied', 'Access denied');

CREATE OR REPLACE FUNCTION AccessDenied (
) RETURNS 	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 1);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 2), 'ru', 'AccessDeniedForUser', 'Для пользователя %s данное действие запрещено');
SELECT CreateExceptionResource(GetExceptionUUID(400, 2), 'en', 'AccessDeniedForUser', 'Access denied for user %s');

CREATE OR REPLACE FUNCTION AccessDeniedForUser (
  pUserName	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 2), pUserName);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 3), 'ru', 'ExecuteMethodError', 'Недостаточно прав для выполнения метода: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 3), 'en', 'ExecuteMethodError', 'Insufficient rights to execute method: %s');

CREATE OR REPLACE FUNCTION ExecuteMethodError (
  pMessage	text
) RETURNS 	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 3), pMessage);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 4), 'ru', 'NonceExpired', 'Истекло время запроса');
SELECT CreateExceptionResource(GetExceptionUUID(400, 4), 'en', 'NonceExpired', 'Request timed out');

CREATE OR REPLACE FUNCTION NonceExpired() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 4);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 5), 'ru', 'TokenError', 'Маркер недействителен');
SELECT CreateExceptionResource(GetExceptionUUID(400, 5), 'en', 'TokenError', 'Token invalid');

CREATE OR REPLACE FUNCTION TokenError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 5);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 6), 'ru', 'TokenBelong', 'Маркер принадлежит другому клиенту');
SELECT CreateExceptionResource(GetExceptionUUID(400, 6), 'en', 'TokenBelong', 'Token belongs to the other client');

CREATE OR REPLACE FUNCTION TokenBelong() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 6);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 7), 'ru', 'InvalidScope', 'Некоторые из запрошенных областей недействительны: {верные=[%s], неверные=[%s]}');
SELECT CreateExceptionResource(GetExceptionUUID(400, 7), 'en', 'InvalidScope', 'Some requested areas were invalid: {valid = [%s], invalid = [%s]}');

CREATE OR REPLACE FUNCTION InvalidScope (
  pValid    text[],
  pInvalid  text[]
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 7), array_to_string(pValid, ', '), array_to_string(pInvalid, ', '));
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 8), 'ru', 'AbstractError', 'У абстрактного класса не может быть объектов');
SELECT CreateExceptionResource(GetExceptionUUID(400, 8), 'en', 'AbstractError', 'An abstract class cannot have objects');

CREATE OR REPLACE FUNCTION AbstractError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 8);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 9), 'ru', 'ChangeClassError', 'Изменение класса объекта не допускается');
SELECT CreateExceptionResource(GetExceptionUUID(400, 9), 'en', 'ChangeClassError', 'Object class change is not allowed');

CREATE OR REPLACE FUNCTION ChangeClassError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 9);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 10), 'ru', 'ChangeAreaError', 'Недопустимо изменение области видимости документа');
SELECT CreateExceptionResource(GetExceptionUUID(400, 10), 'en', 'ChangeAreaError', 'Changing document area is not allowed');

CREATE OR REPLACE FUNCTION ChangeAreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 10);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 11), 'ru', 'IncorrectEntity', 'Неверно задана сущность объекта');
SELECT CreateExceptionResource(GetExceptionUUID(400, 11), 'en', 'IncorrectEntity', 'Object entity is set incorrectly');

CREATE OR REPLACE FUNCTION IncorrectEntity() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 11);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 12), 'ru', 'IncorrectClassType', 'Неверно задан тип объекта');
SELECT CreateExceptionResource(GetExceptionUUID(400, 12), 'en', 'IncorrectClassType', 'Invalid object type');

CREATE OR REPLACE FUNCTION IncorrectClassType() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 12);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 13), 'ru', 'IncorrectDocumentType', 'Неверно задан тип документа');
SELECT CreateExceptionResource(GetExceptionUUID(400, 13), 'en', 'IncorrectDocumentType', 'Invalid document type');

CREATE OR REPLACE FUNCTION IncorrectDocumentType() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 13);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 14), 'ru', 'IncorrectLocaleCode', 'Не найден идентификатор языка по коду: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 14), 'en', 'IncorrectLocaleCode', 'Locale not FOUND by code: %s');

CREATE OR REPLACE FUNCTION IncorrectLocaleCode (
  pCode		text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 14), pCode);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 15), 'ru', 'RootAreaError', 'Запрещены операции с документами в корневой области.');
SELECT CreateExceptionResource(GetExceptionUUID(400, 15), 'en', 'RootAreaError', 'Operations with documents in root area are prohibited');

CREATE OR REPLACE FUNCTION RootAreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 15);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 16), 'ru', 'AreaError', 'Область с указанным идентификатором не найдена');
SELECT CreateExceptionResource(GetExceptionUUID(400, 16), 'en', 'AreaError', 'Area not FOUND by specified identifier');

CREATE OR REPLACE FUNCTION AreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 16);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 17), 'ru', 'IncorrectAreaCode', 'Область не найдена по коду: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 17), 'en', 'IncorrectAreaCode', 'Area not FOUND by code: %s');

CREATE OR REPLACE FUNCTION IncorrectAreaCode (
  pCode		text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 17), pCode);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 18), 'ru', 'UserNotMemberArea', 'Пользователь "%s" не имеет доступа к области "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 18), 'en', 'UserNotMemberArea', 'User "%s" does not have access to area "%s"');

CREATE OR REPLACE FUNCTION UserNotMemberArea (
  pUser		text,
  pArea	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 18), pUser, pArea);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 19), 'ru', 'InterfaceError', 'Не найден интерфейс с указанным идентификатором');
SELECT CreateExceptionResource(GetExceptionUUID(400, 19), 'en', 'InterfaceError', 'Interface not FOUND by specified identifier');

CREATE OR REPLACE FUNCTION InterfaceError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 19);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 20), 'ru', 'UserNotMemberInterface', 'У пользователя "%s" нет доступа к интерфейсу "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 20), 'en', 'UserNotMemberInterface', 'User "%s" does not have access to interface "%s"');

CREATE OR REPLACE FUNCTION UserNotMemberInterface (
  pUser		    text,
  pInterface	text
) RETURNS	    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 20), pUser, pInterface);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 21), 'ru', 'UnknownRoleName', 'Неизвестное имя роли: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 21), 'en', 'UnknownRoleName', 'Unknown role name: %s');

CREATE OR REPLACE FUNCTION UnknownRoleName (
  pRoleName	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 21), pRoleName);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 22), 'ru', 'RoleExists', 'Роль "%s" уже существует');
SELECT CreateExceptionResource(GetExceptionUUID(400, 22), 'en', 'RoleExists', 'Role "%s" already exists');

CREATE OR REPLACE FUNCTION RoleExists (
  pRoleName	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 22), pRoleName);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 23), 'ru', 'UserNotFound', 'Пользователь "%s" не существует');
SELECT CreateExceptionResource(GetExceptionUUID(400, 23), 'en', 'UserNotFound', 'User "%s" does not exist');

CREATE OR REPLACE FUNCTION UserNotFound (
  pUserName	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 23), pUserName);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 24), 'ru', 'UserNotFound', 'Пользователь с идентификатором "%s" не существует');
SELECT CreateExceptionResource(GetExceptionUUID(400, 24), 'en', 'UserNotFound', 'User with id "%s" does not exist');

CREATE OR REPLACE FUNCTION UserNotFound (
  pId		uuid
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 24), pId);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 25), 'ru', 'DeleteUserError', 'Вы не можете удалить себя');
SELECT CreateExceptionResource(GetExceptionUUID(400, 25), 'en', 'DeleteUserError', 'You cannot delete yourself');

CREATE OR REPLACE FUNCTION DeleteUserError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 25);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 26), 'ru', 'AlreadyExists', '%s уже существует');
SELECT CreateExceptionResource(GetExceptionUUID(400, 26), 'en', 'AlreadyExists', '%s already exists');

CREATE OR REPLACE FUNCTION AlreadyExists (
  pWho		text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 26), pWho);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 27), 'ru', 'RecordExists', 'Запись с кодом "%s" уже существует');
SELECT CreateExceptionResource(GetExceptionUUID(400, 27), 'en', 'RecordExists', 'Entry with code "%s" already exists');

CREATE OR REPLACE FUNCTION RecordExists (
  pCode     text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 27), pCode);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 28), 'ru', 'InvalidCodes', 'Некоторые коды недействительны: {верные=[%s], неверные=[%s]}');
SELECT CreateExceptionResource(GetExceptionUUID(400, 28), 'en', 'InvalidCodes', 'Some codes were invalid: {valid = [%s], invalid = [%s]}');

CREATE OR REPLACE FUNCTION InvalidCodes (
  pValid    text[],
  pInvalid  text[]
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 28), array_to_string(pValid, ', '), array_to_string(pInvalid, ', '));
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 29), 'ru', 'IncorrectCode', 'Недопустимый код "%s". Допустимые коды: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 29), 'en', 'IncorrectCode', 'Invalid code "%s". Valid codes: [%s]');

CREATE OR REPLACE FUNCTION IncorrectCode (
  pCode		text,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 29), pCode, pArray);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 30), 'ru', 'ObjectNotFound', 'Не найден(а/о) %s по %s: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 30), 'en', 'ObjectNotFound', 'Not FOUND %s with %s: %s');

SELECT CreateExceptionResource(GetExceptionUUID(400, 68), 'ru', 'ObjectNotFound', 'Не найден(а/о) %s по %s: <null>');
SELECT CreateExceptionResource(GetExceptionUUID(400, 68), 'en', 'ObjectNotFound', 'Not FOUND %s with %s: <null>');

CREATE OR REPLACE FUNCTION ObjectNotFound (
  pWho		text,
  pParam	text,
  pId		uuid
) RETURNS	void
AS $$
BEGIN
  IF pId IS NULL THEN
    RAISE EXCEPTION '%', format(GetExceptionStr(400, 68), pWho, pParam);
  ELSE
    RAISE EXCEPTION '%', format(GetExceptionStr(400, 30), pWho, pParam, pId);
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ObjectNotFound (
  pWho		text,
  pParam	text,
  pCode		text
) RETURNS	void
AS $$
BEGIN
  IF pCode IS NULL THEN
    RAISE EXCEPTION '%', format(GetExceptionStr(400, 68), pWho, pParam);
  ELSE
    RAISE EXCEPTION '%', format(GetExceptionStr(400, 30), pWho, pParam, pCode);
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 32), 'ru', 'MethodActionNotFound', 'Не найден метод объекта [%s], для действия: %s [%s]. Текущее состояние: %s [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 32), 'en', 'MethodActionNotFound', 'Object [%s] method not FOUND, for action: %s [%s]. Current state: %s [%s]');

CREATE OR REPLACE FUNCTION MethodActionNotFound (
  pObject	uuid,
  pAction	uuid
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 32), pObject, GetActionCode(pAction), pAction, GetObjectStateCode(pObject), GetObjectState(pObject));
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 33), 'ru', 'MethodNotFound', 'Не найден метод "%s" объекта "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 33), 'en', 'MethodNotFound', 'Method "%s" of object "%s" not FOUND');

CREATE OR REPLACE FUNCTION MethodNotFound (
  pObject	uuid,
  pMethod	uuid
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 33), pMethod, pObject);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 34), 'ru', 'MethodByCodeNotFound', 'Не найден метод по коду "%s" для объекта "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 34), 'en', 'MethodByCodeNotFound', 'No method FOUND by code "%s" for object "%s"');

CREATE OR REPLACE FUNCTION MethodByCodeNotFound (
  pObject	uuid,
  pCode     text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 34), pCode, pObject);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 35), 'ru', 'ChangeObjectStateError', 'Не удалось изменить состояние объекта: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 35), 'en', 'ChangeObjectStateError', 'Failed to change object state: %s');

CREATE OR REPLACE FUNCTION ChangeObjectStateError (
  pObject	uuid
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 35), pObject);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 36), 'ru', 'ChangesNotAllowed', 'Изменения не допускаются');
SELECT CreateExceptionResource(GetExceptionUUID(400, 36), 'en', 'ChangesNotAllowed', 'Changes are not allowed');

CREATE OR REPLACE FUNCTION ChangesNotAllowed (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 36);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 37), 'ru', 'StateByCodeNotFound', 'Не найдено состояние по коду "%s" для объекта "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 37), 'en', 'StateByCodeNotFound', 'No state FOUND by code "%s" for object "%s"');

CREATE OR REPLACE FUNCTION StateByCodeNotFound (
  pObject	uuid,
  pCode     text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 37), pCode, pObject);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 38), 'ru', 'MethodIsEmpty', 'Идентификатор метода не должен быть пустым');
SELECT CreateExceptionResource(GetExceptionUUID(400, 38), 'en', 'MethodIsEmpty', 'Method ID must not be empty');

CREATE OR REPLACE FUNCTION MethodIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 38);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 39), 'ru', 'ActionIsEmpty', 'Идентификатор действия не должен быть пустым');
SELECT CreateExceptionResource(GetExceptionUUID(400, 39), 'en', 'ActionIsEmpty', 'Action ID must not be empty');

CREATE OR REPLACE FUNCTION ActionIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 39);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 40), 'ru', 'ExecutorIsEmpty', 'Исполнитель не должен быть пустым');
SELECT CreateExceptionResource(GetExceptionUUID(400, 40), 'en', 'ExecutorIsEmpty', 'The executor must not be empty');

CREATE OR REPLACE FUNCTION ExecutorIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 40);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 41), 'ru', 'IncorrectDateInterval', 'Дата окончания периода не может быть меньше даты начала периода');
SELECT CreateExceptionResource(GetExceptionUUID(400, 41), 'en', 'IncorrectDateInterval', 'The end date of the period cannot be less than the start date of the period');

CREATE OR REPLACE FUNCTION IncorrectDateInterval (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 41);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 42), 'ru', 'UserPasswordChange', 'Не удалось изменить пароль, установлен запрет на изменение пароля');
SELECT CreateExceptionResource(GetExceptionUUID(400, 42), 'en', 'UserPasswordChange', 'Password change failed, password change is prohibited');

CREATE OR REPLACE FUNCTION UserPasswordChange (
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 42);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 43), 'ru', 'SystemRoleError', 'Операции изменения, удаления для системных ролей запрещены');
SELECT CreateExceptionResource(GetExceptionUUID(400, 43), 'en', 'SystemRoleError', 'Change, delete operations for system roles are prohibited');

CREATE OR REPLACE FUNCTION SystemRoleError (
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 43);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 44), 'ru', 'LoginIpTableError', 'Вход в систему невозможен. Ограничен доступ по IP-адресу: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 44), 'en', 'LoginIpTableError', 'Login is not possible. Limited access by IP-address: %s');

CREATE OR REPLACE FUNCTION LoginIpTableError (
  pHost		inet
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 44), host(pHost));
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 45), 'ru', 'OperationNotPossible', 'Операция невозможна, есть связанные документы');
SELECT CreateExceptionResource(GetExceptionUUID(400, 45), 'en', 'OperationNotPossible', 'Operation is not possible, there are related documents');

CREATE OR REPLACE FUNCTION OperationNotPossible (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 45);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 46), 'ru', 'ViewNotFound', 'Представление "%s.%s" не найдено');
SELECT CreateExceptionResource(GetExceptionUUID(400, 46), 'en', 'ViewNotFound', 'View "%s.%s" not FOUND');

CREATE OR REPLACE FUNCTION ViewNotFound (
  pScheme   text,
  pTable	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 46), pScheme, pTable);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 47), 'ru', 'InvalidVerificationCodeType', 'Недопустимый код типа верификации: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 47), 'en', 'InvalidVerificationCodeType', 'Invalid verification type code: %s');

CREATE OR REPLACE FUNCTION InvalidVerificationCodeType (
  pType     char
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 47), pType);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 48), 'ru', 'InvalidPhoneNumber', 'Неправильный номер телефона: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 48), 'en', 'InvalidPhoneNumber', 'Invalid phone number: %s');

CREATE OR REPLACE FUNCTION InvalidPhoneNumber (
  pPhone    text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 48), pPhone);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 49), 'ru', 'ObjectIsNull', 'Не указан идентификатор объекта');
SELECT CreateExceptionResource(GetExceptionUUID(400, 49), 'en', 'ObjectIsNull', 'Object id not specified');

CREATE OR REPLACE FUNCTION ObjectIsNull (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 49);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 50), 'ru', 'PerformActionError', 'Вы не можете выполнить данное действие');
SELECT CreateExceptionResource(GetExceptionUUID(400, 50), 'en', 'PerformActionError', 'You cannot perform this action');

CREATE OR REPLACE FUNCTION PerformActionError (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 50);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 51), 'ru', 'IdentityNotConfirmed', 'Личность не подтверждена');
SELECT CreateExceptionResource(GetExceptionUUID(400, 51), 'en', 'IdentityNotConfirmed', 'Identity not confirmed');

CREATE OR REPLACE FUNCTION IdentityNotConfirmed (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 51);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 52), 'ru', 'ReadOnlyError', 'Операции изменения для ролей только для чтения запрещены');
SELECT CreateExceptionResource(GetExceptionUUID(400, 52), 'en', 'ReadOnlyError', 'Modify operations for read-only roles are not allowed');

CREATE OR REPLACE FUNCTION ReadOnlyError (
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 52);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 53), 'ru', 'ActionAlreadyCompleted', 'Вы уже выполнили это действие');
SELECT CreateExceptionResource(GetExceptionUUID(400, 53), 'en', 'ActionAlreadyCompleted', 'You have already completed this action');

CREATE OR REPLACE FUNCTION ActionAlreadyCompleted (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 53);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 60), 'ru', 'JsonIsEmpty', 'JSON не должен быть пустым');
SELECT CreateExceptionResource(GetExceptionUUID(400, 60), 'en', 'JsonIsEmpty', 'JSON must not be empty');

CREATE OR REPLACE FUNCTION JsonIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 60);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 61), 'ru', 'IncorrectJsonKey', '(%s) Недопустимый ключ "%s". Допустимые ключи: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 61), 'en', 'IncorrectJsonKey', '(%s) Invalid key "%s". Valid keys: [%s]');

CREATE OR REPLACE FUNCTION IncorrectJsonKey (
  pRoute	text,
  pKey		text,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 61), pRoute, pKey, pArray);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 62), 'ru', 'JsonKeyNotFound', '(%s) Не найден обязательный ключ: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 62), 'en', 'JsonKeyNotFound', '(%s) Required key not FOUND: %s');

CREATE OR REPLACE FUNCTION JsonKeyNotFound (
  pRoute	text,
  pKey		text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 62), pRoute, pKey);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 63), 'ru', 'IncorrectJsonType', 'Неверный тип "%s", ожидается "%s"');
SELECT CreateExceptionResource(GetExceptionUUID(400, 63), 'en', 'IncorrectJsonType', 'Invalid type "%s", expected "%s"');

CREATE OR REPLACE FUNCTION IncorrectJsonType (
  pType		text,
  pExpected	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 63), pType, pExpected);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 64), 'ru', 'IncorrectKeyInArray', 'Недопустимый ключ "%s" в массиве "%s". Допустимые ключи: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 64), 'en', 'IncorrectKeyInArray', 'Invalid key "%s" in array "%s". Valid keys: [%s]');

CREATE OR REPLACE FUNCTION IncorrectKeyInArray (
  pKey		    text,
  pArrayName	text,
  pArray	    anyarray
) RETURNS	    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 64), pKey, pArrayName, pArray);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 65), 'ru', 'IncorrectValueInArray', 'Недопустимое значение "%s" в массиве "%s". Допустимые значения: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 65), 'en', 'IncorrectValueInArray', 'Invalid value "%s" in array "%s". Valid values: [%s]');

CREATE OR REPLACE FUNCTION IncorrectValueInArray (
  pValue	    text,
  pArrayName	text,
  pArray	    anyarray
) RETURNS	    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 65), pValue, pArrayName, pArray);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 66), 'ru', 'ValueOutOfRange', 'Значение [%s] выходит за пределы допустимого диапазона');
SELECT CreateExceptionResource(GetExceptionUUID(400, 66), 'en', 'ValueOutOfRange', 'Value [%s] is out of range');

CREATE OR REPLACE FUNCTION ValueOutOfRange (
  pValue	    integer
) RETURNS	    void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 66), pValue);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 67), 'ru', 'DateValidityPeriod', 'Дата начала не должна превышать дату окончания');
SELECT CreateExceptionResource(GetExceptionUUID(400, 67), 'en', 'DateValidityPeriod', 'The start date must not exceed the end date');

CREATE OR REPLACE FUNCTION DateValidityPeriod() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 67);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
--- !!! Id: 68 занят. Смотреть ObjectNotFound
--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 70), 'ru', 'IssuerNotFound', 'OAuth 2.0: Не найден эмитент: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 70), 'en', 'IssuerNotFound', 'OAuth 2.0: Issuer not FOUND: %s');

CREATE OR REPLACE FUNCTION IssuerNotFound (
  pCode     text
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 70), pCode);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 71), 'ru', 'AudienceNotFound', 'OAuth 2.0: Клиент не найден');
SELECT CreateExceptionResource(GetExceptionUUID(400, 71), 'en', 'AudienceNotFound', 'OAuth 2.0: Client not FOUND');

CREATE OR REPLACE FUNCTION AudienceNotFound()
RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 71);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 72), 'ru', 'GuestAreaError', 'Запрещены операции с документами в гостевой области.');
SELECT CreateExceptionResource(GetExceptionUUID(400, 72), 'en', 'GuestAreaError', 'Operations with documents in guest area are prohibited');

CREATE OR REPLACE FUNCTION GuestAreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 72);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 73), 'ru', 'NotFound', 'Не найдено');
SELECT CreateExceptionResource(GetExceptionUUID(400, 73), 'en', 'NotFound', 'Not found');

CREATE OR REPLACE FUNCTION NotFound() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 73);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 74), 'ru', 'DefaultAreaDocumentError', 'Документ можно изменить только в области «По умолчанию»');
SELECT CreateExceptionResource(GetExceptionUUID(400, 74), 'en', 'DefaultAreaDocumentError', 'The document can only be changed in the "Default" area');

CREATE OR REPLACE FUNCTION DefaultAreaDocumentError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 74);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 80), 'ru', 'IncorrectRegistryKey', 'Недопустимый ключ "%s". Допустимые ключи: [%s]');
SELECT CreateExceptionResource(GetExceptionUUID(400, 80), 'en', 'IncorrectRegistryKey', 'Invalid key "%s". Valid keys: [%s]');

CREATE OR REPLACE FUNCTION IncorrectRegistryKey (
  pKey		text,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 80), pKey, pArray);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 81), 'ru', 'IncorrectRegistryDataType', 'Неверный тип данных: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 81), 'en', 'IncorrectRegistryDataType', 'Invalid data type: %s');

CREATE OR REPLACE FUNCTION IncorrectRegistryDataType (
  pType		integer
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 81), pType);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 90), 'ru', 'RouteIsEmpty', 'Путь не должен быть пустым');
SELECT CreateExceptionResource(GetExceptionUUID(400, 90), 'en', 'RouteIsEmpty', 'Path must not be empty');

CREATE OR REPLACE FUNCTION RouteIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', GetExceptionStr(400, 90);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 91), 'ru', 'RouteNotFound', 'Не найден маршрут: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 91), 'en', 'RouteNotFound', 'Route not found: %s');

CREATE OR REPLACE FUNCTION RouteNotFound (
  pRoute	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 91), pRoute);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------

SELECT CreateExceptionResource(GetExceptionUUID(400, 92), 'ru', 'EndPointNotSet', 'Конечная точка не указана для пути: %s');
SELECT CreateExceptionResource(GetExceptionUUID(400, 92), 'en', 'EndPointNotSet', 'Endpoint not set for path: %s');

CREATE OR REPLACE FUNCTION EndPointNotSet (
  pPath		text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '%', format(GetExceptionStr(400, 92), pPath);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
