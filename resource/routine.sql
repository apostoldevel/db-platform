--------------------------------------------------------------------------------
-- FUNCTION SetResourceSequence ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetResourceSequence (
  pId		uuid,
  pSequence	integer,
  pDelta	integer
) RETURNS 	void
AS $$
DECLARE
  nId		uuid;
  nNode     uuid;
BEGIN
  IF pDelta <> 0 THEN
    SELECT node INTO nNode FROM db.resource WHERE id = pId;
    SELECT id INTO nId
      FROM db.resource
     WHERE coalesce(node, null_uuid()) = coalesce(nNode, null_uuid())
       AND sequence = pSequence
       AND id <> pId;

    IF found THEN
      PERFORM SetResourceSequence(nId, pSequence + pDelta, pDelta);
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

CREATE OR REPLACE FUNCTION SortResource (
  pNode     uuid
) RETURNS 	void
AS $$
DECLARE
  r         record;
BEGIN
  FOR r IN
    SELECT id, (row_number() OVER(order by sequence))::int as newsequence
      FROM db.resource
     WHERE coalesce(node, null_uuid()) = coalesce(pNode, null_uuid())
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

CREATE OR REPLACE FUNCTION SetResourceData (
  pResource	    uuid,
  pLocale		uuid,
  pName			text,
  pDescription	text,
  pEncoding		text,
  pData			text
) RETURNS 	    void
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
 * Создаёт ресурс
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pRoot - Идентификатор корневого узла (Передать null для создания корневого узла)
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pType - MIME тип
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {text} pEncoding - Кодировка
 * @param {text} pData - Данные
 * @param {integer} pSequence - Очерёдность
 * @param {uuid} pLocale - Локаль
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateResource (
  pId           uuid,
  pRoot         uuid,
  pNode         uuid,
  pType     	text,
  pName         text,
  pDescription	text DEFAULT null,
  pEncoding		text DEFAULT null,
  pData			text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocale		uuid DEFAULT current_locale()
) RETURNS       uuid
AS $$
DECLARE
  uResource		uuid;
  nLevel        integer;
BEGIN
  nLevel := 0;

  IF pNode IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.resource WHERE id = pNode;
  END IF;

  IF NULLIF(pSequence, 0) IS NULL THEN
    SELECT max(sequence) + 1 INTO pSequence FROM db.resource WHERE coalesce(node, null_uuid()) = coalesce(pNode, null_uuid());
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
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateResource --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет ресурс
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pRoot - Идентификатор корневого узла
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pType - MIME тип
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {text} pEncoding - Кодировка
 * @param {text} pData - Данные
 * @param {integer} pSequence - Очерёдность
 * @param {uuid} pLocale - Локаль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION UpdateResource (
  pId           uuid,
  pRoot         uuid DEFAULT null,
  pNode         uuid DEFAULT null,
  pType			text DEFAULT null,
  pName         text DEFAULT null,
  pDescription	text DEFAULT null,
  pEncoding		text DEFAULT null,
  pData			text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocale		uuid DEFAULT current_locale()
) RETURNS       void
AS $$
DECLARE
  nNode         uuid;

  nSequence     integer;
  nLevel	    integer;
BEGIN
  IF pNode IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.resource WHERE id = pNode;
  END IF;

  SELECT node, sequence INTO nNode, nSequence FROM db.resource WHERE id = pId;

  pNode := coalesce(pNode, nNode, null_uuid());
  pSequence := coalesce(pSequence, nSequence);

  UPDATE db.resource
     SET root = coalesce(pRoot, root),
         node = CheckNull(pNode),
         type = coalesce(pType, type),
         level = coalesce(nLevel, level),
         sequence = pSequence
   WHERE id = pId;

  PERFORM SetResourceData(pId, pLocale, pName, pDescription, pEncoding, pData);

  IF coalesce(nNode, null_uuid()) <> coalesce(pNode, null_uuid()) THEN
    SELECT max(sequence) + 1 INTO nSequence FROM db.resource WHERE coalesce(node, null_uuid()) = coalesce(pNode, null_uuid());
    PERFORM SortResource(nNode);
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
 * Устанавливает ресурс
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pRoot - Идентификатор корневого узла
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pType - MIME тип
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {text} pEncoding - Кодировка
 * @param {text} pData - Данные
 * @param {integer} pSequence - Очерёдность
 * @param {uuid} pLocale - Локаль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetResource (
  pId           uuid,
  pRoot         uuid DEFAULT null,
  pNode         uuid DEFAULT null,
  pType			text DEFAULT null,
  pName         text DEFAULT null,
  pDescription	text DEFAULT null,
  pEncoding		text DEFAULT null,
  pData			text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocale		uuid DEFAULT current_locale()
) RETURNS       uuid
AS $$
DECLARE
  uResource		uuid;
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

CREATE OR REPLACE FUNCTION GetResource (
  pResource	    uuid,
  pLocale		uuid DEFAULT current_locale()
) RETURNS		text
AS $$
DECLARE
  vData			text;
BEGIN
  SELECT data INTO vData FROM db.resource_data WHERE resource = pResource AND locale = pLocale;
  RETURN vData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
