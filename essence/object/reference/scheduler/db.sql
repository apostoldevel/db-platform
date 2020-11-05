--------------------------------------------------------------------------------
-- SCHEDULER -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.scheduler ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.scheduler (
    id			    numeric(12) PRIMARY KEY,
    reference		numeric(12) NOT NULL,
    period          interval,
    dateNext        timestamptz,
    dateStart       timestamptz DEFAULT Now() NOT NULL,
    dateStop        timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_scheduler_reference FOREIGN KEY (reference) REFERENCES db.reference(id)
);

COMMENT ON TABLE db.scheduler IS 'Планировщик.';

COMMENT ON COLUMN db.scheduler.id IS 'Идентификатор.';
COMMENT ON COLUMN db.scheduler.reference IS 'Справочник.';
COMMENT ON COLUMN db.scheduler.period IS 'Период выполнения.';
COMMENT ON COLUMN db.scheduler.dateNext IS 'Дата следующего выполнения.';
COMMENT ON COLUMN db.scheduler.dateStart IS 'Дата начала выполнения.';
COMMENT ON COLUMN db.scheduler.dateStop IS 'Дата окончания выполнения.';

CREATE INDEX ON db.scheduler (reference);

CREATE INDEX ON db.scheduler (dateNext);
CREATE INDEX ON db.scheduler (dateStart, dateStop);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_scheduler_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEW.reference INTO NEW.id;
  END IF;

  IF NEW.dateNext IS NULL THEN
    NEW.dateNext := NEW.dateStart + coalesce(NEW.period, 0);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_scheduler_insert
  BEFORE INSERT ON db.scheduler
  FOR EACH ROW
  EXECUTE PROCEDURE ft_scheduler_insert();

--------------------------------------------------------------------------------
-- CreateScheduler -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт планировщик
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {interval} pPeriod - Период выполнения
 * @param {timestamptz} pDateNext - Дата следующего выполнения
 * @param {timestamptz} pDateStart - Дата начала выполнения
 * @param {timestamptz} pDateStop - Дата окончания выполнения
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION CreateScheduler (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         varchar,
  pPeriod       interval default null,
  pDateNext     timestamptz default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription	text default null
) RETURNS       numeric
AS $$
DECLARE
  nReference	numeric;
  nClass        numeric;
  nMethod       numeric;
BEGIN
  nReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.scheduler (id, reference, period, dateNext, dateStart, dateStop)
  VALUES (nReference, nReference, pPeriod, pDateNext, pDateStart, pDateStop);

  SELECT class INTO nClass FROM db.type WHERE id = pType;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  RETURN nReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditScheduler ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует планировщик
 * @param {numeric} pId - Идентификатор
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditScheduler (
  pId           numeric,
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         varchar,
  pPeriod       interval default null,
  pDateNext     timestamptz default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nClass        numeric;
  nMethod       numeric;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription);

  UPDATE db.scheduler
     SET period = coalesce(pPeriod, period),
         dateNext = coalesce(pDateNext, dateNext),
         dateStart = coalesce(pDateStart, dateStart),
         dateStop = coalesce(pDateStop, dateStop)
   WHERE id = pId;

  SELECT class INTO nClass FROM db.object WHERE id = pId;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetScheduler -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetScheduler (
  pCode		varchar
) RETURNS 	numeric
AS $$
BEGIN
  RETURN GetReference(pCode, 'scheduler');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Scheduler -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Scheduler (Id, Reference, Code, Name, Description,
  Period, DateNext, DateStart, DateStop
)
AS
  SELECT s.id, s.reference, d.code, d.name, d.description,
         s.period, s.dateNext, s.dateStart, s.dateStop
    FROM db.scheduler s INNER JOIN db.reference d ON s.reference = d.id;

GRANT SELECT ON Scheduler TO administrator;

--------------------------------------------------------------------------------
-- AccessScheduler -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessScheduler
AS
  WITH RECURSIVE access AS (
    SELECT * FROM AccessObjectUser(GetEssence('scheduler'), current_userid())
  )
  SELECT s.* FROM Scheduler s INNER JOIN access ac ON s.id = ac.object;

GRANT SELECT ON AccessScheduler TO administrator;

--------------------------------------------------------------------------------
-- ObjectScheduler -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectScheduler (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  Period, DateNext, DateStart, DateStop,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT s.id, r.object, r.parent,
         r.essence, r.essencecode, r.essencename,
         r.class, r.classcode, r.classlabel,
         r.type, r.typecode, r.typename, r.typedescription,
         r.code, r.name, r.label, r.description,
         s.period, s.datenext, s.datestart, s.datestop,
         r.statetype, r.statetypecode, r.statetypename,
         r.state, r.statecode, r.statelabel, r.lastupdate,
         r.owner, r.ownercode, r.ownername, r.created,
         r.oper, r.opercode, r.opername, r.operdate
    FROM AccessScheduler s INNER JOIN ObjectReference r ON s.reference = r.id;

GRANT SELECT ON ObjectScheduler TO administrator;
