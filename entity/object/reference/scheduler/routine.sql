--------------------------------------------------------------------------------
-- CreateScheduler -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new job scheduler and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Type (must belong to 'scheduler' entity)
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {interval} pPeriod - Execution interval (e.g., '1 hour')
 * @param {timestamptz} pDateStart - Start of active window (NULL = now)
 * @param {timestamptz} pDateStop - End of active window (NULL = far future)
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created scheduler
 * @throws IncorrectClassType - When pType does not belong to scheduler entity
 * @see EditScheduler
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateScheduler (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pPeriod       interval default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
DECLARE
  uReference    uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'scheduler' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.scheduler (id, reference, period, dateStart, dateStop)
  VALUES (uReference, uReference, pPeriod, pDateStart, pDateStop);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditScheduler ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing scheduler (NULL params keep current values).
 * @param {uuid} pId - Scheduler to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {interval} pPeriod - New execution interval (NULL keeps current)
 * @param {timestamptz} pDateStart - New start date (NULL keeps current)
 * @param {timestamptz} pDateStop - New stop date (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @see CreateScheduler
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditScheduler (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pPeriod       interval default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription    text default null
) RETURNS       void
AS $$
DECLARE
  uClass        uuid;
  uMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription, current_locale());

  UPDATE db.scheduler
     SET period = coalesce(pPeriod, period),
         dateStart = coalesce(pDateStart, dateStart),
         dateStop = coalesce(pDateStop, dateStop)
   WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetScheduler -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a scheduler ID by its business code.
 * @param {text} pCode - Scheduler code
 * @return {uuid} - Scheduler ID or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetScheduler (
  pCode        text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'scheduler');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
