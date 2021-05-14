--------------------------------------------------------------------------------
-- API WORKFLOW ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ESSENCE ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Сущность
 */
CREATE OR REPLACE VIEW api.entity
AS
  SELECT * FROM Entity;

GRANT SELECT ON api.entity TO administrator;

--------------------------------------------------------------------------------
-- api.get_entity -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает сущность.
 * @return {SETOF api.entity} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_entity (
  pId         uuid
) RETURNS     SETOF api.entity
AS $$
  SELECT * FROM api.entity WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_entity ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список сощностей.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.entity}
 */
CREATE OR REPLACE FUNCTION api.list_entity (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.entity
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'entity', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TYPE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.type
AS
  SELECT * FROM Type;

GRANT SELECT ON api.type TO administrator;

--------------------------------------------------------------------------------
-- api.type --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.type (
  pEntity	uuid
) RETURNS	SETOF api.type
AS $$
  SELECT * FROM api.type WHERE entity = pEntity;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт тип.
 * @param {uuid} pClass - Идентификатор класса
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_type (
  pClass	    uuid,
  pCode		    text,
  pName		    text,
  pDescription  text DEFAULT null
) RETURNS 	    uuid
AS $$
BEGIN
  RETURN AddType(pClass, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_type -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет тип.
 * @param {uuid} pId - Идентификатор типа
 * @param {uuid} pClass - Идентификатор класса
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @out param {uuid} id - Идентификатор типа
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_type (
  pId           uuid,
  pClass        uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM EditType(pId, pClass, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_type ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_type (
  pId           uuid,
  pClass        uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS       SETOF api.type
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_type(pClass, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_type(pId, pClass, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.type WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_type -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет тип.
 * @param {uuid} pId - Идентификатор типа
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_type (
  pId         uuid
) RETURNS     void
AS $$
BEGIN
  PERFORM DeleteType(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип.
 * @return {Type} - Тип
 */
CREATE OR REPLACE FUNCTION api.get_type (
  pId         uuid
) RETURNS     SETOF api.type
AS $$
  SELECT * FROM api.type WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_type_id -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип объекта по коду.
 * @param {text} pCode - Код типа объекта
 * @return {uuid} - Тип объекта
 */
CREATE OR REPLACE FUNCTION api.get_type_id (
  pCode		text
) RETURNS	uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetType(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_type ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список типов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.type}
 */
CREATE OR REPLACE FUNCTION api.list_type (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.type
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'type', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CLASS -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.class
AS
  SELECT *, row_to_json(DecodeClassAccess(id)) as access FROM ClassTree;

GRANT SELECT ON api.class TO administrator;

--------------------------------------------------------------------------------
-- api.add_class ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт класс.
 * @param {uuid} pParent - Идентификатор "родителя"
 * @param {uuid} pEntity - Идентификатор сущности
 * @param {text} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {boolean} pAbstract - Абстрактный (Да/Нет)
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_class (
  pParent       uuid,
  pEntity		uuid,
  pCode         text,
  pLabel        text,
  pAbstract     boolean DEFAULT true
) RETURNS       uuid
AS $$
BEGIN
  RETURN AddClass(pParent, pEntity, pCode, pLabel, pAbstract);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_class ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет класс.
 * @param {uuid} pId - Идентификатор класса
 * @param {uuid} pParent - Идентификатор "родителя"
 * @param {uuid} pEntity - Идентификатор сущности
 * @param {text} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {boolean} pAbstract - Абстрактный (Да/Нет)
 * @out {uuid} id - Идентификатор класса
 * @out param {uuid} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_class (
  pId           uuid,
  pParent       uuid,
  pEntity		uuid,
  pCode         text,
  pLabel        text,
  pAbstract     boolean DEFAULT true
) RETURNS       void
AS $$
BEGIN
  PERFORM EditClass(pId, pParent, pEntity, pCode, pLabel, pAbstract);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_class ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_class (
  pId           uuid,
  pParent       uuid,
  pEntity		uuid,
  pCode         text,
  pLabel        text,
  pAbstract     boolean DEFAULT true
) RETURNS       SETOF api.class
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_class(pParent, pEntity, pCode, pLabel, pAbstract);
  ELSE
    PERFORM api.update_class(pId, pParent, pEntity, pCode, pLabel, pAbstract);
  END IF;

  RETURN QUERY SELECT * FROM api.class WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_class ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет класс.
 * @param {uuid} pId - Идентификатор класса
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_class (
  pId         uuid
) RETURNS     void
AS $$
BEGIN
  PERFORM DeleteClass(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_class ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает класс.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_class (
  pId       uuid
) RETURNS   SETOF api.class
AS $$
  SELECT * FROM api.class WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_class --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список классов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.class}
 */
CREATE OR REPLACE FUNCTION api.list_class (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.class
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'class', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.decode_class_access -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Расшифровка маски прав доступа для класса.
 * @return {SETOF record} - Запись
 */
CREATE OR REPLACE FUNCTION api.decode_class_access (
  pId       uuid,
  pUserId	uuid default current_userid(),
  OUT a		boolean,
  OUT c		boolean,
  OUT s		boolean,
  OUT u		boolean,
  OUT d		boolean
) RETURNS 	record
AS $$
  SELECT * FROM DecodeClassAccess(pId, pUserId);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW api.class_access -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.class_access
AS
  SELECT * FROM ClassMembers;

GRANT SELECT ON api.class_access TO administrator;

--------------------------------------------------------------------------------
-- api.class_access ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает участников и права доступа для класса.
 * @return {SETOF api.class_access} - Запись
 */
CREATE OR REPLACE FUNCTION api.class_access (
  pId       uuid
) RETURNS 	SETOF api.class_access
AS $$
  SELECT * FROM api.class_access WHERE class = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_class_access -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список участников и права доступа для класса.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.class_access}
 */
CREATE OR REPLACE FUNCTION api.list_class_access (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.class_access
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'class_access', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- STATE -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.state_type
AS
  SELECT * FROM StateType;

GRANT SELECT ON api.state_type TO administrator;

--------------------------------------------------------------------------------
-- api.get_state_type ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип состояния.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_state_type (
  pId		uuid
) RETURNS	SETOF api.state_type
AS $$
  SELECT * FROM api.state_type WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.state
AS
  SELECT * FROM State;

GRANT SELECT ON api.state TO administrator;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.state (
  pClass	uuid
) RETURNS	SETOF api.state
AS $$
  SELECT * FROM api.state WHERE class = pClass
  UNION ALL
  SELECT *
    FROM api.state
   WHERE id = GetState(pClass, code)
     AND id NOT IN (SELECT id FROM api.state WHERE class = pClass)
   ORDER BY sequence
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_state ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт состояние.
 * @param {uuid} pClass - Идентификатор класса
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {integer} pSequence - Очередность
 * @out param {uuid} id - Идентификатор состояния
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_state (
  pClass      uuid,
  pType       uuid,
  pCode       text,
  pLabel      text,
  pSequence   integer
) RETURNS     uuid
AS $$
BEGIN
  RETURN AddState(pClass, pType, pCode, pLabel, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_state ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет состояние.
 * @param {uuid} pId - Идентификатор состояния
 * @param {uuid} pClass - Идентификатор класса
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {integer} pSequence - Очередность
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_state (
  pId         uuid,
  pClass      uuid DEFAULT null,
  pType       uuid DEFAULT null,
  pCode       text DEFAULT null,
  pLabel      text DEFAULT null,
  pSequence   integer DEFAULT null
) RETURNS     void
AS $$
BEGIN
  PERFORM EditState(pId, pClass, pType, pCode, pLabel, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_state ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_state (
  pId           uuid,
  pClass        uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pCode         text DEFAULT null,
  pLabel        text DEFAULT null,
  pSequence     integer DEFAULT null
) RETURNS       SETOF api.state
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_state(pClass, pType, pCode, pLabel, pSequence);
  ELSE
    PERFORM api.update_state(pId, pClass, pType, pCode, pLabel, pSequence);
  END IF;

  RETURN QUERY SELECT * FROM api.state WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_state ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет состояние.
 * @param {uuid} pId - Идентификатор состояния
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_state (
  pId         uuid
) RETURNS     void
AS $$
BEGIN
  PERFORM DeleteState(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_state ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает состояние.
 * @param {uuid} pId - Идентификатор состояния
 * @return {SETOF api.state} - Состояние
 */
CREATE OR REPLACE FUNCTION api.get_state (
  pId       uuid
) RETURNS   SETOF api.state
AS $$
  SELECT * FROM api.state WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_state --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список состояний.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.state}
 */
CREATE OR REPLACE FUNCTION api.list_state (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.state
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'state', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ACTION ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.action
AS
  SELECT * FROM Action;

GRANT SELECT ON api.action TO administrator;

--------------------------------------------------------------------------------
-- api.get_action --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает действие.
 * @param {uuid} pId - Идентификатор действия
 * @return {SETOF api.action} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_action (
  pId         uuid
) RETURNS     SETOF api.action
AS $$
  SELECT * FROM api.action WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_action -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список действий.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.action}
 */
CREATE OR REPLACE FUNCTION api.list_action (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.action
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'action', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- METHOD ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.method
AS
  SELECT * FROM Method;

GRANT SELECT ON api.method TO administrator;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.method (
  pClass      uuid,
  pState      uuid DEFAULT null
) RETURNS     SETOF api.method
AS $$
  SELECT * FROM api.method WHERE class = pClass AND state IS NOT DISTINCT FROM pState
   UNION ALL
  SELECT *
    FROM api.method
   WHERE id = GetMethod(pClass, action, pState)
     AND id NOT IN (SELECT id FROM api.method WHERE class = pClass AND state IS NOT DISTINCT FROM pState)
   ORDER BY statecode, sequence
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_method --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт метод (операцию).
 * @param {uuid} pParent - Идентификатор родителя (для создания вложенных методов, для построения меню)
 * @param {uuid} pClass - Идентификатор класса: api.class
 * @param {uuid} pState - Идентификатор состояния: api.state
 * @param {uuid} pAction - Идентификатор действия: api.action
 * @param {text} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {integer} pSequence - Очередность
 * @param {boolean} pVisible - Видимый: Да/Нет
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_method (
  pParent       uuid,
  pClass        uuid,
  pState        uuid,
  pAction       uuid,
  pCode         text,
  pLabel        text,
  pSequence     integer,
  pVisible      boolean
) RETURNS       uuid
AS $$
BEGIN
  RETURN AddMethod(pParent, pClass, pState, pAction, pCode, pLabel, pSequence, pVisible);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_method -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет метод (операцию).
 * @param {uuid} pId - Идентификатор метода
 * @param {uuid} pParent - Идентификатор родителя (для создания вложенных методов, для построения меню)
 * @param {uuid} pClass - Идентификатор класса: api.class
 * @param {uuid} pState - Идентификатор состояния: api.state
 * @param {uuid} pAction - Идентификатор действия: api.action
 * @param {text} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {integer} pSequence - Очередность
 * @param {boolean} pVisible - Видимый: Да/Нет
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_method (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pClass        uuid DEFAULT null,
  pState        uuid DEFAULT null,
  pAction       uuid DEFAULT null,
  pCode         text DEFAULT null,
  pLabel        text DEFAULT null,
  pSequence     integer DEFAULT null,
  pVisible      boolean DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM EditMethod(pId, pParent, pClass, pState, pAction, pCode, pLabel, pSequence, pVisible);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_method --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_method (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pClass        uuid DEFAULT null,
  pState        uuid DEFAULT null,
  pAction       uuid DEFAULT null,
  pCode         text DEFAULT null,
  pLabel        text DEFAULT null,
  pSequence     integer DEFAULT null,
  pVisible      boolean DEFAULT null
) RETURNS       SETOF api.method
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_method(pParent, pClass, pState, pAction, pCode, pLabel, pSequence, pVisible);
  ELSE
    PERFORM api.update_method(pId, pParent, pClass, pState, pAction, pCode, pLabel, pSequence, pVisible);
  END IF;

  RETURN QUERY SELECT * FROM api.method WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_method -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет метод (операцию).
 * @param {uuid} pId - Идентификатор метода
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_method (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM DeleteMethod(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_method --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает метод.
 * @param {uuid} pId - Идентификатор метода
 * @return {record} - метод
 */
CREATE OR REPLACE FUNCTION api.get_method (
  pId       uuid
) RETURNS   SETOF api.method
AS $$
  SELECT * FROM api.method WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_method -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список методов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.method}
 */
CREATE OR REPLACE FUNCTION api.list_method (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.method
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'method', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_methods -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает методы объекта.
 * @param {uuid} pClass - Идентификатор класса
 * @param {uuid} pState - Идентификатор состояния
 * @param {uuid} pAction - Идентификатор действия
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_methods (
  pClass        uuid,
  pState        uuid,
  pAction       uuid DEFAULT null
) RETURNS       SETOF api.method
AS $$
  SELECT *
    FROM api.method m
   WHERE m.class = pClass
     AND m.state = coalesce(pState, m.state)
     AND m.action = coalesce(pAction, m.action)
   ORDER BY m.sequence
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_methods_json --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_methods_json (
  pClass        uuid,
  pState        uuid
) RETURNS       json
AS $$
DECLARE
  arResult      json[];
  r             record;
BEGIN
  FOR r IN SELECT * FROM api.get_methods(pClass, pState)
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_methods_jsonb -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_methods_jsonb (
  pClass        uuid,
  pState        uuid
) RETURNS       jsonb
AS $$
BEGIN
  RETURN api.get_methods_json(pClass, pState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.decode_method_access ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Расшифровка маски прав доступа для метода.
 * @return {SETOF record} - Запись
 */
CREATE OR REPLACE FUNCTION api.decode_method_access (
  pId       uuid,
  pUserId	uuid default current_userid(),
  OUT x		boolean,
  OUT v		boolean,
  OUT e		boolean
) RETURNS 	record
AS $$
  SELECT * FROM DecodeMethodAccess(pId, pUserId);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW api.method_access ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.method_access
AS
  SELECT * FROM MethodMembers;

GRANT SELECT ON api.method_access TO administrator;

--------------------------------------------------------------------------------
-- api.method_access -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает участников и права доступа для метода.
 * @return {SETOF api.method_access} - Запись
 */
CREATE OR REPLACE FUNCTION api.method_access (
  pId       uuid
) RETURNS 	SETOF api.method_access
AS $$
  SELECT * FROM api.method_access WHERE method = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_method_access ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список участников и права доступа для метода.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.method_access}
 */
CREATE OR REPLACE FUNCTION api.list_method_access (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.method_access
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'method_access', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TRANSITION ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.transition
AS
  SELECT * FROM Transition;

GRANT SELECT ON api.transition TO administrator;

--------------------------------------------------------------------------------
-- api.add_transition ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт переход в новое состояние.
 * @param {uuid} pState - Идентификатор состояния
 * @param {uuid} pMethod - Идентификатор метода (операции)
 * @param {text} pNewState - Идентификатор нового состояния
 * @out param {uuid} id - Идентификатор перехода
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_transition (
  pState        uuid,
  pMethod       uuid,
  pNewState     uuid
) RETURNS       uuid
AS $$
BEGIN
  RETURN AddTransition(pState, pMethod, pNewState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_transition -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет переход в новое состояние.
 * @param {uuid} pId - Идентификатор перехода
 * @param {uuid} pState - Идентификатор состояния
 * @param {uuid} pMethod - Идентификатор метода (операции)
 * @param {text} pNewState - Идентификатор нового состояния
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_transition (
  pId           uuid,
  pState        uuid DEFAULT null,
  pMethod       uuid DEFAULT null,
  pNewState     uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM EditTransition(pId, pState, pMethod, pNewState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_transition ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_transition (
  pId           uuid,
  pState        uuid DEFAULT null,
  pMethod       uuid DEFAULT null,
  pNewState     uuid DEFAULT null
) RETURNS       SETOF api.transition
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_transition(pState, pMethod, pNewState);
  ELSE
    PERFORM api.update_transition(pId, pState, pMethod, pNewState);
  END IF;

  RETURN QUERY SELECT * FROM api.transition WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_transition -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет переход в новое состояние.
 * @param {uuid} pId - Идентификатор перехода
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_transition (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM DeleteTransition(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_transition ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает переход в новое состояние.
 * @return {SETOF api.transition} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_transition (
  pId       uuid
) RETURNS   SETOF api.transition
AS $$
  SELECT * FROM api.transition WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_transition ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список переходов в новое состояние.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.transition}
 */
CREATE OR REPLACE FUNCTION api.list_transition (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.transition
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'transition', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EVENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.event_type
AS
  SELECT * FROM EventType;

GRANT SELECT ON api.event_type TO administrator;

--------------------------------------------------------------------------------
-- api.get_event_type ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип события.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_event_type (
  pId       uuid
) RETURNS   SETOF api.event_type
AS $$
  SELECT * FROM api.event_type WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.event
AS
  SELECT * FROM Event;

GRANT SELECT ON api.event TO administrator;

--------------------------------------------------------------------------------
-- api.add_event ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт событие.
 * @param {uuid} pClass - Идентификатор класса
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pAction - Идентификатор действия
 * @param {text} pLabel - Наименование
 * @param {text} pText - PL/pgSQL Код
 * @param {integer} pSequence - Очередность
 * @param {boolean} pEnabled - Включен: Да/Нет
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_event (
  pClass        uuid,
  pType         uuid,
  pAction       uuid,
  pLabel        text,
  pText         text,
  pSequence     integer,
  pEnabled      boolean
) RETURNS       uuid
AS $$
BEGIN
  RETURN AddEvent(pClass, pType, pAction, pLabel, pText, pSequence, pEnabled);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_event ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет событие.
 * @param {uuid} pId - Идентификатор события
 * @param {uuid} pClass - Идентификатор класса
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pAction - Идентификатор действия
 * @param {text} pLabel - Наименование
 * @param {text} pText - PL/pgSQL Код
 * @param {integer} pSequence - Очередность
 * @param {boolean} pEnabled - Включен: Да/Нет
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_event (
  pId           uuid,
  pClass        uuid default null,
  pType         uuid default null,
  pAction       uuid default null,
  pLabel        text default null,
  pText         text default null,
  pSequence     integer default null,
  pEnabled      boolean default null
) RETURNS       void
AS $$
BEGIN
  PERFORM EditEvent(pId, pClass, pType, pAction, pLabel, pText, pSequence, pEnabled);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_event ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_event (
  pId           uuid,
  pClass        uuid default null,
  pType         uuid default null,
  pAction       uuid default null,
  pLabel        text default null,
  pText         text default null,
  pSequence     integer default null,
  pEnabled      boolean default null
) RETURNS       SETOF api.event
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_event(pClass, pType, pAction, pLabel, pText, pSequence, pEnabled);
  ELSE
    PERFORM api.update_event(pId, pClass, pType, pAction, pLabel, pText, pSequence, pEnabled);
  END IF;

  RETURN QUERY SELECT * FROM api.event WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_event ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет событие.
 * @param {uuid} pId - Идентификатор события
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_event (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM DeleteEvent(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_event ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает событыие.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_event (
  pId       uuid
) RETURNS   SETOF api.event
AS $$
  SELECT * FROM api.event WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_event --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список событий.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.event}
 */
CREATE OR REPLACE FUNCTION api.list_event (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.event
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'event', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
