--------------------------------------------------------------------------------
-- API WORKFLOW ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ESSENCE ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Workflow entity view.
 * @since 1.0.0
 */
CREATE OR REPLACE VIEW api.entity
AS
  SELECT * FROM Entity;

GRANT SELECT ON api.entity TO administrator;

--------------------------------------------------------------------------------
-- api.get_entity -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a single entity by its identifier.
 * @param {uuid} pId - Entity identifier
 * @return {SETOF api.entity} - Entity record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_entity (
  pId       uuid
) RETURNS   SETOF api.entity
AS $$
  SELECT * FROM api.entity WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_entity -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count entity records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_entity (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'entity', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_entity ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List entities with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions: [{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}]
 * @param {jsonb} pFilter - Column-value filter: {"<col>": "<val>"}
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.entity}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_entity (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.entity
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
/**
 * @brief List object types belonging to a specific entity.
 * @param {uuid} pEntity - Entity identifier to filter by
 * @return {SETOF api.type} - Matching type records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.type (
  pEntity    uuid
) RETURNS    SETOF api.type
AS $$
  SELECT * FROM api.type WHERE entity = pEntity;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new object type under a class.
 * @param {uuid} pClass - Class this type belongs to
 * @param {text} pCode - Unique type code
 * @param {text} pName - Display name
 * @param {text} pDescription - Description (optional)
 * @return {uuid} - Identifier of the newly created type
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_type (
  pClass        uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       uuid
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
 * @brief Update an existing object type.
 * @param {uuid} pId - Type identifier
 * @param {uuid} pClass - New class (NULL keeps existing)
 * @param {text} pCode - New code (NULL keeps existing)
 * @param {text} pName - New display name (NULL keeps existing)
 * @param {text} pDescription - New description (NULL keeps existing)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_type (
  pId           uuid,
  pClass        uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
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
/**
 * @brief Upsert an object type: create if pId is NULL, update otherwise.
 * @param {uuid} pId - Type identifier (NULL to create)
 * @param {uuid} pClass - Class this type belongs to
 * @param {text} pCode - Type code
 * @param {text} pName - Display name
 * @param {text} pDescription - Description (optional)
 * @return {SETOF api.type} - The created or updated type record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_type (
  pId           uuid,
  pClass        uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
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
 * @brief Delete an object type by its identifier.
 * @param {uuid} pId - Type identifier
 * @return {void}
 * @since 1.0.0
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
 * @brief Fetch a single object type by its identifier.
 * @param {uuid} pId - Type identifier
 * @return {SETOF api.type} - Type record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_type (
  pId       uuid
) RETURNS   SETOF api.type
AS $$
  SELECT * FROM api.type WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_type_id -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve an object type identifier from a code or UUID string.
 * @param {text} pCode - Type code or UUID string
 * @return {uuid} - Resolved type identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_type_id (
  pCode     text
) RETURNS   uuid
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
-- api.count_type --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count type records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_type (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'type', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_type ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List object types with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Column-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.type}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_type (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.type
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
-- FUNCTION ClassTree ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List classes in the hierarchy starting from a given parent.
 * @param {uuid} pParent - Parent class identifier (root if NULL)
 * @return {SETOF api.class} - Class tree records with decoded access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.class (
  pParent   uuid
) RETURNS   SETOF api.class
AS $$
  SELECT *, row_to_json(DecodeClassAccess(id)) as access FROM ClassTree(pParent);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_class ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new class in the hierarchy.
 * @param {uuid} pParent - Parent class (NULL for root)
 * @param {uuid} pEntity - Entity this class belongs to
 * @param {text} pCode - Unique class code
 * @param {text} pLabel - Display label
 * @param {boolean} pAbstract - Whether the class is abstract
 * @return {uuid} - Identifier of the newly created class
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_class (
  pParent       uuid,
  pEntity       uuid,
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
 * @brief Update an existing class.
 * @param {uuid} pId - Class identifier
 * @param {uuid} pParent - New parent class
 * @param {uuid} pEntity - New entity
 * @param {text} pCode - New code
 * @param {text} pLabel - New label
 * @param {boolean} pAbstract - Whether the class is abstract
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_class (
  pId           uuid,
  pParent       uuid,
  pEntity       uuid,
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
/**
 * @brief Upsert a class: create if pId is NULL, update otherwise.
 * @param {uuid} pId - Class identifier (NULL to create)
 * @param {uuid} pParent - Parent class
 * @param {uuid} pEntity - Entity
 * @param {text} pCode - Class code
 * @param {text} pLabel - Display label
 * @param {boolean} pAbstract - Whether the class is abstract
 * @return {SETOF api.class} - The created or updated class record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_class (
  pId           uuid,
  pParent       uuid,
  pEntity       uuid,
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
-- api.copy_class --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Copy all workflow definitions (events, states, methods, transitions) between classes.
 * @param {uuid} pSource - Source class to copy from
 * @param {uuid} pDestination - Destination class to copy into
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.copy_class (
  pSource       uuid,
  pDestination  uuid
) RETURNS       void
AS $$
BEGIN
  PERFORM CopyClass(pSource, pDestination);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.clone_class -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new child class by cloning workflow definitions from the parent.
 * @param {uuid} pParent - Parent class to clone from
 * @param {uuid} pEntity - Entity for the new class
 * @param {text} pCode - Code for the new class
 * @param {text} pLabel - Label for the new class
 * @param {boolean} pAbstract - Whether the new class is abstract
 * @return {SETOF api.class} - The newly created class record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.clone_class (
  pParent   uuid,
  pEntity   uuid,
  pCode     text,
  pLabel    text,
  pAbstract boolean DEFAULT false
) RETURNS   SETOF api.class
AS $$
DECLARE
  uId       uuid;
BEGIN
  uId := CloneClass(pParent, pEntity, pCode, pLabel, pAbstract);
  RETURN QUERY SELECT * FROM api.class WHERE id = uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_class ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a class and cascade-remove its workflow definitions.
 * @param {uuid} pId - Class identifier
 * @return {void}
 * @since 1.0.0
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
 * @brief Fetch a single class by its identifier.
 * @param {uuid} pId - Class identifier
 * @return {SETOF api.class} - Class record
 * @since 1.0.0
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
-- api.count_class -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count class records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_class (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'class', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_class --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List classes with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Column-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.class}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_class (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.class
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
 * @brief Decode the ACU bitmask into boolean flags for a class and user.
 * @param {uuid} pId - Class identifier
 * @param {uuid} pUserId - User (defaults to current session user)
 * @return {record} - (a=access, c=create, s=select, u=update, d=delete)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.decode_class_access (
  pId       uuid,
  pUserId   uuid default current_userid(),
  OUT a     boolean,
  OUT c     boolean,
  OUT s     boolean,
  OUT u     boolean,
  OUT d     boolean
) RETURNS   record
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
 * @brief List users/groups and their access rights for a specific class.
 * @param {uuid} pId - Class identifier
 * @return {SETOF api.class_access} - Members with permission bits
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.class_access (
  pId       uuid
) RETURNS   SETOF api.class_access
AS $$
  SELECT * FROM api.class_access WHERE class = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_class_access ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count class_access records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_class_access (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'class_access', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_class_access -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List class access entries with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Column-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.class_access}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_class_access (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.class_access
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
 * @brief Fetch a single state type by its identifier.
 * @param {uuid} pId - State type identifier
 * @return {SETOF api.state_type} - State type record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_state_type (
  pId       uuid
) RETURNS   SETOF api.state_type
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
/**
 * @brief List states for a class, including inherited states from the class hierarchy.
 * @param {uuid} pClass - Class identifier
 * @return {SETOF api.state} - State records ordered by sequence
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.state (
  pClass    uuid
) RETURNS   SETOF api.state
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
/**
 * @brief List states for all classes that define a given object type.
 * @param {uuid} pType - Object type identifier
 * @return {SETOF api.state} - State records ordered by type and sequence
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.state_by_type (
  pType     uuid
) RETURNS   SETOF api.state
AS $$
  SELECT * FROM api.state WHERE class IN (SELECT class FROM Type WHERE id = pType) ORDER BY type, sequence;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_state ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new state for a class.
 * @param {uuid} pClass - Class this state belongs to
 * @param {uuid} pType - State type (created, enabled, etc.)
 * @param {text} pCode - Unique state code
 * @param {text} pLabel - Display label
 * @param {integer} pSequence - Display order
 * @return {uuid} - Identifier of the newly created state
 * @since 1.0.0
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
 * @brief Update an existing state.
 * @param {uuid} pId - State identifier
 * @param {uuid} pClass - New class (NULL keeps existing)
 * @param {uuid} pType - New state type (NULL keeps existing)
 * @param {text} pCode - New code (NULL keeps existing)
 * @param {text} pLabel - New label (NULL keeps existing)
 * @param {integer} pSequence - New display order (NULL keeps existing)
 * @return {void}
 * @since 1.0.0
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
/**
 * @brief Upsert a state: create if pId is NULL, update otherwise.
 * @param {uuid} pId - State identifier (NULL to create)
 * @param {uuid} pClass - Class this state belongs to
 * @param {uuid} pType - State type
 * @param {text} pCode - State code
 * @param {text} pLabel - Display label
 * @param {integer} pSequence - Display order
 * @return {SETOF api.state} - The created or updated state record
 * @since 1.0.0
 */
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
 * @brief Delete a state and its dependent transitions and methods.
 * @param {uuid} pId - State identifier
 * @return {void}
 * @since 1.0.0
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
 * @brief Fetch a single state by its identifier.
 * @param {uuid} pId - State identifier
 * @return {SETOF api.state} - State record
 * @since 1.0.0
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
-- api.count_state -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count state records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_state (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'state', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_state --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List states with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Column-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.state}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_state (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.state
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
 * @brief Fetch a single action by its identifier.
 * @param {uuid} pId - Action identifier
 * @return {SETOF api.action} - Action record
 * @since 1.0.0
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
-- api.count_action ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count action records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_action (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'action', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_action -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List actions with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Column-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.action}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_action (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.action
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
  SELECT * FROM AccessMethod;

GRANT SELECT ON api.method TO administrator;

--------------------------------------------------------------------------------
/**
 * @brief List methods for a class and state, including inherited methods from the class hierarchy.
 * @param {uuid} pClass - Class identifier
 * @param {uuid} pState - State to filter by (NULL = stateless methods)
 * @return {SETOF api.method} - Method records ordered by state code and sequence
 * @since 1.0.0
 */
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
     AND id NOT IN (SELECT id FROM db.method WHERE class = pClass AND state IS NOT DISTINCT FROM pState)
   ORDER BY statecode, sequence
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_method --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new method binding a class, state, and action.
 * @param {uuid} pParent - Parent method for nested hierarchy (optional)
 * @param {uuid} pClass - Class this method belongs to
 * @param {uuid} pState - State in which this method is available
 * @param {uuid} pAction - Action this method performs
 * @param {text} pCode - Method code
 * @param {text} pLabel - Display label
 * @param {integer} pSequence - Display order
 * @param {boolean} pVisible - Whether visible in the UI
 * @return {uuid} - Identifier of the newly created method
 * @since 1.0.0
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
 * @brief Update an existing method.
 * @param {uuid} pId - Method identifier
 * @param {uuid} pParent - New parent method (NULL keeps existing)
 * @param {uuid} pClass - New class (NULL keeps existing)
 * @param {uuid} pState - New state (NULL keeps existing)
 * @param {uuid} pAction - New action (NULL keeps existing)
 * @param {text} pCode - New code (NULL keeps existing)
 * @param {text} pLabel - New label (NULL keeps existing)
 * @param {integer} pSequence - New display order (NULL keeps existing)
 * @param {boolean} pVisible - New visibility flag (NULL keeps existing)
 * @return {void}
 * @since 1.0.0
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
/**
 * @brief Upsert a method: create if pId is NULL, update otherwise.
 * @param {uuid} pId - Method identifier (NULL to create)
 * @param {uuid} pParent - Parent method
 * @param {uuid} pClass - Class
 * @param {uuid} pState - State
 * @param {uuid} pAction - Action
 * @param {text} pCode - Method code
 * @param {text} pLabel - Display label
 * @param {integer} pSequence - Display order
 * @param {boolean} pVisible - Visibility flag
 * @return {SETOF api.method} - The created or updated method record
 * @since 1.0.0
 */
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
 * @brief Delete a method by its identifier.
 * @param {uuid} pId - Method identifier
 * @return {void}
 * @since 1.0.0
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
 * @brief Fetch a single method by its identifier.
 * @param {uuid} pId - Method identifier
 * @return {SETOF api.method} - Method record with access flags
 * @since 1.0.0
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
-- api.count_method ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count method records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_method (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'method', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_method -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List methods with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Column-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.method}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_method (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.method
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
 * @brief Fetch methods available for a class in a given state.
 * @param {uuid} pClass - Class identifier
 * @param {uuid} pState - State identifier
 * @param {uuid} pAction - Optional action filter
 * @return {SETOF api.method} - Matching method records ordered by sequence
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_methods (
  pClass        uuid,
  pState        uuid,
  pAction       uuid DEFAULT null
) RETURNS       SETOF api.method
AS $$
  SELECT *
    FROM api.method
   WHERE class = pClass
     AND state = coalesce(pState, state)
     AND action = coalesce(pAction, action)
   ORDER BY sequence
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_methods ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch methods available for a specific object, computing per-object access masks.
 * @param {uuid} pObject - Object identifier
 * @return {SETOF api.method} - Method records with object-level access applied
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_methods (
  pObject       uuid
) RETURNS       SETOF api.method
AS $$
DECLARE
  r             record;

  uClass        uuid;
  uState        uuid;
BEGIN
  SELECT class, state INTO uClass, uState FROM db.object WHERE id = pObject;

  FOR r IN SELECT id FROM db.method WHERE class = uClass AND state = uState
  LOOP
    PERFORM FROM db.oma WHERE object = pObject AND method = r.id AND userid = current_userid();
    IF NOT FOUND THEN
      WITH access AS (
        SELECT method, bit_or(allow) & ~bit_or(deny) AS mask
          FROM db.amu
         WHERE method = r.id
           AND userid IN (SELECT current_userid() UNION SELECT userid FROM db.member_group WHERE member = current_userid())
         GROUP BY method
      ) INSERT INTO db.oma SELECT pObject, method, current_userid(), mask FROM access;
    END IF;
  END LOOP;

  RETURN QUERY
    SELECT m.*
      FROM api.method m INNER JOIN db.oma a ON a.object = pObject AND a.method = m.id AND a.userid = current_userid()
     WHERE m.class = uClass
       AND m.state = uState
     ORDER BY m.sequence;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_methods_json --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch methods for a class and state as a JSON array.
 * @param {uuid} pClass - Class identifier
 * @param {uuid} pState - State identifier
 * @return {json} - JSON array of method records
 * @since 1.0.0
 */
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
/**
 * @brief Fetch methods for a class and state as a JSONB value.
 * @param {uuid} pClass - Class identifier
 * @param {uuid} pState - State identifier
 * @return {jsonb} - JSONB array of method records
 * @since 1.0.0
 */
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
 * @brief Decode the AMU bitmask into boolean flags for a method and user.
 * @param {uuid} pId - Method identifier
 * @param {uuid} pUserId - User (defaults to current session user)
 * @return {record} - (x=execute, v=visible, e=enable)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.decode_method_access (
  pId       uuid,
  pUserId   uuid default current_userid(),
  OUT x     boolean,
  OUT v     boolean,
  OUT e     boolean
) RETURNS   record
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
 * @brief List users/groups and their access rights for a specific method.
 * @param {uuid} pId - Method identifier
 * @return {SETOF api.method_access} - Members with permission bits
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.method_access (
  pId       uuid
) RETURNS   SETOF api.method_access
AS $$
  SELECT * FROM api.method_access WHERE method = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_method_access -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count method_access records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_method_access (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'method_access', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_method_access ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List method access entries with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Column-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.method_access}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_method_access (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.method_access
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
 * @brief Create a new state transition.
 * @param {uuid} pState - Current state (NULL for initial transitions)
 * @param {uuid} pMethod - Method that triggers the transition
 * @param {uuid} pNewState - Target state after the transition
 * @return {uuid} - Identifier of the newly created transition
 * @since 1.0.0
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
 * @brief Update an existing state transition.
 * @param {uuid} pId - Transition identifier
 * @param {uuid} pState - New current state (NULL keeps existing)
 * @param {uuid} pMethod - New method (NULL keeps existing)
 * @param {uuid} pNewState - New target state (NULL keeps existing)
 * @return {void}
 * @since 1.0.0
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
/**
 * @brief Upsert a state transition: create if pId is NULL, update otherwise.
 * @param {uuid} pId - Transition identifier (NULL to create)
 * @param {uuid} pState - Current state
 * @param {uuid} pMethod - Method
 * @param {uuid} pNewState - Target state
 * @return {SETOF api.transition} - The created or updated transition record
 * @since 1.0.0
 */
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
 * @brief Delete a state transition by its identifier.
 * @param {uuid} pId - Transition identifier
 * @return {void}
 * @since 1.0.0
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
 * @brief Fetch a single state transition by its identifier.
 * @param {uuid} pId - Transition identifier
 * @return {SETOF api.transition} - Transition record
 * @since 1.0.0
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
-- api.count_transition --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count transition records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_transition (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'transition', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_transition ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List state transitions with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Column-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.transition}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_transition (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.transition
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
 * @brief Fetch a single event type by its identifier.
 * @param {uuid} pId - Event type identifier
 * @return {SETOF api.event_type} - Event type record
 * @since 1.0.0
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
 * @brief Create a new workflow event handler.
 * @param {uuid} pClass - Class this event is bound to
 * @param {uuid} pType - Event type (before, after, execute)
 * @param {uuid} pAction - Action that triggers this event
 * @param {text} pLabel - Display label
 * @param {text} pText - PL/pgSQL code body
 * @param {integer} pSequence - Execution order
 * @param {boolean} pEnabled - Whether the handler is active
 * @return {uuid} - Identifier of the newly created event
 * @since 1.0.0
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
 * @brief Update an existing workflow event handler.
 * @param {uuid} pId - Event identifier
 * @param {uuid} pClass - New class (NULL keeps existing)
 * @param {uuid} pType - New event type (NULL keeps existing)
 * @param {uuid} pAction - New action (NULL keeps existing)
 * @param {text} pLabel - New label (NULL keeps existing)
 * @param {text} pText - New PL/pgSQL code body (NULL keeps existing)
 * @param {integer} pSequence - New execution order (NULL keeps existing)
 * @param {boolean} pEnabled - New enabled flag (NULL keeps existing)
 * @return {void}
 * @since 1.0.0
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
/**
 * @brief Upsert an event: create if pId is NULL, update otherwise.
 * @param {uuid} pId - Event identifier (NULL to create)
 * @param {uuid} pClass - Class
 * @param {uuid} pType - Event type
 * @param {uuid} pAction - Action
 * @param {text} pLabel - Display label
 * @param {text} pText - PL/pgSQL code body
 * @param {integer} pSequence - Execution order
 * @param {boolean} pEnabled - Whether active
 * @return {SETOF api.event} - The created or updated event record
 * @since 1.0.0
 */
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
 * @brief Delete a workflow event by its identifier.
 * @param {uuid} pId - Event identifier
 * @return {void}
 * @since 1.0.0
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
 * @brief Fetch a single event by its identifier.
 * @param {uuid} pId - Event identifier
 * @return {SETOF api.event} - Event record
 * @since 1.0.0
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
-- api.count_event -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count event records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_event (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'event', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_event --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List events with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Column-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.event}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_event (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.event
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'event', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PRIORITY --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.priority
AS
  SELECT * FROM Priority;

GRANT SELECT ON api.priority TO administrator;

--------------------------------------------------------------------------------
-- api.get_priority ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a single priority level by its identifier.
 * @param {uuid} pId - Priority identifier
 * @return {SETOF api.priority} - Priority record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_priority (
  pId         uuid
) RETURNS     SETOF api.priority
AS $$
  SELECT * FROM api.priority WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_priority ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count priority records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_priority (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'priority', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_priority -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List priority levels with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Column-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by
 * @return {SETOF api.priority}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_priority (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.priority
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'priority', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
