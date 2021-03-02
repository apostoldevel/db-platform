--------------------------------------------------------------------------------
-- CreateProperty --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт свойство
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateProperty (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription	text default null
) RETURNS       uuid
AS $$
DECLARE
  nReference	uuid;
  nClass        uuid;
  nMethod       uuid;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'property' THEN
    PERFORM IncorrectClassType();
  END IF;

  nReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.property (id, reference)
  VALUES (nReference, nReference);

  nMethod := GetMethod(nClass, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  RETURN nReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditProperty ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует свойство
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditProperty (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nClass        uuid;
  nMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription);

  SELECT class INTO nClass FROM db.object WHERE id = pId;

  nMethod := GetMethod(nClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProperty --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProperty (
  pCode		text
) RETURNS 	uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'property');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
