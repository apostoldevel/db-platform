--------------------------------------------------------------------------------
-- OBSERVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.publisher ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.publisher
AS
  SELECT * FROM Publisher;

GRANT SELECT ON api.publisher TO administrator;

--------------------------------------------------------------------------------
-- api.publisher ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.publisher (
  pCode         text
) RETURNS       SETOF api.publisher
AS $$
  SELECT * FROM api.publisher WHERE code = pCode;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_publisher -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает наблюдателя.
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_publisher (
  pCode         text
) RETURNS       SETOF api.publisher
AS $$
  SELECT * FROM api.publisher WHERE code = pCode;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_publisher ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает наблюдателей в виде списка.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.publisher}
 */
CREATE OR REPLACE FUNCTION api.list_publisher (
  pSearch       jsonb DEFAULT null,
  pFilter       jsonb DEFAULT null,
  pLimit        integer DEFAULT null,
  pOffSet       integer DEFAULT null,
  pOrderBy      jsonb DEFAULT null
) RETURNS       SETOF api.publisher
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'publisher', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
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
  pPublisher    text,
  pSession      varchar,
  pIdentity     text
) RETURNS       SETOF api.listener
AS $$
  SELECT * FROM api.listener WHERE publisher = pPublisher AND session = pSession AND identity = pIdentity
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_listener ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.add_listener (
  pPublisher    text,
  pSession    	varchar,
  pIdentity		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		void
AS $$
BEGIN
  PERFORM CreateListener(pPublisher, pSession, pIdentity, pFilter, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_listener ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.update_listener (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		boolean
AS $$
BEGIN
  RETURN EditListener(pPublisher, pSession, pIdentity, pFilter, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_listener ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_listener (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS       SETOF api.listener
AS $$
BEGIN
  IF NOT api.update_listener(pPublisher, pSession, pIdentity, pFilter, pParams) THEN
    PERFORM api.add_listener(pPublisher, pSession, pIdentity, pFilter, pParams);
  END IF;

  RETURN QUERY SELECT * FROM api.get_listener(pPublisher, pSession, pIdentity);
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
  pPublisher	text,
  pSession		varchar,
  pIdentity		text
) RETURNS       SETOF api.listener
AS $$
  SELECT * FROM api.listener(pPublisher, pSession, pIdentity);
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
  pPublisher	text,
  pSession		varchar,
  pIdentity		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		SETOF api.listener
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.set_listener(pPublisher, coalesce(pSession, current_session()), pIdentity, pFilter, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.unsubscribe_observer ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.unsubscribe_observer (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text
) RETURNS		boolean
AS $$
BEGIN
  RETURN DeleteListener(pPublisher, coalesce(pSession, current_session()), pIdentity);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
