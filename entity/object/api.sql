--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object
AS
  SELECT * FROM Object;

GRANT SELECT ON api.object TO administrator;

--------------------------------------------------------------------------------
-- api.add_object --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет объект.
 * @param {numeric} pParent - Ссылка на родительский объект: api.object | null
 * @param {varchar} pType - Тип
 * @param {text} pLabel - Метка
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_object (
  pParent       numeric,
  pType         varchar,
  pLabel        text default null
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateObject(pParent, GetType(lower(pType)), pLabel);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_object -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует объект.
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {varchar} pType - Тип
 * @param {text} pLabel - Метка
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_object (
  pId		    numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pLabel        text default null
) RETURNS       void
AS $$
DECLARE
  nType         numeric;
  nObject       numeric;
BEGIN
  SELECT t.id INTO nObject FROM db.object t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := GetType(lower(pType));
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditObject(nObject, pParent, nType,pLabel);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object (
  pId		    numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pLabel        text default null
) RETURNS       SETOF api.object
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_object(pParent, pType, pLabel);
  ELSE
    PERFORM api.update_object(pId, pParent, pType, pLabel);
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
 * @param {numeric} pId - Идентификатор
 * @return {api.object}
 */
CREATE OR REPLACE FUNCTION api.get_object (
  pId		numeric
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
-- api.change_object_state -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Изменить состояние объекта.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {varchar} pCode - Код нового состояния объекта
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.change_object_state (
  pObject       numeric,
  pCode         varchar,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
DECLARE
  nEntity       numeric;
  nType         numeric;
  nClass        numeric;
  nState        numeric;
BEGIN
  id := pObject;

  SELECT o.type INTO nType FROM db.object o WHERE o.id = pObject;
  SELECT t.class INTO nClass FROM db.type t WHERE t.id = nType;

  nEntity := GetEntity(nClass);
  IF nEntity IS NULL THEN
    PERFORM ObjectNotFound('object', 'id', pObject);
  END IF;

  SELECT s.id INTO nState FROM db.state s WHERE s.class = nClass AND s.code = pCode;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Неверный код состояния: "%".', pCode;
  END IF;

  PERFORM ChangeObjectState(pObject, nState);
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
-- api.get_object_label --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_label (
  pObject       numeric
) RETURNS       text
AS $$
DECLARE
  nId           numeric;
BEGIN
  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;
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
  pObject       numeric,
  pLabel        text,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  nId           numeric;
BEGIN
  id := null;

  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pObject);
  END IF;

  id := nId;

  PERFORM SetObjectLabel(pObject, pLabel);
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
 * @param {numeric} pId - Идентификатор объекта
 * @out param {numeric} id - Идентификатор
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.object_force_delete (
  pId	        numeric
) RETURNS	    void
AS $$
DECLARE
  nId		    numeric;
  nState	    numeric;
BEGIN
  SELECT o.id INTO nId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pId);
  END IF;

  SELECT s.id INTO nState FROM db.state s WHERE s.class = GetObjectClass(pId) AND s.code = 'deleted';

  IF NOT FOUND THEN
    PERFORM StateByCodeNotFound(pId, 'deleted');
  END IF;

  PERFORM AddObjectState(pId, nState);
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
  pId       numeric,
  pUserId	numeric DEFAULT current_userid(),
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
  pId       numeric
) RETURNS 	SETOF api.object_access
AS $$
  SELECT * FROM api.object_access WHERE object = pId;
$$ LANGUAGE SQL
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
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_object_group (
  pCode         varchar,
  pName         varchar,
  pDescription  text DEFAULT null
) RETURNS       numeric
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
 * @param {numeric} pId - Идентификатор группы объектов
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_object_group (
  pId               numeric,
  pCode             varchar DEFAULT null,
  pName             varchar DEFAULT null,
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
  pId               numeric,
  pCode             varchar DEFAULT null,
  pName             varchar DEFAULT null,
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
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_object_group (
  pId         numeric
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
 * @param {numeric} pObjectGroup - Идентификатор группу объектов
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.add_object_to_group (
  pGroup    numeric,
  pObject   numeric
) RETURNS   void
AS $$
BEGIN
  PERFORM AddObjectToGroup(pGroup, pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_object_from_group ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удалить объект из группы.
 * @param {numeric} pObjectGroup - Идентификатор зоны
 * @param {numeric} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанной зоны
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_object_from_group (
  pGroup    numeric,
  pObject   numeric DEFAULT null
) RETURNS   void
AS $$
BEGIN
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
  pGroupId      numeric
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
  SELECT * FROM ObjectFile;

GRANT SELECT ON api.object_file TO administrator;

--------------------------------------------------------------------------------
-- api.set_object_file ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Связывает файл с объектом
 * @param {numeric} pId - Идентификатор объекта
 * @return {SETOF api.object_file}
 */
CREATE OR REPLACE FUNCTION api.set_object_file (
  pId	    numeric,
  pName		text,
  pPath		text,
  pSize		numeric,
  pDate		timestamp,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null
) RETURNS   SETOF api.object_file
AS $$
BEGIN
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
  pId       numeric,
  pFiles    json
) RETURNS   SETOF api.object_file
AS $$
DECLARE
  r         record;
  arKeys    text[];
  nId       numeric;
BEGIN
  SELECT o.id INTO nId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pId);
  END IF;

  IF pFiles IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['name', 'path', 'size', 'date', 'data', 'hash', 'text', 'type']);
    PERFORM CheckJsonKeys('/object/file/files', arKeys, pFiles);

    FOR r IN SELECT * FROM json_to_recordset(pFiles) AS files(name text, path text, size int, date timestamp, data text, hash text, text text, type text)
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
  pId           numeric,
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
  pId	    numeric
) RETURNS	json
AS $$
BEGIN
  RETURN GetObjectFilesJson(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_files_jsonb --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_files_jsonb (
  pId	    numeric
) RETURNS	jsonb
AS $$
BEGIN
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
 * @param {numeric} pId - Идентификатор объекта
 * @return {api.object_file}
 */
CREATE OR REPLACE FUNCTION api.get_object_file (
  pId       numeric,
  pName     text
) RETURNS	SETOF api.object_file
AS $$
  SELECT * FROM api.object_file WHERE object = pId AND name = pName;
$$ LANGUAGE SQL
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
-- OBJECT DATA -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_data_type --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_data_type
AS
  SELECT * FROM ObjectDataType;

GRANT SELECT ON api.object_data_type TO administrator;

--------------------------------------------------------------------------------
-- api.get_object_data_type_by_code --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_data_type (
  pCode		varchar
) RETURNS	numeric
AS $$
BEGIN
  RETURN GetObjectDataType(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.object_data -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_data
AS
  SELECT * FROM ObjectData;

GRANT SELECT ON api.object_data TO administrator;

--------------------------------------------------------------------------------
-- api.set_object_data ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает данные объекта
 * @param {numeric} pId - Идентификатор объекта
 * @param {varchar} pType - Код типа данных
 * @param {varchar} pCode - Код
 * @param {text} pData - Данные
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.set_object_data (
  pId           numeric,
  pType         varchar,
  pCode         varchar,
  pData         text
) RETURNS       SETOF api.object_data
AS $$
DECLARE
  r             record;
  nType         numeric;
  arTypes       text[];
BEGIN
  pType := lower(pType);

  FOR r IN SELECT code FROM db.object_data_type
  LOOP
    arTypes := array_append(arTypes, r.code::text);
  END LOOP;

  IF array_position(arTypes, pType::text) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  nType := GetObjectDataType(pType);

  PERFORM SetObjectData(pId, nType, pCode, pData);

  RETURN QUERY SELECT * FROM api.get_object_data(pId, nType, pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_data_json ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_data_json (
  pId           numeric,
  pData	        json
) RETURNS       SETOF api.object_data
AS $$
DECLARE
  nId           numeric;
  arKeys        text[];
  r             record;
BEGIN
  SELECT o.id INTO nId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pId);
  END IF;

  IF pData IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['type', 'code', 'data']);
    PERFORM CheckJsonKeys('/object/data', arKeys, pData);

    FOR r IN SELECT * FROM json_to_recordset(pData) AS data(type varchar, code varchar, data text)
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
  pId       numeric,
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
  pId	    numeric
) RETURNS	json
AS $$
BEGIN
  RETURN GetObjectDataJson(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_data_jsonb ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_data_jsonb (
  pId	    numeric
) RETURNS	jsonb
AS $$
BEGIN
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
 * @param {numeric} pId - Идентификатор объекта
 * @return {api.object_data}
 */
CREATE OR REPLACE FUNCTION api.get_object_data (
  pId	    numeric,
  pType		numeric,
  pCode		varchar
) RETURNS	SETOF api.object_data
AS $$
  SELECT * FROM api.object_data WHERE object = pId AND type = pType AND code = pCode
$$ LANGUAGE SQL
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
  SELECT * FROM ObjectCoordinates;

GRANT SELECT ON api.object_coordinates TO administrator;

--------------------------------------------------------------------------------
-- api.set_object_coordinates --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает координаты объекта
 * @param {numeric} pId - Идентификатор объекта
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pLatitude - Широта
 * @param {numeric} pLongitude - Долгота
 * @param {numeric} pAccuracy - Точность (высота над уровнем моря)
 * @param {text} pDescription - Описание
 * @return {SETOF api.object_coordinates}
 */
CREATE OR REPLACE FUNCTION api.set_object_coordinates (
  pId           numeric,
  pCode         varchar,
  pLatitude     numeric,
  pLongitude    numeric,
  pAccuracy     numeric DEFAULT 0,
  pLabel        varchar DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       SETOF api.object_coordinates
AS $$
BEGIN
  pCode := coalesce(pCode, 'default');
  pAccuracy := coalesce(pAccuracy, 0);
  PERFORM NewObjectCoordinates(pId, pCode, pLatitude, pLongitude, pAccuracy, pLabel, pDescription);
  PERFORM SetObjectData(pId, GetObjectDataType('json'), 'geo', GetObjectCoordinatesJson(pId, pCode)::text);

  RETURN QUERY SELECT * FROM api.get_object_coordinates(pId, pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_coordinates_json ---------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_coordinates_json (
  pId           numeric,
  pCoordinates  json
) RETURNS       SETOF api.object_coordinates
AS $$
DECLARE
  r             record;
  nId           numeric;
  arKeys        text[];
BEGIN
  SELECT o.id INTO nId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pId);
  END IF;

  IF pCoordinates IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['code', 'latitude', 'longitude', 'accuracy', 'label', 'description']);
    PERFORM CheckJsonKeys('/object/coordinates', arKeys, pCoordinates);

    FOR r IN SELECT * FROM json_to_recordset(pCoordinates) AS x(code varchar, latitude numeric, longitude numeric, accuracy numeric, label varchar, description text)
    LOOP
      RETURN NEXT api.set_object_coordinates(pId, r.code, r.latitude, r.longitude, r.accuracy, r.label, r.description);
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
  pId           numeric,
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
  pId	    numeric
) RETURNS	json
AS $$
BEGIN
  RETURN GetObjectCoordinatesJson(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_coordinates_jsonb --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_coordinates_jsonb (
  pId	    numeric
) RETURNS	jsonb
AS $$
BEGIN
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
 * @param {numeric} pId - Идентификатор объекта
 * @return {api.object_coordinates}
 */
CREATE OR REPLACE FUNCTION api.get_object_coordinates (
  pId           numeric,
  pCode         varchar,
  pDateFrom     timestamptz DEFAULT oper_date()
) RETURNS       SETOF api.object_coordinates
AS $$
  SELECT *
    FROM api.object_coordinates
   WHERE object = pId
     AND code = pCode
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;
$$ LANGUAGE SQL
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
