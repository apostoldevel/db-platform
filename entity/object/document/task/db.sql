--------------------------------------------------------------------------------
-- TASK ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.task ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.task (
    id			    numeric(12) PRIMARY KEY,
    document	    numeric(12) NOT NULL,
    code		    varchar(30) NOT NULL,
    calendar        numeric(12) NOT NULL,
    scheduler       numeric(12) NOT NULL,
    program         numeric(12),
    executor        numeric(12),
    CONSTRAINT fk_task_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_task_calendar FOREIGN KEY (calendar) REFERENCES db.calendar(id),
    CONSTRAINT fk_task_scheduler FOREIGN KEY (scheduler) REFERENCES db.scheduler(id),
    CONSTRAINT fk_task_program FOREIGN KEY (program) REFERENCES db.program(id),
    CONSTRAINT fk_task_executor FOREIGN KEY (executor) REFERENCES db.client(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.task IS 'Задача.';

COMMENT ON COLUMN db.task.id IS 'Идентификатор';
COMMENT ON COLUMN db.task.document IS 'Документ';
COMMENT ON COLUMN db.task.code IS 'Код';
COMMENT ON COLUMN db.task.calendar IS 'Календарь';
COMMENT ON COLUMN db.task.scheduler IS 'Планировщик';
COMMENT ON COLUMN db.task.program IS 'Программа';
COMMENT ON COLUMN db.task.executor IS 'Исполнитель.';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.task (code);

CREATE INDEX ON db.task (document);
CREATE INDEX ON db.task (scheduler);
CREATE INDEX ON db.task (program);
CREATE INDEX ON db.task (executor);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_task_insert()
RETURNS trigger AS $$
DECLARE
  nOwner    numeric;
  nUserId   numeric;
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS NULL THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  IF NEW.executor IS NOT NULL THEN
    SELECT owner INTO nOwner FROM db.object WHERE id = NEW.document;

    nUserId := GetClientUserId(NEW.executor);
    IF nOwner <> nUserId THEN
      UPDATE db.aou SET allow = allow | B'110' WHERE object = NEW.document AND userid = nUserId;
      IF NOT FOUND THEN
        INSERT INTO db.aou SELECT NEW.document, nUserId, B'000', B'110';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_task_insert
  BEFORE INSERT ON db.task
  FOR EACH ROW
  EXECUTE PROCEDURE ft_task_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_task_after_update()
RETURNS trigger AS $$
DECLARE
  nOwner    numeric;
  nUserId   numeric;
BEGIN
  IF coalesce(OLD.executor, 0) <> coalesce(NEW.executor, 0) THEN
    SELECT owner INTO nOwner FROM db.object WHERE id = NEW.document;

    IF NEW.executor IS NOT NULL THEN
      nUserId := GetClientUserId(NEW.executor);
      IF nOwner <> nUserId THEN
        UPDATE db.aou SET allow = allow | B'110' WHERE object = NEW.document AND userid = nUserId;
        IF NOT found THEN
          INSERT INTO db.aou SELECT NEW.document, nUserId, B'000', B'110';
        END IF;
      END IF;
    END IF;

    IF OLD.executor IS NOT NULL THEN
      nUserId := GetClientUserId(OLD.executor);
      IF nOwner <> nUserId THEN
        DELETE FROM db.aou WHERE object = OLD.document AND userid = nUserId;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_task_after_update
  AFTER UPDATE ON db.task
  FOR EACH ROW
  EXECUTE PROCEDURE ft_task_after_update();

--------------------------------------------------------------------------------
-- CreateTask ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateTask (
  pParent           numeric,
  pType             numeric,
  pCode             varchar,
  pLabel            varchar,
  pCalendar         numeric default null,
  pScheduler        numeric default null,
  pProgram          numeric default null,
  pExecutor         numeric default null,
  pDescription      text default null
) RETURNS           numeric
AS $$
DECLARE
  nDocument         numeric;
  nClass            numeric;
  nMethod           numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'task' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO nDocument FROM db.task WHERE code = pCode;

  IF found THEN
    PERFORM TaskExists(pCode);
  END IF;

  nDocument := CreateDocument(pParent, pType, pLabel, pDescription);

  INSERT INTO db.task (id, document, code, calendar, scheduler, program, executor)
  VALUES (nDocument, nDocument, pCode, pCalendar, pScheduler, pProgram, pExecutor);

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nDocument, nMethod);

  RETURN nDocument;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditTask --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditTask (
  pId               numeric,
  pParent           numeric default null,
  pType             numeric default null,
  pCode             varchar default null,
  pLabel            varchar default null,
  pCalendar         numeric default null,
  pScheduler        numeric default null,
  pProgram          numeric default null,
  pExecutor         numeric default null,
  pDescription      text default null
) RETURNS           void
AS $$
DECLARE
  nDocument         numeric;
  vCode             varchar;

  old               db.task%rowtype;
  new               db.task%rowtype;

  nClass            numeric;
  nMethod           numeric;
BEGIN
  SELECT code INTO vCode FROM db.task WHERE id = pId;
  IF vCode <> coalesce(pCode, vCode) THEN
    SELECT id INTO nDocument FROM db.task WHERE code = pCode;
    IF found THEN
      PERFORM TaskExists(pCode);
    END IF;
  END IF;

  PERFORM EditDocument(pId, pParent, pType, pLabel, pDescription);

  SELECT * INTO old FROM db.task WHERE id = pId;

  UPDATE db.task
     SET code = coalesce(pCode, code),
         calendar = coalesce(pCalendar, calendar),
         scheduler = coalesce(pScheduler, scheduler),
         program = CheckNull(coalesce(pProgram, program, 0)),
         executor = CheckNull(coalesce(pExecutor, executor, 0))
   WHERE id = pId;

  SELECT * INTO new FROM db.task WHERE id = pId;

  SELECT class INTO nClass FROM db.type WHERE id = pType;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod, jsonb_build_object('old', row_to_json(old), 'new', row_to_json(new)));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetTask ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetTask (
  pCode     text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.task WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Task ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Task (Id, Document, Code,
  Calendar, CalendarCode, CalendarName,
  Scheduler, SchedulerCode, SchedulerName, Period, DateNext, DateStart, DateStop,
  Program, ProgramCode, ProgramName,
  Executor, ExecutorCode, ExecutorName
)
AS
  SELECT t.id, t.document, t.code,
         t.calendar, rc.code, rc.name,
         t.scheduler, s.code, s.name, s.period, s.datenext, s.datestart, s.datestop,
         t.program, p.code, p.name,
         t.executor, c.code, c.fullname
    FROM db.task t INNER JOIN calendar rc ON t.calendar = rc.id
                   INNER JOIN scheduler s ON t.scheduler = s.id
                    LEFT JOIN program   p ON t.program = p.id
                    LEFT JOIN client    c ON t.executor = c.id;

GRANT SELECT ON Task TO administrator;

--------------------------------------------------------------------------------
-- AccessTask ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessTask
AS
  WITH RECURSIVE access AS (
    SELECT * FROM AccessObjectUser(GetEntity('task'), current_userid())
  )
  SELECT t.* FROM Task t INNER JOIN access ac ON t.id = ac.object;

GRANT SELECT ON AccessTask TO administrator;

--------------------------------------------------------------------------------
-- ObjectTask ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectTask (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Calendar, CalendarCode, CalendarName,
  Scheduler, SchedulerCode, SchedulerName,
  Period, DateNext, DateStart, DateStop,
  Program, ProgramCode, ProgramName,
  Executor, ExecutorCode, ExecutorName,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription
)
AS
  SELECT t.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         t.code, t.calendar, t.calendarcode, t.calendarname,
         t.scheduler, t.schedulercode, t.schedulername,
         t.period, t.datenext, t.datestart, t.datestop,
         t.program, t.programcode, t.programname,
         t.executor, t.executorcode, t.executorname,
         o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription
    FROM AccessTask t INNER JOIN Document d ON t.document = d.id
                      INNER JOIN Object   o ON t.document = o.id;

GRANT SELECT ON ObjectTask TO administrator;
