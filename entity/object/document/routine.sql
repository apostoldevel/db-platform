--------------------------------------------------------------------------------
-- NewDocumentText -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new locale-specific text record for a document.
 * @param {uuid} pDocument - Document identifier
 * @param {text} pDescription - Localized description text
 * @param {uuid} pLocale - Locale identifier (defaults to current locale)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewDocumentText (
  pDocument     uuid,
  pDescription  text,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       void
AS $$
BEGIN
  INSERT INTO db.document_text (document, locale, description)
  VALUES (pDocument, pLocale, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditDocumentText ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update locale-specific text for a document, inserting if absent.
 * @param {uuid} pDocument - Document identifier
 * @param {text} pDescription - New description (NULL keeps current value)
 * @param {uuid} pLocale - Locale identifier (defaults to current locale)
 * @return {void}
 * @see NewDocumentText
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditDocumentText (
  pDocument     uuid,
  pDescription  text,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.document_text
     SET description = CheckNull(coalesce(pDescription, description, ''))
   WHERE document = pDocument AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewDocumentText(pDocument, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateDocument --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new document with localized text for all or a specific locale.
 * @param {uuid} pParent - Parent object reference
 * @param {uuid} pType - Document type identifier
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Localized description
 * @param {text} pText - Full-text content (falls back to pDescription)
 * @param {uuid} pLocale - Target locale (NULL populates all locales)
 * @param {uuid} pPriority - Priority level (defaults to normal)
 * @return {uuid} - Identifier of the created document
 * @see EditDocument
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateDocument (
  pParent       uuid,
  pType         uuid,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pText         text DEFAULT null,
  pLocale       uuid DEFAULT null,
  pPriority     uuid DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  l             record;

  uObject       uuid;
  uEntity       uuid;
  uClass        uuid;
BEGIN
  uObject := CreateObject(pParent, pType, pLabel, coalesce(pText, pDescription));

  uEntity := GetObjectEntity(uObject);
  uClass := GetObjectClass(uObject);

  INSERT INTO db.document (id, object, entity, class, type, priority, area)
  VALUES (uObject, uObject, uEntity, uClass, pType, pPriority, current_area())
  RETURNING id INTO uObject;

  IF pLocale IS NULL THEN
    FOR l IN SELECT id FROM db.locale
    LOOP
      PERFORM NewDocumentText(uObject, pDescription, l.id);
    END LOOP;
  ELSE
    PERFORM NewDocumentText(uObject, pDescription, pLocale);
  END IF;

  RETURN uObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditDocument ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing document and its localized text.
 * @param {uuid} pId - Document identifier
 * @param {uuid} pParent - New parent object (NULL keeps current)
 * @param {uuid} pType - New document type (NULL keeps current)
 * @param {text} pLabel - New display label (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @param {text} pText - New full-text content (NULL keeps current)
 * @param {uuid} pLocale - Target locale (NULL updates all locales)
 * @param {uuid} pPriority - New priority level (NULL keeps current)
 * @return {void}
 * @see CreateDocument
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditDocument (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pText         text DEFAULT null,
  pLocale       uuid DEFAULT null,
  pPriority     uuid DEFAULT null
) RETURNS       void
AS $$
DECLARE
  l                record;
BEGIN
  PERFORM EditObject(pId, pParent, pType, pLabel, coalesce(pText, pDescription), pLocale);

  UPDATE db.document
     SET type = coalesce(pType, type),
         priority = coalesce(pPriority, priority)
   WHERE id = pId;

  IF pLocale IS NULL THEN
    FOR l IN SELECT id FROM db.locale
    LOOP
      PERFORM EditDocumentText(pId, pDescription, l.id);
    END LOOP;
  ELSE
    PERFORM EditDocumentText(pId, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDocumentDescription ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the localized description of a document.
 * @param {uuid} pDocument - Document identifier
 * @param {uuid} pLocale - Locale identifier (defaults to current locale)
 * @return {text} - Description text
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetDocumentDescription (
  pDocument     uuid,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       text
AS $$
  SELECT description FROM db.document_text WHERE document = pDocument AND locale = pLocale
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDocumentArea -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the visibility area assigned to a document.
 * @param {uuid} pDocument - Document identifier
 * @return {uuid} - Area identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetDocumentArea (
  pDocument     uuid
) RETURNS       uuid
AS $$
  SELECT area FROM db.document WHERE id = pDocument
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ChangeDocumentArea ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Reassign a document and all its children to a new visibility area.
 * @param {uuid} pId - Root document identifier
 * @param {uuid} pArea - Target area identifier
 * @return {void}
 * @throws ChangeAreaError - When the target area is outside the current scope
 * @see GetDocumentArea
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ChangeDocumentArea (
  pId           uuid,
  pArea         uuid
) RETURNS       void
AS $$
DECLARE
  r             record;
  uMethod       uuid;
BEGIN
  FOR r IN
    WITH RECURSIVE _tree(id, parent, class, area) AS (
      SELECT o.id, o.parent, o.class, d.area FROM db.object o INNER JOIN db.document d USING (id) WHERE o.id = pId
       UNION
      SELECT o.id, o.parent, o.class, d.area FROM db.object o INNER JOIN db.document d USING (id) INNER JOIN _tree t ON o.parent = t.id
    ) SELECT * FROM _tree t
  LOOP
    UPDATE db.document SET area = pArea WHERE id = r.id;

    uMethod := GetMethod(r.class, GetAction('save'));
    PERFORM ExecuteMethod(r.id, uMethod, jsonb_build_object('old', jsonb_build_object('area', r.area), 'new', jsonb_build_object('area', pArea)));
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
