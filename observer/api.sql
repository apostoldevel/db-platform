--------------------------------------------------------------------------------
-- OBSERVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.observer ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.observer
AS
  SELECT * FROM Observer;

GRANT SELECT ON api.observer TO administrator;

--------------------------------------------------------------------------------
-- api.observer ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.observer (
  pCode			text
) RETURNS       SETOF api.observer
AS $$
  SELECT * FROM api.observer WHERE code = pCode;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_observer ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает наблюдателя.
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_observer (
  pId           numeric
) RETURNS       SETOF api.observer
AS $$
  SELECT * FROM api.observer WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_observer -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает наблюдателей в виде списка.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_group}
 */
CREATE OR REPLACE FUNCTION api.list_observer (
  pSearch		jsonb DEFAULT null,
  pFilter		jsonb DEFAULT null,
  pLimit		integer DEFAULT null,
  pOffSet		integer DEFAULT null,
  pOrderBy		jsonb DEFAULT null
) RETURNS		SETOF api.object_group
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'observer', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.listener ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.listener
AS
  SELECT * FROM Listener;

GRANT SELECT ON api.listener TO administrator;

--------------------------------------------------------------------------------
-- api.listener ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.listener (
  pObserver		numeric,
  pSession		text
) RETURNS       SETOF api.listener
AS $$
  SELECT * FROM api.listener
   WHERE observer = pObserver
     AND session = pSession
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_listener ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.add_listener (
  pObserver		numeric,
  pSession		text,
  pFilter		jsonb
) RETURNS		void
AS $$
BEGIN
  PERFORM CreateListener(pObserver, pSession, pFilter);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_listener ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.update_listener (
  pObserver		numeric,
  pSession		text,
  pFilter		jsonb
) RETURNS		boolean
AS $$
BEGIN
  RETURN EditListener(pObserver, pSession, pFilter);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_listener ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_listener (
  pObserver		numeric,
  pSession		text,
  pFilter		jsonb
) RETURNS       SETOF api.listener
AS $$
BEGIN
  IF NOT api.update_listener(pObserver, pSession, pFilter) THEN
    PERFORM api.add_listener(pObserver, pSession, pFilter);
  END IF;

  RETURN QUERY SELECT * FROM api.get_listener(pObserver, pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_listener ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает слушателя.
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_listener (
  pObserver		numeric,
  pSession		text
) RETURNS       SETOF api.listener
AS $$
  SELECT * FROM api.listener(pObserver, pSession);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_listener -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает слушателей в виде списка.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.listener}
 */
CREATE OR REPLACE FUNCTION api.list_listener (
  pSearch		jsonb DEFAULT null,
  pFilter		jsonb DEFAULT null,
  pLimit		integer DEFAULT null,
  pOffSet		integer DEFAULT null,
  pOrderBy		jsonb DEFAULT null
) RETURNS		SETOF api.listener
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'listener', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.subscribe_observer ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.subscribe_observer (
  pObserver		text,
  pSession		text,
  pFilter		jsonb
) RETURNS		SETOF api.listener
AS $$
DECLARE
  nObserver		numeric;
BEGIN
  nObserver := GetObserver(pObserver);
  RETURN QUERY SELECT * FROM api.set_listener(nObserver, coalesce(pSession, current_session()), coalesce(pFilter, '{}'::jsonb));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.unsubscribe_observer ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.unsubscribe_observer (
  pObserver		text,
  pSession		text
) RETURNS		void
AS $$
DECLARE
  nObserver		numeric;
BEGIN
  nObserver := GetObserver(pObserver);
  PERFORM DeleteListener(nObserver, coalesce(pSession, current_session()));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

