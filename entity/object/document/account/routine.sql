--------------------------------------------------------------------------------
-- CreateAccount ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт счёт
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {uuid} pType - Тип
 * @param {uuid} pCurrency - Валюта
 * @param {uuid} pCategory - Категория
 * @param {uuid} pClient - Клиент
 * @param {text} pCode - Код
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateAccount (
  pParent       uuid,
  pType         uuid,
  pCurrency		uuid,
  pCategory		uuid,
  pClient       uuid,
  pCode         text,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  uAccount		uuid;
  uDocument     uuid;

  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'account' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO uId FROM db.account WHERE currency = pCurrency AND code = pCode;

  IF FOUND THEN
    PERFORM AccountCodeExists(pCode);
  END IF;

  uDocument := CreateDocument(pParent, pType, pLabel, pDescription);

  INSERT INTO db.account (id, document, currency, category, client, code)
  VALUES (uDocument, uDocument, pCurrency, pCategory, pClient, pCode)
  RETURNING id INTO uAccount;

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uAccount, uMethod);

  RETURN uAccount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditAccount -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует счёт.
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {uuid} pType - Тип
 * @param {uuid} pCurrency - Валюта
 * @param {uuid} pCategory - Категория
 * @param {uuid} pClient - Клиент
 * @param {text} pCode - Код
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditAccount (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCurrency		uuid default null,
  pCategory		uuid default null,
  pClient       uuid default null,
  pCode         text default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
  uClass        uuid;
  uMethod       uuid;

  -- current
  cCurrency		uuid;
  cCode         text;
BEGIN
  SELECT currency, code INTO cCurrency, cCode FROM db.account WHERE id = pId;

  pCurrency := coalesce(pCurrency, cCurrency);
  pCode := coalesce(pCode, cCode);

  IF pCode <> cCode THEN
    SELECT id INTO uId FROM db.account WHERE currency = pCurrency AND code = pCode;
    IF FOUND THEN
      PERFORM AccountCodeExists(pCode);
    END IF;
  END IF;

  PERFORM EditDocument(pId, pParent, pType, pLabel, pDescription);

  UPDATE db.account
     SET currency = coalesce(pCurrency, currency),
         category = coalesce(pCategory, category),
         client = coalesce(pClient, client),
         code = pCode
   WHERE id = pId;

  uClass := GetObjectClass(pId);
  uMethod := GetMethod(uClass, GetAction('edit'));

  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAccount ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAccount (
  pCode		text,
  pCurrency	uuid
) RETURNS	uuid
AS $$
  SELECT id FROM db.account WHERE currency = pCurrency AND code = pCode;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAccountCode --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAccountCode (
  pAccount	uuid
) RETURNS	text
AS $$
  SELECT code FROM db.account WHERE id = pAccount;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAccountClient ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAccountClient (
  pAccount	uuid
) RETURNS	uuid
AS $$
  SELECT client FROM db.account WHERE id = pAccount;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ChangeBalance ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет баланс счёта.
 * @param {uuid} pAccount - Счёт
 * @param {numeric} pAmount - Сумма
 * @param {integer} pType - Тип
 * @param {timestamptz} pDateFrom - Дата
 * @return {void}
 */
CREATE OR REPLACE FUNCTION ChangeBalance (
  pAccount		uuid,
  pAmount       numeric,
  pType         integer DEFAULT 1,
  pDateFrom     timestamptz DEFAULT Now()
) RETURNS       void
AS $$
DECLARE
  dtDateFrom    timestamptz;
  dtDateTo 	    timestamptz;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT validFromDate, validToDate INTO dtDateFrom, dtDateTo
    FROM db.balance
   WHERE type = pType
     AND account = pAccount
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.balance SET amount = pAmount
     WHERE type = pType
       AND account = pAccount
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.balance SET validToDate = pDateFrom
     WHERE type = pType
       AND account = pAccount
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.balance (type, account, amount, validfromdate, validToDate)
    VALUES (pType, pAccount, pAmount, pDateFrom, coalesce(dtDateTo, MAXDATE()));
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewTurnOver -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Новое движение по счёту.
 * @param {uuid} pAccount - Счёт
 * @param {numeric} pDebit - Сумма обота по дебету
 * @param {numeric} pCredit - Сумма обота по кредиту
 * @param {integer} pType - Тип
 * @param {timestamptz} pTimestamp - Дата
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION NewTurnOver (
  pAccount		uuid,
  pDebit        numeric,
  pCredit       numeric,
  pType         integer DEFAULT 1,
  pTimestamp	timestamptz DEFAULT Now()
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
BEGIN
  INSERT INTO db.turnover (type, account, debit, credit, timestamp)
  VALUES (pType, pAccount, pDebit, pCredit, pTimestamp)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateBalance ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет баланс счёта.
 * @param {uuid} pAccount - Счёт
 * @param {numeric} pAmount - Сумма изменения остатка. Если сумма положительная, то счёт кредитуется, если сумма отрицательная - счёт дебетуется.
 * @param {integer} pType - Тип
 * @param {timestamptz} pDateFrom - Дата
 * @return {numeric} - Баланс (остаток на счёте)
 */
CREATE OR REPLACE FUNCTION UpdateBalance (
  pAccount		uuid,
  pAmount       numeric,
  pType         integer DEFAULT 1,
  pDateFrom     timestamptz DEFAULT Now()
) RETURNS       numeric
AS $$
DECLARE
  uId           uuid;
  nBalance      numeric;
BEGIN
  IF pAmount > 0 THEN
    uId := NewTurnOver(pAccount, 0, pAmount, pType, pDateFrom);
  END IF;

  IF pAmount < 0 THEN
    uId := NewTurnOver(pAccount, pAmount, 0, pType, pDateFrom);
  END IF;

  if uId IS NOT NULL THEN
    SELECT Sum(credit) + Sum(debit) INTO nBalance
      FROM db.turnover
     WHERE type = pType
       AND account = pAccount;

    PERFORM ChangeBalance(pAccount, nBalance, pType, pDateFrom);
  END IF;

  RETURN nBalance;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetBalance ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает баланс счёта.
 * @param {numeric} pAccount - Счёт
 * @param {integer} pType - Тип
 * @param {timestamptz} pDateFrom - Дата
 * @return {numeric} - Баланс (остаток на счёте)
 */
CREATE OR REPLACE FUNCTION GetBalance (
  pAccount		uuid,
  pType         integer DEFAULT 1,
  pDateFrom     timestamptz DEFAULT oper_date()
) RETURNS       numeric
AS $$
  SELECT amount
    FROM db.balance
   WHERE type = pType
     AND account = pAccount
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
