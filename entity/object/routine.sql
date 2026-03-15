--------------------------------------------------------------------------------
-- NewObjectText ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a localized text record for an object.
 * @param {uuid} pObject - Object identifier
 * @param {text} pLabel - Short display label
 * @param {text} pText - Extended description
 * @param {uuid} pLocale - Locale (defaults to current session locale)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewObjectText (
  pObject   uuid,
  pLabel    text,
  pText     text,
  pLocale   uuid DEFAULT current_locale()
) RETURNS   void
AS $$
BEGIN
  INSERT INTO db.object_text (object, locale, label, text)
  VALUES (pObject, pLocale, pLabel, pText);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectText --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update localized text for an object, inserting if not found.
 * @param {uuid} pObject - Object identifier
 * @param {text} pLabel - New label (NULL preserves existing)
 * @param {text} pText - New description (NULL preserves existing)
 * @param {uuid} pLocale - Locale to update
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditObjectText (
  pObject       uuid,
  pLabel        text,
  pText         text,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.object_text
     SET label = CheckNull(coalesce(pLabel, label, '')),
         text =  CheckNull(coalesce(pText, text, ''))
   WHERE object = pObject AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewObjectText(pObject, pLabel, pText, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateObject ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new object with localized text in all (or one) locale(s).
 * @param {uuid} pParent - Parent object (NULL for root)
 * @param {uuid} pType - Object type identifier
 * @param {text} pLabel - Display label
 * @param {text} pText - Description text
 * @param {uuid} pLocale - Target locale (NULL = all locales)
 * @return {uuid} - Newly created object identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateObject (
  pParent   uuid,
  pType     uuid,
  pLabel    text DEFAULT null,
  pText     text DEFAULT null,
  pLocale   uuid DEFAULT null
) RETURNS   uuid
AS $$
DECLARE
  l         record;
  uId       uuid;
BEGIN
  INSERT INTO db.object (id, parent, type)
  VALUES (GetVar('object', 'id')::uuid, CheckNull(pParent), pType)
  RETURNING id INTO uId;

  IF pLocale IS NULL THEN
    FOR l IN SELECT id FROM db.locale
    LOOP
      PERFORM NewObjectText(uId, pLabel, pText, l.id);
    END LOOP;
  ELSE
    PERFORM NewObjectText(uId, pLabel, pText, pLocale);
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObject ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing object's type, parent, and localized text.
 * @param {uuid} pId - Object identifier
 * @param {uuid} pParent - New parent (NULL preserves existing)
 * @param {uuid} pType - New type (NULL preserves existing)
 * @param {text} pLabel - New label (NULL preserves existing)
 * @param {text} pText - New description (NULL preserves existing)
 * @param {uuid} pLocale - Target locale (NULL = all locales)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditObject (
  pId       uuid,
  pParent   uuid DEFAULT null,
  pType     uuid DEFAULT null,
  pLabel    text DEFAULT null,
  pText     text DEFAULT null,
  pLocale   uuid DEFAULT null
) RETURNS   void
AS $$
DECLARE
  l         record;
BEGIN
  UPDATE db.object
     SET type = coalesce(pType, type),
         parent = CheckNull(coalesce(pParent, parent, null_uuid()))
   WHERE id = pId;

  IF pLocale IS NULL THEN
    FOR l IN SELECT id FROM db.locale
    LOOP
      PERFORM EditObjectText(pId, pLabel, pText, l.id);
    END LOOP;
  ELSE
    PERFORM EditObjectText(pId, pLabel, pText, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectParent -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Assign a new parent to an object.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pParent - New parent object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetObjectParent (
  pObject   uuid,
  pParent   uuid
) RETURNS   void
AS $$
BEGIN
  UPDATE db.object SET parent = pParent WHERE id = pObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectMembers ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List all users/groups that have access to a given object.
 * @param {uuid} pObject - Object identifier
 * @return {SETOF ObjectMembers} - Access entries with user details
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectMembers (
  pObject   uuid
) RETURNS   SETOF ObjectMembers
AS $$
  SELECT * FROM ObjectMembers WHERE object = pObject;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectEntity -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the entity identifier of an object.
 * @param {uuid} pObject - Object identifier
 * @return {uuid} - Entity identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectEntity (
  pObject   uuid
) RETURNS   uuid
AS $$
  SELECT entity FROM db.object WHERE id = pObject;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectParent -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the parent of an object.
 * @param {uuid} pObject - Object identifier
 * @return {uuid} - Parent object identifier (NULL if root)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectParent (
  pObject   uuid
) RETURNS   uuid
AS $$
  SELECT parent FROM db.object WHERE id = pObject;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectLabel -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the display label of an object for a given locale.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pLocale - Locale (defaults to current)
 * @return {text} - Label text
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectLabel (
  pObject   uuid,
  pLocale   uuid DEFAULT current_locale()
) RETURNS   text
AS $$
  SELECT label FROM db.object_text WHERE object = pObject AND locale = pLocale;
$$ LANGUAGE sql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetObjectLabel -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the display label of an object for one or all locales.
 * @param {uuid} pObject - Object identifier
 * @param {text} pLabel - New label text
 * @param {uuid} pLocale - Target locale (NULL = all locales)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetObjectLabel (
  pObject   uuid,
  pLabel    text,
  pLocale   uuid DEFAULT current_locale()
) RETURNS   void
AS $$
DECLARE
  l         record;
BEGIN
  IF pLocale IS NULL THEN
    FOR l IN SELECT id FROM db.locale
    LOOP
      UPDATE db.object_text SET label = pLabel WHERE object = pObject AND locale = l.id;
    END LOOP;
  ELSE
    UPDATE db.object_text SET label = pLabel WHERE object = pObject AND locale = pLocale;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectClass -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the class identifier of an object.
 * @param {uuid} pId - Object identifier
 * @return {uuid} - Class identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectClass (
  pId       uuid
) RETURNS   uuid
AS $$
  SELECT class FROM db.object WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectType ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the type identifier of an object.
 * @param {uuid} pId - Object identifier
 * @return {uuid} - Type identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectType (
  pId       uuid
) RETURNS   uuid
AS $$
  SELECT type FROM db.object WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectTypeCode --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the type code string for an object.
 * @param {uuid} pId - Object identifier
 * @return {text} - Type code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectTypeCode (
  pId       uuid
) RETURNS   text
AS $$
  SELECT code FROM db.type WHERE id = (
    SELECT type FROM db.object WHERE id = pId
  );
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectState -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the current workflow state of an object.
 * @param {uuid} pId - Object identifier
 * @return {uuid} - State identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectState (
  pId       uuid
) RETURNS   uuid
AS $$
  SELECT state FROM db.object WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateCode -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the state code string for an object.
 * @param {uuid} pId - Object identifier
 * @return {text} - State code (e.g. 'created', 'enabled')
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectStateCode (
  pId       uuid
) RETURNS   text
AS $$
DECLARE
  uState    uuid;
  vCode     text;
BEGIN
  SELECT state INTO uState FROM db.object WHERE id = pId;
  IF FOUND THEN
    SELECT code INTO vCode FROM db.state WHERE id = uState;
  END IF;

  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateType -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the state type identifier for an object.
 * @param {uuid} pId - Object identifier
 * @return {uuid} - State type identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectStateType (
  pId       uuid
) RETURNS   uuid
AS $$
DECLARE
  uState    uuid;
BEGIN
  SELECT state INTO uState FROM db.object WHERE id = pId;
  RETURN GetStateTypeByState(uState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateTypeCode ---------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the state type code string for an object.
 * @param {uuid} pId - Object identifier
 * @return {text} - State type code (e.g. 'created', 'enabled', 'disabled', 'deleted')
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectStateTypeCode (
  pId       uuid
) RETURNS   text
AS $$
DECLARE
  uState    uuid;
BEGIN
  SELECT state INTO uState FROM db.object WHERE id = pId;
  RETURN GetStateTypeCodeByState(uState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetObjectOwner -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Assign a new owner to an object.
 * @param {uuid} pId - Object identifier
 * @param {uuid} pOwner - New owner user identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetObjectOwner (
  pId       uuid,
  pOwner    uuid
) RETURNS   void
AS $$
BEGIN
  UPDATE db.object SET owner = pOwner WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectOwner -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the owner of an object.
 * @param {uuid} pId - Object identifier
 * @return {uuid} - Owner user identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectOwner (
  pId       uuid
) RETURNS   uuid
AS $$
  SELECT owner FROM db.object WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectOper ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the last operator (user) who modified an object.
 * @param {uuid} pId - Object identifier
 * @return {uuid} - Operator user identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectOper (
  pId       uuid
) RETURNS   uuid
AS $$
  SELECT oper FROM db.object WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddObjectState -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Add or update a state entry in the object state history.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pState - New state identifier
 * @param {timestamptz} pDateFrom - Effective date (defaults to oper_date)
 * @return {uuid} - Object state record identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddObjectState (
  pObject       uuid,
  pState        uuid,
  pDateFrom     timestamptz DEFAULT oper_date()
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;

  dtDateFrom    timestamptz;
  dtDateTo      timestamptz;
BEGIN
  SELECT id, validFromDate, validToDate INTO uId, dtDateFrom, dtDateTo
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    UPDATE db.object_state SET State = pState
     WHERE object = pObject
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    UPDATE db.object_state SET validToDate = pDateFrom
     WHERE object = pObject
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.object_state (object, state, validFromDate, validToDate)
    VALUES (pObject, pState, pDateFrom, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO uId;
  END IF;

  UPDATE db.object SET state = pState WHERE id = pObject;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectState -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the state of an object as of a specific date.
 * @param {uuid} pObject - Object identifier
 * @param {timestamptz} pDate - Point-in-time date
 * @return {uuid} - State identifier valid at the given date
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectState (
  pObject   uuid,
  pDate     timestamptz
) RETURNS   uuid
AS $$
  SELECT state
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDate
     AND validToDate > pDate;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetNewState --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the target state for a workflow method transition.
 * @param {uuid} pMethod - Method identifier
 * @return {uuid} - New state identifier (NULL if no transition)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetNewState (
  pMethod   uuid
) RETURNS   uuid
AS $$
  SELECT newstate FROM db.transition WHERE method = pMethod;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ChangeObjectState -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Transition an object to the new state defined by the current method.
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @param {uuid} pMethod - Method identifier (defaults to context_method)
 * @return {void}
 * @see AddObjectState
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ChangeObjectState (
  pObject   uuid DEFAULT context_object(),
  pMethod   uuid DEFAULT context_method()
) RETURNS   void
AS $$
DECLARE
  r         record;
  uNewState uuid;
  uAction   uuid;
BEGIN
  uNewState := GetNewState(pMethod);
  IF uNewState IS NOT NULL THEN
    PERFORM AddObjectState(pObject, uNewState);
    SELECT action INTO uAction FROM db.method WHERE id = pMethod;
    SELECT s.id, s.type, t.code AS typecode, stt.name AS typename, stt.description AS typedescription,
           s.code, st.label, s.sequence
      INTO r
      FROM db.state s INNER JOIN db.state_type        t ON s.type = t.id
                       LEFT JOIN db.state_type_text stt ON stt.type = t.id AND stt.locale = current_locale()
                       LEFT JOIN db.state_text       st ON st.state = s.id AND st.locale = current_locale()
     WHERE s.id = uNewState;
    PERFORM AddMethodStack(jsonb_build_object('object', pObject, 'method', pMethod, 'action', jsonb_build_object('id', uAction, 'code', GetActionCode(uAction)), 'newstate', row_to_json(r)));
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectMethod ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve the method for a given action on an object (based on class+state).
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pAction - Action identifier
 * @return {uuid} - Method identifier (NULL if no matching method)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectMethod (
  pObject   uuid,
  pAction   uuid
) RETURNS   uuid
AS $$
DECLARE
  uClass    uuid;
  uState    uuid;
BEGIN
  SELECT class, state INTO uClass, uState FROM db.object WHERE id = pObject;
  RETURN GetMethod(uClass, pAction, uState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddMethodStack -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Append a result to the method execution stack for an object+method pair.
 * @param {jsonb} pResult - Result data to accumulate
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @param {uuid} pMethod - Method identifier (defaults to context_method)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddMethodStack (
  pResult   jsonb,
  pObject   uuid DEFAULT context_object(),
  pMethod   uuid DEFAULT context_method()
) RETURNS   void
AS $$
BEGIN
  INSERT INTO db.method_stack (object, method, result) VALUES (pObject, pMethod, pResult)
  ON CONFLICT (object, method) DO UPDATE SET result = coalesce(db.method_stack.result, '{}'::jsonb) || pResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION ClearMethodStack ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Reset the method execution stack for an object+method pair.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pMethod - Method identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ClearMethodStack (
  pObject   uuid,
  pMethod   uuid
) RETURNS   void
AS $$
  SELECT AddMethodStack(NULL, pObject, pMethod);
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetMethodStack -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the accumulated result from the method execution stack.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pMethod - Method identifier
 * @return {jsonb} - Accumulated result (NULL if no entry)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetMethodStack (
  pObject   uuid,
  pMethod   uuid
) RETURNS   jsonb
AS $$
  SELECT result FROM db.method_stack WHERE object = pObject AND method = pMethod
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteAction -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute all event handlers registered for a class+action pair.
 * @param {uuid} pClass - Class identifier (defaults to context_class)
 * @param {uuid} pAction - Action identifier (defaults to context_action)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ExecuteAction (
  pClass    uuid DEFAULT context_class(),
  pAction   uuid DEFAULT context_action()
) RETURNS   void
AS $$
DECLARE
  uClass    uuid;
  Rec       record;
BEGIN
  FOR Rec IN
    SELECT t.code AS typecode, e.text
      FROM db.event e INNER JOIN db.event_type t ON e.type = t.id
     WHERE e.class = pClass
       AND e.action = pAction
       AND e.enabled
     ORDER BY e.sequence
  LOOP
    IF Rec.typecode = 'parent' THEN
      SELECT parent INTO uClass FROM db.class_tree WHERE id = pClass;
      IF uClass IS NOT NULL THEN
        PERFORM ExecuteAction(uClass, pAction);
      END IF;
    ELSIF Rec.typecode = 'event' THEN
      EXECUTE 'SELECT ' || Rec.Text;
    ELSIF Rec.typecode = 'plpgsql' THEN
      EXECUTE Rec.Text;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteMethod -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a workflow method on an object (check access, fire events, notify).
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pMethod - Method identifier
 * @param {jsonb} pParams - Optional parameters passed to event handlers
 * @return {jsonb} - Method execution result from the stack
 * @throws ExecuteMethodError - When the user lacks execute permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ExecuteMethod (
  pObject       uuid,
  pMethod       uuid,
  pParams       jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  uSaveObject   uuid;
  uSaveClass    uuid;
  uSaveMethod   uuid;
  uSaveAction   uuid;
  jSaveParams   jsonb;

  sLabel        text;
  sActionCode   text;

  uClass        uuid;
  uAction       uuid;
  uOldState     uuid;
  uNewState     uuid;
BEGIN
  IF session_user <> 'apibot' THEN
    IF NOT CheckObjectMethodAccess(pObject, pMethod, B'100') THEN
      SELECT label INTO sLabel FROM db.method_text WHERE method = pMethod AND locale = current_locale();
      PERFORM ExecuteMethodError(sLabel);
    END IF;
  END IF;

  uSaveObject := context_object();
  uSaveClass  := context_class();
  uSaveMethod := context_method();
  uSaveAction := context_action();
  jSaveParams := context_params();

  PERFORM ClearMethodStack(pObject, pMethod);

  SELECT class, state INTO uClass, uOldState FROM db.object WHERE id = pObject;
  SELECT action INTO uAction FROM db.method WHERE id = pMethod;
  SELECT code INTO sActionCode FROM db.action WHERE id = uAction;

  PERFORM InitContext(pObject, uClass, pMethod, uAction);
  PERFORM InitParams(pParams);

  PERFORM ExecuteAction(uClass, uAction);

  PERFORM InitParams(jSaveParams);
  PERFORM InitContext(uSaveObject, uSaveClass, uSaveMethod, uSaveAction);

  SELECT state INTO uNewState FROM db.object WHERE id = pObject;
  IF FOUND THEN
    PERFORM AddNotification(uClass, uAction, pMethod, uOldState, uNewState, pObject);
  END IF;

  RETURN GetMethodStack(pObject, pMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteMethodForAllChild ------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the same action on all child objects of a given class.
 * @param {uuid} pObject - Parent object identifier
 * @param {uuid} pClass - Class to filter children by
 * @param {uuid} pMethod - Current method (for context restore)
 * @param {uuid} pAction - Action to execute on children
 * @param {jsonb} pParams - Parameters to pass to each child method
 * @return {jsonb} - Array of execution results from children
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ExecuteMethodForAllChild (
  pObject   uuid DEFAULT context_object(),
  pClass    uuid DEFAULT context_class(),
  pMethod   uuid DEFAULT context_method(),
  pAction   uuid DEFAULT context_action(),
  pParams   jsonb DEFAULT context_params()
) RETURNS   jsonb
AS $$
DECLARE
  r         record;
  uMethod   uuid;
  result    jsonb;
BEGIN
  result := jsonb_build_array();

  FOR r IN SELECT id, class, state FROM db.object WHERE parent = pObject AND class = pClass
  LOOP
    uMethod := GetMethod(r.class, pAction, r.state);
    IF uMethod IS NOT NULL THEN
      result := result || ExecuteMethod(r.id, uMethod, pParams);
    END IF;
  END LOOP;

  PERFORM InitContext(pObject, pClass, pMethod, pAction);
  PERFORM InitParams(pParams);

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteObjectAction -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a named action on an object (resolves method from class+state).
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pAction - Action identifier
 * @param {jsonb} pParams - Optional parameters
 * @return {jsonb} - Method execution result
 * @throws MethodActionNotFound - When no method matches the action in current state
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ExecuteObjectAction (
  pObject   uuid,
  pAction   uuid,
  pParams   jsonb DEFAULT null
) RETURNS   jsonb
AS $$
DECLARE
  uMethod   uuid;
BEGIN
  uMethod := GetObjectMethod(pObject, pAction);

  IF uMethod IS NULL THEN
    PERFORM MethodActionNotFound(pObject, pAction);
  END IF;

  RETURN ExecuteMethod(pObject, uMethod, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsCreated ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether an object is in the 'created' state type.
 * @param {uuid} pObject - Object identifier
 * @return {boolean} - TRUE if state type is 'created'
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsCreated (
  pObject   uuid
) RETURNS   boolean
AS $$
BEGIN
  RETURN GetObjectStateTypeCode(pObject) = 'created';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsEnabled ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether an object is in the 'enabled' state type.
 * @param {uuid} pObject - Object identifier
 * @return {boolean} - TRUE if state type is 'enabled'
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsEnabled (
  pObject   uuid
) RETURNS   boolean
AS $$
BEGIN
  RETURN GetObjectStateTypeCode(pObject) = 'enabled';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsDisabled ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether an object is in the 'disabled' state type.
 * @param {uuid} pObject - Object identifier
 * @return {boolean} - TRUE if state type is 'disabled'
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsDisabled (
  pObject   uuid
) RETURNS   boolean
AS $$
BEGIN
  RETURN GetObjectStateTypeCode(pObject) = 'disabled';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsDeleted ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether an object is in the 'deleted' state type.
 * @param {uuid} pObject - Object identifier
 * @return {boolean} - TRUE if state type is 'deleted'
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsDeleted (
  pObject   uuid
) RETURNS   boolean
AS $$
BEGIN
  RETURN GetObjectStateTypeCode(pObject) = 'deleted';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsActive -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether an object is active (created or enabled).
 * @param {uuid} pObject - Object identifier
 * @return {boolean} - TRUE if state type is 'created' or 'enabled'
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsActive (
  pObject   uuid
) RETURNS   boolean
AS $$
DECLARE
  vCode     text;
BEGIN
  vCode := GetObjectStateTypeCode(pObject);
  RETURN vCode = 'created' OR vCode = 'enabled';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoAction -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a named action on an object by action code string.
 * @param {uuid} pObject - Object identifier
 * @param {text} pAction - Action code (e.g. 'enable', 'delete')
 * @param {jsonb} pParams - Optional parameters
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoAction (
  pObject   uuid,
  pAction   text,
  pParams   jsonb DEFAULT null
) RETURNS   jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction(pAction), pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoTryAction --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute a named action on an object, suppressing exceptions.
 * @param {uuid} pObject - Object identifier
 * @param {text} pAction - Action code
 * @param {jsonb} pParams - Optional parameters
 * @return {jsonb} - Execution result or NULL on error
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoTryAction (
  pObject   uuid,
  pAction   text,
  pParams   jsonb DEFAULT null
) RETURNS   jsonb
AS $$
DECLARE
  vMessage  text;
  vContext  text;
BEGIN
  RETURN DoAction(pObject, pAction, pParams);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;
  PERFORM WriteDiagnostics(vMessage, vContext, pObject);
  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoSave -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'save' method on an object.
 * @param {uuid} pObject - Object identifier
 * @param {jsonb} pParams - Optional parameters
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoSave (
  pObject   uuid,
  pParams   jsonb DEFAULT null
) RETURNS   jsonb
AS $$
BEGIN
  RETURN ExecuteMethod(pObject, GetMethod(GetObjectClass(pObject), GetAction('save')), pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoCreate -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'create' action on an object.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoCreate (
  pObject   uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('create'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoEnable -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'enable' action on an object.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoEnable (
  pObject   uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('enable'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoDisable ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'disable' action on an object.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoDisable (
  pObject   uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('disable'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoDelete -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'delete' action on an object.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoDelete (
  pObject   uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('delete'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoComplete ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'complete' action on an object.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoComplete (
  pObject    uuid
) RETURNS    jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('complete'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoDone -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'done' action on an object.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoDone (
  pObject    uuid
) RETURNS    jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('done'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoFail -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'fail' action on an object.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoFail (
  pObject    uuid
) RETURNS    jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('fail'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoCancel -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'cancel' action on an object.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoCancel (
  pObject   uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('cancel'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoUpdate -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'update' action on an object.
 * @param {uuid} pObject - Object identifier
 * @param {jsonb} pParams - Optional parameters
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoUpdate (
  pObject   uuid,
  pParams   jsonb DEFAULT null
) RETURNS   jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('update'), pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoRestore ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'restore' action on an object.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoRestore (
  pObject   uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('restore'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoDrop -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the 'drop' action on an object (permanent removal).
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - Execution result
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DoDrop (
  pObject   uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('drop'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateObjectGroup -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a named object group for the current user.
 * @param {text} pCode - Unique group code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {uuid} - Newly created group identifier (NULL if conflict)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateObjectGroup (
  pCode         text,
  pName         text,
  pDescription  text
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
BEGIN
  INSERT INTO db.object_group (code, name, description)
  VALUES (pCode, pName, pDescription)
  ON CONFLICT DO NOTHING
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectGroup -------------------------------------------------------------
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
CREATE OR REPLACE FUNCTION EditObjectGroup (
  pId           uuid,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.object_group
     SET code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = coalesce(pDescription, description)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectGroup --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve an object group identifier by code and owner.
 * @param {text} pCode - Group code
 * @param {uuid} pOwner - Owner user (defaults to current)
 * @return {uuid} - Group identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectGroup (
  pCode     text,
  pOwner    uuid DEFAULT current_userid()
) RETURNS   uuid
AS $$
  SELECT id FROM db.object_group WHERE owner = pOwner AND code = pCode;
$$ LANGUAGE sql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List all object groups owned by a given user.
 * @param {uuid} pOwner - Owner user (defaults to current)
 * @return {SETOF ObjectGroup} - Group records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ObjectGroup (
  pOwner    uuid DEFAULT current_userid()
) RETURNS   SETOF ObjectGroup
AS $$
  SELECT * FROM ObjectGroup WHERE owner = pOwner
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddObjectToGroup ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Add an object to a group (no-op on duplicate).
 * @param {uuid} pGroup - Group identifier
 * @param {uuid} pObject - Object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddObjectToGroup (
  pGroup    uuid,
  pObject   uuid
) RETURNS   void
AS $$
BEGIN
  INSERT INTO db.object_group_member (gid, object) VALUES (pGroup, pObject)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectFromGroup -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Remove an object from a group; delete the group if it becomes empty.
 * @param {uuid} pGroup - Group identifier
 * @param {uuid} pObject - Object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteObjectFromGroup (
  pGroup    uuid,
  pObject   uuid
) RETURNS   void
AS $$
DECLARE
  nCount    integer;
BEGIN
  DELETE FROM db.object_group_member
   WHERE gid = pGroup
     AND object = pObject;

  SELECT count(object) INTO nCount
    FROM db.object_group_member
   WHERE gid = pGroup;

  IF nCount = 0 THEN
    DELETE FROM db.object_group WHERE id = pGroup;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetObjectLink ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a temporal link between two objects.
 * @param {uuid} pObject - Source object identifier
 * @param {uuid} pLinked - Target object identifier (NULL to close the link)
 * @param {text} pKey - Relationship key
 * @param {timestamptz} pDateFrom - Effective date
 * @return {uuid} - Object link record identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetObjectLink (
  pObject       uuid,
  pLinked       uuid,
  pKey          text,
  pDateFrom     timestamptz DEFAULT oper_date()
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  uLinked       uuid;

  dtDateFrom    timestamptz;
  dtDateTo      timestamptz;
BEGIN
  SELECT id, linked, validFromDate, validToDate INTO uId, uLinked, dtDateFrom, dtDateTo
    FROM db.object_link
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF uLinked IS DISTINCT FROM pLinked THEN
    UPDATE db.object_link SET validToDate = pDateFrom
     WHERE object = pObject
       AND key = pKey
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    IF pLinked IS NOT NULL THEN
      INSERT INTO db.object_link (object, linked, key, validFromDate, validToDate)
      VALUES (pObject, pLinked, pKey, pDateFrom, coalesce(dtDateTo, MAXDATE()))
      RETURNING id INTO uId;
    END IF;
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectLink ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the linked object for a given key as of a specific date.
 * @param {uuid} pObject - Source object identifier
 * @param {text} pKey - Relationship key
 * @param {timestamptz} pDate - Point-in-time date
 * @return {uuid} - Linked object identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectLink (
  pObject   uuid,
  pKey      text,
  pDate     timestamptz DEFAULT oper_date()
) RETURNS   uuid
AS $$
DECLARE
  uLinked   uuid;
BEGIN
  SELECT linked INTO uLinked
    FROM db.object_link
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN uLinked;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetObjectReference -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a temporal external reference for an object.
 * @param {uuid} pObject - Object identifier
 * @param {text} pKey - Reference key
 * @param {text} pReference - External reference value (URI, code, etc.)
 * @param {timestamptz} pDateFrom - Effective date
 * @return {uuid} - Object reference record identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetObjectReference (
  pObject       uuid,
  pKey          text,
  pReference    text,
  pDateFrom     timestamptz DEFAULT oper_date()
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  vReference    text;

  dtDateFrom    timestamptz;
  dtDateTo      timestamptz;
BEGIN
  SELECT id, reference, validFromDate, validToDate INTO uId, vReference, dtDateFrom, dtDateTo
    FROM db.object_reference
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF vReference IS DISTINCT FROM pReference THEN
    UPDATE db.object_reference SET validToDate = pDateFrom
     WHERE object = pObject
       AND key = pKey
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    IF pReference IS NOT NULL THEN
      INSERT INTO db.object_reference (object, key, reference, validFromDate, validToDate)
      VALUES (pObject, pKey, pReference, pDateFrom, coalesce(dtDateTo, MAXDATE()))
      RETURNING id INTO uId;
    END IF;
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectReference -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the external reference value for an object by key and date.
 * @param {uuid} pObject - Object identifier
 * @param {text} pKey - Reference key
 * @param {timestamptz} pDate - Point-in-time date
 * @return {text} - Reference value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectReference (
  pObject       uuid,
  pKey          text,
  pDate         timestamptz DEFAULT oper_date()
) RETURNS       text
AS $$
DECLARE
  vReference    text;
BEGIN
  SELECT reference INTO vReference
    FROM db.object_reference
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN vReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReferenceObject -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve an object identifier by external reference value and key.
 * @param {text} pReference - External reference value
 * @param {text} pKey - Reference key
 * @param {timestamptz} pDate - Point-in-time date
 * @return {uuid} - Object identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReferenceObject (
  pReference    text,
  pKey          text,
  pDate         timestamptz DEFAULT oper_date()
) RETURNS       uuid
AS $$
DECLARE
  uObject       uuid;
BEGIN
  SELECT object INTO uObject
    FROM db.object_reference
   WHERE reference = pReference
     AND key = pKey
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN uObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewObjectFile ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new file and attach it to an object.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pFile - Existing file identifier (NULL to create a new file)
 * @param {text} pName - File name
 * @param {text} pPath - File path (use '~/' for auto-generated path)
 * @param {integer} pSize - File size in bytes
 * @param {timestamptz} pDate - File date
 * @param {bytea} pData - Binary file content
 * @param {text} pHash - SHA-256 hash (auto-computed if NULL and data provided)
 * @param {text} pText - Text content or description
 * @param {text} pMime - MIME type
 * @param {text} pDone - Callback on success
 * @param {text} pFail - Callback on failure
 * @return {uuid} - File identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewObjectFile (
  pObject   uuid,
  pFile     uuid,
  pName     text,
  pPath     text,
  pSize     integer,
  pDate     timestamptz,
  pData     bytea DEFAULT null,
  pHash     text DEFAULT null,
  pText     text DEFAULT null,
  pMime     text DEFAULT null,
  pDone     text DEFAULT null,
  pFail     text DEFAULT null
) RETURNS   uuid
AS $$
DECLARE
  uRoot     uuid;
  uParent   uuid;
  vType     char;
  vClass    text;
BEGIN
  IF pFile IS NULL THEN
    vClass := GetClassCode(GetObjectClass(pObject));

    uRoot := GetFile(null::uuid, vClass);
    IF uRoot IS NULL THEN
      uRoot := NewFilePath(concat('/', vClass));
    END IF;

    IF NULLIF(pPath, '') IS NOT NULL THEN
      IF pPath = '~/' THEN
        pPath := concat('/', vClass, '/', pObject, '/');
      END IF;
      uParent := NewFilePath(pPath);
    ELSE
      uParent := uRoot;
    END IF;

    vType := '-';

    IF pData IS NOT NULL THEN
      IF pMime = 'text/x-uri' THEN
        vType := 'l';
      ELSE
        IF pHash IS NULL THEN
          pHash := encode(digest(pData, 'sha256'), 'hex');
        END IF;
        IF pSize IS NULL THEN
          pSize := length(pData);
        END IF;
      END IF;
    END IF;

    pFile := GetFile(uParent, pName);
    IF pFile IS NULL THEN
      pFile := NewFile(null, uRoot, uParent, pName, vType, GetObjectOwner(pObject), null, null, pSize, pDate, pData, pMime, pText, pHash, pDone, pFail);
    END IF;
  END IF;

  INSERT INTO db.object_file (object, file)
  VALUES (pObject, pFile) ON CONFLICT DO NOTHING;

  RETURN pFile;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectFile --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update metadata of an existing file attached to an object.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pFile - File identifier (NULL to resolve by path+name)
 * @param {text} pName - File name
 * @param {text} pPath - File path
 * @param {integer} pSize - New file size
 * @param {timestamptz} pDate - New file date
 * @param {bytea} pData - New binary content
 * @param {text} pHash - New SHA-256 hash
 * @param {text} pText - New text content
 * @param {text} pMime - New MIME type
 * @return {void}
 * @throws NotFound - When file cannot be resolved
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditObjectFile (
  pObject   uuid,
  pFile     uuid,
  pName     text,
  pPath     text,
  pSize     integer,
  pDate     timestamptz,
  pData     bytea DEFAULT null,
  pHash     text DEFAULT null,
  pText     text DEFAULT null,
  pMime     text DEFAULT null
) RETURNS   void
AS $$
DECLARE
  vClass    text;
BEGIN
  IF pFile IS NULL THEN
    IF NULLIF(NULLIF(pPath, ''), '~/') IS NULL THEN
      vClass := GetClassCode(GetObjectClass(pObject));
      pPath := concat('/', vClass, '/', pObject, '/');
    END IF;
    pFile := FindFile(concat(pPath, pName));
    IF pFile IS NULL THEN
      PERFORM NotFound();
    END IF;
  END IF;

  PERFORM EditFile(pFile, null, null, pName, null, null, null, pSize, pDate, pData, pMime, pText, pHash);

  UPDATE db.object_file
     SET updated = Now()
   WHERE object = pObject
     AND file = pFile;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectFile ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Remove a file attachment from an object; delete the file if unreferenced.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pFile - File identifier (NULL to resolve by path+name)
 * @param {text} pName - File name (used when pFile is NULL)
 * @param {text} pPath - File path (used when pFile is NULL)
 * @return {boolean} - TRUE if the attachment was removed
 * @throws NotFound - When file cannot be resolved
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteObjectFile (
  pObject   uuid,
  pFile     uuid,
  pName     text DEFAULT null,
  pPath     text DEFAULT null
) RETURNS   boolean
AS $$
DECLARE
  vClass    text;
BEGIN
  IF pFile IS NULL THEN
    IF NULLIF(NULLIF(pPath, ''), '~/') IS NULL THEN
      vClass := GetClassCode(GetObjectClass(pObject));
      pPath := concat('/', vClass, '/', pObject, '/');
    END IF;
    pFile := FindFile(concat(pPath, pName));
    IF pFile IS NULL THEN
      PERFORM NotFound();
    END IF;
  END IF;

  DELETE FROM db.object_file WHERE object = pObject AND file = pFile;

  IF FOUND THEN
    PERFORM FROM db.object_file WHERE file = pFile;

    IF NOT FOUND THEN
      PERFORM DeleteFile(pFile);
    END IF;

    RETURN true;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ClearObjectFiles ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Remove all file attachments from an object.
 * @param {uuid} pObject - Object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ClearObjectFiles (
  pObject   uuid
) RETURNS   void
AS $$
BEGIN
  DELETE FROM db.object_file WHERE object = pObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectFile ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a file attachment: create, update, or delete based on size.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pFile - File identifier (NULL to resolve by path+name)
 * @param {text} pName - File name
 * @param {text} pPath - File path
 * @param {integer} pSize - File size (negative = delete)
 * @param {timestamptz} pDate - File date
 * @param {bytea} pData - Binary content
 * @param {text} pHash - SHA-256 hash
 * @param {text} pText - Text content
 * @param {text} pMime - MIME type
 * @param {text} pDone - Callback on success
 * @param {text} pFail - Callback on failure
 * @return {uuid} - File identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetObjectFile (
  pObject   uuid,
  pFile     uuid,
  pName     text,
  pPath     text,
  pSize     integer,
  pDate     timestamptz,
  pData     bytea DEFAULT null,
  pHash     text DEFAULT null,
  pText     text DEFAULT null,
  pMime     text DEFAULT null,
  pDone     text DEFAULT null,
  pFail     text DEFAULT null
) RETURNS   uuid
AS $$
DECLARE
  vClass    text;
BEGIN
  IF pFile IS NULL THEN
    IF NULLIF(NULLIF(pPath, ''), '~/') IS NULL THEN
      vClass := GetClassCode(GetObjectClass(pObject));
      pPath := concat('/', vClass, '/', pObject, '/');
    END IF;
    pFile := FindFile(concat(pPath, pName));
  END IF;

  IF coalesce(pSize, 0) >= 0 THEN
    PERFORM FROM db.object_file WHERE object = pObject AND file = pFile;
    IF NOT FOUND THEN
      pFile := NewObjectFile(pObject, pFile, pName, pPath, pSize, pDate, pData, pHash, pText, pMime, pDone, pFail);
    ELSE
      PERFORM EditObjectFile(pObject, pFile, pName, pPath, pSize, pDate, pData, pHash, pText, pMime);
    END IF;
  ELSE
    PERFORM DeleteObjectFile(pObject, pFile, pName, pPath);
  END IF;

  RETURN pFile;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFiles --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all file attachments of an object as a 2D text array.
 * @param {uuid} pObject - Object identifier
 * @return {text[][]} - Array of file metadata rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectFiles (
  pObject   uuid
) RETURNS   text[][]
AS $$
DECLARE
  arResult  text[][];
  i         integer DEFAULT 1;
  r         ObjectFile%rowtype;
BEGIN
  FOR r IN
    SELECT *
      FROM ObjectFile
     WHERE object = pObject
     ORDER BY text
  LOOP
    arResult[i] := ARRAY[r.object, r.name, r.path, r.size, r.date, r.hash, r.text, r.type, r.loaded];
    i := i + 1;
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFilesJson ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all file attachments of an object as a JSON array.
 * @param {uuid} pObject - Object identifier
 * @return {json} - JSON array of file records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectFilesJson (
  pObject   uuid
) RETURNS   json
AS $$
DECLARE
  arResult  json[];
  r         record;
BEGIN
  FOR r IN
    SELECT *
      FROM ObjectFile
     WHERE object = pObject
     ORDER BY path, name
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFilesJsonb ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all file attachments of an object as a JSONB value.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - JSONB array of file records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectFilesJsonb (
  pObject   uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN GetObjectFilesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert or replace arbitrary key-value data for an object.
 * @param {uuid} pObject - Object identifier
 * @param {text} pType - Data format (text, json, xml, base64)
 * @param {text} pCode - Data key
 * @param {text} pData - Data value
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewObjectData (
  pObject   uuid,
  pType     text,
  pCode     text,
  pData     text
) RETURNS   void
AS $$
BEGIN
  INSERT INTO db.object_data (object, type, code, data)
  VALUES (pObject, pType, pCode, pData)
  ON CONFLICT (object, type, code) DO UPDATE SET data = pData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectData --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update existing key-value data for an object.
 * @param {uuid} pObject - Object identifier
 * @param {text} pType - Data format
 * @param {text} pCode - Data key
 * @param {text} pData - New data value (NULL preserves existing)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditObjectData (
  pObject   uuid,
  pType     text,
  pCode     text,
  pData     text
) RETURNS   void
AS $$
BEGIN
  UPDATE db.object_data
     SET data = coalesce(pData, data)
   WHERE object = pObject
     AND type = pType
     AND code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectData ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a key-value data entry from an object.
 * @param {uuid} pObject - Object identifier
 * @param {text} pType - Data format
 * @param {text} pCode - Data key
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteObjectData (
  pObject   uuid,
  pType     text,
  pCode     text
) RETURNS   void
AS $$
BEGIN
  DELETE FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert or delete key-value data for an object.
 * @param {uuid} pObject - Object identifier
 * @param {text} pType - Data format (text, json, xml, base64)
 * @param {text} pCode - Data key
 * @param {text} pData - Data value (NULL = delete)
 * @return {text} - Previous data value (NULL if new)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetObjectData (
  pObject   uuid,
  pType     text,
  pCode     text,
  pData     text
) RETURNS   text
AS $$
DECLARE
  vData     text;
BEGIN
  IF pData IS NOT NULL THEN
    SELECT data INTO vData FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
    IF NOT FOUND THEN
      PERFORM NewObjectData(pObject, pType, pCode, pData);
    ELSE
      PERFORM EditObjectData(pObject, pType, pCode, pData);
    END IF;
  ELSE
    PERFORM DeleteObjectData(pObject, pType, pCode);
  END IF;
  RETURN vData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectDataJSON -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Store JSON data for an object under a given code.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Data key
 * @param {json} pData - JSON data
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetObjectDataJSON (
  pObject   uuid,
  pCode     text,
  pData     json
) RETURNS   void
AS $$
BEGIN
  PERFORM SetObjectData(pObject, 'json', pCode, pData::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectDataXML ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Store XML data for an object under a given code.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Data key
 * @param {xml} pData - XML data
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetObjectDataXML (
  pObject   uuid,
  pCode     text,
  pData     xml
) RETURNS   void
AS $$
BEGIN
  PERFORM SetObjectData(pObject, 'xml', pCode, pData::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a single key-value data entry for an object.
 * @param {uuid} pObject - Object identifier
 * @param {text} pType - Data format
 * @param {text} pCode - Data key
 * @return {text} - Data value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectData (
  pObject   uuid,
  pType     text,
  pCode     text
) RETURNS   text
AS $$
  SELECT data FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataJSON -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a JSON data entry for an object by code.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Data key
 * @return {json} - JSON data
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectDataJSON (
  pObject   uuid,
  pCode     text
) RETURNS   json
AS $$
BEGIN
  RETURN GetObjectData(pObject, 'json', pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataXML ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch an XML data entry for an object by code.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Data key
 * @return {json} - XML data as JSON
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectDataXML (
  pObject   uuid,
  pCode     text
) RETURNS   json
AS $$
BEGIN
  RETURN GetObjectData(pObject, 'xml', pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataJson -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all key-value data entries for an object as a JSON array.
 * @param {uuid} pObject - Object identifier
 * @return {json} - JSON array of data records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectDataJson (
  pObject   uuid
) RETURNS   json
AS $$
DECLARE
  r         record;
  arResult  json[];
BEGIN
  FOR r IN
    SELECT object, type, Code, Data
      FROM ObjectData
     WHERE object = pObject
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataJsonb ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all key-value data entries for an object as a JSONB value.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - JSONB array of data records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectDataJsonb (
  pObject   uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN GetObjectDataJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectCoordinates -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List all object coordinates valid at a given date.
 * @param {timestamptz} pDateFrom - Point-in-time date
 * @return {SETOF ObjectCoordinates} - Coordinate records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ObjectCoordinates (
  pDateFrom timestamptz
) RETURNS   SETOF ObjectCoordinates
AS $$
  SELECT * FROM ObjectCoordinates WHERE validfromdate <= pDateFrom AND validtodate > pDateFrom
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewObjectCoordinates --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update temporal GPS coordinates for an object.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Coordinate set code (e.g. 'default')
 * @param {numeric} pLatitude - Latitude in decimal degrees
 * @param {numeric} pLongitude - Longitude in decimal degrees
 * @param {numeric} pAccuracy - Accuracy / altitude in meters
 * @param {text} pLabel - Short display label
 * @param {text} pDescription - Optional description
 * @param {jsonb} pData - Additional free-form JSON data
 * @param {timestamptz} pDateFrom - Effective date
 * @return {uuid} - Coordinate record identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewObjectCoordinates (
  pObject       uuid,
  pCode         text,
  pLatitude     numeric,
  pLongitude    numeric,
  pAccuracy     numeric DEFAULT 0,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pData         jsonb DEFAULT null,
  pDateFrom     timestamptz DEFAULT oper_date()
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  dtDateFrom    timestamptz;
  dtDateTo      timestamptz;
BEGIN
  SELECT id, validFromDate, validToDate INTO uId, dtDateFrom, dtDateTo
    FROM db.object_coordinates
   WHERE object = pObject
     AND code = pCode
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    UPDATE db.object_coordinates
       SET latitude = pLatitude, longitude = pLongitude, accuracy = pAccuracy,
           label = coalesce(pLabel, label),
           description = coalesce(pDescription, description)
     WHERE object = pObject
       AND code = pCode
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    UPDATE db.object_coordinates SET validToDate = pDateFrom
     WHERE object = pObject
       AND code = pCode
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.object_coordinates (object, code, latitude, longitude, accuracy, label, description, data, validFromDate, validToDate)
    VALUES (pObject, pCode, pLatitude, pLongitude, pAccuracy, pLabel, pDescription, pData, pDateFrom, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO uId;
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectCoordinates -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete all coordinate records for an object by code.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Coordinate set code
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteObjectCoordinates (
  pObject   uuid,
  pCode     text
) RETURNS   void
AS $$
BEGIN
  DELETE FROM db.object_coordinates WHERE object = pObject AND code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectCoordinates --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch coordinates for an object by code.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Coordinate set code
 * @return {ObjectCoordinates} - Coordinate record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectCoordinates (
  pObject   uuid,
  pCode     text
) RETURNS   ObjectCoordinates
AS $$
  SELECT * FROM ObjectCoordinates WHERE object = pObject AND code = pCode;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectCoordinatesJson ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch coordinates for an object as a JSON array, filtered by code and date.
 * @param {uuid} pObject - Object identifier
 * @param {text} pCode - Coordinate set code (NULL = all codes)
 * @param {timestamptz} pDateFrom - Point-in-time date
 * @return {json} - JSON array of coordinate records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectCoordinatesJson (
  pObject   uuid,
  pCode     text DEFAULT NULL,
  pDateFrom timestamptz DEFAULT Now()
) RETURNS   json
AS $$
DECLARE
  arResult  json[];
  r         record;
BEGIN
  FOR r IN
    SELECT *
      FROM ObjectCoordinates
     WHERE object = pObject
       AND code = coalesce(pCode, code)
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectCoordinatesJsonb ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch coordinates for an object as a JSONB value.
 * @param {uuid} pObject - Object identifier
 * @return {jsonb} - JSONB array of coordinate records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectCoordinatesJsonb (
  pObject   uuid
) RETURNS   jsonb
AS $$
BEGIN
  RETURN GetObjectCoordinatesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
