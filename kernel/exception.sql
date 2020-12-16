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

CREATE OR REPLACE FUNCTION LoginFailed() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40100: Не выполнен вход в систему.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AuthenticateError (
  pMessage	text
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40101: Вход в систему невозможен. %', pMessage;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION LoginError() RETURNS void
AS $$
BEGIN
  PERFORM AuthenticateError('Проверьте правильность имени пользователя и повторите ввод пароля.');
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserLockError() RETURNS void
AS $$
BEGIN
  PERFORM AuthenticateError('Учетная запись заблокирована.');
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION PasswordExpired() RETURNS void
AS $$
BEGIN
  PERFORM AuthenticateError('Истек срок действия пароля.');
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION TokenExpired() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40300: Маркер не найден или истек срок его действия.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION SignatureError () RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40301: Подпись не верна или отсутствует.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION NonceExpired() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40302: Истекло время запроса.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AccessDenied (
  pMessage	text DEFAULT 'данной операции'
) RETURNS void
AS $$
BEGIN
  --RAISE NOTICE '[%] SESSION: ID: %; USER: %', session_user, session_userid(), session_username();
  --RAISE NOTICE '[%] CURRENT: ID: %; USER: %', session_user, current_userid(), current_username();

  RAISE EXCEPTION 'ERR-40303: Недостаточно прав для выполнения %.', pMessage;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AccessDeniedForUser (
  pUserName	text
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40304: Для пользователя "%" данное действие запрещено.', pUserName;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION TokenError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40001: Маркер недействителен.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION TokenBelong() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40002: Маркер принадлежит другому клиенту.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION InvalidScope (
  pValid    text[],
  pInvalid  text[]
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40010: Некоторые запрошенные области были недействительными: {верные=[%], неверные=[%]}', array_to_string(pValid, ', '), array_to_string(pInvalid, ', ');
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AbstractError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40011: У абстрактного класса не может быть объектов.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ChangeClassError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40012: Недопустимо изменение класса объекта.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ChangeAreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40013: Недопустимо изменение подразделения документа.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectEntity() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40014: Неверно задана сущность объекта.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectClassType() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40015: Неверно задан тип объекта.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectDocumentType() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40016: Неверно задан тип документа.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectLocaleCode (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40017: Не найден идентификатор языка по коду: %.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION RootAreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40018: Запрещены операции с документами в корневых зонах.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40019: Не найдена зона с указанным идентификатором.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectAreaCode (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40020: Не найдена зона с кодом: %.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserNotMemberArea (
  pUser		varchar,
  pArea	    varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40021: У пользователя "%" нет доступа к зоне "%".', pUser, pArea;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION InterfaceError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40022: Не найден интерфейс с указанным идентификатором.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserNotMemberInterface (
  pUser		    varchar,
  pInterface	varchar
) RETURNS	    void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40023: У пользователя "%" нет доступа к интерфейсу "%".', pUser, pInterface;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UnknownRoleName (
  pRoleName	varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40024: Группа "%" не существует.', pRoleName;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION RoleExists (
  pRoleName	varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40025: Роль "%" уже существует.', pRoleName;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserNotFound (
  pUserName	varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40026: Пользователь "%" не существует.', pUserName;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserNotFound (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40027: Пользователь с идентификатором "%" не существует.', pId;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION DeleteUserError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40028: Нельзя удалить самого себя.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AlreadyExists (
  pWho		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40029: % уже существует.', pWho;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectKeyInArray (
  pKey		    varchar,
  pArrayName	varchar,
  pArray	    anyarray
) RETURNS	    void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40030: Недопустимый ключ "%" в массиве "%". Допустимые ключи: %.', pKey, pArrayName, pArray;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectValueInArray (
  pValue	    varchar,
  pArrayName	varchar,
  pArray	    anyarray
) RETURNS	    void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40031: Недопустимое значение "%" в массиве "%". Допустимые значения: %.', pValue, pArrayName, pArray;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectCode (
  pCode		varchar,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40032: Недопустимый код "%". Допустимые коды: %.', pCode, pArray;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ObjectNotFound (
  pWho		varchar,
  pParam	varchar,
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40033: Не найден(а/о) % с идентификатором (%): %.', pWho, pParam, pId;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ObjectNotFound (
  pWho		varchar,
  pParam	varchar,
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40033: Не найден(а/о) % по %: %.', pWho, pParam, pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION MethodActionNotFound (
  pObject	numeric,
  pAction	numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40034: Не найден метод объекта "%", для действия: "%" (%).', pObject, pAction, GetActionCode(pAction);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION MethodNotFound (
  pObject	numeric,
  pMethod	numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40035: Не найден метод % объекта "%".', pMethod, pObject;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION MethodByCodeNotFound (
  pObject	numeric,
  pCode     text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40036: Не найден метод по коду "%" для объекта "%".', pCode, pObject;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ChangeObjectStateError (
  pObject	numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40037: Не удалось изменить состояние объекта: %.', pObject;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION RouteIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40038: Путь не должен быть пустым.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION RouteNotFound (
  pRoute	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40039: Не найден путь: "%".', pRoute;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION JsonIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40040: JSON не должен быть пустым';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectJsonKey (
  pRoute	text,
  pKey		text,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40041: [%] Недопустимый ключ "%" в JSON. Допустимые ключи: %.', pRoute, pKey, pArray;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION JsonKeyNotFound (
  pRoute	text,
  pKey		text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40042: [%] Не найден обязательный ключ "%" в JSON.', pRoute, pKey;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectJsonType (
  pType		text,
  pExpected	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40043: Неверный тип JSON "%", ожидается "%".', pType, pExpected;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION MethodIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40044: Идентификатор метода не должен быть пустым';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ActionIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40045: Идентификатор действия не должен быть пустым';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ExecutorIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40046: Исполнитель не должен быть пустым';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectDateInterval (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40047: Дата окончания периода не может быть меньше даты начала периода.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserPasswordChange (
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40048: Не удалось изменить пароль, установлен запрет на изменение пароля.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION SystemRoleError (
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40049: Операции изменения, удаления для системных ролей запрещены.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION LoginIpTableError (
  pHost		inet
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40050: Вход в систему невозможен. Ограничен доступ по IP-адресу: %', host(pHost);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IssuerNotFound (
  pCode     text
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40051: OAuth 2.0: Не найден эмитент: %', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AudienceNotFound()
RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40052: OAuth 2.0: Клиент не найден.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION StateByCodeNotFound (
  pObject	numeric,
  pCode     text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40053: Не найдено состояние по коду "%" для объекта "%".', pCode, pObject;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION RecordExists (
  pCode     varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40054: Запись с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION OperationNotPossible (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40055: Операция невозможна, есть связанные документы.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ViewNotFound (
  pScheme   text,
  pTable	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40056: Представление "%.%" не найдено.', pScheme, pTable;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION InvalidVerificationCodeType (
  pType     char
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40057: Недопустимый код типа верификации: "%".', pType;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectRegistryKey (
  pKey		text,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40060: Недопустимый ключ "%". Допустимые ключи: %.', pKey, pArray;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectRegistryDataType (
  pType		integer
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40061: Неверный тип данных: %.', pType;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION InvalidPhoneNumber (
  pPhone    text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40062: Неправильный номер телефона: %.', pPhone;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION EndPointNotSet (
  pPath		text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40063: Не установлена конечная точка для пути: "%".', pPath;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
