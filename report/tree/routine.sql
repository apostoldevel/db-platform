--------------------------------------------------------------------------------
-- CreateReportTree ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт дерево отчётов
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pRoot - Идентификатор корневого узла (Передать null или null_uuid() для создания корневого узла)
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {integer} pSequence - Очерёдность
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateReportTree (
  pParent       uuid,
  pType         uuid,
  pRoot         uuid,
  pNode         uuid,
  pCode         text,
  pName         text,
  pDescription	text DEFAULT null,
  pSequence     integer default null
) RETURNS       uuid
AS $$
DECLARE
  uRoot			uuid;
  uReference	uuid;
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
    SELECT root, level + 1 INTO uRoot, nLevel FROM db.report_tree WHERE id = pNode;
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
 * Редактирует дерево отчётов
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pRoot - Идентификатор корневого узла
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {integer} pSequence - Очерёдность
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditReportTree (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pRoot         uuid default null,
  pNode         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text DEFAULT null,
  pSequence     integer default null
) RETURNS       void
AS $$
DECLARE
  uId			uuid;
  uRoot         uuid;
  uNode         uuid;
  uClass        uuid;
  uMethod       uuid;

  nSequence     integer;
  nLevel	    integer;
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

CREATE OR REPLACE FUNCTION GetReportTree (
  pCode		text
) RETURNS 	uuid
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

CREATE OR REPLACE FUNCTION SetReportTreeSequence (
  pId		uuid,
  pSequence	integer,
  pDelta	integer
) RETURNS 	void
AS $$
DECLARE
  uId		uuid;
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

CREATE OR REPLACE FUNCTION SortReportTree (
  pNode     uuid
) RETURNS 	void
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
