--------------------------------------------------------------------------------
-- CreateVersion ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт версию
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION CreateVersion (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         varchar,
  pDescription	text default null
) RETURNS       numeric
AS $$
DECLARE
  nReference	numeric;
  nClass        numeric;
  nMethod       numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'version' THEN
    PERFORM IncorrectClassType();
  END IF;

  nReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.version (id, reference)
  VALUES (nReference, nReference);

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  RETURN nReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditVersion -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует версию
 * @param {numeric} pId - Идентификатор
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditVersion (
  pId           numeric,
  pParent       numeric default null,
  pType         numeric default null,
  pCode         varchar default null,
  pName         varchar default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nClass        numeric;
  nMethod       numeric;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription);

  SELECT class INTO nClass FROM db.object WHERE id = pId;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetVersion ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetVersion (
  pCode		varchar
) RETURNS 	numeric
AS $$
BEGIN
  RETURN GetReference(pCode, 'version');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
