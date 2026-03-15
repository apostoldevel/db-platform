--------------------------------------------------------------------------------
-- FUNCTION SetResourceSequence ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Reassign the sort position of a resource, shifting siblings recursively.
 * @param {uuid} pId - Resource whose position is being changed
 * @param {integer} pSequence - Target sequence number
 * @param {integer} pDelta - Shift direction (+1 / -1) for colliding siblings; 0 to set without shifting
 * @return {void}
 * @see SortResource
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetResourceSequence (
  pId           uuid,
  pSequence     integer,
  pDelta        integer
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
  uNode         uuid;
BEGIN
  IF pDelta <> 0 THEN
    SELECT node INTO uNode FROM db.resource WHERE id = pId;
    SELECT id INTO uId
      FROM db.resource
     WHERE node IS NOT DISTINCT FROM uNode
       AND sequence = pSequence
       AND id <> pId;

    IF FOUND THEN
      PERFORM SetResourceSequence(uId, pSequence + pDelta, pDelta);
    END IF;
  END IF;

  UPDATE db.resource SET sequence = pSequence WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SortResource -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Re-number all children of a parent node into a contiguous sequence.
 * @param {uuid} pNode - Parent node whose children are re-sorted
 * @return {void}
 * @see SetResourceSequence
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SortResource (
  pNode         uuid
) RETURNS       void
AS $$
DECLARE
  r             record;
BEGIN
  FOR r IN
    SELECT id, (row_number() OVER(order by sequence))::int as newsequence
      FROM db.resource
     WHERE node IS NOT DISTINCT FROM pNode
  LOOP
    PERFORM SetResourceSequence(r.id, r.newsequence, 0);
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetResourceData ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert locale-specific content for a resource node.
 * @param {uuid} pResource - Target resource
 * @param {uuid} pLocale - Locale for the content
 * @param {text} pName - Human-readable name / key
 * @param {text} pDescription - Longer description or label
 * @param {text} pEncoding - Character encoding of the data payload
 * @param {text} pData - Actual content payload
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetResourceData (
  pResource     uuid,
  pLocale       uuid,
  pName         text,
  pDescription  text,
  pEncoding     text,
  pData         text
) RETURNS       void
AS $$
BEGIN
  INSERT INTO db.resource_data (resource, locale, name, description, encoding, data)
  VALUES (pResource, pLocale, pName, pDescription, pEncoding, pData)
    ON CONFLICT (resource, locale) DO UPDATE
      SET name = pName,
          description = pDescription,
          encoding = pEncoding,
          data = pData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateResource --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new resource node in the tree with locale-specific content.
 * @param {uuid} pId - Explicit UUID or NULL to auto-generate
 * @param {uuid} pRoot - Root node of the tree (NULL to start a new tree)
 * @param {uuid} pNode - Parent node in the hierarchy
 * @param {text} pType - MIME type of the content
 * @param {text} pName - Human-readable name / key
 * @param {text} pDescription - Longer description or label
 * @param {text} pEncoding - Character encoding of the data payload
 * @param {text} pData - Actual content payload
 * @param {integer} pSequence - Sort position among siblings (auto-appended when NULL)
 * @param {uuid} pLocale - Locale for the content
 * @return {uuid} - ID of the newly created resource
 * @see SetResourceData, SetResourceSequence
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateResource (
  pId           uuid,
  pRoot         uuid,
  pNode         uuid,
  pType         text,
  pName         text,
  pDescription  text DEFAULT null,
  pEncoding     text DEFAULT null,
  pData         text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       uuid
AS $$
DECLARE
  uResource     uuid;
  nLevel        integer;
BEGIN
  nLevel := 0;

  IF pNode IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.resource WHERE id = pNode;
    IF NOT FOUND THEN
      nLevel := 0;
    END IF;
  END IF;

  IF NULLIF(pSequence, 0) IS NULL THEN
    SELECT max(sequence) + 1 INTO pSequence FROM db.resource WHERE node IS NOT DISTINCT FROM pNode;
  ELSE
    PERFORM SetResourceSequence(pNode, pSequence, 1);
  END IF;

  uResource := coalesce(pId, gen_random_uuid());

  INSERT INTO db.resource (id, root, node, type, level, sequence)
  VALUES (uResource, pRoot, pNode, pType, nLevel, pSequence);

  PERFORM SetResourceData(uResource, pLocale, pName, pDescription, pEncoding, pData);

  RETURN uResource;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- UpdateResource --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing resource node and its locale-specific content.
 * @param {uuid} pId - Resource to update
 * @param {uuid} pRoot - New root node (NULL to keep current)
 * @param {uuid} pNode - New parent node (NULL to keep current)
 * @param {text} pType - New MIME type (NULL to keep current)
 * @param {text} pName - New name (NULL to keep current)
 * @param {text} pDescription - New description (NULL to keep current)
 * @param {text} pEncoding - New encoding (NULL to keep current)
 * @param {text} pData - New content payload (NULL to keep current)
 * @param {integer} pSequence - New sort position (NULL to keep current)
 * @param {uuid} pLocale - Locale for the content
 * @return {void}
 * @see SetResourceData, SortResource
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION UpdateResource (
  pId           uuid,
  pRoot         uuid DEFAULT null,
  pNode         uuid DEFAULT null,
  pType         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null,
  pEncoding     text DEFAULT null,
  pData         text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       void
AS $$
DECLARE
  uNode         uuid;

  nSequence     integer;
  nLevel        integer;
BEGIN
  IF pNode IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.resource WHERE id = pNode;
    IF NOT FOUND THEN
      nLevel := 0;
    END IF;
  END IF;

  SELECT node, sequence INTO uNode, nSequence FROM db.resource WHERE id = pId;

  pNode := coalesce(pNode, uNode, null_uuid());
  pSequence := coalesce(pSequence, nSequence);

  UPDATE db.resource
     SET root = coalesce(pRoot, root),
         node = CheckNull(pNode),
         type = coalesce(pType, type),
         level = coalesce(nLevel, level),
         sequence = pSequence
   WHERE id = pId;

  PERFORM SetResourceData(pId, pLocale, pName, pDescription, pEncoding, pData);

  IF uNode IS DISTINCT FROM pNode THEN
    SELECT max(sequence) + 1 INTO nSequence FROM db.resource WHERE node IS NOT DISTINCT FROM pNode;
    PERFORM SortResource(uNode);
  END IF;

  IF pSequence < nSequence THEN
    PERFORM SetResourceSequence(pId, pSequence, 1);
  END IF;

  IF pSequence > nSequence THEN
    PERFORM SetResourceSequence(pId, pSequence, -1);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetResource -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a resource node (upsert by ID).
 * @param {uuid} pId - Resource ID (NULL to create new)
 * @param {uuid} pRoot - Root node of the tree
 * @param {uuid} pNode - Parent node in the hierarchy
 * @param {text} pType - MIME type of the content
 * @param {text} pName - Human-readable name / key
 * @param {text} pDescription - Longer description or label
 * @param {text} pEncoding - Character encoding of the data payload
 * @param {text} pData - Actual content payload
 * @param {integer} pSequence - Sort position among siblings
 * @param {uuid} pLocale - Locale for the content
 * @return {uuid} - ID of the created or existing resource
 * @see CreateResource, UpdateResource
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetResource (
  pId           uuid,
  pRoot         uuid DEFAULT null,
  pNode         uuid DEFAULT null,
  pType         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null,
  pEncoding     text DEFAULT null,
  pData         text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       uuid
AS $$
DECLARE
  uResource     uuid;
BEGIN
  IF pId IS NULL THEN
    uResource := CreateResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, pLocale);
  ELSE
    SELECT id INTO uResource FROM db.resource WHERE id = pId;
    IF NOT FOUND THEN
      uResource := CreateResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, pLocale);
    ELSE
      PERFORM UpdateResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, pLocale);
    END IF;
  END IF;

  RETURN uResource;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetResource --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the data payload of a resource for a given locale.
 * @param {uuid} pResource - Resource to look up
 * @param {uuid} pLocale - Locale (defaults to session locale)
 * @return {text} - Content payload or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetResource (
  pResource     uuid,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       text
AS $$
  SELECT data FROM db.resource_data WHERE resource = pResource AND locale = pLocale;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteResource --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a resource node and its locale data from the tree.
 * @param {uuid} pId - Resource to delete
 * @return {void}
 * @throws NotFound - When no resource exists with the given ID
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteResource (
  pId           uuid
) RETURNS       void
AS $$
BEGIN
  DELETE FROM db.resource WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM NotFound();
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
