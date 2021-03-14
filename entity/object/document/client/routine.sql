--------------------------------------------------------------------------------
-- FUNCTION NewClientName ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет/обновляет наименование клиента.
 * @param {uuid} pClient - Идентификатор клиента
 * @param {text} pName - Полное наименование компании/Ф.И.О.
 * @param {text} pFirst - Имя
 * @param {text} pLast - Фамилия
 * @param {text} pMiddle - Отчество
 * @param {text} pShort - Краткое наименование компании
 * @param {uuid} pLocale - Идентификатор локали
 * @param {timestamp} pDateFrom - Дата изменения
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION NewClientName (
  pClient	    uuid,
  pName		    text,
  pShort	    text default null,
  pFirst	    text default null,
  pLast		    text default null,
  pMiddle	    text default null,
  pLocale		uuid default current_locale(),
  pDateFrom	    timestamp default oper_date()
) RETURNS 	    void
AS $$
DECLARE
  nId		    uuid;

  dtDateFrom    timestamp;
  dtDateTo 	    timestamp;
BEGIN
  nId := null;

  pName := NULLIF(trim(pName), '');
  pShort := NULLIF(trim(pShort), '');
  pFirst := NULLIF(trim(pFirst), '');
  pLast := NULLIF(trim(pLast), '');
  pMiddle := NULLIF(trim(pMiddle), '');

  -- получим дату значения в текущем диапозоне дат
  SELECT validFromDate, validToDate INTO dtDateFrom, dtDateTo
    FROM db.client_name
   WHERE client = pClient
     AND locale = pLocale
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.client_name SET name = pName, short = pShort, first = pFirst, last = pLast, middle = pMiddle
     WHERE client = pClient
       AND locale = pLocale
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.client_name SET validToDate = pDateFrom
     WHERE client = pClient
       AND locale = pLocale
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.client_name (client, locale, name, short, first, last, middle, validfromdate, validToDate)
    VALUES (pClient, pLocale, pName, pShort, pFirst, pLast, pMiddle, pDateFrom, coalesce(dtDateTo, MAXDATE()));
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
 * @param {uuid} pClient - Идентификатор клиента
 * @param {text} pName - Полное наименование компании/Ф.И.О.
 * @param {text} pShort - Краткое наименование компании
 * @param {text} pFirst - Имя
 * @param {text} pLast - Фамилия
 * @param {text} pMiddle - Отчество
 * @param {uuid} pLocale - Идентификатор локали
 * @param {timestamp} pDateFrom - Дата изменения
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION EditClientName (
  pClient	    uuid,
  pName		    text,
  pShort	    text default null,
  pFirst	    text default null,
  pLast		    text default null,
  pMiddle	    text default null,
  pLocale		uuid default current_locale(),
  pDateFrom	    timestamp default oper_date()
) RETURNS 	    void
AS $$
DECLARE
  nMethod	    uuid;

  vHash		    text;
  cHash		    text;

  r		        record;
BEGIN
  SELECT * INTO r FROM GetClientNameRec(pClient, pLocale, pDateFrom);

  pName := coalesce(pName, r.name);
  pShort := coalesce(pShort, r.short, '<null>');
  pFirst := coalesce(pFirst, r.first, '<null>');
  pLast := coalesce(pLast, r.last, '<null>');
  pMiddle := coalesce(pMiddle, r.middle, '<null>');

  vHash := encode(digest(pName || pShort || pFirst || pLast || pMiddle, 'md5'), 'hex');
  cHash := encode(digest(r.name || coalesce(r.short, '<null>') || coalesce(r.first, '<null>') || coalesce(r.last, '<null>') || coalesce(r.middle, '<null>'), 'md5'), 'hex');

  IF vHash <> cHash THEN
    PERFORM NewClientName(pClient, pName, CheckNull(pShort), CheckNull(pFirst), CheckNull(pLast), CheckNull(pMiddle), pLocale, pDateFrom);

    nMethod := GetMethod(GetObjectClass(pClient), GetAction('edit'));
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
 * @param {uuid} pClient - Идентификатор клиента
 * @param {uuid} pLocale - Идентификатор локали
 * @param {timestamp} pDate - Дата
 * @return {SETOF db.client_name}
 */
CREATE OR REPLACE FUNCTION GetClientNameRec (
  pClient	    uuid,
  pLocale		uuid default current_locale(),
  pDate		    timestamp default oper_date()
) RETURNS	    SETOF db.client_name
AS $$
BEGIN
  RETURN QUERY SELECT *
    FROM db.client_name n
   WHERE n.client = pClient
     AND n.locale = pLocale
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
 * @param {uuid} pClient - Идентификатор клиента
 * @param {uuid} pLocale - Идентификатор локали
 * @param {timestamp} pDate - Дата
 * @return {json}
 */
CREATE OR REPLACE FUNCTION GetClientNameJson (
  pClient	    uuid,
  pLocale		uuid default current_locale(),
  pDate		    timestamp default oper_date()
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;
BEGIN
  FOR r IN
    SELECT *
      FROM db.client_name n
     WHERE n.client = pClient
       AND n.locale = pLocale
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
 * @param {uuid} pClient - Идентификатор клиента
 * @param {uuid} pLocale - Идентификатор локали
 * @param {timestamp} pDate - Дата
 * @return {(text|null|exception)}
 */
CREATE OR REPLACE FUNCTION GetClientName (
  pClient       uuid,
  pLocale		uuid default current_locale(),
  pDate		    timestamp default oper_date()
) RETURNS       text
AS $$
DECLARE
  vName		    text;
BEGIN
  SELECT name INTO vName FROM GetClientNameRec(pClient, pLocale, pDate);

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
 * @param {uuid} pClient - Идентификатор клиента
 * @param {uuid} pLocale - Идентификатор локали
 * @param {timestamp} pDate - Дата
 * @return {(text|null|exception)}
 */
CREATE OR REPLACE FUNCTION GetClientShortName (
  pClient	    uuid,
  pLocale		uuid default current_locale(),
  pDate         timestamp default oper_date()
) RETURNS       text
AS $$
DECLARE
  vShort        text;
BEGIN
  SELECT short INTO vShort FROM GetClientNameRec(pClient, pLocale, pDate);

  RETURN vShort;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClient ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт нового клиента
 * @param {uuid} pParent - Ссылка на родительский объект
 * @param {uuid} pType - Тип
 * @param {text} pCode - ИНН - для юридического лица | Имя пользователя (login) | null
 * @param {uuid} pUserId - Пользователь (users): Учётная запись клиента
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {jsonb} pPhone - Справочник телефонов
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pAddress - Почтовые адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {timestamp} pCreation - Дата открытия | Дата рождения | null
 * @param {text} pDescription - Описание
 * @return {uuid} - Id клиента
 */
CREATE OR REPLACE FUNCTION CreateClient (
  pParent	    uuid,
  pType		    uuid,
  pCode		    text,
  pUserId	    uuid,
  pName         jsonb,
  pPhone	    jsonb default null,
  pEmail	    jsonb default null,
  pInfo         jsonb default null,
  pCreation     timestamp default null,
  pDescription	text default null
) RETURNS 	    uuid
AS $$
DECLARE
  nId		    uuid;
  nClient	    uuid;
  nDocument	    uuid;

  cn            record;

  nClass	    uuid;
  nMethod	    uuid;
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

  SELECT * INTO cn FROM jsonb_to_record(pName) AS x(name text, short text, first text, last text, middle text);

  IF NULLIF(trim(cn.short), '') IS NULL THEN
    cn.short := coalesce(NULLIF(trim(cn.name), ''), pCode);
  END IF;

  IF pUserId = null_uuid() THEN
    pUserId := CreateUser(pCode, pCode, cn.short, pPhone->>0, pEmail->>0, NULLIF(trim(cn.name), ''));
  END IF;

  INSERT INTO db.client (id, document, code, creation, userid, phone, email, info)
  VALUES (nDocument, nDocument, pCode, pCreation, pUserId, pPhone, pEmail, pInfo)
  RETURNING id INTO nClient;

  PERFORM NewClientName(nClient, cn.name, cn.short, cn.first, cn.last, cn.middle);

  nMethod := GetMethod(nClass, GetAction('create'));
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
 * @param {uuid} pId - Идентификатор клиента
 * @param {uuid} pParent - Ссылка на родительский объект
 * @param {uuid} pType - Тип
 * @param {text} pCode - ИНН - для юридического лица | Имя пользователя (login) | null
 * @param {uuid} pUserId - Пользователь (users): Учётная запись клиента
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {jsonb} pPhone - Справочник телефонов
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {timestamp} pCreation - Дата открытия | Дата рождения | null
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditClient (
  pId		    uuid,
  pParent	    uuid default null,
  pType		    uuid default null,
  pCode		    text default null,
  pUserId	    uuid default null,
  pName         jsonb default null,
  pPhone	    jsonb default null,
  pEmail	    jsonb default null,
  pInfo         jsonb default null,
  pCreation     timestamp default null,
  pDescription	text default null
) RETURNS 	    void
AS $$
DECLARE
  nId		    uuid;
  nMethod	    uuid;

  r             record;

  old           Client%rowtype;
  new           Client%rowtype;

  -- current
  cCode		    text;
  cUserId	    uuid;
BEGIN
  SELECT code, userid INTO cCode, cUserId FROM db.client WHERE id = pId;

  pCode := coalesce(pCode, cCode);
  pUserId := coalesce(pUserId, cUserId, null_uuid());

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

  FOR r IN SELECT * FROM jsonb_to_record(pName) AS x(name text, short text, first text, last text, middle text)
  LOOP
    PERFORM EditClientName(pId, r.name, r.short, r.first, r.last, r.middle);
  END LOOP;

  SELECT * INTO new FROM Client WHERE id = pId;

  nMethod := GetMethod(GetObjectClass(pId), GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod, jsonb_build_object('old', row_to_json(old), 'new', row_to_json(new)));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetClient -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClient (
  pCode		text
) RETURNS	uuid
AS $$
DECLARE
  nId		uuid;
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
  pClient	uuid
) RETURNS	text
AS $$
DECLARE
  vCode     text;
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
  pClient	uuid
) RETURNS	uuid
AS $$
DECLARE
  nUserId	uuid;
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
  pUserId       uuid
) RETURNS       uuid
AS $$
DECLARE
  nId           uuid;
BEGIN
  SELECT id INTO nId FROM db.client WHERE userid = pUserId;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
