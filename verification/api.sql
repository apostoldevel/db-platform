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
 * Создает новый код подтверждения.
 * @param {char} pType - Тип: [M]ail - Почта; [P]hone - Телефон;
 * @param {text} pCode - Код: Если не указать то буде создан автоматически.
 * @param {numeric} pUserId - Идентификатор учётной записи.
 * @return {SETOF api.verification_code}
 */
CREATE OR REPLACE FUNCTION api.new_verification_code (
  pType         char,
  pCode		    text DEFAULT null,
  pUserId       numeric DEFAULT current_userid()
) RETURNS       SETOF api.verification_code
AS $$
DECLARE
  nId           numeric;
BEGIN
  nId := NewVerificationCode(pType, pCode, pUserId);
  RETURN QUERY SELECT * FROM api.verification_code WHERE id = nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.check_verification_code -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Сверяет код подтверждения.
 * @param {char} pType - Тип: [M]ail - Почта; [P]hone - Телефон;
 * @param {text} pCode - Код подтверждения.
 * @param {numeric} pUserId - Идентификатор учётной записи.
 * @return {bool}
 */
CREATE OR REPLACE FUNCTION api.check_verification_code (
  pType         char,
  pCode		    text,
  pUserId       numeric DEFAULT current_userid()
) RETURNS       bool
AS $$
BEGIN
  RETURN CheckVerificationCode(pType, pCode, pUserId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.try_verification_code ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Сверяет код подтверждения.
 * @param {char} pType - Тип: [M]ail - Почта; [P]hone - Телефон;
 * @out param {bool} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.try_verification_code (
  pType         char,
  pCode		    text,
  pUserId       numeric DEFAULT current_userid(),
  OUT result    bool,
  OUT message   text
) RETURNS       record
AS $$
  SELECT TryVerificationCode(pType, pCode, pUserId), GetErrorMessage();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_verification_code ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает код подтверждения.
 * @return {record} - Данные интерфейса
 */
CREATE OR REPLACE FUNCTION api.get_verification_code (
  pId		numeric
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
 * Возвращает коды подтверждения.
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

