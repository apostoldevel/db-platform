--------------------------------------------------------------------------------
-- FUNCTION NewClientName ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет/обновляет наименование клиента.
 * @param {numeric} pClient - Идентификатор клиента
 * @param {text} pName - Полное наименование компании/Ф.И.О.
 * @param {text} pFirst - Имя
 * @param {text} pLast - Фамилия
 * @param {text} pMiddle - Отчество
 * @param {text} pShort - Краткое наименование компании
 * @param {varchar} pLocaleCode - Код языка
 * @param {timestamp} pDateFrom - Дата изменения
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION NewClientName (
  pClient	    numeric,
  pName		    text,
  pShort	    text default null,
  pFirst	    text default null,
  pLast		    text default null,
  pMiddle	    text default null,
  pLocaleCode   varchar default locale_code(),
  pDateFrom	    timestamp default oper_date()
) RETURNS 	    void
AS $$
DECLARE
  nId		    numeric;
  nLocale       numeric;

  dtDateFrom    timestamp;
  dtDateTo 	    timestamp;
BEGIN
  nId := null;

  pName := NULLIF(trim(pName), '');
  pShort := NULLIF(trim(pShort), '');
  pFirst := NULLIF(trim(pFirst), '');
  pLast := NULLIF(trim(pLast), '');
  pMiddle := NULLIF(trim(pMiddle), '');

  SELECT id INTO nLocale FROM db.locale WHERE code = coalesce(pLocaleCode, 'ru');

  IF not found THEN
    PERFORM IncorrectLocaleCode(pLocaleCode);
  END IF;

  -- получим дату значения в текущем диапозоне дат
  SELECT validFromDate, validToDate INTO dtDateFrom, dtDateTo
    FROM db.client_name
   WHERE Client = pClient
     AND Locale = nLocale
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.client_name SET name = pName, short = pShort, first = pFirst, last = pLast, middle = pMiddle
     WHERE Client = pClient
       AND Locale = nLocale
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.client_name SET validToDate = pDateFrom
     WHERE Client = pClient
       AND Locale = nLocale
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.client_name (client, locale, name, short, first, last, middle, validfromdate, validToDate)
    VALUES (pClient, nLocale, pName, pShort, pFirst, pLast, pMiddle, pDateFrom, coalesce(dtDateTo, MAXDATE()));
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditClientName -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет/обновляет наименование клиента (вызывает метод действия 'edit').
 * @param {numeric} pClient - Идентификатор клиента
 * @param {text} pName - Полное наименование компании/Ф.И.О.
 * @param {text} pShort - Краткое наименование компании
 * @param {text} pFirst - Имя
 * @param {text} pLast - Фамилия
 * @param {text} pMiddle - Отчество
 * @param {varchar} pLocaleCode - Код языка
 * @param {timestamp} pDateFrom - Дата изменения
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION EditClientName (
  pClient	    numeric,
  pName		    text,
  pShort	    text default null,
  pFirst	    text default null,
  pLast		    text default null,
  pMiddle	    text default null,
  pLocaleCode   varchar default locale_code(),
  pDateFrom	    timestamp default oper_date()
) RETURNS 	    void
AS $$
DECLARE
  nMethod	    numeric;

  vHash		    text;
  cHash		    text;

  r		        record;
BEGIN
  SELECT * INTO r FROM GetClientNameRec(pClient, pLocaleCode, pDateFrom);

  pName := coalesce(pName, r.name);
  pShort := coalesce(pShort, r.short, '<null>');
  pFirst := coalesce(pFirst, r.first, '<null>');
  pLast := coalesce(pLast, r.last, '<null>');
  pMiddle := coalesce(pMiddle, r.middle, '<null>');

  vHash := encode(digest(pName || pShort || pFirst || pLast || pMiddle, 'md5'), 'hex');
  cHash := encode(digest(r.name || coalesce(r.short, '<null>') || coalesce(r.first, '<null>') || coalesce(r.last, '<null>') || coalesce(r.middle, '<null>'), 'md5'), 'hex');

  IF vHash <> cHash THEN
    PERFORM NewClientName(pClient, pName, CheckNull(pShort), CheckNull(pFirst), CheckNull(pLast), CheckNull(pMiddle), pLocaleCode, pDateFrom);

    nMethod := GetMethod(GetObjectClass(pClient), null, GetAction('edit'));
    PERFORM ExecuteMethod(pClient, nMethod);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClientNameRec ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает наименование клиента.
 * @param {numeric} pClient - Идентификатор клиента
 * @param {varchar} pLocaleCode - Код языка
 * @param {timestamp} pDate - Дата
 * @return {SETOF db.client_name}
 */
CREATE OR REPLACE FUNCTION GetClientNameRec (
  pClient	    numeric,
  pLocaleCode   varchar default locale_code(),
  pDate		    timestamp default oper_date()
) RETURNS	    SETOF db.client_name
AS $$
DECLARE
  nLocale       numeric;
BEGIN
  SELECT id INTO nLocale FROM db.locale WHERE code = coalesce(pLocaleCode, 'ru');

  IF NOT FOUND THEN
    PERFORM IncorrectLocaleCode(pLocaleCode);
  END IF;

  RETURN QUERY SELECT *
    FROM db.client_name n
   WHERE n.client = pClient
     AND n.locale = nLocale
     AND n.validFromDate <= pDate
     AND n.validToDate > pDate;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClientNameJson --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает наименование клиента.
 * @param {numeric} pClient - Идентификатор клиента
 * @param {varchar} pLocaleCode - Код языка
 * @param {timestamp} pDate - Дата
 * @return {json}
 */
CREATE OR REPLACE FUNCTION GetClientNameJson (
  pClient	    numeric,
  pLocaleCode   varchar default locale_code(),
  pDate		    timestamp default oper_date()
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;
  nLocale       numeric;
BEGIN
  SELECT id INTO nLocale FROM db.locale WHERE code = coalesce(pLocaleCode, 'ru');

  IF NOT FOUND THEN
    PERFORM IncorrectLocaleCode(pLocaleCode);
  END IF;

  FOR r IN
    SELECT *
      FROM db.client_name n
     WHERE n.client = pClient
       AND n.locale = nLocale
       AND n.validFromDate <= pDate
       AND n.validToDate > pDate
  LOOP
    RETURN NEXT row_to_json(r);
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClientName ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает полное наименование клиента.
 * @param {numeric} pClient - Идентификатор клиента
 * @param {varchar} pLocaleCode - Код языка
 * @param {timestamp} pDate - Дата
 * @return {(text|null|exception)}
 */
CREATE OR REPLACE FUNCTION GetClientName (
  pClient       numeric,
  pLocaleCode	varchar default locale_code(),
  pDate		    timestamp default oper_date()
) RETURNS       text
AS $$
DECLARE
  vName		    text;
BEGIN
  SELECT name INTO vName FROM GetClientNameRec(pClient, pLocaleCode, pDate);

  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClientShortName -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает краткое наименование клиента.
 * @param {numeric} pClient - Идентификатор клиента
 * @param {varchar} pLocaleCode - Код языка
 * @param {timestamp} pDate - Дата
 * @return {(text|null|exception)}
 */
CREATE OR REPLACE FUNCTION GetClientShortName (
  pClient	    numeric,
  pLocaleCode   varchar default locale_code(),
  pDate         timestamp default oper_date()
) RETURNS       text
AS $$
DECLARE
  vShort        text;
BEGIN
  SELECT short INTO vShort FROM GetClientNameRec(pClient, pLocaleCode, pDate);

  RETURN vShort;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ChangeBalance ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет баланс Клиента.
 * @param {numeric} pClient - Клиент
 * @param {numeric} pAmount - Сумма
 * @param {integer} pType - Тип
 * @param {timestamptz} pDateFrom - Дата
 * @return {void}
 */
CREATE OR REPLACE FUNCTION ChangeBalance (
  pClient       numeric,
  pAmount       numeric,
  pType         integer DEFAULT 1,
  pDateFrom     timestamptz DEFAULT Now()
) RETURNS       void
AS $$
DECLARE
  dtDateFrom    timestamp;
  dtDateTo 	    timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT validFromDate, validToDate INTO dtDateFrom, dtDateTo
    FROM db.balance
   WHERE type = pType
     AND client = pClient
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.balance SET amount = pAmount
     WHERE type = pType
       AND client = pClient
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.balance SET validToDate = pDateFrom
     WHERE type = pType
       AND client = pClient
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.balance (type, client, amount, validfromdate, validToDate)
    VALUES (pType, pClient, pAmount, pDateFrom, coalesce(dtDateTo, MAXDATE()));
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
 * @param {numeric} pClient - Клиент
 * @param {numeric} pDebit - Сумма обота по дебету
 * @param {numeric} pCredit - Сумма обота по кредиту
 * @param {integer} pType - Тип
 * @param {timestamptz} pTurnDate - Дата
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION NewTurnOver (
  pClient       numeric,
  pDebit        numeric,
  pCredit       numeric,
  pType         integer DEFAULT 1,
  pTurnDate     timestamptz DEFAULT Now()
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
BEGIN
  INSERT INTO db.turn_over (type, client, debit, credit, turn_date)
  VALUES (pType, pClient, pDebit, pCredit, pTurnDate)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateBalance ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет баланс клиента.
 * @param {numeric} pClient - Клиент
 * @param {numeric} pAmount - Сумма изменения остатка. Если сумма положительная, то счёт кредитуется, если сумма отрицательная - счёт дебетуется.
 * @param {integer} pType - Тип
 * @param {timestamptz} pDateFrom - Дата
 * @return {numeric} - Баланс (остаток на счёте)
 */
CREATE OR REPLACE FUNCTION UpdateBalance (
  pClient       numeric,
  pAmount       numeric,
  pType         integer DEFAULT 1,
  pDateFrom     timestamptz DEFAULT Now()
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
  nBalance      numeric;
BEGIN
  IF pAmount > 0 THEN
    nId := NewTurnOver(pClient, 0, pAmount, pType, pDateFrom);
  END IF;

  IF pAmount < 0 THEN
    nId := NewTurnOver(pClient, pAmount, 0, pType, pDateFrom);
  END IF;

  if nId IS NOT NULL THEN
    SELECT Sum(credit) + Sum(debit) INTO nBalance
      FROM db.turn_over
     WHERE type = pType
       AND client = pClient;

    PERFORM ChangeBalance(pClient, nBalance, pType, pDateFrom);
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
 * Возвращает баланс клиента.
 * @param {numeric} pClient - Клиент
 * @param {integer} pType - Тип
 * @param {timestamptz} pDateFrom - Дата
 * @return {numeric} - Баланс (остаток на счёте)
 */
CREATE OR REPLACE FUNCTION GetBalance (
  pClient       numeric,
  pType         integer DEFAULT 1,
  pDateFrom     timestamptz DEFAULT oper_date()
) RETURNS       numeric
AS $$
DECLARE
  nBalance      numeric;
BEGIN
  SELECT amount INTO nBalance
    FROM db.balance
   WHERE type = pType
     AND client = pClient
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  RETURN nBalance;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClient ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт нового клиента
 * @param {numeric} pParent - Ссылка на родительский объект
 * @param {numeric} pType - Тип
 * @param {text} pCode - ИНН - для юридического лица | Имя пользователя (login) | null
 * @param {numeric} pUserId - Пользователь (users): Учётная запись клиента
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {jsonb} pPhone - Справочник телефонов
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pAddress - Почтовые адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {timestamp} pCreation - Дата открытия | Дата рождения | null
 * @param {text} pDescription - Описание
 * @return {numeric} - Id клиента
 */
CREATE OR REPLACE FUNCTION CreateClient (
  pParent	    numeric,
  pType		    numeric,
  pCode		    text,
  pUserId	    numeric,
  pName         jsonb,
  pPhone	    jsonb default null,
  pEmail	    jsonb default null,
  pInfo         jsonb default null,
  pCreation     timestamp default null,
  pDescription	text default null
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
  nClient	    numeric;
  nDocument	    numeric;

  cn            record;

  nClass	    numeric;
  nMethod	    numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'client' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO nId FROM db.client WHERE code = pCode;

  IF found THEN
    PERFORM ClientCodeExists(pCode);
  END IF;

  nDocument := CreateDocument(pParent, pType, null, pDescription);

  SELECT * INTO cn FROM jsonb_to_record(pName) AS x(name varchar, short varchar, first varchar, last varchar, middle varchar);

  IF NULLIF(trim(cn.short), '') IS NULL THEN
    cn.short := coalesce(NULLIF(trim(cn.name), ''), pCode);
  END IF;

  IF pUserId = 0 THEN
    pUserId := CreateUser(pCode, pCode, cn.short, pPhone->>0, pEmail->>0, NULLIF(trim(cn.name), ''));
  END IF;

  INSERT INTO db.client (id, document, code, creation, userid, phone, email, info)
  VALUES (nDocument, nDocument, pCode, pCreation, pUserId, pPhone, pEmail, pInfo)
  RETURNING id INTO nClient;

  PERFORM NewClientName(nClient, cn.name, cn.short, cn.first, cn.last, cn.middle);

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nClient, nMethod);

  RETURN nClient;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditClient ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует основные параметры клиента.
 * @param {numeric} pId - Идентификатор клиента
 * @param {numeric} pParent - Ссылка на родительский объект
 * @param {numeric} pType - Тип
 * @param {text} pCode - ИНН - для юридического лица | Имя пользователя (login) | null
 * @param {numeric} pUserId - Пользователь (users): Учётная запись клиента
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {jsonb} pPhone - Справочник телефонов
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {timestamp} pCreation - Дата открытия | Дата рождения | null
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditClient (
  pId		    numeric,
  pParent	    numeric default null,
  pType		    numeric default null,
  pCode		    text default null,
  pUserId	    numeric default null,
  pName         jsonb default null,
  pPhone	    jsonb default null,
  pEmail	    jsonb default null,
  pInfo         jsonb default null,
  pCreation     timestamp default null,
  pDescription	text default null
) RETURNS 	    void
AS $$
DECLARE
  nId		    numeric;
  nMethod	    numeric;

  r             record;

  old           Client%rowtype;
  new           Client%rowtype;

  -- current
  cCode		    varchar;
  cUserId	    numeric;
BEGIN
  SELECT code, userid INTO cCode, cUserId FROM db.client WHERE id = pId;

  pCode := coalesce(pCode, cCode);
  pUserId := coalesce(pUserId, cUserId, 0);

  IF pCode <> cCode THEN
    SELECT id INTO nId FROM db.client WHERE code = pCode;
    IF found THEN
      PERFORM ClientCodeExists(pCode);
    END IF;
  END IF;

  PERFORM EditDocument(pId, pParent, pType, null, pDescription);

  SELECT * INTO old FROM Client WHERE id = pId;

  UPDATE db.client
     SET code = pCode,
         userid = CheckNull(pUserId),
         phone = CheckNull(coalesce(pPhone, phone, '{}')),
         email = CheckNull(coalesce(pEmail, email, '{}')),
         info = CheckNull(coalesce(pInfo, info, '{}')),
         creation = CheckNull(coalesce(pCreation, creation, MINDATE()))
   WHERE id = pId;

  FOR r IN SELECT * FROM jsonb_to_record(pName) AS x(name varchar, short varchar, first varchar, last varchar, middle varchar)
  LOOP
    PERFORM EditClientName(pId, r.name, r.short, r.first, r.last, r.middle);
  END LOOP;

  SELECT * INTO new FROM Client WHERE id = pId;

  nMethod := GetMethod(GetObjectClass(pId), null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod, jsonb_build_object('old', row_to_json(old), 'new', row_to_json(new)));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetClient -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClient (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.client WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetClientCode ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClientCode (
  pClient	numeric
) RETURNS	varchar
AS $$
DECLARE
  vCode     varchar;
BEGIN
  SELECT code INTO vCode FROM db.client WHERE id = pClient;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetClientUserId -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClientUserId (
  pClient	numeric
) RETURNS	numeric
AS $$
DECLARE
  nUserId	numeric;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pClient;
  RETURN nUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetClientByUserId -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClientByUserId (
  pUserId       numeric
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
BEGIN
  SELECT id INTO nId FROM db.client WHERE userid = pUserId;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
