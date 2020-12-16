--------------------------------------------------------------------------------
-- OBSERVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.observer ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные наблюдателя.
 * @param {text} pSession - Сессия
 * @param {timestamptz} pDateFrom - Дата начала периода
 * @return {SETOF json}
 */
CREATE OR REPLACE FUNCTION api.observer (
  pSession		text,
  pDateFrom		timestamptz
) RETURNS       SETOF json
AS $$
DECLARE
  l             record;
  r             record;
  e             record;

  type			text;
  hook			jsonb;

  vPublisher	text;
  vUserName		text;
BEGIN
  FOR l IN SELECT * FROM db.listener WHERE session = pSession
  LOOP
	SELECT code INTO vPublisher FROM db.publisher WHERE id = l.publisher;

	IF vPublisher = 'notify' THEN

	  type := l.params->>'type';
	  hook := l.params->'hook';

	  FOR r IN SELECT * FROM api.notification(pDateFrom) ORDER BY id
	  LOOP
		IF IsListenerFilter(vPublisher, l.filter, jsonb_build_object('entity', r.entitycode, 'class', r.classcode, 'action', r.actioncode, 'method', r.methodcode, 'object', r.object)) THEN
		  IF type = 'object' THEN
			FOR e IN EXECUTE format('SELECT * FROM api.get_%s($1)', r.entitycode) USING r.object
			LOOP
			  RETURN NEXT row_to_json(e);
			END LOOP;
		  ELSIF type = 'hook' THEN
			FOR e IN SELECT * FROM api.run(coalesce(hook->>'method', 'POST'), hook->>'path', hook->'payload')
			LOOP
			  RETURN NEXT e.run;
			END LOOP;
		  ELSE
			RETURN NEXT row_to_json(r);
		  END IF;
		END IF;
	  END LOOP;

	ELSIF vPublisher = 'log' THEN

	  vUserName := current_username();

	  FOR r IN
	    SELECT *
		  FROM api.event_log
		 WHERE username = vUserName
		   AND datetime >= pDateFrom
		 ORDER BY id
	  LOOP
		IF IsListenerFilter(vPublisher, l.filter, jsonb_build_object('type', r.type, 'code', r.code, 'category', r.category)) THEN
		  RETURN NEXT row_to_json(r);
		END IF;
	  END LOOP;

	ELSIF vPublisher = 'geo' THEN

	  FOR r IN SELECT * FROM api.object_coordinates(pDateFrom) ORDER BY validfromdate
	  LOOP
		IF IsListenerFilter(vPublisher, l.filter, jsonb_build_object('code', r.code, 'object', r.object)) THEN
		  RETURN NEXT row_to_json(r);
		END IF;
	  END LOOP;
	END IF;

  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

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
  pCode			text
) RETURNS       SETOF api.publisher
AS $$
  SELECT * FROM api.publisher WHERE code = pCode;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_publisher ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает наблюдателя.
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_publisher (
  pId           numeric
) RETURNS       SETOF api.publisher
AS $$
  SELECT * FROM api.publisher WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_publisher -----------------------------------------------------------
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
  pSearch		jsonb DEFAULT null,
  pFilter		jsonb DEFAULT null,
  pLimit		integer DEFAULT null,
  pOffSet		integer DEFAULT null,
  pOrderBy		jsonb DEFAULT null
) RETURNS		SETOF api.publisher
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
  pPublisher	numeric,
  pSession		text
) RETURNS       SETOF api.listener
AS $$
  SELECT * FROM api.listener WHERE publisher = pPublisher AND session = pSession
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_listener ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.add_listener (
  pPublisher	numeric,
  pSession		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		void
AS $$
BEGIN
  PERFORM CreateListener(pPublisher, pSession, pFilter, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_listener ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.update_listener (
  pPublisher	numeric,
  pSession		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		boolean
AS $$
BEGIN
  RETURN EditListener(pPublisher, pSession, pFilter, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_listener ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_listener (
  pPublisher	numeric,
  pSession		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS       SETOF api.listener
AS $$
BEGIN
  IF NOT api.update_listener(pPublisher, pSession, pFilter, pParams) THEN
    PERFORM api.add_listener(pPublisher, pSession, pFilter, pParams);
  END IF;

  RETURN QUERY SELECT * FROM api.get_listener(pPublisher, pSession);
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
  pPublisher	numeric,
  pSession		text
) RETURNS       SETOF api.listener
AS $$
  SELECT * FROM api.listener(pPublisher, pSession);
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
  pCode			text,
  pSession		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		SETOF api.listener
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.set_listener(GetPublisher(pCode), coalesce(pSession, current_session()), pFilter, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.unsubscribe_observer ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.unsubscribe_observer (
  pCode			text,
  pSession		text
) RETURNS		void
AS $$
BEGIN
  PERFORM DeleteListener(GetPublisher(pCode), coalesce(pSession, current_session()));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
