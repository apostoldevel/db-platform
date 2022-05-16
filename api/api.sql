--------------------------------------------------------------------------------
-- API -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- API LOG ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.log
AS
  SELECT * FROM apiLog;

GRANT SELECT ON api.log TO administrator;

--------------------------------------------------------------------------------
-- api.log ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Журнал событий текущего пользователя.
 * @param {char} pType - Тип события: {M|W|E}
 * @param {integer} pCode - Код
 * @param {timestamp} pDateFrom - Дата начала периода
 * @param {timestamp} pDateTo - Дата окончания периода
 * @return {SETOF api.log} - Записи
 */
CREATE OR REPLACE FUNCTION api.log (
  pUserName     text DEFAULT null,
  pPath		    text DEFAULT null,
  pDateFrom	    timestamp DEFAULT null,
  pDateTo	    timestamp DEFAULT null
) RETURNS	    SETOF api.log
AS $$
  SELECT *
    FROM api.log
   WHERE username = coalesce(pUserName, username)
     AND path = coalesce(pPath, path)
     AND datetime >= coalesce(pDateFrom, MINDATE())
     AND datetime < coalesce(pDateTo, MAXDATE())
   ORDER BY datetime DESC, id
   LIMIT 500
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_log -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает событие
 * @param {bigint} pId - Идентификатор
 * @return {api.log}
 */
CREATE OR REPLACE FUNCTION api.get_log (
  pId		bigint
) RETURNS	api.log
AS $$
  SELECT * FROM api.log WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_log ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список событий.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.log}
 */
CREATE OR REPLACE FUNCTION api.list_log (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.log
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'log', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.sql ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает динамический SQL запрос.
 * @param {text} pScheme - Схема
 * @param {text} pTable - Таблица
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {text} - SQL запрос

 Где сравнение (compare):
   EQL - равно
   NEQ - не равно
   LSS - меньше
   LEQ - меньше или равно
   GTR - больше
   GEQ - больше или равно
   GIN - для поиска вхождений JSON

   AND - битовый AND
   OR  - битовый OR
   XOR - битовый XOR
   NOT - битовый NOT

   ISN - IS NULL - Ключ (value) должен быть опушен
   INN - IS NOT NULL - Ключ (value) должен быть опушен

   LKE - LIKE - Значение ключа (value) должно передаваться вместе со знаком '%' в нужном месте
   IKE - ILIKE - Регистр-независимый LIKE.

   SIM - Регулярные выражения: SIMILAR TO

   PSX - Регулярное выражение POSIX: ~
   PSI - Регулярное выражение POSIX: ~*
   PSN - Регулярное выражение POSIX: !~
   PIN - Регулярное выражение POSIX: !~*
 */
CREATE OR REPLACE FUNCTION api.sql (
  pScheme       text,
  pTable        text,
  pSearch       jsonb DEFAULT null,
  pFilter       jsonb DEFAULT null,
  pLimit        integer DEFAULT null,
  pOffSet       integer DEFAULT null,
  pOrderBy      jsonb DEFAULT null
) RETURNS       text
AS $$
DECLARE
  r             record;

  uId           uuid;

--  vTable        text;

  vWith         text;
  vSelect       text;
  vWhere        text;
  vJoin         text;

  vCondition    text;
  vField        text;
  vCompare      text;
  vValue        text;
  vLStr         text;
  vRStr         text;

  arValues      text[];
  arColumns     text[];
BEGIN
  pOrderBy := NULLIF(pOrderBy, '{}');
  pOrderBy := NULLIF(pOrderBy, '[]');
/*
  SELECT table_name INTO vTable
    FROM information_schema.tables
   WHERE table_catalog = current_database()
     AND table_schema = pScheme
     AND table_name = pTable
     AND table_type = 'VIEW';

  IF NOT FOUND THEN
    PERFORM ViewNotFound(pScheme, pTable);
  END IF;
*/
  --arColumns := GetColumns(pTable, pScheme, 't');

  vSelect := coalesce(vWith, '') || 'SELECT ' || coalesce(array_to_string(arColumns, ', '), 't.*') || E'\n  FROM ' || pScheme || '.' || pTable || ' t ' || coalesce(vJoin, '');

  arColumns := GetColumns(pTable, pScheme);

  IF pFilter IS NOT NULL THEN
    PERFORM CheckJsonbKeys(pTable || '/filter', arColumns, pFilter);

    FOR r IN SELECT * FROM jsonb_each(pFilter)
    LOOP
      pSearch := coalesce(pSearch, '[]'::jsonb) || jsonb_build_object('field', r.key, 'value', r.value);
    END LOOP;
  END IF;

  IF pSearch IS NOT NULL THEN

    IF jsonb_typeof(pSearch) = 'array' THEN

      PERFORM CheckJsonbKeys(pTable || '/search', ARRAY['condition', 'field', 'compare', 'value', 'valarr', 'lstr', 'rstr'], pSearch);

      FOR r IN SELECT * FROM jsonb_to_recordset(pSearch) AS x(condition text, field text, compare text, value text, valarr jsonb, lstr text, rstr text)
      LOOP
        vCondition := coalesce(upper(r.condition), 'AND');
        vField     := coalesce(lower(r.field), '');
        vCompare   := coalesce(upper(r.compare), 'EQL');
        vLStr	   := coalesce(r.lstr, '');
        vRStr	   := coalesce(r.rstr, '');

        vField := quote_literal_json(vField);

        arValues := array_cat(null, ARRAY['AND', 'OR']);
        IF NOT vCondition = ANY (arValues) THEN
          PERFORM IncorrectValueInArray(vCondition, 'condition', arValues);
        END IF;

        IF NOT vField = ANY (arColumns) THEN
          PERFORM IncorrectValueInArray(vField, 'field', arColumns);
        END IF;

        IF r.valarr IS NOT NULL THEN
          vValue := jsonb_array_to_string(r.valarr, ',');

          vCompare := coalesce(nullif(upper(vCompare), 'EQL'), 'IN');

          arValues := array_cat(null, ARRAY['IN', 'NOT IN']);
          IF NOT vCompare = ANY (arValues) THEN
            PERFORM IncorrectValueInArray(coalesce(r.compare, ''), 'compare', arValues);
          END IF;

          IF vWhere IS NULL THEN
            vWhere := E'\n WHERE ' || vField || ' ' || vCompare || ' (' || vValue || ')';
          ELSE
            vWhere := vWhere || E'\n   ' || vCondition || ' ' || vField || ' ' || vCompare || ' (' || vValue  || ')';
          END IF;

        ELSE
          vValue := quote_nullable(r.value);

          arValues := array_cat(null, ARRAY['EQL', 'NEQ', 'LSS', 'LEQ', 'GTR', 'GEQ', 'GIN', 'AND', 'OR', 'XOR', 'NOT', 'ISN', 'INN', 'LKE', 'IKE', 'SIM', 'PSX', 'PSI', 'PSN', 'PIN']);
          IF NOT vCompare = ANY (arValues) THEN
            PERFORM IncorrectValueInArray(vCompare, 'compare', arValues);
          END IF;

		  IF vField = 'statetypecode' THEN
			vField := 'statetype';
			SELECT id INTO uId FROM db.state_type WHERE code = r.value;
			vValue := quote_nullable(uId);
		  ELSIF vField = 'typecode' THEN
			vField := 'type';
			SELECT id INTO uId FROM db.type WHERE code = r.value;
			vValue := quote_nullable(uId);
		  ELSIF vField = 'classcode' THEN
			vField := 'class';
			SELECT id INTO uId FROM db.class_tree WHERE code = r.value;
			vValue := quote_nullable(uId);
		  ELSIF vField = 'entitycode' THEN
			vField := 'entity';
			SELECT id INTO uId FROM db.entity WHERE code = r.value;
			vValue := quote_nullable(uId);
		  END IF;

          IF vCompare IN ('AND', 'OR', 'XOR', 'NOT') THEN
            vValue := vValue || ' = ' || vValue;
          END IF;

          IF vWhere IS NULL THEN
            vWhere := E'\n WHERE ' || vLStr || vField || GetCompare(vCompare) || vValue || vRStr;
          ELSE
            vWhere := vWhere || E'\n   ' || vCondition || ' ' || vLStr || vField || GetCompare(vCompare) || vValue || vRStr;
          END IF;
        END IF;

      END LOOP;

    ELSE
      PERFORM IncorrectJsonType(jsonb_typeof(pSearch), 'array');
    END IF;

  END IF;

  vSelect := vSelect || coalesce(vWhere, '');

  IF pOrderBy IS NOT NULL THEN
    --PERFORM CheckJsonbValues('orderby', array_cat(arColumns, array_add_text(arColumns, ' desc')), pOrderBy);
    vSelect := vSelect || E'\n ORDER BY ' || array_to_string(array_quote_literal_json(JsonbToStrArray(pOrderBy)), ',');
  ELSE
    IF 'sequence' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY sequence';
    ELSIF 'created' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY created DESC';
    ELSIF 'datetime' = ANY(arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY datetime DESC';
    ELSIF 'name' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY name';
    ELSIF 'label' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY label';
    ELSIF 'code' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY code';
    ELSIF 'id' = ANY (arColumns) THEN
      vSelect := vSelect || E'\n ORDER BY id';
    END IF;
  END IF;

  IF pLimit IS NOT NULL THEN
    IF pLimit > 0 THEN
      vSelect := vSelect || E'\n LIMIT ' || pLimit;
    END IF;
  ELSE
    vSelect := vSelect || E'\n LIMIT 500';
  END IF;

  IF pOffSet IS NOT NULL THEN
    vSelect := vSelect || E'\nOFFSET ' || pOffSet;
  END IF;

  IF GetDebugMode() THEN
    PERFORM WriteToEventLog('D', 9001, 'sql', vSelect);
    RAISE NOTICE '%', vSelect;
  END IF;

  RETURN vSelect;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.run ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет REST JSON API запрос.
 * @param {text} pMethod - HTTP-Метод
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @return {SETOF json}
 */
CREATE OR REPLACE FUNCTION api.run (
  pMethod		text,
  pPath			text,
  pPayload		jsonb DEFAULT null
) RETURNS		SETOF json
AS $$
DECLARE
  r				record;

  arPath		text[];

  uPath			uuid;
  uEndpoint		uuid;

  nLength		integer;

  nApiId        bigint;
  dtBegin       timestamptz;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  dtBegin := clock_timestamp();

  uPath := QueryPath(pPath);
  IF uPath IS NULL THEN
	PERFORM RouteNotFound(pPath);
  END IF;

  uEndpoint := GetEndpoint(uPath, pMethod);
  IF uEndpoint IS NULL THEN
	PERFORM EndPointNotSet(pPath);
  END IF;

  arPath := path_to_array(pPath);
  nLength := array_length(arPath, 1);

  pPath := '/';
  IF nLength >= 3 THEN
    FOR i IN 3..nLength
    LOOP
	  pPath := coalesce(nullif(pPath, '/'), '') || '/' || arPath[i];
    END LOOP;
  END IF;

  IF arPath[nLength] = 'count' THEN
    pPayload := pPayload || jsonb_build_object('reclimit', 0);
  END IF;

  nApiId := AddApiLog(pPath, pPayload);

  FOR r IN EXECUTE GetEndpointDefinition(uEndpoint) USING pPath, pPayload
  LOOP
	RETURN NEXT r;
  END LOOP;

  UPDATE db.api_log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN NEXT json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));

  nApiId := AddApiLog(pPath, pPayload);
  UPDATE db.api_log SET eventid = AddEventLog('E', ErrorCode, 'run', ErrorMessage) WHERE id = nApiId;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
