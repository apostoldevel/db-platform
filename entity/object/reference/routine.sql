--------------------------------------------------------------------------------
-- NewReferenceText ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new localized text row for a reference entry.
 * @param {uuid} pReference - Reference to attach text to
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @param {uuid} pLocale - Locale (defaults to current)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewReferenceText (
  pReference    uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       void
AS $$
BEGIN
  INSERT INTO db.reference_text (reference, locale, name, description)
  VALUES (pReference, pLocale, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReferenceText -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update localized text for a reference entry, or insert if missing.
 * @param {uuid} pReference - Reference to update text for
 * @param {text} pName - New display name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @param {uuid} pLocale - Locale to update
 * @return {void}
 * @see NewReferenceText
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditReferenceText (
  pReference    uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.reference_text
     SET name = CheckNull(coalesce(pName, name, '')),
         description = CheckNull(coalesce(pDescription, description, ''))
   WHERE reference = pReference AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewReferenceText(pReference, pName, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateReference -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new reference catalog entry with localized text for all locales.
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Type that determines the entity class
 * @param {text} pCode - Unique business code within scope + entity
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @param {uuid} pLocale - Locale (NULL = all locales)
 * @return {uuid} - ID of the created reference
 * @see EditReference
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateReference (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  l             record;

  uObject       uuid;
  uEntity       uuid;
  uClass        uuid;
BEGIN
  uObject := CreateObject(pParent, pType, pName, pDescription);

  uEntity := GetObjectEntity(uObject);
  uClass := GetObjectClass(uObject);

  INSERT INTO db.reference (id, object, scope, entity, class, type, code)
  VALUES (uObject, uObject, current_scope(), uEntity, uClass, pType, pCode)
  RETURNING id INTO uObject;

  IF pLocale IS NULL THEN
    FOR l IN SELECT id FROM db.locale
    LOOP
      PERFORM NewReferenceText(uObject, pName, pDescription, l.id);
    END LOOP;
  ELSE
    PERFORM NewReferenceText(uObject, pName, pDescription, pLocale);
  END IF;

  RETURN uObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReference ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing reference entry (NULL params keep current values).
 * @param {uuid} pId - Reference to update
 * @param {uuid} pParent - New parent object (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @param {uuid} pLocale - Locale (NULL = all locales)
 * @return {void}
 * @see CreateReference
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditReference (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
DECLARE
  l             record;
BEGIN
  PERFORM EditObject(pId, pParent, pType, pName, pDescription, pLocale);

  UPDATE db.reference
     SET type = coalesce(pType, type),
         code = coalesce(pCode, code)
   WHERE id = pId;

  IF pLocale IS NULL THEN
    FOR l IN SELECT id FROM db.locale
    LOOP
      PERFORM EditReferenceText(pId, pName, pDescription, l.id);
    END LOOP;
  ELSE
    PERFORM EditReferenceText(pId, pName, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReference -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a reference ID by entity, code, and scope.
 * @param {uuid} pEntity - Entity to search within
 * @param {text} pCode - Business code
 * @param {uuid} pScope - Scope (defaults to current)
 * @return {uuid} - Reference ID or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReference (
  pEntity       uuid,
  pCode         text,
  pScope        uuid DEFAULT current_scope()
) RETURNS       uuid
AS $$
  SELECT id FROM db.reference WHERE scope = pScope AND entity = pEntity AND code = pCode;
$$ LANGUAGE sql
   SECURITY DEFINER STABLE STRICT
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReference -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve a reference ID from a dot-prefixed code, auto-detecting entity.
 * @param {text} pCode - Business code (entity extracted from suffix after '.')
 * @param {text} pEntity - Entity code override (NULL = auto-detect)
 * @return {uuid} - Reference ID or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReference (
  pCode         text,
  pEntity       text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN GetReference(GetEntity(coalesce(pEntity, SubStr(pCode, StrPos(pCode, '.') + 1))), pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER STABLE
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReferenceCode ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the business code of a reference entry.
 * @param {uuid} pId - Reference ID
 * @return {text} - Business code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReferenceCode (
  pId           uuid
) RETURNS       text
AS $$
  SELECT code FROM db.reference WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER STABLE STRICT
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReferenceName ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the localized name of a reference entry.
 * @param {uuid} pId - Reference ID
 * @param {uuid} pLocale - Locale (defaults to current)
 * @return {text} - Display name
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReferenceName (
  pId           uuid,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       text
AS $$
  SELECT name FROM db.reference_text WHERE reference = pId AND locale = pLocale;
$$ LANGUAGE sql
   SECURITY DEFINER STABLE STRICT
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReferenceDescription --------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the localized description of a reference entry.
 * @param {uuid} pId - Reference ID
 * @param {uuid} pLocale - Locale (defaults to current)
 * @return {text} - Description text
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReferenceDescription (
  pId           uuid,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       text
AS $$
  SELECT description FROM db.reference_text WHERE reference = pId AND locale = pLocale;
$$ LANGUAGE sql
   SECURITY DEFINER STABLE STRICT
   SET search_path = kernel, pg_temp;
