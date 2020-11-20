--------------------------------------------------------------------------------
-- CLIENT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.client ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.client
AS
  SELECT * FROM ObjectClient;

GRANT SELECT ON api.client TO administrator;

--------------------------------------------------------------------------------
-- api.client ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.client (
  pState	numeric
) RETURNS	SETOF api.client
AS $$
  SELECT * FROM api.client WHERE state = pState;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.client ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.client (
  pState	varchar
) RETURNS	SETOF api.client
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.client(GetState(GetClass('client'), pState));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_client --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет нового клиента.
 * @param {numeric} pParent - Идентификатор родителя | null
 * @param {varchar} pType - Tип клиента
 * @param {text} pCode - ИНН - для юридического лица | Имя пользователя (login) | null
 * @param {numeric} pUserId - Идентификатор пользователя системы | null
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {jsonb} pPhone - Телефоны
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {timestamp} pCreation - Дата открытия | Дата рождения | null
 * @param {text} pDescription - Информация о клиенте
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_client (
  pParent       numeric,
  pType         varchar,
  pCode         text,
  pUserId       numeric,
  pName         jsonb,
  pPhone        jsonb DEFAULT null,
  pEmail        jsonb DEFAULT null,
  pInfo         jsonb DEFAULT null,
  pCreation     timestamp default null,
  pDescription  text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nClient       numeric;
  arKeys        text[];
BEGIN
  pType := lower(coalesce(pType, 'physical'));

  arKeys := array_cat(arKeys, ARRAY['name', 'short', 'first', 'last', 'middle']);
  PERFORM CheckJsonbKeys('add_client', arKeys, pName);

  nClient := CreateClient(pParent, CodeToType(pType, 'client'), pCode, pUserId, pName, pPhone, pEmail, pInfo, pCreation, pDescription);

  RETURN nClient;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_client -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет данные клиента.
 * @param {numeric} pId - Идентификатор (api.get_client)
 * @param {numeric} pParent - Идентификатор родителя | null
 * @param {varchar} pType - Tип клиента
 * @param {text} pCode - ИНН - для юридического лица | Имя пользователя (login) | null
 * @param {numeric} pUserId - Идентификатор пользователя системы | null
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {jsonb} pPhone - Телефоны
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {timestamp} pCreation - Дата открытия | Дата рождения | null
 * @param {text} pDescription - Информация о клиенте
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_client (
  pId           numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         text default null,
  pUserId       numeric default null,
  pName         jsonb default null,
  pPhone        jsonb DEFAULT null,
  pEmail        jsonb DEFAULT null,
  pInfo         jsonb DEFAULT null,
  pCreation     timestamp default null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  nType         numeric;
  nClient       numeric;
  arKeys        text[];
BEGIN
  SELECT c.id INTO nClient FROM db.client c WHERE c.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('клиент', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'client');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  arKeys := array_cat(arKeys, ARRAY['name', 'short', 'first', 'last', 'middle']);
  PERFORM CheckJsonbKeys('update_client', arKeys, pName);

  PERFORM EditClient(nClient, pParent, nType, pCode, pUserId, pName, pPhone, pEmail, pInfo, pCreation, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_client --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_client (
  pId           numeric,
  pParent       numeric,
  pType         varchar,
  pCode         text,
  pUserId       numeric,
  pName         jsonb,
  pPhone        jsonb DEFAULT null,
  pEmail        jsonb DEFAULT null,
  pInfo         jsonb DEFAULT null,
  pCreation     timestamp default null,
  pDescription  text DEFAULT null
) RETURNS       SETOF api.client
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_client(pParent, pType, pCode, pUserId, pName, pPhone, pEmail, pInfo, pCreation, pDescription);
  ELSE
    PERFORM api.update_client(pId, pParent, pType, pCode, pUserId, pName, pPhone, pEmail, pInfo, pCreation, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.client WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_client --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает клиента
 * @param {numeric} pId - Идентификатор
 * @return {api.client} - Клиент
 */
CREATE OR REPLACE FUNCTION api.get_client (
  pId		numeric
) RETURNS	SETOF api.client
AS $$
  SELECT * FROM api.client WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_client -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список клиентов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.client} - Клиенты
 */
CREATE OR REPLACE FUNCTION api.list_client (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.client
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'client', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
