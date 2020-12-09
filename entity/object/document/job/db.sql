--------------------------------------------------------------------------------
-- JOB -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.job ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.job (
    id			    numeric(12) PRIMARY KEY,
    document	    numeric(12) NOT NULL,
    code		    text NOT NULL,
    scheduler       numeric(12) NOT NULL,
    program         numeric(12) NOT NULL,
    dateRun         timestamptz NOT NULL DEFAULT Now(),
    CONSTRAINT fk_job_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_job_scheduler FOREIGN KEY (scheduler) REFERENCES db.scheduler(id),
    CONSTRAINT fk_job_program FOREIGN KEY (program) REFERENCES db.program(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.job IS 'Задание.';

COMMENT ON COLUMN db.job.id IS 'Идентификатор';
COMMENT ON COLUMN db.job.document IS 'Документ';
COMMENT ON COLUMN db.job.code IS 'Код';
COMMENT ON COLUMN db.job.scheduler IS 'Планировщик';
COMMENT ON COLUMN db.job.program IS 'Программа';
COMMENT ON COLUMN db.job.dateRun IS 'Дата запуска.';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.job (code);

CREATE INDEX ON db.job (document);
CREATE INDEX ON db.job (scheduler);
CREATE INDEX ON db.job (program);
CREATE INDEX ON db.job (dateRun);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_job_insert()
RETURNS trigger AS $$
DECLARE
  iPeriod		interval;
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS NULL THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  IF NEW.scheduler IS NOT NULL THEN
    SELECT period INTO iPeriod FROM db.scheduler WHERE id = NEW.scheduler;
    NEW.dateRun := Now() + coalesce(iPeriod, '0 seconds'::interval);
  END IF;

  IF NEW.dateRun IS NULL THEN
    NEW.dateRun := Now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_job_insert
  BEFORE INSERT ON db.job
  FOR EACH ROW
  EXECUTE PROCEDURE ft_job_insert();

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

--------------------------------------------------------------------------------
-- Job -------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Job (Id, Document, Code,
  Scheduler, SchedulerCode, SchedulerName,
  DateStart, DateStop, Period, DateRun,
  Program, ProgramCode, ProgramName
)
AS
  SELECT j.id, j.document, j.code,
         j.scheduler, s.code, s.name,
         s.datestart, s.datestop, s.period, j.daterun,
         j.program, p.code, p.name
    FROM db.job j INNER JOIN Scheduler s ON j.scheduler = s.id
                  INNER JOIN Program   p ON j.program = p.id;

GRANT SELECT ON Job TO administrator;

--------------------------------------------------------------------------------
-- AccessJob -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessJob
AS
  WITH RECURSIVE access AS (
    SELECT * FROM AccessObjectUser(GetEntity('job'), current_userid())
  )
  SELECT t.* FROM Job t INNER JOIN access ac ON t.id = ac.object;

GRANT SELECT ON AccessJob TO administrator;

--------------------------------------------------------------------------------
-- ObjectJob -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectJob (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Scheduler, SchedulerCode, SchedulerName,
  DateStart, DateStop, Period, DateRun,
  Program, ProgramCode, ProgramName,
  Code, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription
)
AS
  SELECT j.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         j.scheduler, j.schedulercode, j.schedulername,
         j.datestart, j.datestop, j.period, j.daterun,
         j.program, j.programcode, j.programname,
         j.code, o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription
    FROM AccessJob j INNER JOIN Document d ON j.document = d.id
                     INNER JOIN Object   o ON j.document = o.id;

GRANT SELECT ON ObjectJob TO administrator;
