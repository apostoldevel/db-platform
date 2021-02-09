--------------------------------------------------------------------------------
-- ADMIN API -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.signin ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Вход в систему по имени и паролю виртуального пользователя.
 * @param {text} pUserName - Пользователь (login)
 * @param {text} pPassword - Пароль
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @out param {text} session - Сессия
 * @out param {text} secret - Секретный ключ для подписи методом HMAC-256
 * @out param {text} code - Одноразовый код авторизации для получения маркера см. OAuth 2.0
 * @return {record}
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
  nAudience     numeric;
BEGIN
  SELECT a.id INTO nAudience FROM oauth2.audience a WHERE a.code = oauth2_current_client_id();

  IF NOT found THEN
    PERFORM AudienceNotFound();
  END IF;

  session := SignIn(CreateOAuth2(nAudience, ARRAY['api']), pUserName, pPassword, pAgent, pHost);

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
 * @brief Выход из системы.
 * @param {text} pSession - Сессия
 * @param {boolean} pCloseAll - Закрыть все сессии
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.signout (
  pSession      text DEFAULT current_session(),
  pCloseAll 	boolean DEFAULT false
) RETURNS       boolean
AS $$
BEGIN
  RETURN SignOut(pSession, pCloseAll);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.authenticate ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Аутентификация.
 * @param {text} pSession - Сессия
 * @param {text} pSecret - Секретный код
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @out param {boolean} authorized - Результат авторизации
 * @out param {numeric} userid - Идентификатор учётной записи
 * @out param {text} code - Код авторизации (разрешение на авторизацию для OAuth2)
 * @out param {text} message - Сообшение
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.authenticate (
  pSession			text,
  pSecret			text,
  pAgent			text DEFAULT null,
  pHost       		inet DEFAULT null,
  OUT authorized    boolean,
  OUT userid		numeric,
  OUT code			text,
  OUT message		text
) RETURNS			record
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
 * Авторизовать.
 * @param {text} pSession - Сессия
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @out param {boolean} authorized - Результат авторизации
 * @out param {numeric} userid - Идентификатор учётной записи
 * @out param {text} message - Сообшение
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.authorize (
  pSession          text,
  pAgent            text DEFAULT null,
  pHost             inet DEFAULT null,
  OUT authorized    boolean,
  OUT userid		numeric,
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
 * Substitute user.
 * Меняет текущего пользователя в активном сеансе на указанного пользователя
 * @param {text} pUserName - Имя пользователь для подстановки
 * @param {text} pPassword - Пароль текущего пользователя
 * @return {void}
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
-- api.login -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему под именем виртуального пользователя.
 * @param {text} pUserName - Имя пользователь
 * @param {text} pPassword - Пароль пользователя
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @out param {text} session - Сессия
 * @out param {text} secret - Секретный ключ для подписи методом HMAC-256
 * @out param {text} code - Одноразовый код авторизации для получения маркера см. OAuth 2.0
 * @return {record} - Возвращяет сессию указанного пользователя
 */
CREATE OR REPLACE FUNCTION api.login (
  pUserName     text,
  pPassword     text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  OUT session   text,
  OUT secret    text,
  OUT code      text
) RETURNS       record
AS $$
BEGIN
  session := Login(CreateSystemOAuth2(), pUserName, pPassword, pAgent, pHost);

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
-- LOCALE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.locale ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Язык
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
  SELECT s.code, s.userid, s.suid, u.username, u.name, s.created, s.updated,
         u.input_last, s.host, u.lc_ip, u.status, u.statustext, u.state, u.statetext,
         u.session_limit
    FROM session s INNER JOIN users u ON s.userid = u.id;

GRANT SELECT ON api.session TO administrator;

--------------------------------------------------------------------------------
-- api.session -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Активные сессии.
 * @param {numeric} pUserId - Идентификатор пользователя
 * @param {text} pUsername - Наименование пользователя (login)
 * @return {SETOF api.session} - Записи
 */
CREATE OR REPLACE FUNCTION api.session (
  pUserId       numeric DEFAULT null,
  pUsername     text DEFAULT null
) RETURNS	    SETOF api.session
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
 * Возвращает сессию
 * @param {numeric} pId - Идентификатор
 * @return {api.session}
 */
CREATE OR REPLACE FUNCTION api.get_session (
  pCode		varchar
) RETURNS	SETOF api.session
AS $$
  SELECT * FROM api.session WHERE code = pCode
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_session ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список сессий.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.session}
 */
CREATE OR REPLACE FUNCTION api.list_session (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.session
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
  SELECT * FROM users;

GRANT SELECT ON api.user TO administrator;

--------------------------------------------------------------------------------
-- api.add_user ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт учётную запись пользователя.
 * @param {text} pUserName - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pName - Полное имя
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @return {numeric}
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
) RETURNS               numeric
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
 * Обновляет учётную запись пользователя.
 * @param {numeric} pId - Идентификатор учетной записи
 * @param {text} pUserName - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pName - Полное имя
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_user (
  pId                   numeric,
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

CREATE OR REPLACE FUNCTION api.set_user (
  pId                   numeric,
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
 * Удаляет учётную запись пользователя.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_user (
  pId         numeric
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
 * Возвращает учётную запись пользователя.
 * @return {SETOF api.user} - Учётная запись пользователя
 */
CREATE OR REPLACE FUNCTION api.get_user (
  pId         numeric DEFAULT current_userid()
) RETURNS     SETOF api.user
AS $$
  SELECT * FROM api.user WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_user ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список пользователей.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.user}
 */
CREATE OR REPLACE FUNCTION api.list_user (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.user
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'user', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.change_password ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет пароль пользователя.
 * @param {numeric} pId - Идентификатор учетной записи
 * @param {text} pOldPass - Старый пароль
 * @param {text} pNewPass - Новый пароль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.change_password (
  pId           numeric,
  pOldPass      text,
  pNewPass      text
) RETURNS       void
AS $$
BEGIN
  IF NOT CheckPassword(pId, pOldPass) THEN
    RAISE EXCEPTION '%', GetErrorMessage();
  END IF;

  PERFORM SetPassword(pId, pNewPass);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.recovery_password -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запускает процедуру восстановления пароля пользователя.
 * @param {text} pIdentifier - Идентификатор пользователя (username, email, phone)
 * @return {uuid} - Талон восстановления (recovery ticket)
 */
CREATE OR REPLACE FUNCTION api.recovery_password (
  pIdentifier		text
) RETURNS			uuid
AS $$
DECLARE
  nTicket			uuid;
  nUserId			numeric;
  vOAuthSecret		text;
BEGIN
  SELECT id INTO nUserId FROM db.user WHERE phone = TrimPhone(pIdentifier) AND type = 'U';

  IF FOUND THEN
	IF IsUserRole(GetGroup('system'), session_userid()) THEN
	  SELECT a.secret INTO vOAuthSecret FROM oauth2.audience a WHERE a.code = session_username();
	  IF found THEN
		PERFORM SubstituteUser(GetUser('admin'), vOAuthSecret);
		nTicket := RecoveryPasswordByPhone(nUserId);
		PERFORM SubstituteUser(session_userid(), vOAuthSecret);
	  END IF;
	ELSE
	  nTicket := RecoveryPasswordByPhone(nUserId);
	END IF;
  END IF;

  SELECT id INTO nUserId FROM db.user WHERE email = pIdentifier AND type = 'U';

  IF FOUND THEN
	IF IsUserRole(GetGroup('system'), session_userid()) THEN
	  SELECT a.secret INTO vOAuthSecret FROM oauth2.audience a WHERE a.code = session_username();
	  IF found THEN
		PERFORM SubstituteUser(GetUser('admin'), vOAuthSecret);
		nTicket := RecoveryPasswordByEmail(nUserId);
		PERFORM SubstituteUser(session_userid(), vOAuthSecret);
	  END IF;
	ELSE
	  nTicket := RecoveryPasswordByEmail(nUserId);
	END IF;
  END IF;

  RETURN coalesce(nTicket, gen_random_uuid());
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.check_recovery_ticket ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Сверяет секретный ответ.
 * @param {uuid} pTicket -  Талон восстановления (recovery ticket)
 * @param {text} vSecurityAnswer - Секретный ответ
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.check_recovery_ticket (
  pTicket			uuid,
  vSecurityAnswer	text,
  OUT result    	bool,
  OUT message   	text
) RETURNS       	record
AS $$
DECLARE
  nUserId			numeric;
BEGIN
  nUserId := CheckRecoveryTicket(pTicket, vSecurityAnswer);

  result := nUserId IS NOT NULL;
  message := GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.reset_password ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Сбрасывает пароль пользователя.
 * @param {uuid} pTicket -  Талон восстановления (recovery ticket)
 * @param {text} vSecurityAnswer - Секретный ответ
 * @param {text} pPassword - Новый пароль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.reset_password (
  pTicket			uuid,
  vSecurityAnswer	text,
  pPassword			text,
  OUT result    	bool,
  OUT message   	text
) RETURNS       	record
AS $$
DECLARE
  nUserId			numeric;
  vOAuthSecret		text;
BEGIN
  nUserId := CheckRecoveryTicket(pTicket, vSecurityAnswer);

  result := nUserId IS NOT NULL;
  message := GetErrorMessage();

  IF result THEN
    SELECT a.secret INTO vOAuthSecret FROM oauth2.audience a WHERE a.code = session_username();

    IF found THEN
	  PERFORM SubstituteUser(GetUser('admin'), vOAuthSecret);
      PERFORM SetPassword(nUserId, pPassword);
      PERFORM SubstituteUser(session_userid(), vOAuthSecret);
	ELSE
      PERFORM SetPassword(nUserId, pPassword);
    END IF;

    UPDATE db.recovery_ticket SET used = true WHERE ticket = pTicket;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.user_member -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список групп пользователя.
 * @return {record} - Группы
 */
CREATE OR REPLACE FUNCTION api.user_member (
  pUserId numeric DEFAULT current_userid()
) RETURNS TABLE (id numeric, username text, name text, description text)
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
 * Возвращает список групп пользователя.
 * @return {record} - Группы
 */
CREATE OR REPLACE FUNCTION api.member_user (
  pUserId numeric DEFAULT current_userid()
) RETURNS TABLE (id numeric, username text, name text, description text)
AS $$
  SELECT * FROM api.user_member(pUserId);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.user_lock ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Блокирует учётную запись пользователя.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.user_lock (
  pId           numeric
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
 * Снимает блокировку с учётной записи пользователя.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки/результата
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.user_unlock (
  pId       numeric
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
 * Возвращает таблицу IP-адресов в виде одной строки.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @param {char} pType - Тип: A - allow; D - denied'
 * @out param {numeric} id - Идентификатор учётной записи пользователя
 * @out param {char} type - Тип: A - allow; D - denied'
 * @out param {text} iptable - IP-адреса в виде одной строки
 * @return {text}
 */
CREATE OR REPLACE FUNCTION api.get_user_iptable (
  pId		numeric,
  pType		char
) RETURNS TABLE (id numeric, type char, iptable text)
AS $$
  SELECT pId, pType, GetIPTableStr(pId, pType);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_user_iptable --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает таблицу IP-адресов из строки.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @param {char} pType - Тип: A - allow; D - denied'
 * @param {text} pIpTable - IP-адреса в виде одной строки
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.set_user_iptable (
  pId       	numeric,
  pType     	char,
  pIpTable  	text
) RETURNS   	void
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
 * Создаёт группу учётных записей пользователя.
 * @param {varchar} pUserName - Группа
 * @param {text} pName - Полное имя
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_group (
  pUserName     text,
  pName         text,
  pDescription  text
) RETURNS       numeric
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
 * Обновляет учётные данные группы.
 * @param {numeric} pId - Идентификатор группы
 * @param {varchar} pUserName - Группа
 * @param {text} pName - Полное имя
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_group (
  pId           numeric,
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

CREATE OR REPLACE FUNCTION api.set_group (
  pId           numeric,
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
 * Удаляет группу.
 * @param {numeric} pId - Идентификатор группы
 * @out {numeric} id - Идентификатор группы
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_group (
  pId           numeric
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
 * Возвращает группу.
 * @return {SETOF api.group} - Группа
 */
CREATE OR REPLACE FUNCTION api.get_group (
  pId         numeric
) RETURNS     SETOF api.group
AS $$
  SELECT * FROM api.group WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_group --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список групп.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.group}
 */
CREATE OR REPLACE FUNCTION api.list_group (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.group
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
 * Добавляет пользователя в группу.
 * @param {numeric} pGroup - Идентификатор группы
 * @param {numeric} pMember - Идентификатор пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.group_member_add (
  pGroup        numeric,
  pMember       numeric
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
 * Добавляет пользователя в группу.
 * @param {numeric} pMember - Идентификатор пользователя
 * @param {numeric} pGroup - Идентификатор группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.member_group_add (
  pMember       numeric,
  pGroup        numeric
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
 * Удаляет пользователя из группу.
 * @param {numeric} pGroup - Идентификатор группы
 * @param {numeric} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанной группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.group_member_delete (
  pGroup        numeric,
  pMember       numeric DEFAULT null
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
 * Удаляет группу для пользователя.
 * @param {numeric} pMember - Идентификатор пользователя
 * @param {numeric} pGroup - Идентификатор группы, при null удаляет все группы для указанного пользователя
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.member_group_delete (
  pMember       numeric,
  pGroup        numeric
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
 * Возвращает список пользователей группы.
 * @return {TABLE} - Группы
 */
CREATE OR REPLACE FUNCTION api.group_member (
  pGroupId    numeric
) RETURNS TABLE (
  id          numeric,
  username    text,
  name        text,
  email       text,
  phone       text,
  statustext  text,
  description text
)
AS $$
  SELECT u.id, u.username, u.name, u.email, u.phone, u.statustext, u.description
    FROM db.member_group m INNER JOIN users u ON u.id = m.member
   WHERE m.userid = pGroupId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_group ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список групп пользователя.
 * @return {TABLE} - Группы
 */
CREATE OR REPLACE FUNCTION api.member_group (
  pUserId     numeric DEFAULT current_userid()
) RETURNS TABLE (
  id          numeric,
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

CREATE OR REPLACE FUNCTION api.get_groups_json (
  pMember       numeric
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
 * Проверяет роль пользователя.
 * @param {numeric} pRole - Идентификатор роли (группы)
 * @param {numeric} pUser - Идентификатор пользователя (учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION api.is_user_role (
  pRole         numeric,
  pUser         numeric DEFAULT current_userid()
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
 * Проверяет роль пользователя.
 * @param {text} pRole - Код роли (группы)
 * @param {text} pUser - Код пользователя (учётной записи)
 * @return {boolean}
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
 * Позвращает тип зоны.
 * @param {numeric} pId - Идентификатор типа зоны
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_area_type (
  pId		numeric
) RETURNS	SETOF api.area_type
AS $$
  SELECT * FROM api.area_type WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.area
AS
  SELECT * FROM Area;

GRANT SELECT ON api.area TO administrator;

--------------------------------------------------------------------------------
-- api.add_area ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт зону.
 * @param {numeric} pParent - Идентификатор "родителя"
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_area (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         varchar,
  pDescription  text DEFAULT null
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateArea(pParent, pType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_area -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет зону.
 * @param {numeric} pId - Идентификатор зоны
 * @param {numeric} pParent - Идентификатор "родителя"
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {timestamp} pValidFromDate - Дата открытия
 * @param {timestamp} pValidToDate - Дата закрытия
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_area (
  pId               numeric,
  pParent           numeric DEFAULT null,
  pType             numeric DEFAULT null,
  pCode             varchar DEFAULT null,
  pName             varchar DEFAULT null,
  pDescription      text DEFAULT null,
  pValidFromDate    timestamp DEFAULT null,
  pValidToDate      timestamp DEFAULT null
) RETURNS           void
AS $$
BEGIN
  PERFORM EditArea(pId, pParent, pType, pCode, pName, pDescription, pValidFromDate, pValidToDate);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_area ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_area (
  pId               numeric,
  pParent           numeric DEFAULT null,
  pType             numeric DEFAULT null,
  pCode             varchar DEFAULT null,
  pName             varchar DEFAULT null,
  pDescription      text DEFAULT null,
  pValidFromDate    timestamp DEFAULT null,
  pValidToDate      timestamp DEFAULT null
) RETURNS           SETOF api.area
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_area(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_area(pId, pParent, pType, pCode, pName, pDescription, pValidFromDate, pValidToDate);
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
 * Удаляет зону.
 * @param {numeric} pId - Идентификатор зоны
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_area (
  pId       numeric
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
 * Безопасно удаляет зону.
 * @param {numeric} pId - Идентификатор зоны
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.safely_delete_area (
  pId       numeric
) RETURNS   bool
AS $$
DECLARE
  vMessage  text;
BEGIN
  PERFORM SetErrorMessage('Успешно.');
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
 * Удаляет зоны без документов.
 * @return {void}
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
 * Возвращает данные зоны.
 * @return {record} - Данные зоны
 */
CREATE OR REPLACE FUNCTION api.get_area (
  pId         numeric
) RETURNS     SETOF api.area
AS $$
  SELECT * FROM api.area WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_area ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список зон.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.area}
 */
CREATE OR REPLACE FUNCTION api.list_area (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.area
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
 * Добавляет пользователя или группу в зону.
 * @param {numeric} pArea - Идентификатор зоны
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.area_member_add (
  pArea       numeric,
  pMember     numeric
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
 * Добавляет пользователя или группу в зону.
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @param {numeric} pArea - Идентификатор зоны
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.member_area_add (
  pMember     numeric,
  pArea       numeric
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
 * Удаляет пользователя из зоны.
 * @param {numeric} pArea - Идентификатор зоны
 * @param {numeric} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанной зоны
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.area_member_delete (
  pArea       numeric,
  pMember     numeric DEFAULT null
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
 * Удаляет зону для пользователя.
 * @param {numeric} pMember - Идентификатор пользователя
 * @param {numeric} pArea - Идентификатор зоны, при null удаляет все зоны для указанного пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.member_area_delete (
  pMember     numeric,
  pArea       numeric
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
 * Возвращает список участников зоны.
 * @return {SETOF record} - Запись
 */
CREATE OR REPLACE FUNCTION api.area_member (
  pAreaId     numeric
) RETURNS TABLE (
  id          numeric,
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
 * Возвращает зоны доступные участнику.
 * @return {record} - Данные зоны
 */
CREATE OR REPLACE FUNCTION api.member_area (
  pUserId   numeric DEFAULT current_userid()
) RETURNS   SETOF api.area
AS $$
  WITH RECURSIVE area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE id IN (
      SELECT area FROM db.member_area WHERE member IN (
        SELECT pUserId
         UNION ALL
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
 * Создаёт интерфейс.
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор интерфейса
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_interface (
  pName         varchar,
  pDescription  text DEFAULT null
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateInterface(pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_interface --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет интерфейс.
 * @param {numeric} pId - Идентификатор интерфейса
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_interface (
  pId           numeric,
  pName         varchar,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM UpdateInterface(pId, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_interface -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_interface (
  pId           numeric,
  pName         varchar,
  pDescription  text DEFAULT null
) RETURNS       SETOF api.interface
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_interface(pName, pDescription);
  ELSE
    PERFORM api.update_interface(pId, pName, pDescription);
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
 * Удаляет интерфейс.
 * @param {numeric} pId - Идентификатор интерфейса
 * @out {numeric} id - Идентификатор интерфейса
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_interface (
  pId         numeric
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
 * Возвращает данные интерфейса.
 * @return {record} - Данные интерфейса
 */
CREATE OR REPLACE FUNCTION api.get_interface (
  pId		numeric
) RETURNS	SETOF api.interface
AS $$
  SELECT * FROM api.interface WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_interface ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список интерфейсов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.area}
 */
CREATE OR REPLACE FUNCTION api.list_interface (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.interface
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
 * Добавляет пользователя или группу к интерфейсу.
 * @param {numeric} pInterface - Идентификатор интерфейса
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.interface_member_add (
  pMember       numeric,
  pInterface	numeric
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
 * Добавляет пользователя или группу к интерфейсу.
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @param {numeric} pInterface - Идентификатор интерфейса
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.member_interface_add (
  pMember       numeric,
  pInterface	numeric
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
 * Удаляет пользователя или группу из интерфейса.
 * @param {numeric} pInterface - Идентификатор интерфейса
 * @param {numeric} pMember - Идентификатор пользователя/группы, при null удаляет всех пользователей из указанного интерфейса
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.interface_member_delete (
  pInterface	numeric,
  pMember       numeric DEFAULT null
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
 * Удаляет интерфейс для пользователя или группу.
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @param {numeric} pInterface - Идентификатор интерфейса, при null удаляет все рабочие места для указанного пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.member_interface_delete (
  pMember       numeric,
  pInterface	numeric
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
 * Возвращает список участников интерфейса.
 * @return {SETOF record} - Запись
 */
CREATE OR REPLACE FUNCTION api.interface_member (
  pInterfaceId  numeric
) RETURNS TABLE (
  id            numeric,
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
 * Возвращает интерфейсы доступные участнику.
 * @return {record} - Данные интерфейса
 */
CREATE OR REPLACE FUNCTION api.member_interface (
  pUserId   numeric DEFAULT current_userid()
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
/*
 * Устанавливает битовую маску доступа для класса и пользователя.
 * @param {numeric} pClass - Идентификатор класса
 * @param {int} pMask - Маска доступа. Десять бит (d:{acsud}a:{acsud}) где: d - запрещающие биты; a - разрешающие биты: {a - access; c - create; s - select, u - update, d - delete}
 * @param {numeric} pUserId - Идентификатор пользователя/группы
 * @param {boolean} pRecursive - Рекурсивно установить права для всех нижестоящих классов.
 * @param {boolean} pObjectSet - Установить права на объектах (документах) принадлежащих указанному классу.
 * @return {void}
*/
CREATE OR REPLACE FUNCTION api.chmodc (
  pClass        numeric,
  pMask         int,
  pUserId       numeric default current_userid(),
  pRecursive	boolean default true,
  pObjectSet	boolean default false
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
/*
 * Устанавливает битовую маску доступа для методов и пользователя.
 * @param {numeric} pMethod - Идентификатор метода
 * @param {int} pMask - Маска доступа. Три бита (xve) где: x - execute, v - visible, e - enable
 * @param {numeric} pUserId - Идентификатор пользователся/группы
 * @return {void}
*/
CREATE OR REPLACE FUNCTION api.chmodm (
  pMethod	numeric,
  pMask		int,
  pUserId	numeric default current_userid()
) RETURNS 	void
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
/*
 * Устанавливает битовую маску доступа для объекта и пользователя.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {int} pMask - Маска доступа. Три бита (sud) где: s - select, u - update, d - delete
 * @param {numeric} pUserId - Идентификатор пользователся/группы
 * @return {void}
*/
CREATE OR REPLACE FUNCTION api.chmodo (
  pObject	numeric,
  pMask		int,
  pUserId	numeric default current_userid()
) RETURNS 	void
AS $$
BEGIN
  PERFORM kernel.chmodo(pObject, pMask::bit(6), pUserId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
