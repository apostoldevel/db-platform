--------------------------------------------------------------------------------
-- CreateJob -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateJob (
  pParent           numeric,
  pType             numeric,
  pScheduler        numeric default null,
  pProgram          numeric default null,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           numeric
AS $$
DECLARE
  nDocument         numeric;
  nClass            numeric;
  nMethod           numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'job' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO nDocument FROM db.job WHERE code = pCode;

  IF found THEN
    PERFORM JobExists(pCode);
  END IF;

  nDocument := CreateDocument(pParent, pType, pLabel, pDescription);

  INSERT INTO db.job (id, document, code, scheduler, program, daterun)
  VALUES (nDocument, nDocument, pCode, pScheduler, pProgram, pDateRun);

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nDocument, nMethod);

  RETURN nDocument;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditJob ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditJob (
  pId               numeric,
  pParent           numeric default null,
  pType             numeric default null,
  pScheduler        numeric default null,
  pProgram          numeric default null,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           void
AS $$
DECLARE
  nDocument         numeric;
  vCode             text;

  old               db.job%rowtype;
  new               db.job%rowtype;

  nClass            numeric;
  nMethod           numeric;
BEGIN
  SELECT code INTO vCode FROM db.job WHERE id = pId;

  IF vCode <> coalesce(pCode, vCode) THEN
    SELECT id INTO nDocument FROM db.job WHERE code = pCode;
    IF found THEN
      PERFORM JobExists(pCode);
    END IF;
  END IF;

  PERFORM EditDocument(pId, pParent, pType, pLabel, pDescription);

  SELECT * INTO old FROM db.job WHERE id = pId;

  UPDATE db.job
     SET code = coalesce(pCode, code),
         scheduler = CheckNull(coalesce(pScheduler, scheduler, 0)),
         program = CheckNull(coalesce(pProgram, program, 0)),
         dateRun = coalesce(pDateRun, dateRun)
   WHERE id = pId;

  SELECT * INTO new FROM db.job WHERE id = pId;

  SELECT class INTO nClass FROM db.type WHERE id = pType;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod, jsonb_build_object('old', row_to_json(old), 'new', row_to_json(new)));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetJob ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetJob (
  pCode     text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.job WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
