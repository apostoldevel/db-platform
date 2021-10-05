--------------------------------------------------------------------------------
-- VERIFICATION ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.verification_code -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.verification_code
AS
  SELECT * FROM VerificationCode;

GRANT SELECT ON api.verification_code TO administrator;

--------------------------------------------------------------------------------
-- api.new_verification_code ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создает новый код верификации.
 * @param {char} pType - Тип: [M]ail - Почта; [P]hone - Телефон;
 * @param {text} pCode - Код: Если не указать то буде создан автоматически.
 * @param {uuid} pUserId - Идентификатор учётной записи.
 * @return {SETOF api.verification_code}
 */
CREATE OR REPLACE FUNCTION api.new_verification_code (
  pType         char,
  pCode		    text DEFAULT null,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       SETOF api.verification_code
AS $$
DECLARE
  uId           uuid;
BEGIN
  uId := NewVerificationCode(pUserId, pType, pCode);
  RETURN QUERY SELECT * FROM api.verification_code WHERE id = uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.confirm_verification_code -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Подтверждает код верификации.
 * @param {char} pType - Тип: [M]ail - Почта; [P]hone - Телефон;
 * @out param {bool} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.confirm_verification_code (
  pType         char,
  pCode		    text,
  OUT result    bool,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  uUserId		uuid;
  vOAuthSecret  text;
BEGIN
  uUserId := ConfirmVerificationCode(pType, pCode);

  result := uUserId IS NOT NULL;
  message := GetErrorMessage();

  IF result AND IsUserRole(GetGroup('system'), session_userid()) THEN
	SELECT a.secret INTO vOAuthSecret FROM oauth2.audience a WHERE a.code = session_username();
	IF FOUND THEN
	  PERFORM SubstituteUser(GetUser('apibot'), vOAuthSecret);
	  IF pType = 'M' THEN
		PERFORM DoConfirmEmail(uUserId);
	  ELSIF pType = 'P' THEN
		PERFORM DoConfirmPhone(uUserId);
	  END IF;
	  PERFORM SubstituteUser(session_userid(), vOAuthSecret);
	END IF;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_verification_code ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает код верификации.
 * @return {record} - Данные интерфейса
 */
CREATE OR REPLACE FUNCTION api.get_verification_code (
  pId		uuid
) RETURNS	SETOF api.verification_code
AS $$
  SELECT * FROM api.verification_code WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_verification_code --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает коды верификации.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.verification_code}
 */
CREATE OR REPLACE FUNCTION api.list_verification_code (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.verification_code
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'verification_code', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

