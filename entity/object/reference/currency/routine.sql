--------------------------------------------------------------------------------
-- CreateCurrency --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт валюту
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {integer} pDigital - Цифровой код
 * @param {integer} pDecimal - Количество знаков после запятой
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateCurrency (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription	text default null,
  pDigital		integer default null,
  pDecimal		integer default null
) RETURNS       uuid
AS $$
DECLARE
  nReference	uuid;
  nClass        uuid;
  nMethod       uuid;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'currency' THEN
    PERFORM IncorrectClassType();
  END IF;

  nReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.currency (id, reference, digital, decimal)
  VALUES (nReference, nReference, pDigital, pDecimal);

  nMethod := GetMethod(nClass, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  RETURN nReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditCurrency ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует валюту
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {integer} pDigital - Цифровой код
 * @param {integer} pDecimal - Количество знаков после запятой
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditCurrency (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null,
  pDigital		integer default null,
  pDecimal		integer default null
) RETURNS       void
AS $$
DECLARE
  nClass        uuid;
  nMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription);

  UPDATE db.currency
     SET digital = CheckNull(coalesce(pDigital, digital, 0)),
         decimal = coalesce(pDecimal, decimal)
   WHERE id = pId;

  SELECT class INTO nClass FROM db.object WHERE id = pId;

  nMethod := GetMethod(nClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetCurrency --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCurrency (
  pCode		text
) RETURNS 	uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'currency');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
