--------------------------------------------------------------------------------
-- CreateJob -------------------------------------------------------------------
--------------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION GetJob (
  pCode     text
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.job WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
