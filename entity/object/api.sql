--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object
AS
  SELECT * FROM AccessObject;

GRANT SELECT ON api.object TO administrator;

--------------------------------------------------------------------------------
-- api.add_object --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new object.
 * @param {uuid} pParent - Parent object identifier (NULL for root)
 * @param {uuid} pType - Object type identifier
 * @param {text} pLabel - Display label
 * @param {text} pData - Description text
 * @return {uuid} - Newly created object identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_object (
  pParent       uuid,
  pType         uuid,
  pLabel        text default null,
  pData         text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateObject(pParent, pType, pLabel, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_object -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing object's type, parent, and label.
 * @param {uuid} pId - Object identifier
 * @param {uuid} pParent - New parent (NULL preserves existing)
 * @param {uuid} pType - New type (NULL preserves existing)
 * @param {text} pLabel - New label
 * @param {text} pData - New description
 * @return {void}
 * @throws ObjectNotFound - When the object does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_object (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pLabel        text default null,
  pData         text default null
) RETURNS       void
AS $$
DECLARE
  uObject       uuid;
BEGIN
  SELECT t.id INTO uObject FROM db.object t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pId);
  END IF;

  PERFORM EditObject(uObject, pParent, pType, pLabel, pData, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert an object: create if pId is NULL, otherwise update.
 * @param {uuid} pId - Object identifier (NULL = create)
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Object type identifier
 * @param {text} pLabel - Display label
 * @param {text} pData - Description text
 * @return {SETOF api.object} - The created or updated object
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pLabel        text default null,
  pData         text default null
) RETURNS       SETOF api.object
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_object(pParent, pType, pLabel, pData);
  ELSE
    PERFORM api.update_object(pId, pParent, pType, pLabel, pData);
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
 * @brief Fetch a single object by identifier (with access check).
 * @param {uuid} pId - Object identifier
 * @return {SETOF api.object} - Object record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object (
  pId       uuid
) RETURNS   SETOF api.object
AS $$
  SELECT * FROM api.object WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List objects with search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-value filter object
 * @param {integer} pLimit - Maximum number of rows
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.object} - Matching object records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_object (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.object
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_label --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the display label of an object (with access check).
 * @param {uuid} pObject - Object identifier
 * @return {text} - Label text
 * @throws ObjectNotFound - When the object does not exist or is inaccessible
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_label (
  pObject   uuid
) RETURNS   text
AS $$
DECLARE
  uId       uuid;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pObject AND CheckObjectAccess(id, B'100');
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
/**
 * @brief Set the display label of an object for all locales.
 * @param {uuid} pObject - Object identifier
 * @param {text} pLabel - New label text
 * @return {record} - (id, result, message) tuple
 * @throws ObjectNotFound - When the object does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_label (
  pObject       uuid,
  pLabel        text,
  OUT id        uuid,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  uId           uuid;
BEGIN
  id := null;

  SELECT o.id INTO uId FROM db.object o WHERE o.id = pObject;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pObject);
  END IF;

  id := uId;

  PERFORM SetObjectLabel(pObject, pLabel, null);
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
 * @brief Force-delete an object by setting its state to 'deleted' (bypasses workflow).
 * @param {uuid} pId - Object identifier
 * @return {void}
 * @throws ObjectNotFound - When the object does not exist
 * @throws StateByCodeNotFound - When 'deleted' state is not defined for the class
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.object_force_delete (
  pId           uuid
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
  uState        uuid;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pId);
  END IF;

  SELECT s.id INTO uState FROM db.state s WHERE s.class = GetObjectClass(pId) AND s.code = 'deleted';

  IF NOT FOUND THEN
    PERFORM StateByCodeNotFound(pId, 'deleted');
  END IF;

  PERFORM AddObjectState(pId, uState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.decode_object_access ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Decode the access mask for an object into boolean flags (select, update, delete).
 * @param {uuid} pId - Object identifier
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {record} - (s: select, u: update, d: delete) booleans
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.decode_object_access (
  pId       uuid,
  pUserId   uuid DEFAULT null,
  OUT s     boolean,
  OUT u     boolean,
  OUT d     boolean
) RETURNS   record
AS $$
  SELECT * FROM DecodeObjectAccess(pId, coalesce(pUserId, current_userid()));
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
 * @brief List users/groups and their access permissions for a given object.
 * @param {uuid} pId - Object identifier
 * @return {SETOF api.object_access} - Access entries with user details
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.object_access (
  pId       uuid
) RETURNS   SETOF api.object_access
AS $$
  SELECT * FROM api.object_access WHERE object = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT ACTION ---------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.execute_object_action ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a workflow action on an object by action UUID.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pAction - Action identifier
 * @param {jsonb} pParams - Optional JSON parameters
 * @return {jsonb} - Execution result
 * @throws NotFound - When the object does not exist
 * @throws ActionIsEmpty - When pAction is NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.execute_object_action (
  pObject        uuid,
  pAction        uuid,
  pParams        jsonb DEFAULT null
) RETURNS        jsonb
AS $$
BEGIN
  PERFORM FROM db.object WHERE id = pObject;

  IF NOT FOUND THEN
    PERFORM NotFound();
  END IF;

  IF pAction IS NULL THEN
    PERFORM ActionIsEmpty();
  END IF;

  RETURN ExecuteObjectAction(pObject, pAction, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.execute_object_action ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a workflow action on an object by action code string.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Action code (e.g. 'enable', 'delete')
 * @param {jsonb} pParams - Optional JSON parameters
 * @return {jsonb} - Execution result
 * @throws IncorrectCode - When the action code is invalid
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.execute_object_action (
  pObject       uuid,
  pCode         text,
  pParams       jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  arCodes       text[];
  r             record;
BEGIN
  FOR r IN SELECT code FROM db.action
  LOOP
    arCodes := array_append(arCodes, r.code::text);
  END LOOP;

  IF array_position(arCodes, pCode) IS NULL THEN
    PERFORM IncorrectCode(pCode, arCodes);
  END IF;

  RETURN api.execute_object_action(pObject, GetAction(pCode), pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.execute_object_action_try -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a workflow action on an object by UUID, suppressing exceptions.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pAction - Action identifier
 * @param {jsonb} pParams - Optional JSON parameters
 * @return {jsonb} - Execution result or error JSON on failure
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.execute_object_action_try (
  pObject        uuid,
  pAction        uuid,
  pParams        jsonb DEFAULT null
) RETURNS        jsonb
AS $$
DECLARE
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  RETURN api.execute_object_action(pObject, pAction, pParams);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.execute_object_action_try -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a workflow action on an object by code, suppressing exceptions.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Action code
 * @param {jsonb} pParams - Optional JSON parameters
 * @return {jsonb} - Execution result or error JSON on failure
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.execute_object_action_try (
  pObject       uuid,
  pCode         text,
  pParams       jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  RETURN api.execute_object_action(pObject, GetAction(pCode), pParams);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage);
  PERFORM WriteToEventLog('D', ErrorCode, vContext);

  RETURN json_build_object('error', json_build_object('code', coalesce(nullif(ErrorCode, -1), 500), 'message', ErrorMessage));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT METHOD ---------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.execute_method ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a workflow method on an object by method UUID.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pMethod - Method identifier
 * @param {jsonb} pParams - Optional JSON parameters
 * @return {jsonb} - Method execution result
 * @throws ObjectNotFound - When the object does not exist
 * @throws MethodIsEmpty - When pMethod is NULL
 * @throws MethodNotFound - When the method does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.execute_method (
  pObject       uuid,
  pMethod       uuid,
  pParams       jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  uId           uuid;
  uMethod       uuid;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pObject;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pObject);
  END IF;

  IF pMethod IS NULL THEN
    PERFORM MethodIsEmpty();
  END IF;

  SELECT m.id INTO uMethod FROM method m WHERE m.id = pMethod;

  IF NOT FOUND THEN
    PERFORM MethodNotFound(pObject, pMethod);
  END IF;

  RETURN ExecuteMethod(pObject, uMethod, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.execute_method ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a workflow method on an object by method code string.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Method code
 * @param {jsonb} pParams - Optional JSON parameters
 * @return {jsonb} - Method execution result
 * @throws ObjectNotFound - When the object does not exist
 * @throws MethodIsEmpty - When pCode is NULL
 * @throws MethodByCodeNotFound - When the method code is invalid for the class
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.execute_method (
  pObject       uuid,
  pCode         text,
  pParams       jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  uId           uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pObject;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pObject);
  END IF;

  IF pCode IS NULL THEN
    PERFORM MethodIsEmpty();
  END IF;

  uClass := GetObjectClass(pObject);

  SELECT m.id INTO uMethod FROM db.method m WHERE m.class = uClass AND m.code = pCode;

  IF NOT FOUND THEN
    PERFORM MethodByCodeNotFound(pObject, pCode);
  END IF;

  RETURN ExecuteMethod(pObject, uMethod, pParams);
END;
$$ LANGUAGE plpgsql
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
 * @brief Create a named object group for the current user.
 * @param {text} pCode - Unique group code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {uuid} - Newly created group identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_object_group (
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       uuid
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
 * @brief Update an existing object group's attributes.
 * @param {uuid} pId - Group identifier
 * @param {text} pCode - New code (NULL preserves existing)
 * @param {text} pName - New name (NULL preserves existing)
 * @param {text} pDescription - New description (NULL preserves existing)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_object_group (
  pId               uuid,
  pCode             text DEFAULT null,
  pName             text DEFAULT null,
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
/**
 * @brief Upsert an object group: create if pId is NULL, otherwise update.
 * @param {uuid} pId - Group identifier (NULL = create)
 * @param {text} pCode - Group code
 * @param {text} pName - Display name
 * @param {text} pDescription - Description
 * @return {SETOF api.object_group} - The created or updated group
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_group (
  pId               uuid,
  pCode             text DEFAULT null,
  pName             text DEFAULT null,
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
 * @brief Fetch a single object group by identifier.
 * @param {uuid} pId - Group identifier
 * @return {SETOF api.object_group} - Group record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_group (
  pId       uuid
) RETURNS   SETOF api.object_group
AS $$
  SELECT * FROM api.object_group WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_group -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List object groups with search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-value filter object
 * @param {integer} pLimit - Maximum number of rows
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.object_group} - Matching group records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_object_group (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.object_group
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
 * @brief Add an object to a group (requires select access).
 * @param {uuid} pGroup - Group identifier
 * @param {uuid} pObject - Object identifier
 * @return {void}
 * @throws AccessDenied - When the user lacks select access to the object
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_object_to_group (
  pGroup    uuid,
  pObject   uuid
) RETURNS   void
AS $$
BEGIN
  IF NOT CheckObjectAccess(pObject, B'100') THEN
    PERFORM AccessDenied();
  END IF;

  PERFORM AddObjectToGroup(pGroup, pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_object_from_group ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Remove an object from a group (requires select access).
 * @param {uuid} pGroup - Group identifier
 * @param {uuid} pObject - Object identifier
 * @return {void}
 * @throws AccessDenied - When the user lacks select access to the object
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_object_from_group (
  pGroup    uuid,
  pObject   uuid DEFAULT null
) RETURNS   void
AS $$
BEGIN
  IF NOT CheckObjectAccess(pObject, B'100') THEN
    PERFORM AccessDenied();
  END IF;

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
 * @brief List all objects in a group as full object records.
 * @param {uuid} pGroupId - Group identifier
 * @return {SETOF api.object} - Objects belonging to the group
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.object_group_member (
  pGroupId      uuid
) RETURNS       SETOF api.object
AS $$
  SELECT o.*
    FROM api.object_group_member g INNER JOIN api.object o ON o.id = g.object
   WHERE g.gid = pGroupId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT LINK -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_link -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_link
AS
  SELECT l.id, l.object AS objectId, row_to_json(oo) AS object, l.linked AS linkedId, row_to_json(ol) AS linked,
         l.key, l.validfromdate, l.validtodate
    FROM db.object_link l INNER JOIN AccessObject oo ON l.object = oo.id
                          INNER JOIN Object       ol ON l.linked = ol.id
   WHERE l.validfromdate <= oper_date()
     AND l.validtodate > oper_date();

GRANT SELECT ON api.object_link TO administrator;

--------------------------------------------------------------------------------
-- api.set_object_link ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a temporal link between two objects.
 * @param {uuid} pObject - Source object identifier
 * @param {uuid} pLinked - Target object identifier
 * @param {text} pKey - Relationship key
 * @param {timestamptz} pDateFrom - Effective date
 * @return {SETOF api.object_link} - The created or updated link record
 * @throws AccessDenied - When the user lacks update access to the source object
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_link (
  pObject     uuid,
  pLinked     uuid,
  pKey        text DEFAULT null,
  pDateFrom   timestamptz DEFAULT null
) RETURNS     SETOF api.object_link
AS $$
DECLARE
  uId         uuid;
BEGIN
  IF NOT CheckObjectAccess(pObject, B'010') THEN
    PERFORM AccessDenied();
  END IF;

  uId := SetObjectLink(pObject, pLinked, coalesce(pKey, pLinked::text), coalesce(pDateFrom, oper_date()));

  RETURN QUERY SELECT * FROM api.get_object_link(uId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_link ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a single object link by identifier.
 * @param {uuid} pId - Link record identifier
 * @return {SETOF api.object_link} - Link record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_link (
  pId       uuid
) RETURNS   SETOF api.object_link
AS $$
  SELECT * FROM api.object_link WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_link --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List object links with search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-value filter object
 * @param {integer} pLimit - Maximum number of rows
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.object_link} - Matching link records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_object_link (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.object_link
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_link', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
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
  SELECT f.* FROM ObjectFile f INNER JOIN AccessObject o ON f.object = o.id;

GRANT SELECT ON api.object_file TO administrator;

--------------------------------------------------------------------------------
-- api.object_file_data --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_file_data
AS
  SELECT * FROM ObjectFileData;

GRANT SELECT ON api.object_file_data TO administrator;

--------------------------------------------------------------------------------
-- api.set_object_file ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a file attachment for an object (base64-encoded data).
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pFile - File identifier (NULL to create)
 * @param {text} pName - File name
 * @param {text} pPath - File path
 * @param {integer} pSize - File size in bytes
 * @param {timestamptz} pDate - File date
 * @param {text} pData - Base64-encoded file content
 * @param {text} pHash - SHA-256 hash
 * @param {text} pText - Text content
 * @param {text} pType - MIME type
 * @return {SETOF api.object_file} - The attached file record
 * @throws AccessDenied - When the user lacks update access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_file (
  pObject   uuid,
  pFile     uuid,
  pName     text,
  pPath     text,
  pSize     integer,
  pDate     timestamptz,
  pData     text DEFAULT null,
  pHash     text DEFAULT null,
  pText     text DEFAULT null,
  pType     text DEFAULT null
) RETURNS   SETOF api.object_file
AS $$
BEGIN
  IF NOT CheckObjectAccess(pObject, B'010') THEN
    PERFORM AccessDenied();
  END IF;

  pFile := SetObjectFile(pObject, pFile, pName, pPath, pSize, pDate, decode(pData, 'base64'), pHash, pText, pType);

  RETURN QUERY SELECT * FROM api.object_file WHERE object = pObject AND file = pFile;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_files_json ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Batch upsert file attachments from a JSON array.
 * @param {uuid} pId - Object identifier
 * @param {json} pFiles - JSON array of file records
 * @return {SETOF api.object_file} - Attached file records
 * @throws ObjectNotFound - When the object does not exist
 * @throws JsonIsEmpty - When pFiles is NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_files_json (
  pId       uuid,
  pFiles    json
) RETURNS   SETOF api.object_file
AS $$
DECLARE
  r         record;
  arKeys    text[];
BEGIN
  PERFORM FROM db.object o WHERE o.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pId);
  END IF;

  IF pFiles IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['file', 'name', 'path', 'size', 'date', 'data', 'hash', 'text', 'type']);
    PERFORM CheckJsonKeys('/object/file/files', arKeys, pFiles);

    FOR r IN SELECT * FROM json_to_recordset(pFiles) AS files(file uuid, name text, path text, size int, date timestamptz, data text, hash text, text text, type text)
    LOOP
      RETURN NEXT api.set_object_file(pId, r.file, NULLIF(Trim(r.name), ''), NULLIF(Trim(r.path), ''), r.size, r.date, r.data, NULLIF(Trim(r.hash), ''), NULLIF(Trim(r.text), ''), NULLIF(Trim(r.type), ''));
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
/**
 * @brief Batch upsert file attachments from a JSONB array.
 * @param {uuid} pId - Object identifier
 * @param {jsonb} pFiles - JSONB array of file records
 * @return {SETOF api.object_file} - Attached file records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_files_jsonb (
  pId           uuid,
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
/**
 * @brief Fetch all file attachments for an object as JSON (with access check).
 * @param {uuid} pId - Object identifier
 * @return {json} - JSON array of file records
 * @throws AccessDenied - When the user lacks select access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_files_json (
  pId        uuid
) RETURNS    json
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
    PERFORM AccessDenied();
  END IF;

  RETURN GetObjectFilesJson(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_files_jsonb --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all file attachments for an object as JSONB (with access check).
 * @param {uuid} pId - Object identifier
 * @return {jsonb} - JSONB array of file records
 * @throws AccessDenied - When the user lacks select access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_files_jsonb (
  pId        uuid
) RETURNS    jsonb
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
    PERFORM AccessDenied();
  END IF;

  RETURN GetObjectFilesJsonb(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_file ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a specific file with binary data for an object.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pFile - File identifier (NULL to resolve by path+name)
 * @param {text} pName - File name
 * @param {text} pPath - File path
 * @return {SETOF api.object_file_data} - File record with base64-encoded data
 * @throws AccessDenied - When the user lacks select access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_file (
  pObject   uuid,
  pFile     uuid,
  pName     text,
  pPath     text default null
) RETURNS   SETOF api.object_file_data
AS $$
DECLARE
  vClass    text;
BEGIN
  IF NOT CheckObjectAccess(pObject, B'100') THEN
    PERFORM AccessDenied();
  END IF;

  IF pFile IS NULL THEN
    vClass := GetClassCode(GetObjectClass(pObject));

    IF NULLIF(NULLIF(pPath, ''), '~/') IS NULL THEN
      pPath := concat('/', vClass, '/', pObject, '/');
    END IF;

    pFile := FindFile(concat(pPath, pName));

    IF pFile IS NULL THEN
      pPath := concat('/', vClass, '/', GetObjectParent(pObject), '/');
      pFile := FindFile(concat(pPath, pName));
	END IF;
  END IF;

  RETURN QUERY SELECT * FROM api.object_file_data WHERE object = pObject AND file = pFile;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_object_file ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a file attachment from an object.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pFile - File identifier (NULL to resolve by path+name)
 * @param {text} pName - File name
 * @param {text} pPath - File path
 * @return {boolean} - TRUE if the file was removed
 * @throws AccessDenied - When the user lacks delete access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_object_file (
  pObject   uuid,
  pFile     uuid,
  pName     text,
  pPath     text default null
) RETURNS   boolean
AS $$
BEGIN
  IF NOT CheckObjectAccess(pObject, B'001') THEN
    PERFORM AccessDenied();
  END IF;

  RETURN DeleteObjectFile(pObject, pFile, pName, pPath);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_file --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List object file attachments with search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-value filter object
 * @param {integer} pLimit - Maximum number of rows
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.object_file} - Matching file records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_object_file (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.object_file
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_file', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.clear_object_files ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Remove all file attachments from an object.
 * @param {uuid} pId - Object identifier
 * @return {void}
 * @throws AccessDenied - When the user lacks delete access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.clear_object_files (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'001') THEN
    PERFORM AccessDenied();
  END IF;

  PERFORM ClearObjectFiles(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT DATA -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_data -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_data
AS
  SELECT d.* FROM ObjectData d INNER JOIN AccessObject o ON d.object = o.id;

GRANT SELECT ON api.object_data TO administrator;

--------------------------------------------------------------------------------
-- api.set_object_data ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set a key-value data entry for an object.
 * @param {uuid} pId - Object identifier
 * @param {uuid} pType - Data format (text, json, xml, base64)
 * @param {text} pCode - Data key
 * @param {text} pData - Data value
 * @return {SETOF api.object_data} - Updated data record
 * @throws AccessDenied - When the user lacks update access
 * @throws IncorrectCode - When the data type is invalid
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_data (
  pId           uuid,
  pType         uuid,
  pCode         text,
  pData         text
) RETURNS       SETOF api.object_data
AS $$
DECLARE
  r             record;
  uType         uuid;
  arTypes       text[];
BEGIN
  IF NOT CheckObjectAccess(pId, B'010') THEN
    PERFORM AccessDenied();
  END IF;

  pType := lower(pType);

  FOR r IN SELECT type FROM db.object_data
  LOOP
    arTypes := array_append(arTypes, r.type);
  END LOOP;

  IF array_position(arTypes, pType) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  PERFORM SetObjectData(pId, pType, pCode, pData);

  RETURN QUERY SELECT * FROM api.get_object_data(pId, uType, pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_data_json ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Batch set key-value data entries from a JSON array.
 * @param {uuid} pId - Object identifier
 * @param {json} pData - JSON array of {type, code, data} records
 * @return {SETOF api.object_data} - Updated data records
 * @throws ObjectNotFound - When the object does not exist
 * @throws JsonIsEmpty - When pData is NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_data_json (
  pId           uuid,
  pData         json
) RETURNS       SETOF api.object_data
AS $$
DECLARE
  uId           uuid;
  arKeys        text[];
  r             record;
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pId);
  END IF;

  IF pData IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['type', 'code', 'data']);
    PERFORM CheckJsonKeys('/object/data', arKeys, pData);

    FOR r IN SELECT * FROM json_to_recordset(pData) AS data(type text, code text, data text)
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
/**
 * @brief Batch set key-value data entries from a JSONB array.
 * @param {uuid} pId - Object identifier
 * @param {jsonb} pData - JSONB array of {type, code, data} records
 * @return {SETOF api.object_data} - Updated data records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_data_jsonb (
  pId       uuid,
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
/**
 * @brief Fetch all key-value data entries for an object as JSON (with access check).
 * @param {uuid} pId - Object identifier
 * @return {json} - JSON array of data records
 * @throws AccessDenied - When the user lacks select access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_data_json (
  pId        uuid
) RETURNS    json
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
    PERFORM AccessDenied();
  END IF;

  RETURN GetObjectDataJson(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_data_jsonb ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all key-value data entries for an object as JSONB (with access check).
 * @param {uuid} pId - Object identifier
 * @return {jsonb} - JSONB array of data records
 * @throws AccessDenied - When the user lacks select access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_data_jsonb (
  pId        uuid
) RETURNS    jsonb
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
    PERFORM AccessDenied();
  END IF;

  RETURN GetObjectDataJsonb(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_data ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a specific key-value data entry for an object.
 * @param {uuid} pId - Object identifier
 * @param {text} pType - Data format
 * @param {text} pCode - Data key
 * @return {SETOF api.object_data} - Matching data record
 * @throws AccessDenied - When the user lacks select access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_data (
  pId        uuid,
  pType      text,
  pCode      text
) RETURNS    SETOF api.object_data
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
    PERFORM AccessDenied();
  END IF;

  RETURN QUERY SELECT * FROM api.object_data WHERE object = pId AND type = pType AND code = pCode;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_data --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List object data entries with search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-value filter object
 * @param {integer} pLimit - Maximum number of rows
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.object_data} - Matching data records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_object_data (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.object_data
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
  SELECT c.* FROM ObjectCoordinates c INNER JOIN AccessObject o ON c.object = o.id;

GRANT SELECT ON api.object_coordinates TO administrator;

--------------------------------------------------------------------------------
-- api.object_coordinates ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List object coordinates valid at a given date.
 * @param {timestamptz} pDateFrom - Point-in-time date
 * @return {SETOF api.object_coordinates} - Coordinate records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.object_coordinates (
  pDateFrom     timestamptz
) RETURNS       SETOF api.object_coordinates
AS $$
  SELECT * FROM ObjectCoordinates(pDateFrom);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_coordinates --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set GPS coordinates for an object (with device enrichment).
 * @param {uuid} pId - Object identifier
 * @param {text} pCode - Coordinate set code (defaults to 'default')
 * @param {numeric} pLatitude - Latitude in decimal degrees
 * @param {numeric} pLongitude - Longitude in decimal degrees
 * @param {numeric} pAccuracy - Accuracy / altitude in meters
 * @param {text} pLabel - Short display label
 * @param {text} pDescription - Optional description
 * @param {jsonb} pData - Additional JSON data (may include device info)
 * @param {timestamptz} pDateFrom - Effective date
 * @return {SETOF api.object_coordinates} - Updated coordinate record
 * @throws AccessDenied - When the user lacks update access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_coordinates (
  pId           uuid,
  pCode         text,
  pLatitude     numeric,
  pLongitude    numeric,
  pAccuracy     numeric DEFAULT 0,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pData         jsonb DEFAULT null,
  pDateFrom     timestamptz DEFAULT Now()
) RETURNS       SETOF api.object_coordinates
AS $$
DECLARE
  r             record;
  device        jsonb;
  sSerial       text;
BEGIN
  IF NOT CheckObjectAccess(pId, B'010') THEN
    PERFORM AccessDenied();
  END IF;

  pCode := coalesce(pCode, 'default');
  pAccuracy := coalesce(pAccuracy, 0);

  device := pData->>'device';
  IF device IS NOT NULL THEN
    sSerial := device->>'serial';
    IF sSerial IS NOT NULL THEN
      SELECT id, identity INTO r FROM db.device WHERE serial = sSerial;
      pData := pData || jsonb_build_object('device', device || jsonb_build_object('id', r.id, 'identity', r.identity));
    END IF;
  END IF;

  PERFORM NewObjectCoordinates(pId, pCode, pLatitude, pLongitude, pAccuracy, pLabel, pDescription, pData, coalesce(pDateFrom, Now()));
  PERFORM SetObjectDataJSON(pId, 'geo', GetObjectCoordinatesJson(pId, pCode));

  RETURN QUERY SELECT * FROM api.get_object_coordinates(pId, pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_coordinates_json ---------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Batch set GPS coordinates from a JSON array.
 * @param {uuid} pId - Object identifier
 * @param {json} pCoordinates - JSON array of coordinate records
 * @return {SETOF api.object_coordinates} - Updated coordinate records
 * @throws ObjectNotFound - When the object does not exist
 * @throws JsonIsEmpty - When pCoordinates is NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_coordinates_json (
  pId           uuid,
  pCoordinates  json
) RETURNS       SETOF api.object_coordinates
AS $$
DECLARE
  r             record;
  uId           uuid;
  arKeys        text[];
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('object', 'id', pId);
  END IF;

  IF pCoordinates IS NOT NULL THEN
    arKeys := array_cat(arKeys, GetRoutines('set_object_coordinates', 'api', false));
    PERFORM CheckJsonKeys('/object/coordinates', arKeys, pCoordinates);

    FOR r IN SELECT * FROM json_to_recordset(pCoordinates) AS x(code text, latitude numeric, longitude numeric, accuracy numeric, label text, description text, data jsonb, datefrom timestamptz)
    LOOP
      RETURN NEXT api.set_object_coordinates(pId, r.code, r.latitude, r.longitude, r.accuracy, r.label, r.description, r.data, r.datefrom);
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
/**
 * @brief Batch set GPS coordinates from a JSONB array.
 * @param {uuid} pId - Object identifier
 * @param {jsonb} pCoordinates - JSONB array of coordinate records
 * @return {SETOF api.object_coordinates} - Updated coordinate records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_object_coordinates_jsonb (
  pId           uuid,
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
/**
 * @brief Fetch all coordinates for an object as JSON (with access check).
 * @param {uuid} pId - Object identifier
 * @return {json} - JSON array of coordinate records
 * @throws AccessDenied - When the user lacks select access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_coordinates_json (
  pId        uuid
) RETURNS    json
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
    PERFORM AccessDenied();
  END IF;

  RETURN GetObjectCoordinatesJson(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_coordinates_jsonb --------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all coordinates for an object as JSONB (with access check).
 * @param {uuid} pId - Object identifier
 * @return {jsonb} - JSONB array of coordinate records
 * @throws AccessDenied - When the user lacks select access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_coordinates_jsonb (
  pId        uuid
) RETURNS    jsonb
AS $$
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
    PERFORM AccessDenied();
  END IF;

  RETURN GetObjectCoordinatesJsonb(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_coordinates --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch coordinates for an object by code and date (with access check).
 * @param {uuid} pId - Object identifier
 * @param {text} pCode - Coordinate set code
 * @param {timestamptz} pDateFrom - Point-in-time date
 * @return {SETOF api.object_coordinates} - Matching coordinate records
 * @throws AccessDenied - When the user lacks select access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_coordinates (
  pId           uuid,
  pCode         text,
  pDateFrom     timestamptz DEFAULT oper_date()
) RETURNS       SETOF api.object_coordinates
AS $$
DECLARE
  r             record;
BEGIN
  IF NOT CheckObjectAccess(pId, B'100') THEN
    PERFORM AccessDenied();
  END IF;

  FOR r IN
    SELECT *
      FROM api.object_coordinates
     WHERE object = pId
       AND code = pCode
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom
  LOOP
    RETURN NEXT r;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_coordinates -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List object coordinates with search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-value filter object
 * @param {integer} pLimit - Maximum number of rows
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.object_coordinates} - Matching coordinate records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_object_coordinates (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.object_coordinates
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_coordinates', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT STATE HISTORY --------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_state_history ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_state_history
AS
  SELECT * FROM ObjectState;

GRANT SELECT ON api.object_state_history TO administrator;

--------------------------------------------------------------------------------
-- api.get_object_state_history ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a single object state history record by identifier.
 * @param {uuid} pId - State history record identifier
 * @return {SETOF api.object_state_history} - State history record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_state_history (
  pId         uuid
) RETURNS     SETOF api.object_state_history
AS $$
  SELECT * FROM api.object_state_history WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_state_history -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List object state history with search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-value filter object
 * @param {integer} pLimit - Maximum number of rows
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.object_state_history} - Matching state history records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_object_state_history (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.object_state_history
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_state_history', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
