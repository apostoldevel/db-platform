--------------------------------------------------------------------------------
-- NewObjectText ---------------------------------------------------------------
--------------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION EditObjectText (
  pObject       uuid,
  pLabel        text,
  pText         text,
  pLocale		uuid DEFAULT null
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

CREATE OR REPLACE FUNCTION CreateObject (
  pParent	uuid,
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

CREATE OR REPLACE FUNCTION EditObject (
  pId		uuid,
  pParent	uuid DEFAULT null,
  pType		uuid DEFAULT null,
  pLabel	text DEFAULT null,
  pText		text DEFAULT null,
  pLocale	uuid DEFAULT null
) RETURNS	void
AS $$
DECLARE
  l			record;
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

CREATE OR REPLACE FUNCTION SetObjectParent (
  pObject	uuid,
  pParent	uuid
) RETURNS	void
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

CREATE OR REPLACE FUNCTION GetObjectMembers (
  pObject	uuid
) RETURNS 	SETOF ObjectMembers
AS $$
  SELECT * FROM ObjectMembers WHERE object = pObject;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectEntity -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectEntity (
  pObject	uuid
) RETURNS	uuid
AS $$
  SELECT entity FROM db.object WHERE id = pObject;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectParent -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectParent (
  pObject	uuid
) RETURNS	uuid
AS $$
  SELECT parent FROM db.object WHERE id = pObject;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectLabel -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectLabel (
  pObject	uuid,
  pLocale	uuid DEFAULT current_locale()
) RETURNS	text
AS $$
  SELECT label FROM db.object_text WHERE object = pObject AND locale = pLocale;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetObjectLabel -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectLabel (
  pObject	uuid,
  pLabel    text,
  pLocale	uuid DEFAULT current_locale()
) RETURNS	void
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

CREATE OR REPLACE FUNCTION GetObjectClass (
  pId		uuid
) RETURNS	uuid
AS $$
  SELECT class FROM db.object WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectType ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectType (
  pId		uuid
) RETURNS	uuid
AS $$
  SELECT type FROM db.object WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectTypeCode --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectTypeCode (
  pId		uuid
) RETURNS	text
AS $$
  SELECT code FROM db.type WHERE id = (
    SELECT type FROM db.object WHERE id = pId
  );
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectState (
  pId		uuid
) RETURNS	uuid
AS $$
  SELECT state FROM db.object WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateCode -------------------------------------------------
--------------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION SetObjectOwner (
  pId		uuid,
  pOwner    uuid
) RETURNS 	void
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

CREATE OR REPLACE FUNCTION GetObjectOwner (
  pId		uuid
) RETURNS 	uuid
AS $$
  SELECT owner FROM db.object WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectOper ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectOper (
  pId		uuid
) RETURNS 	uuid
AS $$
  SELECT oper FROM db.object WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

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
  -- получим дату значения в текущем диапозоне дат
  SELECT id, validFromDate, validToDate INTO uId, dtDateFrom, dtDateTo
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.object_state SET State = pState
     WHERE object = pObject
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
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

CREATE OR REPLACE FUNCTION GetObjectState (
  pObject	uuid,
  pDate		timestamptz
) RETURNS	uuid
AS $$
  SELECT state
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDate
     AND validToDate > pDate;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetNewState --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetNewState (
  pMethod	uuid
) RETURNS 	uuid
AS $$
  SELECT newstate FROM db.transition WHERE method = pMethod;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ChangeObjectState -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ChangeObjectState (
  pObject	uuid DEFAULT context_object(),
  pMethod	uuid DEFAULT context_method()
) RETURNS 	void
AS $$
DECLARE
  uNewState	uuid;
  uAction	uuid;
BEGIN
  uNewState := GetNewState(pMethod);
  IF uNewState IS NOT NULL THEN
    PERFORM AddObjectState(pObject, uNewState);
    SELECT action INTO uAction FROM db.method WHERE id = pMethod;
    PERFORM AddMethodStack(jsonb_build_object('object', pObject, 'method', pMethod, 'action', jsonb_build_object('id', uAction, 'code', GetActionCode(uAction)), 'newstate', jsonb_build_object('id', uNewState, 'code', GetStateCode(uNewState))));
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectMethod ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectMethod (
  pObject	uuid,
  pAction	uuid
) RETURNS	uuid
AS $$
DECLARE
  uClass	uuid;
  uState	uuid;
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

CREATE OR REPLACE FUNCTION AddMethodStack (
  pResult   jsonb,
  pObject	uuid DEFAULT context_object(),
  pMethod	uuid DEFAULT context_method()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.method_stack SET result = coalesce(result, '{}'::jsonb) || pResult WHERE object = pObject AND method = pMethod;
  IF NOT FOUND THEN
	INSERT INTO db.method_stack (object, method, result) VALUES (pObject, pMethod, pResult);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION ClearMethodStack ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClearMethodStack (
  pObject	uuid,
  pMethod	uuid
) RETURNS	void
AS $$
  SELECT AddMethodStack(NULL, pObject, pMethod);
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetMethodStack -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMethodStack (
  pObject	uuid,
  pMethod	uuid
) RETURNS	jsonb
AS $$
  SELECT result FROM db.method_stack WHERE object = pObject AND method = pMethod
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteAction -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteAction (
  pClass	uuid DEFAULT context_class(),
  pAction	uuid DEFAULT context_action()
) RETURNS	void
AS $$
DECLARE
  uClass	uuid;
  Rec		record;
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

CREATE OR REPLACE FUNCTION ExecuteMethod (
  pObject       uuid,
  pMethod       uuid,
  pParams		jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  uSaveObject	uuid;
  uSaveClass	uuid;
  uSaveMethod	uuid;
  uSaveAction	uuid;
  jSaveParams	jsonb;

  sLabel        text;
  sActionCode	text;

  uClass        uuid;
  uAction       uuid;
BEGIN
  IF session_user <> 'apibot' THEN
	IF NOT CheckMethodAccess(pMethod, B'100') THEN
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

  uClass := GetObjectClass(pObject);

  SELECT action INTO uAction FROM db.method WHERE id = pMethod;
  SELECT code INTO sActionCode FROM db.action WHERE id = uAction;

  PERFORM InitContext(pObject, uClass, pMethod, uAction);
  PERFORM InitParams(pParams);

  PERFORM ExecuteAction(uClass, uAction);

  PERFORM InitParams(jSaveParams);
  PERFORM InitContext(uSaveObject, uSaveClass, uSaveMethod, uSaveAction);

  PERFORM FROM db.object WHERE id = pObject;
  IF FOUND THEN
    PERFORM AddNotification(uClass, uAction, pMethod, pObject);
  END IF;

  RETURN GetMethodStack(pObject, pMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteMethodForAllChild ------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteMethodForAllChild (
  pObject	uuid DEFAULT context_object(),
  pClass	uuid DEFAULT context_class(),
  pMethod	uuid DEFAULT context_method(),
  pAction	uuid DEFAULT context_action(),
  pParams	jsonb DEFAULT context_params()
) RETURNS	jsonb
AS $$
DECLARE
  r			record;
  uMethod	uuid;
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

CREATE OR REPLACE FUNCTION ExecuteObjectAction (
  pObject	uuid,
  pAction	uuid,
  pParams	jsonb DEFAULT null
) RETURNS 	jsonb
AS $$
DECLARE
  uMethod	uuid;
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

CREATE OR REPLACE FUNCTION IsCreated (
  pObject	uuid
) RETURNS 	boolean
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

CREATE OR REPLACE FUNCTION IsEnabled (
  pObject	uuid
) RETURNS 	boolean
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

CREATE OR REPLACE FUNCTION IsDisabled (
  pObject	uuid
) RETURNS 	boolean
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

CREATE OR REPLACE FUNCTION IsDeleted (
  pObject	uuid
) RETURNS 	boolean
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

CREATE OR REPLACE FUNCTION IsActive (
  pObject	uuid
) RETURNS 	boolean
AS $$
DECLARE
  vCode		text;
BEGIN
  vCode := GetObjectStateTypeCode(pObject);
  RETURN vCode = 'created' OR vCode = 'enabled';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoCreate -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoCreate (
  pObject	uuid
) RETURNS 	jsonb
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

CREATE OR REPLACE FUNCTION DoEnable (
  pObject	uuid
) RETURNS 	jsonb
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

CREATE OR REPLACE FUNCTION DoDisable (
  pObject	uuid
) RETURNS 	jsonb
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

CREATE OR REPLACE FUNCTION DoDelete (
  pObject	uuid
) RETURNS 	jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('delete'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoCancel -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoCancel (
  pObject	uuid
) RETURNS 	jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('cancel'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoRestore ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoRestore (
  pObject	uuid
) RETURNS 	jsonb
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

CREATE OR REPLACE FUNCTION DoDrop (
  pObject	uuid
) RETURNS 	jsonb
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

CREATE OR REPLACE FUNCTION EditObjectGroup (
  pId		    uuid,
  pCode		    text DEFAULT null,
  pName		    text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS	    void
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

CREATE OR REPLACE FUNCTION GetObjectGroup (
  pCode		text,
  pOwner    uuid DEFAULT current_userid()
) RETURNS	uuid
AS $$
  SELECT id FROM db.object_group WHERE owner = pOwner AND code = pCode;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ObjectGroup (
  pOwner    uuid DEFAULT current_userid()
) RETURNS	SETOF ObjectGroup
AS $$
  SELECT * FROM ObjectGroup WHERE owner = pOwner
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddObjectToGroup ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectToGroup (
  pGroup	uuid,
  pObject	uuid
) RETURNS	void
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

CREATE OR REPLACE FUNCTION DeleteObjectFromGroup (
  pGroup	uuid,
  pObject	uuid
) RETURNS	void
AS $$
DECLARE
  nCount	integer;
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
 * Устанавливает связь с объектом.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {uuid} pLinked - Идентификатор связанного объекта
 * @param {text} pKey - Ключ
 * @param {timestamptz} pDateFrom - Дата начала периода
 * @return {void}
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
  -- получим дату значения в текущем диапозоне дат
  SELECT linked, validFromDate, validToDate INTO uLinked, dtDateFrom, dtDateTo
    FROM db.object_link
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF uLinked IS DISTINCT FROM pLinked THEN
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.object_link SET validToDate = pDateFrom
     WHERE object = pObject
       AND key = pKey
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    IF pLinked IS NOT NULL THEN
      INSERT INTO db.object_link (object, key, linked, validFromDate, validToDate)
      VALUES (pObject, pKey, pLinked, pDateFrom, coalesce(dtDateTo, MAXDATE()))
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
 * Возвращает связанный с объектом объект.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pKey - Ключ
 * @param {timestamptz} pDate - Дата
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION GetObjectLink (
  pObject	uuid,
  pKey	    text,
  pDate		timestamptz DEFAULT oper_date()
) RETURNS	uuid
AS $$
DECLARE
  uLinked	uuid;
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
-- NormalizeFileName -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NormalizeFileName (
  pName		text,
  pLink     boolean DEFAULT false
) RETURNS	text
AS $$
BEGIN
  IF StrPos(pName, '/') != 0 THEN
	RAISE EXCEPTION 'ERR-40000: Invalid file name value: %', pName;
  END IF;

  IF pLink THEN
    RETURN URLEncode(pName);
  END IF;

  RETURN pName;
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NormalizeFilePath -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NormalizeFilePath (
  pPath		text,
  pLink     boolean DEFAULT false
) RETURNS	text
AS $$
DECLARE
  i         int;
  arPath    text[];
BEGIN
  IF SubStr(pPath, 1, 1) = '.' OR StrPos(pPath, '..') != 0 THEN
	RAISE EXCEPTION 'ERR-40000: Invalid file path value: %', pPath;
  END IF;

  IF NULLIF(NULLIF(pPath, ''), '~/') IS NULL THEN
    RETURN '/';
  END IF;

  arPath := path_to_array(pPath);
  IF arPath IS NULL THEN
    RETURN '/';
  END IF;

  pPath := '/';

  FOR i IN 1..array_length(arPath, 1)
  LOOP
    IF pLink THEN
	  pPath := concat(pPath, URLEncode(arPath[i]), '/');
	ELSE
	  pPath := concat(pPath, arPath[i], '/');
    END IF;
  END LOOP;

  RETURN pPath;
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewObjectFile ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewObjectFile (
  pObject	uuid,
  pName		text,
  pPath		text,
  pSize		integer,
  pDate		timestamptz,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null,
  pCallBack text DEFAULT null
) RETURNS	void
AS $$
BEGIN
  INSERT INTO db.object_file (object, file_name, file_path, file_size, file_date, file_data, file_hash, file_text, file_type, call_back)
  VALUES (pObject, pName, pPath, pSize, pDate, pData, pHash, pText, pType, pCallBack);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectFile --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObjectFile (
  pObject   uuid,
  pName		text,
  pPath		text DEFAULT null,
  pSize		integer DEFAULT null,
  pDate		timestamptz DEFAULT null,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null,
  pCallBack text DEFAULT null,
  pLoad		timestamptz DEFAULT null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object_file
    SET file_path = coalesce(pPath, file_path),
        file_size = coalesce(pSize, file_size),
        file_date = coalesce(pDate, file_date),
        file_data = coalesce(pData, file_data),
        file_hash = coalesce(pHash, file_hash),
        file_text = CheckNull(coalesce(pText, file_text, '')),
        file_type = CheckNull(coalesce(pType, file_type, '')),
        call_back = CheckNull(coalesce(pCallBack, call_back, '')),
        load_date = coalesce(pLoad, load_date)
  WHERE object = pObject
    AND file_name = pName
    AND file_path = NormalizeFilePath(pPath);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectFile ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectFile (
  pObject   uuid,
  pName		text,
  pPath		text DEFAULT null
) RETURNS	boolean
AS $$
BEGIN
  DELETE FROM db.object_file WHERE object = pObject AND file_name = pName AND file_path = NormalizeFilePath(pPath);
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ClearObjectFiles ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClearObjectFiles (
  pObject   uuid
) RETURNS	void
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

CREATE OR REPLACE FUNCTION SetObjectFile (
  pObject	uuid,
  pName		text,
  pPath		text,
  pSize		integer,
  pDate		timestamptz,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null,
  pCallBack text DEFAULT null
) RETURNS	int
AS $$
BEGIN
  IF coalesce(pSize, 0) >= 0 THEN
    PERFORM FROM db.object_file WHERE object = pObject AND file_name = pName AND file_path = NormalizeFilePath(pPath);
    IF NOT FOUND THEN
      PERFORM NewObjectFile(pObject, pName, pPath, pSize, pDate, pData, pHash, pText, pType, pCallBack);
    ELSE
      PERFORM EditObjectFile(pObject, pName, pPath, pSize, pDate, pData, pHash, pText, pType, pCallBack);
    END IF;
  ELSE
    PERFORM DeleteObjectFile(pObject, pName, pPath);
  END IF;

  RETURN pSize;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFiles --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFiles (
  pObject	uuid
) RETURNS	text[][]
AS $$
DECLARE
  arResult	text[][];
  i		    integer DEFAULT 1;
  r		    ObjectFile%rowtype;
BEGIN
  FOR r IN
    SELECT *
      FROM ObjectFile
     WHERE object = pObject
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

CREATE OR REPLACE FUNCTION GetObjectFilesJson (
  pObject	uuid
) RETURNS	json
AS $$
DECLARE
  arResult	json[];
  r		    record;
BEGIN
  FOR r IN
    SELECT Object, Label, Owner, OwnerCode, OwnerName,
           Name, Path, Size, Date, Link, Hash, Text, Type, Loaded, Picture
      FROM ObjectFile
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
-- GetObjectFilesJsonb ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFilesJsonb (
  pObject	uuid
) RETURNS	jsonb
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

CREATE OR REPLACE FUNCTION NewObjectData (
  pObject	uuid,
  pType		text,
  pCode		text,
  pData		text
) RETURNS	void
AS $$
BEGIN
  INSERT INTO db.object_data (object, type, code, data)
  VALUES (pObject, pType, pCode, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectData --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObjectData (
  pObject	uuid,
  pType		text,
  pCode		text,
  pData		text
) RETURNS	void
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

CREATE OR REPLACE FUNCTION DeleteObjectData (
  pObject	uuid,
  pType		text,
  pCode		text
) RETURNS	void
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

CREATE OR REPLACE FUNCTION SetObjectData (
  pObject	uuid,
  pType		text,
  pCode		text,
  pData		text
) RETURNS	text
AS $$
DECLARE
  vData		text;
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

CREATE OR REPLACE FUNCTION SetObjectDataJSON (
  pObject	uuid,
  pCode		text,
  pData		json
) RETURNS	void
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

CREATE OR REPLACE FUNCTION SetObjectDataXML (
  pObject	uuid,
  pCode		text,
  pData		xml
) RETURNS	void
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

CREATE OR REPLACE FUNCTION GetObjectData (
  pObject	uuid,
  pType		text,
  pCode		text
) RETURNS	text
AS $$
  SELECT data FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataJSON -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectDataJSON (
  pObject	uuid,
  pCode		text
) RETURNS	json
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

CREATE OR REPLACE FUNCTION GetObjectDataXML (
  pObject	uuid,
  pCode		text
) RETURNS	json
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

CREATE OR REPLACE FUNCTION GetObjectDataJson (
  pObject	uuid
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
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

CREATE OR REPLACE FUNCTION GetObjectDataJsonb (
  pObject	uuid
) RETURNS	jsonb
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

CREATE OR REPLACE FUNCTION ObjectCoordinates (
  pDateFrom     timestamptz
) RETURNS       SETOF ObjectCoordinates
AS $$
  SELECT * FROM ObjectCoordinates WHERE validfromdate <= pDateFrom AND validtodate > pDateFrom
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewObjectCoordinates --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewObjectCoordinates (
  pObject		uuid,
  pCode			text,
  pLatitude		numeric,
  pLongitude	numeric,
  pAccuracy		numeric DEFAULT 0,
  pLabel		text DEFAULT null,
  pDescription	text DEFAULT null,
  pData			jsonb DEFAULT null,
  pDateFrom		timestamptz DEFAULT Now()
) RETURNS		uuid
AS $$
DECLARE
  uId			uuid;
  dtDateFrom	timestamptz;
  dtDateTo		timestamptz;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT id, validFromDate, validToDate INTO uId, dtDateFrom, dtDateTo
    FROM db.object_coordinates
   WHERE object = pObject
     AND code = pCode
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.object_coordinates
       SET latitude = pLatitude, longitude = pLongitude, accuracy = pAccuracy,
           label = coalesce(pLabel, label),
           description = coalesce(pDescription, description)
     WHERE object = pObject
       AND code = pCode
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
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

CREATE OR REPLACE FUNCTION DeleteObjectCoordinates (
  pObject	uuid,
  pCode		text
) RETURNS	void
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

CREATE OR REPLACE FUNCTION GetObjectCoordinates (
  pObject       uuid,
  pCode         text
) RETURNS       ObjectCoordinates
AS $$
  SELECT * FROM ObjectCoordinates WHERE object = pObject AND code = pCode;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectCoordinatesJson ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectCoordinatesJson (
  pObject		uuid,
  pCode			text DEFAULT NULL,
  pDateFrom		timestamptz DEFAULT Now()
) RETURNS		json
AS $$
DECLARE
  arResult		json[];
  r             record;
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

CREATE OR REPLACE FUNCTION GetObjectCoordinatesJsonb (
  pObject	uuid
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectCoordinatesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
