--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

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
  pHash		text DEFAULT null
) RETURNS   SETOF api.object_file
AS $$
BEGIN
  PERFORM SetObjectFile(pId, pName, pPath, pSize, pDate, pData, pHash);
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
    arKeys := array_cat(arKeys, ARRAY['name', 'path', 'size', 'date', 'data', 'hash']);
    PERFORM CheckJsonKeys('/object/file/files', arKeys, pFiles);

    FOR r IN SELECT * FROM json_to_recordset(pFiles) AS files(name text, path text, size int, date timestamp, data text, hash text)
    LOOP
      RETURN NEXT api.set_object_file(pId, r.name, r.path, r.size, r.date, decode(r.data, 'base64'), r.hash);
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
