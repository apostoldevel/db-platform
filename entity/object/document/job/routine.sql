--------------------------------------------------------------------------------
-- CreateJob -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new scheduled job linked to a scheduler and program.
 * @param {uuid} pParent - Parent object reference
 * @param {uuid} pType - Job type identifier (must belong to entity 'job')
 * @param {uuid} pScheduler - Scheduler that owns this job
 * @param {uuid} pProgram - Program to execute
 * @param {timestamptz} pDateRun - First execution timestamp (NULL defaults via scheduler period)
 * @param {text} pCode - Unique job code within scope (auto-generated if NULL)
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Job description
 * @return {uuid} - Identifier of the created job
 * @throws IncorrectClassType - When pType does not belong to the 'job' entity
 * @throws JobExists - When a job with the same code already exists in this scope
 * @see EditJob
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateJob (
  pParent           uuid,
  pType             uuid,
  pScheduler        uuid default null,
  pProgram          uuid default null,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           uuid
AS $$
DECLARE
  uDocument         uuid;
  uClass            uuid;
  uMethod           uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'job' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO uDocument FROM db.job WHERE scope = current_scope() AND code = pCode;

  IF FOUND THEN
    PERFORM JobExists(pCode);
  END IF;

  uDocument := CreateDocument(pParent, pType, pLabel, pDescription);

  INSERT INTO db.job (id, document, scope, code, scheduler, program, daterun)
  VALUES (uDocument, uDocument, current_scope(), pCode, pScheduler, pProgram, pDateRun);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uDocument, uMethod);

  RETURN uDocument;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditJob ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing job and trigger the "edit" workflow method.
 * @param {uuid} pId - Job identifier
 * @param {uuid} pParent - New parent object (NULL keeps current)
 * @param {uuid} pType - New job type (NULL keeps current)
 * @param {uuid} pScheduler - New scheduler (NULL keeps current)
 * @param {uuid} pProgram - New program (NULL keeps current)
 * @param {timestamptz} pDateRun - New execution timestamp (NULL keeps current)
 * @param {text} pCode - New job code (NULL keeps current)
 * @param {text} pLabel - New display label (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @throws JobExists - When the new code conflicts with an existing job in this scope
 * @see CreateJob
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditJob (
  pId               uuid,
  pParent           uuid default null,
  pType             uuid default null,
  pScheduler        uuid default null,
  pProgram          uuid default null,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           void
AS $$
DECLARE
  uDocument         uuid;
  vCode             text;

  old               db.job%rowtype;
  new               db.job%rowtype;

  uClass            uuid;
  uMethod           uuid;
BEGIN
  SELECT code INTO vCode FROM db.job WHERE id = pId;

  IF vCode <> coalesce(pCode, vCode) THEN
    SELECT id INTO uDocument FROM db.job WHERE scope = current_scope() AND code = pCode;
    IF FOUND THEN
      PERFORM JobExists(pCode);
    END IF;
  END IF;

  PERFORM EditDocument(pId, pParent, pType, pLabel, pDescription, pDescription, current_locale());

  SELECT * INTO old FROM db.job WHERE id = pId;

  UPDATE db.job
     SET code = coalesce(pCode, code),
         scheduler = coalesce(pScheduler, scheduler),
         program = coalesce(pProgram, program),
         dateRun = coalesce(pDateRun, dateRun)
   WHERE id = pId;

  SELECT * INTO new FROM db.job WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod, jsonb_build_object('old', row_to_json(old), 'new', row_to_json(new)));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetJob ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a job identifier by its unique code.
 * @param {text} pCode - Job code
 * @return {uuid} - Job identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetJob (
  pCode     text
) RETURNS   uuid
AS $$
DECLARE
  uId       uuid;
BEGIN
  SELECT id INTO uId FROM db.job WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
