--------------------------------------------------------------------------------
-- NewEntityText ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new locale-specific text row for an entity.
 * @param {uuid} pEntity - Entity to attach the text to
 * @param {text} pName - Localised display name
 * @param {text} pDescription - Localised description (optional)
 * @param {uuid} pLocale - Target locale (defaults to session locale)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewEntityText (
  pEntity       uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       void
AS $$
BEGIN
  INSERT INTO db.entity_text (entity, locale, name, description)
  VALUES (pEntity, pLocale, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditEntityText --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update locale-specific text for an entity, inserting if absent.
 * @param {uuid} pEntity - Entity whose text is being edited
 * @param {text} pName - New display name (NULL keeps existing)
 * @param {text} pDescription - New description (NULL keeps existing)
 * @param {uuid} pLocale - Target locale
 * @return {void}
 * @see NewEntityText
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditEntityText (
  pEntity       uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.entity_text
     SET name = coalesce(pName, name),
         description = CheckNull(coalesce(pDescription, description, ''))
   WHERE entity = pEntity AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewEntityText(pEntity, pName, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddEntity ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new workflow entity with localised text for every locale.
 * @param {text} pCode - Unique entity code
 * @param {text} pName - Display name (replicated to all locales)
 * @param {text} pDescription - Description (optional)
 * @return {uuid} - Identifier of the newly created entity
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddEntity (
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  l             record;
  uId           uuid;
BEGIN
  INSERT INTO db.entity (code)
  VALUES (pCode)
  RETURNING id INTO uId;

  FOR l IN SELECT id FROM db.locale
  LOOP
    PERFORM NewEntityText(uId, pName, pDescription, l.id);
  END LOOP;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditEntity ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing entity and its current-locale text.
 * @param {uuid} pId - Entity to update
 * @param {text} pCode - New code (NULL keeps existing)
 * @param {text} pName - New display name (NULL keeps existing)
 * @param {text} pDescription - New description (NULL keeps existing)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditEntity (
  pId           uuid,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.entity
     SET code = coalesce(pCode, code)
   WHERE id = pId;

  PERFORM EditEntityText(pId, pName, pDescription, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteEntity -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete an entity and cascade-remove all its classes (kernel only).
 * @param {uuid} pId - Entity to delete
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteEntity (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  IF session_user = 'kernel' THEN
    PERFORM DeleteClass(id) FROM db.class_tree WHERE entity = pId;
  END IF;

  DELETE FROM db.entity WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetEntity ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up an entity identifier by its unique code.
 * @param {text} pCode - Entity code
 * @return {uuid} - Entity identifier or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetEntity (
  pCode     text
) RETURNS   uuid
AS $$
  SELECT id FROM db.entity WHERE code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewClassText ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new locale-specific label for a class.
 * @param {uuid} pClass - Class to attach the label to
 * @param {text} pLabel - Localised display label
 * @param {uuid} pLocale - Target locale (defaults to session locale)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewClassText (
  pClass    uuid,
  pLabel    text,
  pLocale   uuid DEFAULT current_locale()
) RETURNS   void
AS $$
BEGIN
  INSERT INTO db.class_text (class, locale, label)
  VALUES (pClass, pLocale, pLabel);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditClassText ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update a locale-specific label for a class, inserting if absent.
 * @param {uuid} pClass - Class whose label is being edited
 * @param {text} pLabel - New label (NULL keeps existing)
 * @param {uuid} pLocale - Target locale
 * @return {void}
 * @see NewClassText
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditClassText (
  pClass    uuid,
  pLabel    text,
  pLocale   uuid DEFAULT null
) RETURNS   void
AS $$
BEGIN
  UPDATE db.class_text
     SET label = coalesce(pLabel, label)
   WHERE class = pClass AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewClassText(pClass, pLabel, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddClass -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new class in the hierarchy with localised labels.
 * @param {uuid} pParent - Parent class (NULL for root)
 * @param {uuid} pEntity - Entity this class belongs to
 * @param {text} pCode - Unique class code
 * @param {text} pLabel - Display label (replicated to all locales)
 * @param {boolean} pAbstract - True if the class is abstract
 * @return {uuid} - Identifier of the newly created class
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddClass (
  pParent   uuid,
  pEntity   uuid,
  pCode     text,
  pLabel    text,
  pAbstract boolean
) RETURNS   uuid
AS $$
DECLARE
  l         record;
  uId       uuid;
  nLevel    integer;
BEGIN
  nLevel := 0;

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.class_tree WHERE id = pParent;
  END IF;

  INSERT INTO db.class_tree (parent, entity, level, code, abstract)
  VALUES (pParent, pEntity, nLevel, pCode, pAbstract)
  RETURNING id INTO uId;

  FOR l IN SELECT id FROM db.locale
  LOOP
    PERFORM NewClassText(uId, pLabel, l.id);
  END LOOP;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CopyClass ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Copy all events, states, methods, and transitions from one class to another.
 * @param {uuid} pSource - Source class to copy from
 * @param {uuid} pDestination - Destination class to copy into
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CopyClass (
  pSource       uuid,
  pDestination  uuid
) RETURNS       void
AS $$
DECLARE
  r             record;
  l             record;
  e             record;
  t             record;

  uEvent        uuid;
  uState        uuid;
  uMethod       uuid;
BEGIN
  FOR r IN SELECT * FROM db.event WHERE class = pSource
  LOOP
    INSERT INTO db.event (class, type, action, text, sequence, enabled)
    VALUES (pDestination, r.type, r.action, r.text, r.sequence, r.enabled)
    RETURNING id INTO uEvent;

    FOR l IN SELECT * FROM db.event_text WHERE event = r.id
    LOOP
      INSERT INTO db.event_text (event, locale, label)
      VALUES (uEvent, l.locale, l.label);
    END LOOP;
  END LOOP;

  PERFORM DefaultMethods(pDestination);
  PERFORM DefaultTransition(pDestination);

  FOR r IN SELECT * FROM db.state WHERE class = pSource
  LOOP
    INSERT INTO db.state (class, type, code, sequence)
    VALUES (pDestination, r.type, r.code, r.sequence)
    RETURNING id INTO uState;

    FOR l IN SELECT * FROM db.state_text WHERE state = r.id
    LOOP
      INSERT INTO db.state_text (state, locale, label)
      VALUES (uState, l.locale, l.label);
    END LOOP;

    FOR e IN SELECT * FROM db.method WHERE class = r.class AND state = r.id
    LOOP
      INSERT INTO db.method (parent, class, state, action, code, sequence, visible)
      VALUES (null, pDestination, uState, e.action, e.code, e.sequence, e.visible)
      RETURNING id INTO uMethod;

      FOR l IN SELECT * FROM db.method_text WHERE method = e.id
      LOOP
        INSERT INTO db.method_text (method, locale, label)
         VALUES (uMethod, l.locale, l.label);
      END LOOP;

      FOR t IN SELECT * FROM db.transition WHERE method = e.id
      LOOP
        INSERT INTO db.transition (state, method, newstate)
        VALUES (uState, uMethod, t.newstate);
      END LOOP;
    END LOOP;
  END LOOP;

  FOR r IN SELECT * FROM db.method WHERE class = pDestination
  LOOP
    FOR e IN SELECT * FROM db.transition WHERE method = r.id
    LOOP
      UPDATE db.transition SET newstate = GetState(r.class, GetStateCode(newstate)) WHERE id = e.id;
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CloneClass ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new child class and copy the parent's workflow definition into it.
 * @param {uuid} pParent - Parent class to clone from
 * @param {uuid} pEntity - Entity for the new class
 * @param {text} pCode - Code for the new class
 * @param {text} pLabel - Label for the new class
 * @param {boolean} pAbstract - Whether the new class is abstract
 * @return {uuid} - Identifier of the newly created class
 * @see AddClass, CopyClass
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CloneClass (
  pParent   uuid,
  pEntity   uuid,
  pCode     text,
  pLabel    text,
  pAbstract boolean
) RETURNS   uuid
AS $$
DECLARE
  uId       uuid;
BEGIN
  uId := AddClass(pParent, pEntity, pCode, pLabel, pAbstract);
  PERFORM CopyClass(pParent, uId);
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditClass ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing class and its current-locale label.
 * @param {uuid} pId - Class to update
 * @param {uuid} pParent - New parent class (NULL keeps existing)
 * @param {uuid} pEntity - New entity (NULL keeps existing)
 * @param {text} pCode - New code (NULL keeps existing)
 * @param {text} pLabel - New label (NULL keeps existing)
 * @param {boolean} pAbstract - New abstract flag (NULL keeps existing)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditClass (
  pId       uuid,
  pParent   uuid DEFAULT null,
  pEntity   uuid DEFAULT null,
  pCode     text DEFAULT null,
  pLabel    text DEFAULT null,
  pAbstract boolean DEFAULT null
) RETURNS   void
AS $$
DECLARE
  nLevel    integer;
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
         abstract = coalesce(pAbstract, abstract)
   WHERE id = pId;

  PERFORM EditClassText(pId, pLabel, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteClass --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a class and cascade-remove its events, methods, states, and types (kernel only).
 * @param {uuid} pId - Class to delete
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteClass (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  IF session_user = 'kernel' THEN
    PERFORM DeleteEvent(id) FROM db.event WHERE class = pId ORDER BY sequence DESC;
    PERFORM DeleteMethod(id) FROM db.method WHERE class = pId ORDER BY sequence DESC;
    PERFORM DeleteState(id) FROM db.state WHERE class = pId ORDER BY sequence DESC;
    PERFORM DeleteType(id) FROM db.type WHERE class = pId;
  END IF;

  DELETE FROM db.class_tree WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClass -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a class identifier by its unique code.
 * @param {text} pCode - Class code
 * @return {uuid} - Class identifier or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetClass (
  pCode     text
) RETURNS   uuid
AS $$
  SELECT id FROM db.class_tree WHERE code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClassEntity -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the entity identifier that a class belongs to.
 * @param {uuid} pClass - Class identifier
 * @return {uuid} - Entity identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetClassEntity (
  pClass    uuid
) RETURNS   uuid
AS $$
  SELECT entity FROM db.class_tree WHERE id = pClass;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClassCode -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the code of a class by its identifier.
 * @param {uuid} pId - Class identifier
 * @return {text} - Class code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetClassCode (
  pId       uuid
) RETURNS   text
AS $$
  SELECT code FROM db.class_tree WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClassLabel ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the localised label of a class.
 * @param {uuid} pClass - Class identifier
 * @return {text} - Localised label for the current locale
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetClassLabel (
  pClass    uuid
) RETURNS   text
AS $$
  SELECT label FROM db.class_text WHERE class = pClass AND locale = current_locale();
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetEntityCode ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve entity code by class id or entity id (tries class lookup first).
 * @param {uuid} pId - Class identifier or entity identifier
 * @return {text} - Entity code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetEntityCode (
  pId       uuid
) RETURNS   text
AS $$
DECLARE
  vCode     text;
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
/**
 * @brief Compute aggregated ACU permissions for a user across all classes.
 * @param {uuid} pUserId - User or group to evaluate
 * @return {SETOF record} - (class, deny, allow, mask) per class
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION acu (
  pUserId   uuid,
  OUT class uuid,
  OUT deny  bit,
  OUT allow bit,
  OUT mask  bit
) RETURNS   SETOF record
AS $$
  SELECT a.class, bit_or(a.deny), bit_or(a.allow), bit_or(a.allow) & ~bit_or(a.deny)
    FROM db.acu a
   WHERE a.userid IN (SELECT pUserId UNION SELECT userid FROM db.member_group WHERE member = pUserId)
   GROUP BY a.class
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION acu ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Compute aggregated ACU permissions for a user on a specific class.
 * @param {uuid} pUserId - User or group to evaluate
 * @param {uuid} pClass - Class to check permissions for
 * @return {SETOF record} - (class, deny, allow, mask)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION acu (
  pUserId   uuid,
  pClass    uuid,
  OUT class uuid,
  OUT deny  bit,
  OUT allow bit,
  OUT mask  bit
) RETURNS   SETOF record
AS $$
  SELECT a.class, bit_or(a.deny), bit_or(a.allow), bit_or(a.allow) & ~bit_or(a.deny)
    FROM db.acu a
   WHERE a.userid IN (SELECT pUserId UNION SELECT userid FROM db.member_group WHERE member = pUserId)
     AND a.class = pClass
   GROUP BY a.class
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetClassAccessMask ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the effective ACU bitmask for a class and user.
 * @param {uuid} pClass - Class to check
 * @param {uuid} pUserId - User (defaults to current session user)
 * @return {bit} - 5-bit effective access mask {acsud}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetClassAccessMask (
  pClass    uuid,
  pUserId   uuid default current_userid()
) RETURNS   bit
AS $$
  SELECT mask FROM acu(pUserId, pClass)
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckClassAccess ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether a user has specific access bits on a class.
 * @param {uuid} pClass - Class to check
 * @param {bit} pMask - Required permission bits
 * @param {uuid} pUserId - User (defaults to current session user)
 * @return {boolean} - True if all requested bits are granted
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckClassAccess (
  pClass    uuid,
  pMask     bit,
  pUserId   uuid default current_userid()
) RETURNS   boolean
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
/**
 * @brief Decode the ACU bitmask into individual boolean flags for a class.
 * @param {uuid} pClass - Class to decode access for
 * @param {uuid} pUserId - User (defaults to current session user)
 * @return {record} - (a=access, c=create, s=select, u=update, d=delete)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DecodeClassAccess (
  pClass    uuid,
  pUserId   uuid default current_userid(),
  OUT a     boolean,
  OUT c     boolean,
  OUT s     boolean,
  OUT u     boolean,
  OUT d     boolean
) RETURNS   record
AS $$
DECLARE
  bMask     bit(5);
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
/**
 * @brief List all users/groups that have ACU entries for a class.
 * @param {uuid} pClass - Class to inspect
 * @return {SETOF ClassMembers} - Users/groups with their permission bits
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetClassMembers (
  pClass    uuid
) RETURNS   SETOF ClassMembers
AS $$
  SELECT * FROM ClassMembers WHERE class = pClass;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- chmodc ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the access bitmask for a class and user, optionally recursing into child classes and objects.
 * @param {uuid} pClass - Class to modify permissions for
 * @param {bit} pMask - 10-bit mask (deny:{acsud} allow:{acsud}); NULL removes the entry
 * @param {uuid} pUserId - User or group (defaults to current session user)
 * @param {boolean} pRecursive - Recursively apply to all child classes
 * @param {boolean} pObjectSet - Also apply permissions to objects owned by this class
 * @return {void}
 * @throws AccessDenied - When the caller is not an administrator
 * @since 1.0.0
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

  bMethod       bit(6);
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
-- NewTypeText -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new locale-specific text row for an object type.
 * @param {uuid} pType - Type to attach the text to
 * @param {text} pName - Localised display name
 * @param {text} pDescription - Localised description (optional)
 * @param {uuid} pLocale - Target locale (defaults to session locale)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewTypeText (
  pType         uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       void
AS $$
BEGIN
  INSERT INTO db.type_text (type, locale, name, description)
  VALUES (pType, pLocale, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditTypeText ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update locale-specific text for an object type, inserting if absent.
 * @param {uuid} pType - Type whose text is being edited
 * @param {text} pName - New display name (NULL keeps existing)
 * @param {text} pDescription - New description (NULL keeps existing)
 * @param {uuid} pLocale - Target locale
 * @return {void}
 * @see NewTypeText
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditTypeText (
  pType         uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.type_text
     SET name = coalesce(pName, name),
         description = CheckNull(coalesce(pDescription, description, ''))
   WHERE type = pType AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewTypeText(pType, pName, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddType ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new object type under a class with localised text for every locale.
 * @param {uuid} pClass - Class this type belongs to
 * @param {text} pCode - Unique type code within the class
 * @param {text} pName - Display name (replicated to all locales)
 * @param {text} pDescription - Description (optional)
 * @param {uuid} pId - Pre-assigned identifier (optional, auto-generated if NULL)
 * @return {uuid} - Identifier of the newly created type
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddType (
  pClass        uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null,
  pId           uuid DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  l             record;
BEGIN
  pId := coalesce(pId, gen_kernel_uuid('b'::bpchar));

  INSERT INTO db.type (id, class, code)
  VALUES (pId, pClass, pCode);

  FOR l IN SELECT id FROM db.locale
  LOOP
    PERFORM NewTypeText(pId, pName, pDescription, l.id);
  END LOOP;

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditType -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing object type and its current-locale text.
 * @param {uuid} pId - Type to update
 * @param {uuid} pClass - New class (NULL keeps existing)
 * @param {text} pCode - New code (NULL keeps existing)
 * @param {text} pName - New display name (NULL keeps existing)
 * @param {text} pDescription - New description (NULL keeps existing)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditType (
  pId           uuid,
  pClass        uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
DECLARE
BEGIN
  UPDATE db.type
     SET class = coalesce(pClass, class),
         code = coalesce(pCode, code)
   WHERE id = pId;

  PERFORM EditTypeText(pId, pName, pDescription, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteType ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete an object type by its identifier.
 * @param {uuid} pId - Type to delete
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteType (
  pId        uuid
) RETURNS    void
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
/**
 * @brief Look up a type identifier by class and code.
 * @param {uuid} pClass - Class the type belongs to
 * @param {text} pCode - Type code
 * @return {uuid} - Type identifier or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetType (
  pClass    uuid,
  pCode     text
) RETURNS   uuid
AS $$
  SELECT id FROM db.type WHERE class = pClass AND code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetType ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a type identifier by code, deriving the class from the code suffix.
 * @param {text} pCode - Full type code (e.g. "client.reference")
 * @param {text} pClass - Optional explicit class code override
 * @return {uuid} - Type identifier or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetType (
  pCode     text,
  pClass    text DEFAULT null
) RETURNS   uuid
AS $$
BEGIN
  RETURN GetType(GetClass(coalesce(pClass, SubStr(pCode, StrPos(pCode, '.') + 1))), pCode);
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetType ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert an object type: create if absent, update if exists.
 * @param {uuid} pClass - Class the type belongs to
 * @param {text} pCode - Type code
 * @param {text} pName - Display name
 * @param {text} pDescription - Description (optional)
 * @return {uuid} - Type identifier (existing or newly created)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetType (
  pClass         uuid,
  pCode          text,
  pName          text,
  pDescription   text DEFAULT null
) RETURNS        uuid
AS $$
DECLARE
  uId            uuid;
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
/**
 * @brief Retrieve the code of an object type by its identifier.
 * @param {uuid} pId - Type identifier
 * @return {text} - Type code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetTypeCode (
  pId        uuid
) RETURNS    text
AS $$
  SELECT code FROM db.type WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetTypeName --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the localised name of an object type.
 * @param {uuid} pId - Type identifier
 * @param {uuid} pLocale - Locale (defaults to session locale)
 * @return {text} - Localised type name
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetTypeName (
  pId        uuid,
  pLocale    uuid DEFAULT current_locale()
) RETURNS    text
AS $$
  SELECT name FROM db.type_text WHERE type = pId AND locale = pLocale;
$$ LANGUAGE sql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetTypeCodes ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List all type codes defined for a class as an array.
 * @param {uuid} pClass - Class to inspect
 * @return {text[]} - Array of type codes sorted alphabetically
 * @since 1.0.0
 */
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
/**
 * @brief Resolve a type code or UUID string into a type identifier, validating against the entity.
 * @param {text} pCode - Type code or UUID string
 * @param {text} pEntity - Entity code to validate against
 * @return {uuid} - Resolved type identifier
 * @throws IncorrectCode - When the code is not found among valid types for the entity
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CodeToType (
  pCode     text,
  pEntity   text
) RETURNS   uuid
AS $$
DECLARE
  r         record;
  arCodes   text[];
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
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
/**
 * @brief Look up a state type identifier by its code.
 * @param {text} pCode - State type code (e.g. "created", "enabled")
 * @return {uuid} - State type identifier or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetStateType (
  pCode      text
) RETURNS    uuid
AS $$
  SELECT id FROM db.state_type WHERE code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateTypeCode ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the code of a state type by its identifier.
 * @param {uuid} pId - State type identifier
 * @return {text} - State type code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetStateTypeCode (
  pId        uuid
) RETURNS    text
AS $$
  SELECT code FROM db.state_type WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewStateText ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new locale-specific label for a state.
 * @param {uuid} pState - State to attach the label to
 * @param {text} pLabel - Localised display label
 * @param {uuid} pLocale - Target locale (defaults to session locale)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewStateText (
  pState    uuid,
  pLabel    text,
  pLocale   uuid DEFAULT current_locale()
) RETURNS   void
AS $$
BEGIN
  INSERT INTO db.state_text (state, locale, label)
  VALUES (pState, pLocale, pLabel);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditStateText ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update a locale-specific label for a state, inserting if absent.
 * @param {uuid} pState - State whose label is being edited
 * @param {text} pLabel - New label (NULL keeps existing)
 * @param {uuid} pLocale - Target locale
 * @return {void}
 * @see NewStateText
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditStateText (
  pState        uuid,
  pLabel        text,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.state_text
     SET label = coalesce(pLabel, label)
   WHERE state = pState AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewStateText(pState, pLabel, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddState -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new state for a class with localised labels for every locale.
 * @param {uuid} pClass - Class this state belongs to
 * @param {uuid} pType - State type (created, enabled, etc.)
 * @param {text} pCode - Unique state code within the class
 * @param {text} pLabel - Display label (replicated to all locales)
 * @param {integer} pSequence - Display order (auto-incremented if NULL)
 * @return {uuid} - Identifier of the newly created state
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddState (
  pClass     uuid,
  pType      uuid,
  pCode      text,
  pLabel     text,
  pSequence  integer DEFAULT null
) RETURNS    uuid
AS $$
DECLARE
  l          record;
  uId        uuid;
BEGIN
  IF pSequence IS NULL THEN
    SELECT coalesce(max(sequence), 0) + 1 INTO pSequence
      FROM db.state
     WHERE class = pClass
       AND type = pType;
  END IF;

  INSERT INTO db.state (class, type, code, sequence)
  VALUES (pClass, pType, pCode, pSequence)
  RETURNING id INTO uId;

  FOR l IN SELECT id FROM db.locale
  LOOP
    PERFORM NewStateText(uId, pLabel, l.id);
  END LOOP;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditState ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing state and its current-locale label.
 * @param {uuid} pId - State to update
 * @param {uuid} pClass - New class (NULL keeps existing)
 * @param {uuid} pType - New state type (NULL keeps existing)
 * @param {text} pCode - New code (NULL keeps existing)
 * @param {text} pLabel - New label (NULL keeps existing)
 * @param {integer} pSequence - New display order (NULL keeps existing)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditState (
  pId        uuid,
  pClass     uuid DEFAULT null,
  pType      uuid DEFAULT null,
  pCode      text DEFAULT null,
  pLabel     text DEFAULT null,
  pSequence  integer DEFAULT null
) RETURNS    void
AS $$
BEGIN
  UPDATE db.state
     SET class = coalesce(pClass, class),
         type = coalesce(pType, type),
         code = coalesce(pCode, code),
         sequence = coalesce(pSequence, sequence)
   WHERE id = pId;

  PERFORM EditStateText(pId, pLabel, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetState -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a state: create if absent, update if exists.
 * @param {uuid} pId - State identifier (NULL to look up by class+code)
 * @param {uuid} pClass - Class the state belongs to
 * @param {uuid} pType - State type
 * @param {text} pCode - State code
 * @param {text} pLabel - Display label
 * @param {integer} pSequence - Display order
 * @return {uuid} - State identifier (existing or newly created)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetState (
  pId           uuid,
  pClass        uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pCode         text DEFAULT null,
  pLabel        text DEFAULT null,
  pSequence     integer DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  IF pId IS NULL THEN
    SELECT id INTO pId FROM db.state WHERE class = pClass AND code = pCode;
  END IF;

  IF pId IS NULL THEN
    pId := AddState(pClass, pType, pCode, pLabel, pSequence);
  ELSE
    PERFORM EditState(pId, pClass, pType, pCode, pLabel, pSequence);
  END IF;

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteState --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a state and cascade-remove its transitions and methods.
 * @param {uuid} pId - State to delete
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteState (
  pId        uuid
) RETURNS    void
AS $$
BEGIN
  DELETE FROM db.transition WHERE newstate = pId;
  DELETE FROM db.transition WHERE state = pId;
  DELETE FROM db.method WHERE state = pId;
  DELETE FROM db.state WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetState -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Find a state by class and code, walking up the class hierarchy.
 * @param {uuid} pClass - Class to start searching from
 * @param {text} pCode - State code
 * @return {uuid} - State identifier (deepest match) or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetState (
  pClass    uuid,
  pCode     text
) RETURNS   uuid
AS $$
DECLARE
  uId       uuid;
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
/**
 * @brief Find a state by class and state type, walking up the class hierarchy.
 * @param {uuid} pClass - Class to start searching from
 * @param {uuid} pType - State type to match
 * @return {uuid} - State identifier (deepest match) or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetState (
  pClass    uuid,
  pType     uuid
) RETURNS   uuid
AS $$
DECLARE
  uId       uuid;
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
/**
 * @brief Retrieve the state type identifier for a given state.
 * @param {uuid} pState - State identifier
 * @return {uuid} - State type identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetStateTypeByState (
  pState    uuid
) RETURNS   uuid
AS $$
  SELECT type FROM db.state WHERE id = pState;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateTypeCodeByState --------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the state type code for a given state.
 * @param {uuid} pState - State identifier
 * @return {text} - State type code (e.g. "created", "enabled")
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetStateTypeCodeByState (
  pState    uuid
) RETURNS   text
AS $$
  SELECT code FROM db.state_type WHERE id = (SELECT type FROM db.state WHERE id = pState);
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateCode -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the code of a state by its identifier.
 * @param {uuid} pState - State identifier
 * @return {text} - State code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetStateCode (
  pState    uuid
) RETURNS   text
AS $$
  SELECT code FROM db.state WHERE id = pState;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateLabel ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the localised label of a state.
 * @param {uuid} pState - State identifier
 * @return {text} - Localised label for the current locale
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetStateLabel (
  pState    uuid
) RETURNS   text
AS $$
  SELECT label FROM db.state_text WHERE state = pState AND locale = current_locale();
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewActionText ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new locale-specific text row for an action.
 * @param {uuid} pAction - Action to attach the text to
 * @param {text} pName - Localised display name
 * @param {text} pDescription - Localised description (optional)
 * @param {uuid} pLocale - Target locale (defaults to session locale)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewActionText (
  pAction       uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       void
AS $$
BEGIN
  INSERT INTO db.action_text (action, locale, name, description)
  VALUES (pAction, pLocale, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditActionText --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update locale-specific text for an action, inserting if absent.
 * @param {uuid} pAction - Action whose text is being edited
 * @param {text} pName - New display name (NULL keeps existing)
 * @param {text} pDescription - New description (NULL keeps existing)
 * @param {uuid} pLocale - Target locale
 * @return {void}
 * @see NewActionText
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditActionText (
  pAction       uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.action_text
     SET name = coalesce(pName, name),
         description = CheckNull(coalesce(pDescription, description, ''))
   WHERE action = pAction AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewActionText(pAction, pName, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddAction ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new workflow action with localised text for every locale.
 * @param {uuid} pId - Pre-assigned action identifier
 * @param {text} pCode - Unique action code
 * @param {text} pName - Display name (replicated to all locales)
 * @param {text} pDescription - Description (optional)
 * @return {uuid} - Identifier of the newly created action
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddAction (
  pId            uuid,
  pCode          text,
  pName          text,
  pDescription   text DEFAULT null
) RETURNS        uuid
AS $$
DECLARE
  l              record;
  uId            uuid;
BEGIN
  INSERT INTO db.action (id, code)
  VALUES (pId, pCode)
  RETURNING id INTO uId;

  FOR l IN SELECT id FROM db.locale
  LOOP
    PERFORM NewActionText(uId, pName, pDescription, l.id);
  END LOOP;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditAction ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing action and its current-locale text.
 * @param {uuid} pId - Action to update
 * @param {text} pCode - New code (NULL keeps existing)
 * @param {text} pName - New display name (NULL keeps existing)
 * @param {text} pDescription - New description (NULL keeps existing)
 * @return {boolean} - True if the action was found and updated
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditAction (
  pId            uuid,
  pCode          text DEFAULT null,
  pName          text DEFAULT null,
  pDescription   text DEFAULT null
) RETURNS        boolean
AS $$
BEGIN
  UPDATE db.action
     SET code = coalesce(pCode, code)
   WHERE id = pId;

  IF FOUND THEN
    PERFORM EditActionText(pId, pName, pDescription, current_locale());
    RETURN true;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteAction -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete an action by its identifier.
 * @param {uuid} pId - Action to delete
 * @return {boolean} - True if the action was found and deleted
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteAction (
  pId       uuid
) RETURNS   boolean
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
/**
 * @brief Upsert an action: create if absent, update if exists.
 * @param {uuid} pId - Action identifier (NULL to look up by code)
 * @param {text} pCode - Action code
 * @param {text} pName - Display name
 * @param {text} pDescription - Description (optional)
 * @return {uuid} - Action identifier (existing or newly created)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetAction (
  pId            uuid,
  pCode          text,
  pName          text,
  pDescription   text DEFAULT null
) RETURNS        uuid
AS $$
DECLARE
  uId            uuid;
BEGIN
  uId := coalesce(pId, GetAction(pCode));

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
/**
 * @brief Look up an action identifier by its unique code.
 * @param {text} pCode - Action code
 * @return {uuid} - Action identifier or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAction (
  pCode       text
) RETURNS     uuid
AS $$
  SELECT id FROM db.action WHERE code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetActionCode ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the code of an action by its identifier.
 * @param {uuid} pId - Action identifier
 * @return {text} - Action code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetActionCode (
  pId        uuid
) RETURNS    text
AS $$
  SELECT code FROM db.action WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetActionName ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the localised name of an action.
 * @param {uuid} pId - Action identifier
 * @return {text} - Localised action name for the current locale
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetActionName (
  pId       uuid
) RETURNS   text
AS $$
  SELECT name FROM db.action_text WHERE action = pId AND locale = current_locale();
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewMethodText ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new locale-specific label for a method.
 * @param {uuid} pMethod - Method to attach the label to
 * @param {text} pLabel - Localised display label
 * @param {uuid} pLocale - Target locale (defaults to session locale)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewMethodText (
  pMethod   uuid,
  pLabel    text,
  pLocale   uuid DEFAULT current_locale()
) RETURNS   void
AS $$
BEGIN
  INSERT INTO db.method_text (method, locale, label)
  VALUES (pMethod, pLocale, pLabel);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditMethodText --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update a locale-specific label for a method, inserting if absent.
 * @param {uuid} pMethod - Method whose label is being edited
 * @param {text} pLabel - New label (NULL keeps existing)
 * @param {uuid} pLocale - Target locale
 * @return {void}
 * @see NewMethodText
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditMethodText (
  pMethod       uuid,
  pLabel        text,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.method_text
     SET label = coalesce(pLabel, label)
   WHERE method = pMethod AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewMethodText(pMethod, pLabel, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddMethod ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new method binding a class, state, and action with localised labels.
 * @param {uuid} pParent - Parent method for nested/sub-menu hierarchy (optional)
 * @param {uuid} pClass - Class this method belongs to
 * @param {uuid} pState - State in which this method is available (NULL = any)
 * @param {uuid} pAction - Action this method performs
 * @param {text} pCode - Method code (auto-generated from state:action if NULL)
 * @param {text} pLabel - Display label (defaults to action name if NULL)
 * @param {integer} pSequence - Display order (auto-incremented if NULL)
 * @param {boolean} pVisible - Whether this method is visible in the UI
 * @return {uuid} - Identifier of the newly created method
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddMethod (
  pParent   uuid,
  pClass    uuid,
  pState    uuid,
  pAction   uuid,
  pCode     text DEFAULT null,
  pLabel    text DEFAULT null,
  pSequence integer DEFAULT null,
  pVisible  boolean DEFAULT null
) RETURNS   uuid
AS $$
DECLARE
  l         record;
  uId       uuid;
BEGIN
  IF pSequence IS NULL THEN
    SELECT coalesce(max(sequence), 0) + 1 INTO pSequence
      FROM db.method
     WHERE class = pClass
       AND state IS NOT DISTINCT FROM pState;
  END IF;

  INSERT INTO db.method (parent, class, state, action, code, sequence, visible)
  VALUES (pParent, pClass, pState, pAction, pCode, pSequence, coalesce(pVisible, true))
  RETURNING id INTO uId;

  pLabel := coalesce(pLabel, GetActionName(pAction));

  FOR l IN SELECT id FROM db.locale
  LOOP
    PERFORM NewMethodText(uId, pLabel, l.id);
  END LOOP;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditMethod ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing method and its current-locale label.
 * @param {uuid} pId - Method to update
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
CREATE OR REPLACE FUNCTION EditMethod (
  pId       uuid,
  pParent   uuid DEFAULT null,
  pClass    uuid DEFAULT null,
  pState    uuid DEFAULT null,
  pAction   uuid DEFAULT null,
  pCode     text DEFAULT null,
  pLabel    text default null,
  pSequence integer default null,
  pVisible  boolean default null
) RETURNS   void
AS $$
BEGIN
  UPDATE db.method
     SET parent = CheckNull(coalesce(pParent, parent, null_uuid())),
         class = coalesce(pClass, class),
         state = coalesce(pState, state),
         action = coalesce(pAction, action),
         code = coalesce(pCode, code),
         sequence = coalesce(pSequence, sequence),
         visible = coalesce(pVisible, visible)
   WHERE id = pId;

  PERFORM EditMethodText(pId, pLabel, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteMethod -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a method and its related stack entries.
 * @param {uuid} pId - Method to delete
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteMethod (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  DELETE FROM db.method_stack WHERE method = pId;
  DELETE FROM db.method WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetMethod ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Find a method by class, action, and state, walking up the non-abstract class hierarchy.
 * @param {uuid} pClass - Class to start searching from
 * @param {uuid} pAction - Action to match
 * @param {uuid} pState - State to match (NULL = stateless methods)
 * @return {uuid} - Method identifier (deepest match) or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetMethod (
  pClass    uuid,
  pAction   uuid,
  pState    uuid DEFAULT null
) RETURNS   uuid
AS $$
DECLARE
  uMethod   uuid;
BEGIN
  WITH RECURSIVE _class_tree(id, parent, level) AS (
    SELECT id, parent, level FROM db.class_tree WHERE id = pClass
    UNION
    SELECT c.id, c.parent, c.level FROM db.class_tree c INNER JOIN _class_tree ct ON ct.parent = c.id AND NOT c.abstract
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
/**
 * @brief Check whether a method is visible in the UI.
 * @param {uuid} pId - Method identifier
 * @return {bool} - True if visible
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsVisibleMethod (
  pId       uuid
) RETURNS   bool
AS $$
  SELECT visible FROM db.method WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsHiddenMethod -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether a method is hidden from the UI.
 * @param {uuid} pId - Method identifier
 * @return {bool} - True if hidden (not visible)
 * @see IsVisibleMethod
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION IsHiddenMethod (
  pId       uuid
) RETURNS   bool
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
/**
 * @brief Compute aggregated AMU permissions for a user across all methods.
 * @param {uuid} pUserId - User or group to evaluate
 * @return {SETOF record} - (method, deny, allow, mask) per method
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION amu (
  pUserId       uuid,
  OUT method    uuid,
  OUT deny      bit,
  OUT allow     bit,
  OUT mask      bit
) RETURNS       SETOF record
AS $$
  SELECT a.method, bit_or(a.deny), bit_or(a.allow), bit_or(a.allow) & ~bit_or(a.deny)
    FROM db.amu a
   WHERE userid IN (SELECT pUserId UNION SELECT userid FROM db.member_group WHERE member = pUserId)
   GROUP BY a.method
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION amu ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Compute aggregated AMU permissions for a user on a specific method.
 * @param {uuid} pUserId - User or group to evaluate
 * @param {uuid} pMethod - Method to check permissions for
 * @return {SETOF record} - (method, deny, allow, mask)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION amu (
  pUserId       uuid,
  pMethod       uuid,
  OUT method    uuid,
  OUT deny      bit,
  OUT allow     bit,
  OUT mask      bit
) RETURNS       SETOF record
AS $$
  SELECT a.method, bit_or(a.deny), bit_or(a.allow), bit_or(a.allow) & ~bit_or(a.deny)
    FROM db.amu a
   WHERE userid IN (SELECT pUserId UNION SELECT userid FROM db.member_group WHERE member = pUserId)
     AND a.method = pMethod
   GROUP BY a.method
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetMethodAccessMask ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the effective AMU bitmask for a method and user.
 * @param {uuid} pMethod - Method to check
 * @param {uuid} pUserId - User (defaults to current session user)
 * @return {bit} - 3-bit effective access mask {xve}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetMethodAccessMask (
  pMethod    uuid,
  pUserId    uuid default current_userid()
) RETURNS    bit
AS $$
  SELECT mask FROM amu(pUserId, pMethod)
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckMethodAccess -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether a user has specific access bits on a method.
 * @param {uuid} pMethod - Method to check
 * @param {bit} pMask - Required permission bits
 * @param {uuid} pUserId - User (defaults to current session user)
 * @return {boolean} - True if all requested bits are granted
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckMethodAccess (
  pMethod    uuid,
  pMask      bit,
  pUserId    uuid default current_userid()
) RETURNS    boolean
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
/**
 * @brief Decode the AMU bitmask into individual boolean flags for a method.
 * @param {uuid} pMethod - Method to decode access for
 * @param {uuid} pUserId - User (defaults to current session user)
 * @return {record} - (x=execute, v=visible, e=enable)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DecodeMethodAccess (
  pMethod    uuid,
  pUserId    uuid default current_userid(),
  OUT x      boolean,
  OUT v      boolean,
  OUT e      boolean
) RETURNS    record
AS $$
DECLARE
  bMask      bit(3);
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
/**
 * @brief List all users/groups that have AMU entries for a method.
 * @param {uuid} pMethod - Method to inspect
 * @return {SETOF MethodMembers} - Users/groups with their permission bits
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetMethodMembers (
  pMethod    uuid
) RETURNS    SETOF MethodMembers
AS $$
  SELECT * FROM MethodMembers WHERE method = pMethod;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- chmodm ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the access bitmask for a method and user.
 * @param {uuid} pMethod - Method to modify permissions for
 * @param {bit} pMask - 6-bit mask (deny:{xve} allow:{xve}); NULL removes the entry
 * @param {uuid} pUserId - User or group (defaults to current session user)
 * @return {void}
 * @throws AccessDenied - When the caller is not an administrator
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION chmodm (
  pMethod    uuid,
  pMask      bit,
  pUserId    uuid default current_userid()
) RETURNS    void
AS $$
DECLARE
  bDeny      bit(3);
  bAllow     bit(3);
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

  DELETE FROM db.oma WHERE method = pMethod;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddTransition ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new state transition record.
 * @param {uuid} pState - Current state (NULL for initial transitions)
 * @param {uuid} pMethod - Method that triggers the transition
 * @param {uuid} pNewState - Target state after the transition
 * @return {uuid} - Identifier of the newly created transition
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddTransition (
  pState     uuid,
  pMethod    uuid,
  pNewState  uuid
) RETURNS    uuid
AS $$
DECLARE
  uId        uuid;
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
/**
 * @brief Update an existing state transition.
 * @param {uuid} pId - Transition to update
 * @param {uuid} pState - New current state (NULL keeps existing)
 * @param {uuid} pMethod - New method (NULL keeps existing)
 * @param {uuid} pNewState - New target state (NULL keeps existing)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditTransition (
  pId       uuid,
  pState    uuid default null,
  pMethod   uuid default null,
  pNewState uuid default null
) RETURNS   void
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
/**
 * @brief Delete a state transition by its identifier.
 * @param {uuid} pId - Transition to delete
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteTransition (
  pId       uuid
) RETURNS   void
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
/**
 * @brief Look up an event type identifier by its code.
 * @param {text} pCode - Event type code (e.g. "before", "after", "execute")
 * @return {uuid} - Event type identifier or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetEventType (
  pCode     text
) RETURNS   uuid
AS $$
DECLARE
  uId       uuid;
BEGIN
  SELECT id INTO uId FROM db.event_type WHERE code = pCode;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewEventText ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new locale-specific label for an event.
 * @param {uuid} pEvent - Event to attach the label to
 * @param {text} pLabel - Localised display label
 * @param {uuid} pLocale - Target locale (defaults to session locale)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewEventText (
  pEvent    uuid,
  pLabel    text,
  pLocale   uuid DEFAULT current_locale()
) RETURNS   void
AS $$
BEGIN
  INSERT INTO db.event_text (event, locale, label)
  VALUES (pEvent, pLocale, pLabel);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditEventText ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update a locale-specific label for an event, inserting if absent.
 * @param {uuid} pEvent - Event whose label is being edited
 * @param {text} pLabel - New label (NULL keeps existing)
 * @param {uuid} pLocale - Target locale
 * @return {void}
 * @see NewEventText
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditEventText (
  pEvent    uuid,
  pLabel    text,
  pLocale   uuid DEFAULT null
) RETURNS   void
AS $$
BEGIN
  UPDATE db.event_text
     SET label = coalesce(pLabel, label)
   WHERE event = pEvent AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewEventText(pEvent, pLabel, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddEvent -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new workflow event handler for a class and action.
 * @param {uuid} pClass - Class this event is bound to
 * @param {uuid} pType - Event type (before, after, execute)
 * @param {uuid} pAction - Action that triggers this event
 * @param {text} pLabel - Display label (replicated to all locales)
 * @param {text} pText - PL/pgSQL code body to execute (optional)
 * @param {integer} pSequence - Execution order (auto-incremented if NULL)
 * @param {boolean} pEnabled - Whether the handler is active
 * @return {uuid} - Identifier of the newly created event
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddEvent (
  pClass    uuid,
  pType     uuid,
  pAction   uuid,
  pLabel    text,
  pText     text default null,
  pSequence integer default null,
  pEnabled  boolean default true
) RETURNS   uuid
AS $$
DECLARE
  l         record;
  uId       uuid;
BEGIN
  IF pSequence IS NULL THEN
    SELECT coalesce(max(sequence), 0) + 1 INTO pSequence FROM db.event WHERE class = pClass AND action = pAction;
  END IF;

  INSERT INTO db.event (class, type, action, text, sequence, enabled)
  VALUES (pClass, pType, pAction, NULLIF(pText, ''), pSequence, pEnabled)
  RETURNING id INTO uId;

  FOR l IN SELECT id FROM db.locale
  LOOP
    PERFORM NewEventText(uId, pLabel, l.id);
  END LOOP;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditEvent ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing workflow event handler.
 * @param {uuid} pId - Event to update
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
CREATE OR REPLACE FUNCTION EditEvent (
  pId       uuid,
  pClass    uuid default null,
  pType     uuid default null,
  pAction   uuid default null,
  pLabel    text default null,
  pText     text default null,
  pSequence integer default null,
  pEnabled  boolean default null
) RETURNS   void
AS $$
BEGIN
  UPDATE db.event
     SET class = coalesce(pClass, class),
         type = coalesce(pType, type),
         action = coalesce(pAction, action),
         text = NULLIF(coalesce(pText, text), ''),
         sequence = coalesce(pSequence, sequence),
         enabled = coalesce(pEnabled, enabled)
   WHERE id = pId;

  PERFORM EditEventText(pId, pLabel, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteEvent --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a workflow event by its identifier.
 * @param {uuid} pId - Event to delete
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteEvent (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  DELETE FROM db.event WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewPriorityText -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new locale-specific text row for a priority level.
 * @param {uuid} pPriority - Priority to attach the text to
 * @param {text} pName - Localised display name
 * @param {text} pDescription - Localised description (optional)
 * @param {uuid} pLocale - Target locale (defaults to session locale)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewPriorityText (
  pPriority     uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       void
AS $$
BEGIN
  INSERT INTO db.priority_text (priority, locale, name, description)
  VALUES (pPriority, pLocale, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditPriorityText ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update locale-specific text for a priority, inserting if absent.
 * @param {uuid} pPriority - Priority whose text is being edited
 * @param {text} pName - New display name (NULL keeps existing)
 * @param {text} pDescription - New description (NULL keeps existing)
 * @param {uuid} pLocale - Target locale
 * @return {void}
 * @see NewPriorityText
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditPriorityText (
  pPriority     uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.priority_text
     SET name = coalesce(pName, name),
         description = CheckNull(coalesce(pDescription, description, ''))
   WHERE priority = pPriority AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewPriorityText(pPriority, pName, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddPriority --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new priority level with localised text for every locale.
 * @param {uuid} pId - Pre-assigned priority identifier
 * @param {text} pCode - Unique priority code
 * @param {text} pName - Display name (replicated to all locales)
 * @param {text} pDescription - Description (optional)
 * @return {uuid} - Identifier of the newly created priority
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddPriority (
  pId           uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  l             record;
  uId           uuid;
BEGIN
  INSERT INTO db.priority (id, code)
  VALUES (pId, pCode)
  RETURNING id INTO uId;

  FOR l IN SELECT id FROM db.locale
  LOOP
    PERFORM NewPriorityText(uId, pName, pDescription, l.id);
  END LOOP;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditPriority -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing priority level and its current-locale text.
 * @param {uuid} pId - Priority to update
 * @param {text} pCode - New code (NULL keeps existing)
 * @param {text} pName - New display name (NULL keeps existing)
 * @param {text} pDescription - New description (NULL keeps existing)
 * @return {boolean} - True if the priority was found and updated
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditPriority (
  pId           uuid,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       boolean
AS $$
BEGIN
  UPDATE db.priority
     SET code = coalesce(pCode, code)
   WHERE id = pId;

  IF FOUND THEN
    PERFORM EditPriorityText(pId, pName, pDescription, current_locale());
    RETURN true;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeletePriority -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a priority level by its identifier.
 * @param {uuid} pId - Priority to delete
 * @return {boolean} - True if the priority was found and deleted
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeletePriority (
  pId        uuid
) RETURNS    boolean
AS $$
BEGIN
  DELETE FROM db.priority WHERE id = pId;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetPriority --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a priority level: create if absent, update if exists.
 * @param {uuid} pId - Priority identifier (NULL to look up by code)
 * @param {text} pCode - Priority code
 * @param {text} pName - Display name
 * @param {text} pDescription - Description (optional)
 * @return {uuid} - Priority identifier (existing or newly created)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetPriority (
  pId            uuid,
  pCode          text,
  pName          text,
  pDescription   text DEFAULT null
) RETURNS        uuid
AS $$
DECLARE
  uId            uuid;
BEGIN
  uId := coalesce(pId, GetPriority(pCode));

  IF uId IS NULL THEN
    uId := AddPriority(gen_kernel_uuid('b'), pCode, pName, pDescription);
  ELSE
    PERFORM EditPriority(uId, pCode, pName, pDescription);
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetPriority --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a priority identifier by its unique code.
 * @param {text} pCode - Priority code
 * @return {uuid} - Priority identifier or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetPriority (
  pCode       text
) RETURNS     uuid
AS $$
  SELECT id FROM db.priority WHERE code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetPriorityCode ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the code of a priority level by its identifier.
 * @param {uuid} pId - Priority identifier
 * @return {text} - Priority code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetPriorityCode (
  pId        uuid
) RETURNS    text
AS $$
  SELECT code FROM db.priority WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetPriorityName ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the localised name of a priority level.
 * @param {uuid} pId - Priority identifier
 * @return {text} - Localised priority name for the current locale
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetPriorityName (
  pId       uuid
) RETURNS   text
AS $$
  SELECT name FROM db.priority_text WHERE priority = pId AND locale = current_locale();
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
