--------------------------------------------------------------------------------
-- API -------------------------------------------------------------------------
--------------------------------------------------------------------------------

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

  vTable        text;

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

  SELECT table_name INTO vTable
    FROM information_schema.tables
   WHERE table_catalog = current_database()
     AND table_schema = pScheme
     AND table_name = pTable
     AND table_type = 'VIEW';

  IF NOT FOUND THEN
    PERFORM ViewNotFound(pScheme, pTable);
  END IF;

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
        vField     := coalesce(lower(r.field), '<null>');
        vCompare   := coalesce(upper(r.compare), 'EQL');
        vLStr	   := coalesce(r.lstr, '');
        vRStr	   := coalesce(r.rstr, '');

        vField := quote_literal_json(vField);

        arValues := array_cat(null, ARRAY['AND', 'OR']);
        IF array_position(arValues, vCondition) IS NULL THEN
          PERFORM IncorrectValueInArray(coalesce(r.condition, '<null>'), 'condition', arValues);
        END IF;

        IF array_position(arColumns, vField) IS NULL THEN
          PERFORM IncorrectValueInArray(coalesce(r.field, '<null>'), 'field', arColumns);
        END IF;

        IF r.valarr IS NOT NULL THEN
          vValue := jsonb_array_to_string(r.valarr, ',');

          IF vWhere IS NULL THEN
            vWhere := E'\n WHERE ' || vField || ' IN (' || vValue || ')';
          ELSE
            vWhere := vWhere || E'\n  ' || vCondition || ' ' || vField || ' IN (' || vValue  || ')';
          END IF;

        ELSE
          vValue := quote_nullable(r.value);

          arValues := array_cat(null, ARRAY['EQL', 'NEQ', 'LSS', 'LEQ', 'GTR', 'GEQ', 'GIN', 'AND', 'OR', 'XOR', 'NOT', 'ISN', 'INN', 'LKE', 'IKE', 'SIM', 'PSX', 'PSI', 'PSN', 'PIN']);
          IF array_position(arValues, vCompare) IS NULL THEN
            PERFORM IncorrectValueInArray(coalesce(r.compare, '<null>'), 'compare', arValues);
          END IF;

          IF vCompare IN ('AND', 'OR', 'XOR', 'NOT') THEN
            vValue := vValue || ' = ' || vValue;
          END IF;

          IF vWhere IS NULL THEN
            vWhere := E'\n WHERE ' || vLStr || vField || GetCompare(vCompare) || vValue || vRStr;
          ELSE
            vWhere := vWhere || E'\n  ' || vCondition || ' ' || vLStr || vField || GetCompare(vCompare) || vValue || vRStr;
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
    IF SubStr(pTable, 1, 7) = 'object_' THEN
      vSelect := vSelect || E'\n ORDER BY object';
    ELSIF SubStr(pTable, 1, 7) = 'session' THEN
      vSelect := vSelect || E'\n ORDER BY created';
    ELSE
      IF array_position(arColumns, 'id') IS NOT NULL THEN
        vSelect := vSelect || E'\n ORDER BY id';
      END IF;
    END IF;
  END IF;

  IF pLimit IS NOT NULL THEN
    vSelect := vSelect || E'\n LIMIT ' || pLimit;
  END IF;

  IF pOffSet IS NOT NULL THEN
    vSelect := vSelect || E'\nOFFSET ' || pOffSet;
  END IF;

  --PERFORM WriteToEventLog('N', 9999, vSelect);

  RETURN vSelect;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- API LOG ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.api_log
AS
  SELECT * FROM apiLog;

GRANT SELECT ON api.api_log TO administrator;

--------------------------------------------------------------------------------
-- api.api_log -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Журнал событий текущего пользователя.
 * @param {char} pType - Тип события: {M|W|E}
 * @param {integer} pCode - Код
 * @param {timestamp} pDateFrom - Дата начала периода
 * @param {timestamp} pDateTo - Дата окончания периода
 * @return {SETOF api.api_log} - Записи
 */
CREATE OR REPLACE FUNCTION api.api_log (
  pUserName     text DEFAULT null,
  pPath		    text DEFAULT null,
  pDateFrom	    timestamp DEFAULT null,
  pDateTo	    timestamp DEFAULT null
) RETURNS	    SETOF api.api_log
AS $$
  SELECT *
    FROM api.api_log
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
-- api.get_api_log -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает событие
 * @param {numeric} pId - Идентификатор
 * @return {api.api}
 */
CREATE OR REPLACE FUNCTION api.get_api_log (
  pId		numeric
) RETURNS	api.api_log
AS $$
  SELECT * FROM api.api_log WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_api_log ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список событий.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.api}
 */
CREATE OR REPLACE FUNCTION api.list_api_log (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.api_log
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'api_log', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
