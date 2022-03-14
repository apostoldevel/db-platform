--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object
AS
  SELECT * FROM AccessObject;

GRANT SELECT ON api.object TO administrator;

--------------------------------------------------------------------------------
-- api.search ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.search_en (
  pText		text
) RETURNS	SETOF api.object
AS $$
  WITH access AS (
    SELECT object FROM aou(current_userid())
  ), search AS (
  SELECT o.object
    FROM db.object_text o INNER JOIN access a ON o.object = a.object
   WHERE o.locale = current_locale()
     AND (o.label ILIKE '%' || pText || '%'
      OR o.text ILIKE '%' || pText || '%'
      OR o.searchable_en @@ websearch_to_tsquery('english', pText))
   UNION
  SELECT r.object
    FROM db.reference r INNER JOIN access a ON r.object = a.object
   WHERE r.code ILIKE '%' || pText || '%'
  ) SELECT o.* FROM api.object o INNER JOIN search s ON o.id = s.object;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.search_ru (
  pText		text
) RETURNS	SETOF api.object
AS $$
  WITH access AS (
    SELECT object FROM aou(current_userid())
  ), search AS (
  SELECT o.object
    FROM db.object_text o INNER JOIN access a ON o.object = a.object
   WHERE o.locale = current_locale()
     AND (o.label ILIKE '%' || pText || '%'
      OR o.text ILIKE '%' || pText || '%'
      OR o.searchable_ru @@ websearch_to_tsquery('russian', pText))
   UNION
  SELECT r.object
    FROM db.reference r INNER JOIN access a ON r.object = a.object
   WHERE r.code ILIKE '%' || pText || '%'
  ) SELECT o.* FROM api.object o INNER JOIN search s ON o.id = s.object;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.search (
  pText			text,
  pEntities     jsonb DEFAULT null,
  pLocaleCode	text DEFAULT locale_code()
) RETURNS		SETOF api.object
AS $$
BEGIN
  IF pLocaleCode = 'ru' THEN
  	RETURN QUERY SELECT * FROM api.search_ru(pText) WHERE array_position(coalesce(JsonbToStrArray(pEntities), ARRAY[entitycode]), entitycode) IS NOT NULL;
  ELSE
  	RETURN QUERY SELECT * FROM api.search_en(pText) WHERE array_position(coalesce(JsonbToStrArray(pEntities), ARRAY[entitycode]), entitycode) IS NOT NULL;
  END IF;

  RETURN;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_object --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет объект.
 * @param {uuid} pParent - Ссылка на родительский объект: api.object | null
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pLabel - Метка
 * @param {text} pData - Данные
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_object (
  pParent       uuid,
  pType         uuid,
  pLabel        text default null,
  pData			text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateObject(pParent, pType, pLabel, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_object -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует объект.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pLabel - Метка
 * @param {text} pData - Данные
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_object (
  pId		    uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pLabel        text default null,
  pData			text default null
) RETURNS       void
AS $$
DECLARE
  uObject       uuid;
BEGIN
  SELECT t.id INTO uObject FROM db.object t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pId);
  END IF;

  PERFORM EditObject(uObject, pParent, pType, pLabel, pData, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object (
  pId		    uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pLabel        text default null,
  pData			text default null
) RETURNS       SETOF api.object
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_object(pParent, pType, pLabel, pData);
  ELSE
    PERFORM api.update_object(pId, pParent, pType, pLabel, pData);
  END IF;

  RETURN QUERY SELECT * FROM api.object WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает объект
 * @param {uuid} pId - Идентификатор
 * @return {api.object}
 */
CREATE OR REPLACE FUNCTION api.get_object (
  pId		uuid
) RETURNS	api.object
AS $$
  SELECT * FROM api.object WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список объектов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object}
 */
CREATE OR REPLACE FUNCTION api.list_object (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.object
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_label --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_label (
  pObject       uuid
) RETURNS       text
AS $$
DECLARE
  uId           uuid;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pObject;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pObject);
  END IF;

  RETURN GetObjectLabel(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_label --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_label (
  pObject       uuid,
  pLabel        text,
  OUT id        uuid,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  uId           uuid;
BEGIN
  id := null;

  SELECT o.id INTO uId FROM db.object o WHERE o.id = pObject;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pObject);
  END IF;

  id := uId;

  PERFORM SetObjectLabel(pObject, pLabel, null);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.object_force_delete -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Принудительно "удаляет" документ (минуя события документооборота).
 * @param {uuid} pId - Идентификатор объекта
 * @out param {uuid} id - Идентификатор
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.object_force_delete (
  pId	        uuid
) RETURNS	    void
AS $$
DECLARE
  uId		    uuid;
  uState	    uuid;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pId);
  END IF;

  SELECT s.id INTO uState FROM db.state s WHERE s.class = GetObjectClass(pId) AND s.code = 'deleted';

  IF NOT FOUND THEN
    PERFORM StateByCodeNotFound(pId, 'deleted');
  END IF;

  PERFORM AddObjectState(pId, uState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.decode_object_access ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Расшифровка маски прав доступа для объекта.
 * @return {SETOF record} - Запись
 */
CREATE OR REPLACE FUNCTION api.decode_object_access (
  pId       uuid,
  pUserId	uuid DEFAULT current_userid(),
  OUT s		boolean,
  OUT u		boolean,
  OUT d		boolean
) RETURNS 	record
AS $$
  SELECT * FROM DecodeObjectAccess(pId, pUserId);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW api.object_access ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_access
AS
  SELECT * FROM ObjectMembers;

GRANT SELECT ON api.object_access TO administrator;

--------------------------------------------------------------------------------
-- api.object_access -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает участников и права доступа для объекта.
 * @return {SETOF api.object_access} - Запись
 */
CREATE OR REPLACE FUNCTION api.object_access (
  pId       uuid
) RETURNS 	SETOF api.object_access
AS $$
  SELECT * FROM api.object_access WHERE object = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT ACTION ---------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.execute_object_action ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет действие над объектом.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {uuid} pAction - Идентификатор действия
 * @param {jsonb} pParams - Параметры в формате JSON
 * @return {jsonb}
 */
CREATE OR REPLACE FUNCTION api.execute_object_action (
  pObject		uuid,
  pAction		uuid,
  pParams		jsonb DEFAULT null
) RETURNS		jsonb
AS $$
BEGIN
  PERFORM FROM db.object WHERE id = pObject;

  IF NOT FOUND THEN
    PERFORM NotFound();
  END IF;

  IF pAction IS NULL THEN
    PERFORM ActionIsEmpty();
  END IF;

  RETURN ExecuteObjectAction(pObject, pAction, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.execute_object_action ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет действие над объектом по коду.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pCode - Код действия
 * @param {jsonb} pParams - Параметры в формате JSON
 * @return {jsonb}
 */
CREATE OR REPLACE FUNCTION api.execute_object_action (
  pObject       uuid,
  pCode         text,
  pParams		jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  arCodes       text[];
  r             record;
BEGIN
  FOR r IN SELECT code FROM db.action
  LOOP
    arCodes := array_append(arCodes, r.code::text);
  END LOOP;

  IF array_position(arCodes, pCode) IS NULL THEN
    PERFORM IncorrectCode(pCode, arCodes);
  END IF;

  RETURN api.execute_object_action(pObject, GetAction(pCode), pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.execute_object_action_try -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет действие над объектом не вызывая ошибки.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {uuid} pAction - Идентификатор действия
 * @param {jsonb} pParams - Параметры в формате JSON
 * @return {jsonb}
 */
CREATE OR REPLACE FUNCTION api.execute_object_action_try (
  pObject		uuid,
  pAction		uuid,
  pParams		jsonb DEFAULT null
) RETURNS		jsonb
AS $$
DECLARE
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  RETURN api.execute_object_action(pObject, pAction, pParams);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.execute_object_action_try -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет действие над объектом по коду не вызывая ошибки.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pCode - Код действия
 * @param {jsonb} pParams - Параметры в формате JSON
 * @return {jsonb}
 */
CREATE OR REPLACE FUNCTION api.execute_object_action_try (
  pObject       uuid,
  pCode         text,
  pParams		jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  RETURN api.execute_object_action(pObject, GetAction(pCode), pParams);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT METHOD ---------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.execute_method ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет метод объекта.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {uuid} pMethod - Идентификатор метода
 * @param {jsonb} pParams - Параметры в формате JSON
 * @return {jsonb}
 */
CREATE OR REPLACE FUNCTION api.execute_method (
  pObject       uuid,
  pMethod       uuid,
  pParams		jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  uId           uuid;
  uMethod       uuid;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pObject;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  IF pMethod IS NULL THEN
    PERFORM MethodIsEmpty();
  END IF;

  SELECT m.id INTO uMethod FROM method m WHERE m.id = pMethod;

  IF NOT FOUND THEN
    PERFORM MethodNotFound(pObject, pMethod);
  END IF;

  RETURN ExecuteMethod(pObject, uMethod, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.execute_method ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет метод объекта.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pCode - Код метода
 * @param {jsonb} pParams - Параметры в формате JSON
 * @return {jsonb}
 */
CREATE OR REPLACE FUNCTION api.execute_method (
  pObject       uuid,
  pCode         text,
  pParams		jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  uId           uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pObject;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  IF pCode IS NULL THEN
    PERFORM MethodIsEmpty();
  END IF;

  uClass := GetObjectClass(pObject);

  SELECT m.id INTO uMethod FROM db.method m WHERE m.class = uClass AND m.code = pCode;

  IF NOT FOUND THEN
    PERFORM MethodByCodeNotFound(pObject, pCode);
  END IF;

  RETURN ExecuteMethod(pObject, uMethod, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT GROUP ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_group ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_group
AS
  SELECT * FROM ObjectGroup(current_userid());

GRANT SELECT ON api.object_group TO administrator;

--------------------------------------------------------------------------------
-- api.add_object_group --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт группу объектов.
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_object_group (
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateObjectGroup(pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_object_group -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет группу объектов.
 * @param {uuid} pId - Идентификатор группы объектов
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_object_group (
  pId               uuid,
  pCode             text DEFAULT null,
  pName             text DEFAULT null,
  pDescription      text DEFAULT null
) RETURNS           void
AS $$
BEGIN
  PERFORM EditObjectGroup(pId, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_group --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_group (
  pId               uuid,
  pCode             text DEFAULT null,
  pName             text DEFAULT null,
  pDescription      text DEFAULT null
) RETURNS           SETOF api.object_group
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_object_group(pCode, pName, pDescription);
  ELSE
    PERFORM api.update_object_group(pId, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.object_group WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_group --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные группы объектов.
 * @return {SETOF api.object_group}
 */
CREATE OR REPLACE FUNCTION api.get_object_group (
  pId         uuid
) RETURNS     SETOF api.object_group
AS $$
  SELECT * FROM api.object_group WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_group -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список групп объектов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_group}
 */
CREATE OR REPLACE FUNCTION api.list_object_group (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.object_group
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_group', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_object_to_group -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет объект в группу.
 * @param {uuid} pGroup - Идентификатор группы объектов
 * @param {uuid} pObject - Идентификатор объекта
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.add_object_to_group (
  pGroup    uuid,
  pObject   uuid
) RETURNS   void
AS $$
BEGIN
  IF NOT CheckObjectAccess(pObject, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  PERFORM AddObjectToGroup(pGroup, pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_object_from_group ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет объект из группы.
 * @param {uuid} pGroup - Идентификатор группы объектов
 * @param {uuid} pObject - Идентификатор объекта
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_object_from_group (
  pGroup    uuid,
  pObject   uuid DEFAULT null
) RETURNS   void
AS $$
BEGIN
  IF NOT CheckObjectAccess(pObject, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  PERFORM DeleteObjectFromGroup(pGroup, pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW api.object_group_member ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_group_member
AS
  SELECT * FROM ObjectGroupMember;

GRANT SELECT ON api.object_group_member TO administrator;

--------------------------------------------------------------------------------
-- api.object_group_member -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список объектов группы.
 * @return {SETOF api.object}
 */
CREATE OR REPLACE FUNCTION api.object_group_member (
  pGroupId      uuid
) RETURNS       SETOF api.object
AS $$
  SELECT o.*
    FROM api.object_group_member g INNER JOIN api.object o ON o.id = g.object
   WHERE g.gid = pGroupId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT FILE -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_file -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_file
AS
  SELECT f.* FROM ObjectFile f INNER JOIN AccessObject o ON f.object = o.id;

GRANT SELECT ON api.object_file TO administrator;

--------------------------------------------------------------------------------
-- api.set_object_file ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Связывает файл с объектом
 * @param {uuid} pId - Идентификатор объекта
 * @return {SETOF api.object_file}
 */
CREATE OR REPLACE FUNCTION api.set_object_file (
  pId	    uuid,
  pName		text,
  pPath		text,
  pSize		integer,
  pDate		timestamptz,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null
) RETURNS   SETOF api.object_file
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'010') THEN
	PERFORM AccessDenied();
  END IF;

  PERFORM SetObjectFile(pId, pName, pPath, pSize, pDate, pData, pHash, pText, pType);

  RETURN QUERY SELECT * FROM api.get_object_file(pId, pName);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_files_json ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_files_json (
  pId       uuid,
  pFiles    json
) RETURNS   SETOF api.object_file
AS $$
DECLARE
  r         record;
  arKeys    text[];
  uId       uuid;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pId);
  END IF;

  IF pFiles IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['name', 'path', 'size', 'date', 'data', 'hash', 'text', 'type']);
    PERFORM CheckJsonKeys('/object/file/files', arKeys, pFiles);

    FOR r IN SELECT * FROM json_to_recordset(pFiles) AS files(name text, path text, size int, date timestamptz, data text, hash text, text text, type text)
    LOOP
      RETURN NEXT api.set_object_file(pId, r.name, r.path, r.size, r.date, decode(r.data, 'base64'), r.hash, r.text, r.type);
    END LOOP;
  ELSE
    PERFORM JsonIsEmpty();
  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_files_jsonb --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_files_jsonb (
  pId           uuid,
  pFiles        jsonb
) RETURNS       SETOF api.object_file
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.set_object_files_json(pId, pFiles::json);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_files_json ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_files_json (
  pId	    uuid
) RETURNS	json
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  RETURN GetObjectFilesJson(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_files_jsonb --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_files_jsonb (
  pId	    uuid
) RETURNS	jsonb
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  RETURN GetObjectFilesJsonb(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_file ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает файлы объекта
 * @param {uuid} pId - Идентификатор объекта
 * @param {text} pName - Наименование файла
 * @param {text} pPath - Путь к файлу
 * @return {api.object_file}
 */
CREATE OR REPLACE FUNCTION api.get_object_file (
  pId       uuid,
  pName     text,
  pPath     text default null
) RETURNS	SETOF api.object_file
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  pPath := coalesce(pPath, '~/');

  RETURN QUERY SELECT * FROM api.object_file WHERE object = pId AND path IS NOT DISTINCT FROM pPath AND name = pName;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_file --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список файлов объекта.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_file}
 */
CREATE OR REPLACE FUNCTION api.list_object_file (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.object_file
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_file', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.clear_object_files ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет все файлы объекта
 * @param {uuid} pId - Идентификатор объекта
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.clear_object_files (
  pId       uuid
) RETURNS	void
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'001') THEN
	PERFORM AccessDenied();
  END IF;

  PERFORM ClearObjectFiles(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT DATA -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_data -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_data
AS
  SELECT d.* FROM ObjectData d INNER JOIN AccessObject o ON d.object = o.id;

GRANT SELECT ON api.object_data TO administrator;

--------------------------------------------------------------------------------
-- api.set_object_data ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает данные объекта
 * @param {uuid} pId - Идентификатор объекта
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pData - Данные
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.set_object_data (
  pId           uuid,
  pType         uuid,
  pCode         text,
  pData         text
) RETURNS       SETOF api.object_data
AS $$
DECLARE
  r             record;
  uType         uuid;
  arTypes       text[];
BEGIN
  IF NOT CheckObjectAccess(pId, B'010') THEN
	PERFORM AccessDenied();
  END IF;

  pType := lower(pType);

  FOR r IN SELECT type FROM db.object_data
  LOOP
    arTypes := array_append(arTypes, r.type);
  END LOOP;

  IF array_position(arTypes, pType) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  PERFORM SetObjectData(pId, pType, pCode, pData);

  RETURN QUERY SELECT * FROM api.get_object_data(pId, uType, pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_data_json ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_data_json (
  pId           uuid,
  pData	        json
) RETURNS       SETOF api.object_data
AS $$
DECLARE
  uId           uuid;
  arKeys        text[];
  r             record;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pId);
  END IF;

  IF pData IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['type', 'code', 'data']);
    PERFORM CheckJsonKeys('/object/data', arKeys, pData);

    FOR r IN SELECT * FROM json_to_recordset(pData) AS data(type text, code text, data text)
    LOOP
      RETURN NEXT api.set_object_data(pId, r.type, r.code, r.data);
    END LOOP;
  ELSE
    PERFORM JsonIsEmpty();
  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_data_jsonb ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_data_jsonb (
  pId       uuid,
  pData     jsonb
) RETURNS   SETOF api.object_data
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.set_object_data_json(pId, pData::json);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_data_json ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_data_json (
  pId	    uuid
) RETURNS	json
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  RETURN GetObjectDataJson(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_data_jsonb ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_data_jsonb (
  pId	    uuid
) RETURNS	jsonb
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  RETURN GetObjectDataJsonb(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_data ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные объекта
 * @param {uuid} pId - Идентификатор объекта
 * @return {api.object_data}
 */
CREATE OR REPLACE FUNCTION api.get_object_data (
  pId	    uuid,
  pType		text,
  pCode		text
) RETURNS	SETOF api.object_data
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  RETURN QUERY SELECT * FROM api.object_data WHERE object = pId AND type = pType AND code = pCode;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_data --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список данных объекта.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_data}
 */
CREATE OR REPLACE FUNCTION api.list_object_data (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.object_data
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_data', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT COORDINATES ----------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_coordinates ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_coordinates
AS
  SELECT c.* FROM ObjectCoordinates c INNER JOIN AccessObject o ON c.object = o.id;

GRANT SELECT ON api.object_coordinates TO administrator;

--------------------------------------------------------------------------------
-- api.object_coordinates ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.object_coordinates (
  pDateFrom     timestamptz
) RETURNS       SETOF api.object_coordinates
AS $$
  SELECT * FROM ObjectCoordinates(pDateFrom);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_coordinates --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает координаты объекта
 * @param {uuid} pId - Идентификатор объекта
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {numeric} pLatitude - Широта
 * @param {numeric} pLongitude - Долгота
 * @param {numeric} pAccuracy - Точность (высота над уровнем моря)
 * @param {text} pDescription - Описание
 * @param {jsonb} pData - Данные в произвольном формате
 * @return {SETOF api.object_coordinates}
 */
CREATE OR REPLACE FUNCTION api.set_object_coordinates (
  pId           uuid,
  pCode         text,
  pLatitude     numeric,
  pLongitude    numeric,
  pAccuracy     numeric DEFAULT 0,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pData			jsonb DEFAULT null,
  pDateFrom		timestamptz DEFAULT Now()
) RETURNS       SETOF api.object_coordinates
AS $$
DECLARE
  r				record;
  device		jsonb;
  sSerial		text;
BEGIN
  IF NOT CheckObjectAccess(pId, B'010') THEN
	PERFORM AccessDenied();
  END IF;

  pCode := coalesce(pCode, 'default');
  pAccuracy := coalesce(pAccuracy, 0);

  device := pData->>'device';
  IF device IS NOT NULL THEN
	sSerial := device->>'serial';
	IF sSerial IS NOT NULL THEN
      SELECT id, identity INTO r FROM db.device WHERE serial = sSerial;
      pData := pData || jsonb_build_object('device', device || jsonb_build_object('id', r.id, 'identity', r.identity));
	END IF;
  END IF;

  PERFORM NewObjectCoordinates(pId, pCode, pLatitude, pLongitude, pAccuracy, pLabel, pDescription, pData, coalesce(pDateFrom, Now()));
  PERFORM SetObjectDataJSON(pId, 'geo', GetObjectCoordinatesJson(pId, pCode));

  RETURN QUERY SELECT * FROM api.get_object_coordinates(pId, pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_coordinates_json ---------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_coordinates_json (
  pId           uuid,
  pCoordinates  json
) RETURNS       SETOF api.object_coordinates
AS $$
DECLARE
  r             record;
  uId           uuid;
  arKeys        text[];
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pId);
  END IF;

  IF pCoordinates IS NOT NULL THEN
    arKeys := array_cat(arKeys, GetRoutines('set_object_coordinates', 'api', false));
    PERFORM CheckJsonKeys('/object/coordinates', arKeys, pCoordinates);

    FOR r IN SELECT * FROM json_to_recordset(pCoordinates) AS x(code text, latitude numeric, longitude numeric, accuracy numeric, label text, description text, data jsonb, datefrom timestamptz)
    LOOP
      RETURN NEXT api.set_object_coordinates(pId, r.code, r.latitude, r.longitude, r.accuracy, r.label, r.description, r.data, r.datefrom);
    END LOOP;
  ELSE
    PERFORM JsonIsEmpty();
  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_coordinates_jsonb --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_coordinates_jsonb (
  pId           uuid,
  pCoordinates  jsonb
) RETURNS       SETOF api.object_coordinates
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.set_object_coordinates_json(pId, pCoordinates::json);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_coordinates_json ---------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_coordinates_json (
  pId	    uuid
) RETURNS	json
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  RETURN GetObjectCoordinatesJson(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_coordinates_jsonb --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_coordinates_jsonb (
  pId	    uuid
) RETURNS	jsonb
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  RETURN GetObjectCoordinatesJsonb(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_coordinates --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные объекта
 * @param {uuid} pId - Идентификатор объекта
 * @return {api.object_coordinates}
 */
CREATE OR REPLACE FUNCTION api.get_object_coordinates (
  pId           uuid,
  pCode         text,
  pDateFrom     timestamptz DEFAULT oper_date()
) RETURNS       SETOF api.object_coordinates
AS $$
DECLARE
  r             record;
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
	PERFORM AccessDenied();
  END IF;

  FOR r IN
	SELECT *
	  FROM api.object_coordinates
	 WHERE object = pId
	   AND code = pCode
	   AND validFromDate <= pDateFrom
	   AND validToDate > pDateFrom
  LOOP
	RETURN NEXT r;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_coordinates -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список данных объекта.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_coordinates}
 */
CREATE OR REPLACE FUNCTION api.list_object_coordinates (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.object_coordinates
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_coordinates', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
