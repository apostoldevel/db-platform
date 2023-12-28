--------------------------------------------------------------------------------
-- EVENT LOG -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.event_log
AS
  SELECT * FROM EventLog;

GRANT SELECT ON api.event_log TO administrator;

--------------------------------------------------------------------------------
-- api.event_log ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Журнал событий пользователя.
 * @param {char} pType - Тип события: {M|W|E}
 * @param {integer} pCode - Код
 * @param {timestamp} pDateFrom - Дата начала периода
 * @param {timestamp} pDateTo - Дата окончания периода
 * @return {SETOF api.event_log} - Записи
 */
CREATE OR REPLACE FUNCTION api.event_log (
  pUserName      text DEFAULT null,
  pType          char DEFAULT null,
  pCode          integer DEFAULT null,
  pDateFrom      timestamp DEFAULT null,
  pDateTo        timestamp DEFAULT null
) RETURNS        SETOF api.event_log
AS $$
  SELECT *
    FROM api.event_log
   WHERE username = coalesce(pUserName, username)
     AND type = coalesce(pType, type)
     AND code = coalesce(pCode, code)
     AND datetime >= coalesce(pDateFrom, MINDATE())
     AND datetime < coalesce(pDateTo, MAXDATE())
   ORDER BY datetime DESC, id
   LIMIT 500
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.write_to_log ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.write_to_log (
  pType         text,
  pCode         integer,
  pText         text
) RETURNS       SETOF api.event_log
AS $$
DECLARE
  nId           bigint;
BEGIN
  nId := AddEventLog(pType, pCode, 'api', pText);
  RETURN QUERY SELECT * FROM api.get_event_log(nId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_event_log -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает событие
 * @param {bigint} pId - Идентификатор
 * @return {api.event_log}
 */
CREATE OR REPLACE FUNCTION api.get_event_log (
  pId        bigint
) RETURNS    api.event_log
AS $$
  SELECT * FROM api.event_log WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_event_log ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список событий.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.event_log}
 */
CREATE OR REPLACE FUNCTION api.list_event_log (
  pSearch    jsonb DEFAULT null,
  pFilter    jsonb DEFAULT null,
  pLimit     integer DEFAULT null,
  pOffSet    integer DEFAULT null,
  pOrderBy   jsonb DEFAULT null
) RETURNS    SETOF api.event_log
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'event_log', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- USER EVENT LOG --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.user_log
AS
  WITH cu AS (
    SELECT current_username() AS username
  )
  SELECT el.* FROM EventLog el INNER JOIN cu ON el.username = cu.username;

GRANT SELECT ON api.user_log TO administrator;

--------------------------------------------------------------------------------
-- api.user_log ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Журнал событий пользователя.
 * @param {char} pType - Тип события: {M|W|E}
 * @param {integer} pCode - Код
 * @param {timestamp} pDateFrom - Дата начала периода
 * @param {timestamp} pDateTo - Дата окончания периода
 * @return {SETOF api.event_log} - Записи
 */
CREATE OR REPLACE FUNCTION api.user_log (
  pType         char DEFAULT null,
  pCode         integer DEFAULT null,
  pDateFrom     timestamp DEFAULT null,
  pDateTo       timestamp DEFAULT null
) RETURNS       SETOF api.user_log
AS $$
  SELECT *
    FROM api.user_log
   WHERE type = coalesce(pType, type)
     AND code = coalesce(pCode, code)
     AND datetime >= coalesce(pDateFrom, MINDATE())
     AND datetime < coalesce(pDateTo, MAXDATE())
   ORDER BY datetime DESC, id
   LIMIT 500
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_user_log ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает событие
 * @param {bigint} pId - Идентификатор
 * @return {api.user_log}
 */
CREATE OR REPLACE FUNCTION api.get_user_log (
  pId        bigint
) RETURNS    api.user_log
AS $$
  SELECT * FROM api.user_log WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_user_log -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список событий.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.user_log}
 */
CREATE OR REPLACE FUNCTION api.list_user_log (
  pSearch    jsonb DEFAULT null,
  pFilter    jsonb DEFAULT null,
  pLimit     integer DEFAULT null,
  pOffSet    integer DEFAULT null,
  pOrderBy   jsonb DEFAULT null
) RETURNS    SETOF api.user_log
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'user_log', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
