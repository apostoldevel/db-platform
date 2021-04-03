--------------------------------------------------------------------------------
-- CreateModel -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт модель
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pVendor - Производитель
 * @param {uuid} pCategory - Категория
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateModel (
  pParent       uuid,
  pType         uuid,
  pVendor       uuid,
  pCategory		uuid,
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

  IF GetEntityCode(uClass) <> 'model' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.model (id, reference, vendor, category)
  VALUES (uReference, uReference, pVendor, pCategory);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditModel -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует модель
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pVendor - Производитель
 * @param {uuid} pCategory - Категория
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditModel (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pVendor       uuid default null,
  pCategory		uuid default null,
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

  UPDATE db.model
     SET vendor = coalesce(pVendor, vendor),
         category = CheckNull(coalesce(pCategory, category, null_uuid()))
   WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetModel -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetModel (
  pCode		text
) RETURNS 	uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'model');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetModelVendor -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetModelVendor (
  pId       uuid
) RETURNS 	uuid
AS $$
  SELECT vendor FROM db.model WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetModelCategory ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetModelCategory (
  pId       uuid
) RETURNS 	uuid
AS $$
  SELECT category FROM db.model WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetModelProperty ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetModelProperty (
  pModel		uuid,
  pProperty		uuid,
  pMeasure		uuid,
  pValue		variant,
  pFormat		text,
  pSequence		integer DEFAULT null
) RETURNS		void
AS $$
DECLARE
  r				record;
BEGIN
  IF pSequence IS NULL THEN
  	SELECT max(sequence) + 1 INTO pSequence FROM db.model_property WHERE model = pModel;
  END IF;

  SELECT * INTO r FROM db.model_property WHERE model = pModel AND property = pProperty;

  pMeasure := CheckNull(coalesce(pMeasure, r.measure, null_uuid()));

  INSERT INTO db.model_property (model, property, measure, value, format, sequence)
  VALUES (pModel, pProperty, pMeasure, pValue, pFormat, coalesce(pSequence, 1))
    ON CONFLICT (model, property) DO UPDATE SET measure = pMeasure, value = coalesce(pValue, r.value), format = coalesce(pFormat, r.format), sequence = coalesce(pSequence, r.sequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteModelProperty ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteModelProperty (
  pModel		uuid,
  pProperty		uuid DEFAULT null
) RETURNS		boolean
AS $$
BEGIN
  IF pProperty IS NOT NULL THEN
    DELETE FROM db.model_property WHERE model = pModel AND property = pProperty;
  ELSE
    DELETE FROM db.model_property WHERE model = pModel;
  END IF;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetModelPropertyJson --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetModelPropertyJson (
  pModel	uuid
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  FOR r IN
    SELECT *
      FROM ModelPropertyJson
     WHERE modelId = pModel
     ORDER BY sequence
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetModelPropertyJsonb -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetModelPropertyJsonb (
  pObject	uuid
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetModelPropertyJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
