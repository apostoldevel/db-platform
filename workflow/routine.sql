--------------------------------------------------------------------------------
-- FUNCTION AddEntity ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddEntity (
  pCode		    text,
  pName		    text,
  pDescription	text DEFAULT null
) RETURNS	    uuid
AS $$
DECLARE
  uId		    uuid;
BEGIN
  INSERT INTO db.entity (code, name, description)
  VALUES (pCode, pName, pDescription)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditEntity ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditEntity (
  pId		    uuid,
  pCode		    text DEFAULT null,
  pName		    text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS	    void
AS $$
DECLARE
BEGIN
  UPDATE db.entity
     SET code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = NULLIF(coalesce(pDescription, description), '<null>')
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteEntity -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteEntity (
  pId		uuid
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.entity WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetEntity ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEntity (
  pCode		text
) RETURNS 	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.entity WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClassLabel ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClassLabel (
  pClass	uuid
) RETURNS	text
AS $$
DECLARE
  vLabel	text;
BEGIN
  SELECT label INTO vLabel FROM db.class_tree WHERE id = pClass;
  RETURN vLabel;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddClass -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddClass (
  pParent	uuid,
  pEntity   uuid,
  pCode		text,
  pLabel	text,
  pAbstract	boolean
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
  nLevel	integer;
BEGIN
  nLevel := 0;

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.class_tree WHERE id = pParent;
  END IF;

  INSERT INTO db.class_tree (parent, entity, level, code, label, abstract)
  VALUES (pParent, pEntity, nLevel, pCode, pLabel, pAbstract)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditClass ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditClass (
  pId		uuid,
  pParent	uuid DEFAULT null,
  pEntity	uuid DEFAULT null,
  pCode		text DEFAULT null,
  pLabel	text DEFAULT null,
  pAbstract	boolean DEFAULT null
) RETURNS	void
AS $$
DECLARE
  nLevel	integer;
BEGIN
  nLevel := 1;

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.class_tree WHERE id = pParent;
  END IF;

  UPDATE db.class_tree
     SET parent = coalesce(pParent, parent),
         entity = coalesce(pEntity, entity),
         level = nLevel,
         code = coalesce(pCode, code),
         label = coalesce(pLabel, label),
         abstract = coalesce(pAbstract, abstract)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteClass --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteClass (
  pId		uuid
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.state WHERE class = pId;
  DELETE FROM db.class_tree WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClass -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClass (
  pCode		text
) RETURNS 	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.class_tree WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClassEntity -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClassEntity (
  pClass	uuid
) RETURNS 	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT entity INTO uId FROM db.class_tree WHERE id = pClass;
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClassCode -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClassCode (
  pId		uuid
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.class_tree WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetEntityCode ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEntityCode (
  pId		uuid
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT t.code INTO vCode
    FROM db.class_tree c INNER JOIN db.entity t ON t.id = c.entity
   WHERE c.id = pId;

  IF FOUND THEN
    RETURN vCode;
  END IF;

  SELECT code INTO vCode FROM db.entity WHERE Id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION acu ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION acu (
  pUserId	uuid,
  OUT class	uuid,
  OUT deny	bit,
  OUT allow	bit,
  OUT mask	bit
) RETURNS	SETOF record
AS $$
  SELECT a.class, bit_or(a.deny), bit_or(a.allow), bit_or(a.allow) & ~bit_or(a.deny)
    FROM db.acu a
   WHERE a.userid IN (SELECT pUserId UNION SELECT userid FROM db.member_group WHERE member = pUserId)
   GROUP BY a.class
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION acu ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION acu (
  pUserId	uuid,
  pClass	uuid,
  OUT class	uuid,
  OUT deny	bit,
  OUT allow	bit,
  OUT mask	bit
) RETURNS	SETOF record
AS $$
  SELECT a.class, bit_or(a.deny), bit_or(a.allow), bit_or(allow) & ~bit_or(deny)
    FROM db.acu a
   WHERE a.userid IN (SELECT pUserId UNION SELECT userid FROM db.member_group WHERE member = pUserId)
     AND a.class = pClass
   GROUP BY a.class
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetClassAccessMask ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClassAccessMask (
  pClass	uuid,
  pUserId	uuid default current_userid()
) RETURNS	bit
AS $$
  SELECT mask FROM acu(pUserId, pClass)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckClassAccess ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckClassAccess (
  pClass	uuid,
  pMask		bit,
  pUserId	uuid default current_userid()
) RETURNS	boolean
AS $$
BEGIN
  RETURN coalesce(GetClassAccessMask(pClass, pUserId) & pMask = pMask, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DecodeClassAccess -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DecodeClassAccess (
  pClass	uuid,
  pUserId	uuid default current_userid(),
  OUT a		boolean,
  OUT c		boolean,
  OUT s		boolean,
  OUT u		boolean,
  OUT d		boolean
) RETURNS 	record
AS $$
DECLARE
  bMask		bit(5);
BEGIN
  bMask := GetClassAccessMask(pClass, pUserId);

  a := bMask & B'10000' = B'10000';
  c := bMask & B'01000' = B'01000';
  s := bMask & B'00100' = B'00100';
  u := bMask & B'00010' = B'00010';
  d := bMask & B'00001' = B'00001';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetClassMembers -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClassMembers (
  pClass	uuid
) RETURNS 	SETOF ClassMembers
AS $$
  SELECT * FROM ClassMembers WHERE class = pClass;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- chmodc ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 * Устанавливает битовую маску доступа для класса и пользователя.
 * @param {uuid} pClass - Идентификатор класса
 * @param {bit} pMask - Маска доступа. Десять бит (d:{acsud}a:{acsud}) где: d - запрещающие биты; a - разрешающие биты: {a - access; c - create; s - select, u - update, d - delete}
 * @param {uuid} pUserId - Идентификатор пользователя/группы
 * @param {boolean} pRecursive - Рекурсивно установить права для всех нижестоящих классов.
 * @param {boolean} pObjectSet - Установить права на объектах (документах) принадлежащих указанному классу.
 * @return {void}
*/
CREATE OR REPLACE FUNCTION chmodc (
  pClass        uuid,
  pMask         bit,
  pUserId       uuid default current_userid(),
  pRecursive    boolean default false,
  pObjectSet    boolean default false
) RETURNS       void
AS $$
DECLARE
  r             record;

  bMethod		bit(6);
  bDeny         bit(5);
  bAllow        bit(5);
  bMask         bit(5);
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  pMask := NULLIF(pMask, B'0000000000');

  bDeny := coalesce(SubString(pMask FROM 1 FOR 5), B'00000');
  bAllow := coalesce(SubString(pMask FROM 6 FOR 5), B'00000');
  bMask := (bAllow & ~bDeny);

  IF pMask IS NOT NULL THEN
    UPDATE db.acu SET deny = bDeny, allow = bAllow WHERE class = pClass AND userid = pUserId;
    IF not FOUND THEN
      INSERT INTO db.acu SELECT pClass, pUserId, bDeny, bAllow;
    END IF;
  ELSE
    DELETE FROM db.acu WHERE class = pClass AND userid = pUserId;
  END IF;

  IF bMask & B'01000' = B'01000' OR bMask & B'00010' = B'00010' THEN
	bMethod := B'000111';
  ELSE
    bMethod := B'000000';
  END IF;

  FOR r IN SELECT id, visible FROM db.method WHERE class = pClass
  LOOP
	IF r.visible THEN
	  bMethod := bMethod | B'000010';
	ELSE
	  bMethod := bMethod & ~B'000010';
	END IF;

	PERFORM chmodm(r.id, bMethod, pUserId);
  END LOOP;

  IF coalesce(pObjectSet, false) THEN
    FOR r IN SELECT id FROM db.object WHERE class = pClass AND owner <> pUserId
    LOOP
      PERFORM chmodo(r.id, SubString(bDeny FROM 3 FOR 3) || SubString(bAllow FROM 3 FOR 3), pUserId);
    END LOOP;
  END IF;

  IF coalesce(pRecursive, false) THEN
    FOR r IN SELECT id FROM db.class_tree WHERE parent = pClass
    LOOP
      PERFORM chmodc(r.id, pMask, pUserId, pRecursive, pObjectSet);
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddType ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddType (
  pClass	    uuid,
  pCode		    text,
  pName		    text,
  pDescription	text DEFAULT null
) RETURNS	    uuid
AS $$
DECLARE
  uId		    uuid;
BEGIN
  INSERT INTO db.type (class, code, name, description)
  VALUES (pClass, pCode, pName, pDescription)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditType -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditType (
  pId		    uuid,
  pClass	    uuid DEFAULT null,
  pCode		    text DEFAULT null,
  pName		    text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS	    void
AS $$
DECLARE
BEGIN
  UPDATE db.type
     SET class = coalesce(pClass, class),
         code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = NULLIF(coalesce(pDescription, description), '<null>')
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteType ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteType (
  pId		uuid
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.type WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetType ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetType (
  pClass    uuid,
  pCode		text
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.type WHERE class = pClass AND code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetType ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetType (
  pCode		text,
  pClass    text DEFAULT null
) RETURNS	uuid
AS $$
BEGIN
  RETURN GetType(GetClass(coalesce(pClass, SubStr(pCode, StrPos(pCode, '.') + 1))), pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetType ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetType (
  pClass	    uuid,
  pCode		    text,
  pName		    text,
  pDescription	text DEFAULT null
) RETURNS	    uuid
AS $$
DECLARE
  uId		    uuid;
BEGIN
  uId := GetType(pClass, pCode);

  IF uId IS NULL THEN
	uId := AddType(pClass, pCode, pName, pDescription);
  ELSE
	PERFORM EditType(uId, pClass, pCode, pName, pDescription);
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetTypeCode --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetTypeCode (
  pId		uuid
) RETURNS	text
AS $$
  SELECT code FROM db.type WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetTypeName --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetTypeName (
  pId		uuid
) RETURNS	text
AS $$
  SELECT name FROM db.type WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetTypeCodes ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetTypeCodes (
  pClass    uuid
) RETURNS   text[]
AS $$
DECLARE
  arResult  text[];
  r         record;
BEGIN
  FOR r IN
    SELECT code
      FROM db.type
     WHERE class = pClass
     ORDER BY code
  LOOP
    arResult := array_append(arResult, r.code::text);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CodeToType ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CodeToType (
  pCode     text,
  pEntity   text
) RETURNS   uuid
AS $$
DECLARE
  r         record;
  arCodes   text[];
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 1, 15) = '4' THEN
    RETURN pCode;
  END IF;

  IF StrPos(pCode, '.') = 0 THEN
    pCode := concat(pCode, '.', pEntity);
  END IF;

  FOR r IN SELECT code FROM Type WHERE EntityCode = pEntity
  LOOP
    arCodes := array_append(arCodes, r.code::text);
  END LOOP;

  IF array_position(arCodes, pCode) IS NULL THEN
    PERFORM IncorrectCode(pCode, arCodes);
  END IF;

  RETURN GetType(pCode);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateType -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateType (
  pCode		text
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.state_type WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateTypeCode ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateTypeCode (
  pId		uuid
) RETURNS	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.state_type WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddState -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddState (
  pClass	uuid,
  pType		uuid,
  pCode		text,
  pLabel	text,
  pSequence	integer DEFAULT null
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  IF pSequence IS NULL THEN
    SELECT coalesce(max(sequence), 0) + 1 INTO pSequence
      FROM db.state
     WHERE class = pClass
       AND type = pType;
  END IF;

  INSERT INTO db.state (class, type, code, label, sequence)
  VALUES (pClass, pType, pCode, pLabel, pSequence)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditState ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditState (
  pId		    uuid,
  pClass	    uuid DEFAULT null,
  pType		    uuid DEFAULT null,
  pCode		    text DEFAULT null,
  pLabel	    text DEFAULT null,
  pSequence		integer DEFAULT null
) RETURNS	    void
AS $$
BEGIN
  UPDATE db.state
     SET class = coalesce(pClass, class),
         type = coalesce(pType, type),
         code = coalesce(pCode, code),
         label = coalesce(pLabel, label),
         sequence = coalesce(pSequence, sequence)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteState --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteState (
  pId		uuid
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.state WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetState -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetState (
  pClass	uuid,
  pCode		text
) RETURNS 	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  WITH RECURSIVE classtree(id, parent, level) AS (
	SELECT id, parent, level FROM db.class_tree WHERE id = pClass
	 UNION ALL
	SELECT c.id, c.parent, c.level
      FROM db.class_tree c INNER JOIN classtree ct ON ct.parent = c.id
  )
  SELECT s.id INTO uId
    FROM db.state s INNER JOIN classtree c ON s.class = c.id
   WHERE s.code = pCode
   ORDER BY c.level DESC;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetState -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetState (
  pClass	uuid,
  pType		uuid
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  WITH RECURSIVE classtree(id, parent, level) AS (
	SELECT id, parent, level FROM db.class_tree WHERE id = pClass
	 UNION ALL
	SELECT c.id, c.parent, c.level
      FROM db.class_tree c INNER JOIN classtree ct ON ct.parent = c.id
  )
  SELECT s.id INTO uId
    FROM db.state s INNER JOIN classtree c ON s.class = c.id
   WHERE s.type = pType
   ORDER BY c.level DESC;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateTypeByState ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateTypeByState (
  pState	uuid
) RETURNS	uuid
AS $$
DECLARE
  uType		uuid;
BEGIN
  SELECT type INTO uType FROM db.state WHERE id = pState;
  RETURN uType;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateTypeCodeByState --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateTypeCodeByState (
  pState	uuid
) RETURNS	text
AS $$
DECLARE
  vCode     text;
BEGIN
  SELECT code INTO vCode FROM db.state_type WHERE id = (SELECT type FROM db.state WHERE id = pState);
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateCode -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateCode (
  pState	uuid
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.state WHERE id = pState;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateLabel ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateLabel (
  pState	uuid
) RETURNS	text
AS $$
DECLARE
  vLabel	text;
BEGIN
  SELECT label INTO vLabel FROM db.state WHERE id = pState;
  RETURN vLabel;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddAction ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddAction (
  pId		    uuid,
  pCode		    text,
  pName		    text,
  pDescription	text DEFAULT null
) RETURNS	    uuid
AS $$
DECLARE
  uId		    uuid;
BEGIN
  INSERT INTO db.action (id, code, name, description)
  VALUES (pId, pCode, pName, pDescription)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditAction ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditAction (
  pId		    uuid,
  pCode		    text DEFAULT null,
  pName		    text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS	    boolean
AS $$
BEGIN
  UPDATE db.action
     SET code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = NULLIF(coalesce(pDescription, description), '<null>')
   WHERE id = pId;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteAction -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteAction (
  pId		uuid
) RETURNS 	boolean
AS $$
BEGIN
  DELETE FROM db.action WHERE id = pId;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetAction ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetAction (
  pCode		    text,
  pName		    text,
  pDescription	text DEFAULT null
) RETURNS	    uuid
AS $$
DECLARE
  uId		    uuid;
BEGIN
  uId := GetAction(pCode);
  IF uId IS NULL THEN
	uId := AddAction(gen_kernel_uuid('b'), pCode, pName, pDescription);
  ELSE
    PERFORM EditAction(uId, pCode, pName, pDescription);
  END IF;
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAction ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAction (
  pCode		text
) RETURNS 	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.action WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetActionCode ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetActionCode (
  pId		uuid
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.action WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetActionName ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetActionName (
  pId		uuid
) RETURNS   text
AS $$
DECLARE
  vName     text;
BEGIN
  SELECT name INTO vName FROM db.action WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddMethod ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMethod (
  pParent	uuid,
  pClass	uuid,
  pState	uuid,
  pAction	uuid,
  pCode		text DEFAULT null,
  pLabel	text DEFAULT null,
  pSequence	integer DEFAULT null,
  pVisible	boolean DEFAULT true
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  IF pSequence IS NULL THEN
    SELECT coalesce(max(sequence), 0) + 1 INTO pSequence
      FROM db.method
     WHERE class = pClass
       AND state IS NOT DISTINCT FROM pState;
  END IF;

  INSERT INTO db.method (parent, class, state, action, code, label, sequence, visible)
  VALUES (pParent, pClass, pState, pAction, pCode, pLabel, pSequence, pVisible)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditMethod ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditMethod (
  pId		uuid,
  pParent	uuid DEFAULT null,
  pClass	uuid DEFAULT null,
  pState	uuid DEFAULT null,
  pAction	uuid DEFAULT null,
  pCode		text DEFAULT null,
  pLabel	text default null,
  pSequence	integer default null,
  pVisible	boolean default null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.method
     SET parent = CheckNull(coalesce(pParent, parent, null_uuid())),
         class = coalesce(pClass, class),
         state = coalesce(pState, state),
         action = coalesce(pAction, action),
         code = coalesce(pCode, code),
         label = coalesce(pLabel, label),
         sequence = coalesce(pSequence, sequence),
         visible = coalesce(pVisible, visible)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteMethod -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteMethod (
  pId		uuid
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.method WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetMethod ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMethod (
  pClass	uuid,
  pAction	uuid,
  pState	uuid DEFAULT null
) RETURNS	uuid
AS $$
DECLARE
  uMethod	uuid;
BEGIN
  WITH RECURSIVE _class_tree(id, parent, level) AS (
    SELECT id, parent, level FROM db.class_tree WHERE id = pClass
    UNION
    SELECT c.id, c.parent, c.level FROM db.class_tree c INNER JOIN _class_tree ct ON ct.parent = c.id
  )
  SELECT m.id INTO uMethod
    FROM db.method m INNER JOIN _class_tree c ON c.id = m.class
   WHERE m.action = pAction
     AND m.state IS NOT DISTINCT FROM pState
   ORDER BY level DESC;

  RETURN uMethod;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsVisibleMethod ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IsVisibleMethod (
  pId		uuid
) RETURNS 	bool
AS $$
DECLARE
  bVisible  bool;
BEGIN
  SELECT visible INTO bVisible FROM db.method WHERE id = pId;
  RETURN bVisible;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsHiddenMethod -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IsHiddenMethod (
  pId		uuid
) RETURNS 	bool
AS $$
BEGIN
  RETURN NOT IsVisibleMethod(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION amu ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION amu (
  pUserId		uuid,
  OUT method	uuid,
  OUT deny		bit,
  OUT allow		bit,
  OUT mask		bit
) RETURNS		SETOF record
AS $$
  SELECT a.method, bit_or(a.deny), bit_or(a.allow), bit_or(allow) & ~bit_or(deny)
    FROM db.amu a
   WHERE userid IN (SELECT pUserId UNION SELECT userid FROM db.member_group WHERE member = pUserId)
   GROUP BY a.method
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION amu ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION amu (
  pUserId		uuid,
  pMethod		uuid,
  OUT method	uuid,
  OUT deny		bit,
  OUT allow		bit,
  OUT mask		bit
) RETURNS		SETOF record
AS $$
  SELECT a.method, bit_or(a.deny), bit_or(a.allow), bit_or(allow) & ~bit_or(deny)
    FROM db.amu a
   WHERE userid IN (SELECT pUserId UNION SELECT userid FROM db.member_group WHERE member = pUserId)
     AND a.method = pMethod
   GROUP BY a.method
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetMethodAccessMask ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMethodAccessMask (
  pMethod	uuid,
  pUserId	uuid default current_userid()
) RETURNS	bit
AS $$
  SELECT mask FROM amu(pUserId, pMethod)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckMethodAccess -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckMethodAccess (
  pMethod	uuid,
  pMask		bit,
  pUserId	uuid default current_userid()
) RETURNS	boolean
AS $$
BEGIN
  RETURN coalesce(GetMethodAccessMask(pMethod, pUserId) & pMask = pMask, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DecodeMethodAccess ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DecodeMethodAccess (
  pMethod	uuid,
  pUserId	uuid default current_userid(),
  OUT x		boolean,
  OUT v		boolean,
  OUT e		boolean
) RETURNS 	record
AS $$
DECLARE
  bMask		bit(3);
BEGIN
  bMask := GetMethodAccessMask(pMethod, pUserId);

  x := bMask & B'100' = B'100';
  v := bMask & B'010' = B'010';
  e := bMask & B'001' = B'001';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetMethodMembers ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMethodMembers (
  pMethod	uuid
) RETURNS 	SETOF MethodMembers
AS $$
  SELECT * FROM MethodMembers WHERE method = pMethod;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- chmodm ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 * Устанавливает битовую маску доступа для метода и пользователя.
 * @param {uuid} pMethod - Идентификатор метода
 * @param {bit} pMask - Маска доступа. Шесть бит (d:{xve}a:{xve}) где: d - запрещающие биты; a - разрешающие биты: {x - execute, v - visible, e - enable}
 * @param {uuid} pUserId - Идентификатор пользователя/группы
 * @return {void}
*/
CREATE OR REPLACE FUNCTION chmodm (
  pMethod	uuid,
  pMask		bit,
  pUserId	uuid default current_userid()
) RETURNS	void
AS $$
DECLARE
  bDeny         bit(3);
  bAllow        bit(3);
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  pMask := NULLIF(pMask, B'000000');

  IF pMask IS NOT NULL THEN
    bDeny := coalesce(SubString(pMask FROM 1 FOR 3), B'000');
    bAllow := coalesce(SubString(pMask FROM 4 FOR 3), B'000');

    UPDATE db.amu SET deny = bDeny, allow = bAllow WHERE method = pMethod AND userid = pUserId;
    IF NOT FOUND THEN
      INSERT INTO db.amu SELECT pMethod, pUserId, bDeny, bAllow;
    END IF;
  ELSE
    DELETE FROM db.amu WHERE method = pMethod AND userid = pUserId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddTransition ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddTransition (
  pState	uuid,
  pMethod	uuid,
  pNewState	uuid
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  INSERT INTO db.transition (state, method, newstate)
  VALUES (pState, pMethod, pNewState)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditTransition -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditTransition (
  pId		uuid,
  pState	uuid default null,
  pMethod	uuid default null,
  pNewState	uuid default null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.transition
     SET state = coalesce(pState, state),
         method = coalesce(pMethod, method),
         newstate = coalesce(pNewState, newstate)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteTransition ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteTransition (
  pId		uuid
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.transition WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetEventType -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEventType (
  pCode		text
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.event_type WHERE code = pCode;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddEvent -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddEvent (
  pClass	uuid,
  pType		uuid,
  pAction	uuid,
  pLabel	text,
  pText		text default null,
  pSequence	integer default null,
  pEnabled	boolean default true
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  IF pSequence IS NULL THEN
    SELECT coalesce(max(sequence), 0) + 1 INTO pSequence FROM db.event WHERE class = pClass AND action = pAction;
  END IF;

  INSERT INTO db.event (class, type, action, label, text, sequence, enabled)
  VALUES (pClass, pType, pAction, pLabel, NULLIF(pText, '<null>'), pSequence, pEnabled)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditEvent ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditEvent (
  pId		uuid,
  pClass	uuid default null,
  pType		uuid default null,
  pAction	uuid default null,
  pLabel	text default null,
  pText		text default null,
  pSequence	integer default null,
  pEnabled	boolean default null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.event
     SET class = coalesce(pClass, class),
         type = coalesce(pType, type),
         action = coalesce(pAction, action),
         label = coalesce(pLabel, label),
         text = NULLIF(coalesce(pText, text), '<null>'),
         sequence = coalesce(pSequence, sequence),
         enabled = coalesce(pEnabled, enabled)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteEvent --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteEvent (
  pId		uuid
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.event WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
