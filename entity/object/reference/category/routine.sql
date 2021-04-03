--------------------------------------------------------------------------------
-- CreateCategory --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт категорию
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateCategory (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription	text default null
) RETURNS       uuid
AS $$
DECLARE
  uReference	uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'category' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.category (id, reference)
  VALUES (uReference, uReference);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditCategory ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует категорию
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditCategory (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  uClass        uuid;
  uMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription);

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetCategory --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCategory (
  pCode		text
) RETURNS 	uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'category');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
