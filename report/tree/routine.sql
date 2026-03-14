--------------------------------------------------------------------------------
-- CreateReportTree ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new report tree node and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier (root, node, or report)
 * @param {uuid} pRoot - Root node identifier (pass NULL or null_uuid() to create a root node)
 * @param {uuid} pNode - Parent node in the hierarchy (NULL for root nodes)
 * @param {text} pCode - Unique string code
 * @param {text} pName - Human-readable name
 * @param {text} pDescription - Detailed description
 * @param {integer} pSequence - Display order among siblings (auto-assigned if NULL)
 * @return {uuid} - Identifier of the newly created tree node
 * @throws IncorrectClassType - When pType does not belong to the 'report_tree' entity
 * @throws InvalidReportType - When node type violates hierarchy rules
 * @see EditReportTree, GetReportTree
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateReportTree (
  pParent       uuid,
  pType         uuid,
  pRoot         uuid,
  pNode         uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null,
  pSequence     integer default null
) RETURNS       uuid
AS $$
DECLARE
  uRoot         uuid;
  uReference    uuid;
  uClass        uuid;
  uMethod       uuid;

  nLevel        integer;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'report_tree' THEN
    PERFORM IncorrectClassType();
  END IF;

  nLevel := 0;
  pRoot := CheckNull(pRoot);
  pNode := CheckNull(pNode);

  IF pNode IS NOT NULL THEN
    IF GetTypeCode(pType) = 'root.report_tree' THEN
      PERFORM InvalidReportType();
    END IF;

    IF GetTypeCode(pType) = 'node.report_tree' THEN
      IF GetTypeCode(GetObjectType(pNode)) = 'report.report_tree' THEN
        PERFORM InvalidReportType();
      END IF;
    END IF;

    SELECT root, level + 1 INTO uRoot, nLevel FROM db.report_tree WHERE id = pNode;
  ELSE
    IF GetTypeCode(pType) != 'root.report_tree' THEN
      PERFORM InvalidReportType();
    END IF;
  END IF;

  IF NULLIF(pSequence, 0) IS NULL THEN
    SELECT max(sequence) + 1 INTO pSequence FROM db.report_tree WHERE node IS NOT DISTINCT FROM pNode;
  ELSE
    PERFORM SetReportTreeSequence(pNode, pSequence, 1);
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  pRoot := coalesce(pRoot, uRoot, uReference);

  IF pRoot IS NOT DISTINCT FROM uReference THEN
    pNode := null;
  END IF;

  INSERT INTO db.report_tree (id, reference, root, node, level, sequence)
  VALUES (uReference, uReference, pRoot, pNode, nLevel, coalesce(pSequence, 1));

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReportTree --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing report tree node (NULL parameters keep current values).
 * @param {uuid} pId - Tree node identifier
 * @param {uuid} pParent - New parent object or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {uuid} pRoot - New root node or NULL to keep
 * @param {uuid} pNode - New parent node or NULL to keep
 * @param {text} pCode - New code or NULL to keep
 * @param {text} pName - New name or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @param {integer} pSequence - New display order or NULL to keep
 * @return {void}
 * @see CreateReportTree, SortReportTree
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditReportTree (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pRoot         uuid default null,
  pNode         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text DEFAULT null,
  pSequence     integer default null
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
  uRoot         uuid;
  uNode         uuid;
  uClass        uuid;
  uMethod       uuid;

  nSequence     integer;
  nLevel        integer;
BEGIN
  SELECT root, node, level, sequence INTO uRoot, uNode, nLevel, nSequence FROM db.report_tree WHERE id = pId;

  pRoot := coalesce(CheckNull(pRoot), uRoot);
  pNode := coalesce(CheckNull(pNode), uNode);
  pSequence := coalesce(pSequence, nSequence);

  IF pId IS NOT DISTINCT FROM pRoot THEN
    pNode := null;
  END IF;

  IF pNode IS NOT NULL THEN
    IF pId IS NOT DISTINCT FROM pNode THEN
      pNode := uNode;
    ELSE
      SELECT node, level + 1 INTO uId, nLevel FROM db.report_tree WHERE id = pNode;
      IF uId IS NOT DISTINCT FROM pId THEN
        UPDATE db.report_tree SET node = uNode WHERE id = pNode;
      END IF;
    END IF;
  END IF;

  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription, current_locale());

  UPDATE db.report_tree
     SET root = pRoot,
         node = pNode,
         level = coalesce(nLevel, level),
         sequence = pSequence
   WHERE id = pId;

  IF uNode IS DISTINCT FROM pNode THEN
    SELECT max(sequence) + 1 INTO nSequence FROM db.report_tree WHERE node IS NOT DISTINCT FROM pNode;
    PERFORM SortReportTree(uNode);
  END IF;

  IF pSequence < nSequence THEN
    PERFORM SetReportTreeSequence(pId, pSequence, 1);
  END IF;

  IF pSequence > nSequence THEN
    PERFORM SetReportTreeSequence(pId, pSequence, -1);
  END IF;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReportTree ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a report tree node identifier by its unique code.
 * @param {text} pCode - Unique tree node code
 * @return {uuid} - Tree node identifier or NULL if not found
 * @see CreateReportTree
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReportTree (
  pCode       text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'report_tree');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetReportTreeSequence ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the display order for a tree node, recursively shifting siblings to avoid collisions.
 * @param {uuid} pId - Tree node identifier
 * @param {integer} pSequence - Target sequence number
 * @param {integer} pDelta - Shift direction (+1 or -1) for displaced siblings; 0 = direct set
 * @return {void}
 * @see SortReportTree
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetReportTreeSequence (
  pId       uuid,
  pSequence integer,
  pDelta    integer
) RETURNS   void
AS $$
DECLARE
  uId        uuid;
  uNode     uuid;
BEGIN
  IF pDelta <> 0 THEN
    SELECT node INTO uNode FROM db.report_tree WHERE id = pId;
    SELECT id INTO uId
      FROM db.report_tree
     WHERE node IS NOT DISTINCT FROM uNode
       AND sequence = pSequence
       AND id <> pId;

    IF FOUND THEN
      PERFORM SetReportTreeSequence(uId, pSequence + pDelta, pDelta);
    END IF;
  END IF;

  UPDATE db.report_tree SET sequence = pSequence WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SortReportTree -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Re-number all children of a given parent node with consecutive sequence values.
 * @param {uuid} pNode - Parent node whose children to re-sort (NULL for root-level)
 * @return {void}
 * @see SetReportTreeSequence
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SortReportTree (
  pNode     uuid
) RETURNS   void
AS $$
DECLARE
  r         record;
BEGIN
  FOR r IN
    SELECT id, (row_number() OVER(order by sequence))::int as newsequence
      FROM db.report_tree
     WHERE node IS NOT DISTINCT FROM pNode
  LOOP
    PERFORM SetReportTreeSequence(r.id, r.newsequence, 0);
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
