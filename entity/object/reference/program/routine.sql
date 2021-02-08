--------------------------------------------------------------------------------
-- CreateProgram ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт программу
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION CreateProgram (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         varchar,
  pBody         text,
  pDescription	text default null
) RETURNS       numeric
AS $$
DECLARE
  nReference	numeric;
  nClass        numeric;
  nMethod       numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'program' THEN
    PERFORM IncorrectClassType();
  END IF;

  nReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.program (reference, body)
  VALUES (nReference, pBody);

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  RETURN nReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditProgram -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует агента
 * @param {numeric} pId - Идентификатор
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditProgram (
  pId           numeric,
  pParent       numeric default null,
  pType         numeric default null,
  pCode         varchar default null,
  pName         varchar default null,
  pBody         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nClass        numeric;
  nMethod       numeric;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription);

  UPDATE db.program
     SET body = coalesce(pBody, body)
   WHERE id = pId;

  SELECT class INTO nClass FROM db.object WHERE id = pId;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProgram ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProgram (
  pCode		varchar
) RETURNS 	numeric
AS $$
BEGIN
  RETURN GetReference(pCode, 'program');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProgramBody -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProgramBody (
  pId       numeric
) RETURNS 	text
AS $$
  SELECT body FROM db.program WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
