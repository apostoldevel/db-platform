--------------------------------------------------------------------------------
-- ACCOUNT ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.account -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.account
AS
  SELECT * FROM ObjectAccount;

GRANT SELECT ON api.account TO administrator;

--------------------------------------------------------------------------------
-- api.account -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.account (
  pState	uuid
) RETURNS	SETOF api.account
AS $$
  SELECT * FROM api.account WHERE state = pState;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.account -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.account (
  pState	text
) RETURNS	SETOF api.account
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.account(GetState(GetClass('account'), pState));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_account -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет счет.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {text} pType - Tип
 * @param {uuid} pCurrency - Валюта
 * @param {uuid} pCategory - Категория
 * @param {uuid} pClient - Клиент
 * @param {text} pCode - Код
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_account (
  pParent       uuid,
  pType         text,
  pCurrency		uuid,
  pCategory		uuid,
  pClient       uuid,
  pCode         text,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateAccount(pParent, CodeToType(lower(coalesce(pType, 'debit')), 'account'), pCurrency, pCategory, pClient, pCode, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_account ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет данные счёта.
 * @param {uuid} pId - Идентификатор (api.get_account)
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {text} pType - Tип
 * @param {uuid} pCurrency - Валюта
 * @param {uuid} pCategory - Категория
 * @param {uuid} pClient - Клиент
 * @param {text} pCode - Код
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_account (
  pId           uuid,
  pParent       uuid default null,
  pType         text default null,
  pCurrency		uuid default null,
  pCategory		uuid default null,
  pClient       uuid default null,
  pCode         text default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uType         uuid;
  uAccount		uuid;
BEGIN
  SELECT c.id INTO uAccount FROM db.account c WHERE c.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('счёт', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    uType := CodeToType(lower(pType), 'account');
  ELSE
    SELECT o.type INTO uType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditAccount(uAccount, pParent, uType, pCurrency, pCategory, pClient, pCode, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_account -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_account (
  pId           uuid,
  pParent       uuid default null,
  pType         text default null,
  pCurrency		uuid default null,
  pCategory		uuid default null,
  pClient       uuid default null,
  pCode         text default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       SETOF api.account
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_account(pParent, pType, pCurrency, pCategory, pClient, pCode, pLabel, pDescription);
  ELSE
    PERFORM api.update_account(pId, pParent, pType, pCurrency, pCategory, pClient, pCode, pLabel, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.account WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_account -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает счёт
 * @param {uuid} pId - Идентификатор
 * @return {api.account}
 */
CREATE OR REPLACE FUNCTION api.get_account (
  pId		uuid
) RETURNS	api.account
AS $$
  SELECT * FROM api.account WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_account ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список счетов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.account} - Клиенты
 */
CREATE OR REPLACE FUNCTION api.list_account (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.account
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'account', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_account_balance -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_account_balance (
  pId       uuid,
  pDateFrom timestamptz DEFAULT oper_date()
) RETURNS   numeric
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  RETURN GetBalance(pId, pDateFrom);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
