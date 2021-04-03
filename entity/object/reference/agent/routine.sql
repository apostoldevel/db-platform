--------------------------------------------------------------------------------
-- CreateAgent -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт агента
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {uuid} pVendor - Производитель
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateAgent (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pVendor       uuid,
  pDescription	text default null
) RETURNS       uuid
AS $$
DECLARE
  uReference	uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'agent' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.agent (id, reference, vendor)
  VALUES (uReference, uReference, pVendor);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditAgent -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует агента
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {uuid} pVendor - Производитель
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditAgent (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pVendor       uuid default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  uClass        uuid;
  uMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription);

  UPDATE db.agent
     SET vendor = coalesce(pVendor, vendor)
   WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAgent -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAgent (
  pCode		text
) RETURNS 	uuid
AS $$
BEGIN
  IF StrPos(pCode, '.') = 0 THEN
    pCode := pCode || '.agent';
  END IF;

  RETURN GetReference(pCode, 'agent');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAgentVendor -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAgentVendor (
  pId       uuid
) RETURNS 	uuid
AS $$
  SELECT vendor FROM db.agent WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
