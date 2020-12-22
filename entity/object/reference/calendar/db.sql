--------------------------------------------------------------------------------
-- db.calendar -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.calendar (
    id            numeric(12) PRIMARY KEY,
    reference     numeric(12) NOT NULL,
    week          numeric(1) NOT NULL DEFAULT 5,
    dayoff        integer[] DEFAULT ARRAY[6,7],
    holiday       integer[][] DEFAULT ARRAY[[1,1], [1,7], [2,23], [3,8], [5,1], [5,9], [6,12], [11,4]],
    work_start    interval DEFAULT '9 hour',
    work_count    interval DEFAULT '8 hour',
    rest_start    interval DEFAULT '13 hour',
    rest_count    interval DEFAULT '1 hour',
    CONSTRAINT ch_calendar_week CHECK (week BETWEEN 1 AND 7),
    CONSTRAINT ch_calendar_dayoff CHECK (min_array(dayoff) >= 1 AND max_array(dayoff) <= 7),
    CONSTRAINT fk_calendar_reference FOREIGN KEY (reference) REFERENCES db.reference(id)
);

COMMENT ON TABLE db.calendar IS 'Календарь.';

COMMENT ON COLUMN db.calendar.id IS 'Идентификатор.';
COMMENT ON COLUMN db.calendar.reference IS 'Справочник.';
COMMENT ON COLUMN db.calendar.week IS 'Количество используемых (рабочих) дней в неделе.';
COMMENT ON COLUMN db.calendar.dayoff IS 'Массив выходных дней в неделе. Допустимые значения [1..7, ...].';
COMMENT ON COLUMN db.calendar.holiday IS 'Массив праздничных дней в году. Допустимые значения [[1..12,1..31], ...].';
COMMENT ON COLUMN db.calendar.work_start IS 'Начало рабочего дня.';
COMMENT ON COLUMN db.calendar.work_count IS 'Количество рабочих часов.';
COMMENT ON COLUMN db.calendar.rest_start IS 'Начало перерыва.';
COMMENT ON COLUMN db.calendar.rest_count IS 'Количество часов перерыва.';

CREATE INDEX ON db.calendar (reference);

CREATE OR REPLACE FUNCTION ft_calendar_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEW.reference INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_calendar_insert
  BEFORE INSERT ON db.calendar
  FOR EACH ROW
  EXECUTE PROCEDURE ft_calendar_insert();

--------------------------------------------------------------------------------
-- db.cdate --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.cdate (
    id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    calendar        numeric(12) NOT NULL,
    date            date NOT NULL,
    flag            bit(4) NOT NULL DEFAULT B'0000',
    work_start      interval,
    work_count      interval,
    rest_start      interval,
    rest_count      interval,
    userid          numeric(12),
    CONSTRAINT fk_cdate_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_cdate_calendar FOREIGN KEY (calendar) REFERENCES db.calendar(id)
);

COMMENT ON TABLE db.cdate IS 'Календарные дни.';

COMMENT ON COLUMN db.cdate.id IS 'Идентификатор.';
COMMENT ON COLUMN db.cdate.calendar IS 'Календарь.';
COMMENT ON COLUMN db.cdate.date IS 'Дата';
COMMENT ON COLUMN db.cdate.flag IS 'Флаг: 1000 - Предпраздничный; 0100 - Праздничный; 0010 - Выходной; 0001 - Нерабочий; 0000 - Рабочий.';
COMMENT ON COLUMN db.cdate.work_start IS 'Начало рабочего дня.';
COMMENT ON COLUMN db.cdate.work_count IS 'Количество рабочих часов.';
COMMENT ON COLUMN db.cdate.rest_start IS 'Начало перерыва.';
COMMENT ON COLUMN db.cdate.rest_count IS 'Количество часов перерыва.';

CREATE INDEX ON db.cdate (calendar);
CREATE INDEX ON db.cdate (date);
CREATE INDEX ON db.cdate (userid);

CREATE UNIQUE INDEX ON db.cdate (calendar, date, userid);

--------------------------------------------------------------------------------
-- CreateCalendar --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт календарь
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pWeek - Количество используемых (рабочих) дней в неделе
 * @param {integer[]} pDayOff - Массив выходных дней в неделе. Допустимые значения [1..7, ...]
 * @param {integer[][]} pHoliday - Двухмерный массив праздничных дней в году. Допустимые значения [[1..12,1..31], ...]
 * @param {interval} pWorkStart - Начало рабочего дня
 * @param {interval} pWorkCount - Количество рабочих часов
 * @param {interval} pRestStart - Начало перерыва
 * @param {interval} pRestCount - Количество часов перерыва
 * @param {text} pDescription - Описание
 * @return {(id|exception)} - Id или ошибку
 */
CREATE OR REPLACE FUNCTION CreateCalendar (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         varchar,
  pWeek         numeric,
  pDayOff       integer[],
  pHoliday      integer[][],
  pWorkStart    interval,
  pWorkCount    interval,
  pRestStart    interval,
  pRestCount    interval,
  pDescription  text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nReference    numeric;
  nClass        numeric;
  nMethod       numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'calendar' THEN
    PERFORM IncorrectClassType();
  END IF;

  nReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.calendar (reference, week, dayoff, holiday, work_start, work_count, rest_start, rest_count)
  VALUES (nReference, pWeek, pDayOff, pHoliday, pWorkStart, pWorkCount, pRestStart, pRestCount);

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  RETURN nReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditCalendar ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует календарь
 * @param {numeric} pId - Идентификатор
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pWeek - Количество используемых (рабочих) дней в неделе
 * @param {integer[]} pDayOff - Массив выходных дней в неделе. Допустимые значения [1..7, ...]
 * @param {integer[][]} pHoliday - Двухмерный массив праздничных дней в году. Допустимые значения [[1..12,1..31], ...]
 * @param {interval} pWorkStart - Начало рабочего дня
 * @param {interval} pWorkCount - Количество рабочих часов
 * @param {interval} pRestStart - Начало перерыва
 * @param {interval} pRestCount - Количество часов перерыва
 * @param {text} pDescription - Описание
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION EditCalendar (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         numeric DEFAULT null,
  pCode         varchar DEFAULT null,
  pName         varchar DEFAULT null,
  pWeek         numeric DEFAULT null,
  pDayOff       integer[] DEFAULT null,
  pHoliday      integer[][] DEFAULT null,
  pWorkStart    interval DEFAULT null,
  pWorkCount    interval DEFAULT null,
  pRestStart    interval DEFAULT null,
  pRestCount    interval DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  nClass        numeric;
  nMethod       numeric;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription);

  UPDATE db.calendar 
     SET week = coalesce(pWeek, week),
         dayoff = coalesce(pDayOff, dayoff),
         holiday = coalesce(pHoliday, holiday),
         work_start = coalesce(pWorkStart, work_start),
         work_count = coalesce(pWorkCount, work_count),
         rest_start = coalesce(pRestStart, rest_start),
         rest_count = coalesce(pRestCount, rest_count)
   WHERE id = pId;

  SELECT class INTO nClass FROM db.object WHERE id = pId;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetCalendar --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCalendar (
  pCode       varchar
) RETURNS     numeric
AS $$
BEGIN
  RETURN GetReference(pCode, 'calendar');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Calendar --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Calendar (Id, Reference, Code, Name, Description,
  Week, DayOff, Holiday, WorkStart, WorkCount, RestStart, RestCount
)
AS
  SELECT c.id, c.reference, d.code, d.name, d.description,
         c.week, c.dayoff, c.holiday, c.work_start, c.work_count, c.rest_start, c.rest_count
    FROM db.calendar c INNER JOIN db.reference d ON c.reference = d.id;

GRANT SELECT ON Calendar TO administrator;

--------------------------------------------------------------------------------
-- AccessCalendar --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessCalendar
AS
  WITH RECURSIVE access AS (
    SELECT * FROM AccessObjectUser(GetEntity('calendar'), current_userid())
  )
  SELECT c.* FROM Calendar c INNER JOIN access ac ON c.id = ac.object;

GRANT SELECT ON AccessCalendar TO administrator;

--------------------------------------------------------------------------------
-- ObjectCalendar --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectCalendar (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  Week, DayOff, Holiday, WorkStart, WorkCount, RestStart, RestCount,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
) 
AS
  SELECT c.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         c.week, c.dayoff, c.holiday, c.workstart, c.workcount, c.reststart, c.restcount,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessCalendar c INNER JOIN Reference r ON c.reference = r.id
                          INNER JOIN Object    o ON c.reference = o.id;

GRANT SELECT ON ObjectCalendar TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION AddCalendarDate ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddCalendarDate (
  pCalendar     numeric,
  pDate         date,
  pFlag         bit,
  pWorkStart    interval,
  pWorkCount    interval,
  pRestStart    interval,
  pRestCount    interval,
  pUserId       numeric DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
  r             db.calendar%rowtype;
BEGIN
  SELECT * INTO r FROM db.calendar WHERE id = pCalendar;

  INSERT INTO db.cdate (calendar, date, flag, work_start, work_count, rest_start, rest_count, userid)
  VALUES (pCalendar, pDate, pFlag, coalesce(pWorkStart, r.work_start), coalesce(pWorkCount, r.work_count), 
                                   coalesce(pRestStart, r.rest_start), coalesce(pRestCount, r.rest_count), pUserId)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditCalendarDate ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditCalendarDate (
  pId           numeric,
  pCalendar     numeric DEFAULT null,
  pDate         date DEFAULT null,
  pFlag         bit DEFAULT null,
  pWorkStart    interval DEFAULT null,
  pWorkCount    interval DEFAULT null,
  pRestStart    interval DEFAULT null,
  pRestCount    interval DEFAULT null,
  pUserId       numeric DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.cdate
     SET calendar = coalesce(pCalendar, calendar),
         date = coalesce(pDate, date),
         flag = coalesce(pFlag, flag),
         work_start = coalesce(pWorkStart, work_start),
         work_count = coalesce(pWorkCount, work_count),
         rest_start = coalesce(pRestStart, rest_start),
         rest_count = coalesce(pRestCount, rest_count),
         userid = NULLIF(coalesce(pUserId, userid), 0)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteCalendarDate -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteCalendarDate (
  pId         numeric
) RETURNS     void
AS $$
BEGIN
  DELETE FROM db.cdate WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetCalendarDate ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCalendarDate (
  pCalendar   numeric,
  pDate       date,
  pUserId     numeric DEFAULT null
) RETURNS     numeric
AS $$
DECLARE
  nId         numeric;
BEGIN
  SELECT id INTO nId FROM db.cdate WHERE calendar = pCalendar AND date = pDate AND coalesce(userid, 0) = coalesce(pUserId, 0);
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- calendar_date ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW calendar_date (Id, Calendar, UserId, Date,
  Label, WorkStart, WorkStop, WorkCount, RestStart, RestCount, Flag
)
AS
  SELECT id, calendar, userid, date,
         CASE 
         WHEN flag & B'1000' = B'1000' THEN 'Сокращённый'
         WHEN flag & B'0100' = B'0100' THEN 'Праздничный'
         WHEN flag & B'0010' = B'0010' THEN 'Выходной'
         WHEN flag & B'0001' = B'0001' THEN 'Не рабочий'
         ELSE 'Рабочий'
         END,
         CASE
         WHEN flag & B'0001' = B'0001' THEN null
         ELSE
           work_start
         END,
         CASE
         WHEN flag & B'0001' = B'0001' THEN null
         WHEN flag & B'1000' = B'1000' THEN work_start + (work_count - interval '1 hour') + rest_count
         ELSE
           work_start + work_count + rest_count
         END,
         CASE 
         WHEN flag & B'0001' = B'0001' THEN null
         WHEN flag & B'1000' = B'1000' THEN work_count - interval '1 hour'
         ELSE
           work_count
         END,
         CASE
         WHEN flag & B'0001' = B'0001' THEN null
         ELSE
           rest_start
         END,
         CASE
         WHEN flag & B'0001' = B'0001' THEN null
         ELSE
           rest_count
         END,
         flag
    FROM db.cdate;

--------------------------------------------------------------------------------
-- FUNCTION calendar_date ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION calendar_date (
  pCalendar   numeric,
  pDateFrom   date,
  pDateTo     date,
  pUserId     numeric DEFAULT null
) RETURNS     SETOF calendar_date
AS $$
  SELECT * 
    FROM calendar_date
   WHERE calendar = pCalendar
     AND date BETWEEN pDateFrom AND pDateTo
     AND userid = pUserId
   UNION
  SELECT *
    FROM calendar_date
   WHERE calendar = pCalendar
     AND date BETWEEN pDateFrom AND pDateTo
     AND userid IS NULL
     AND date NOT IN (SELECT date FROM calendar_date WHERE calendar = pCalendar AND date BETWEEN pDateFrom AND pDateTo AND userid = pUserId)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CalendarDate ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW CalendarDate
AS
  SELECT d.id, d.calendar, c.code AS calendarcode, c.name AS calendarname, c.description AS calendardesc, 
         d.userid, u.username, u.name AS userfullname,
         d.date, d.label, d.workstart, d.workstop, d.workcount, d.reststart, d.restcount, d.flag
    FROM calendar_date d INNER JOIN Calendar c ON d.calendar = c.id
                          LEFT JOIN db.user u ON d.userid = u.id AND u.type = 'U';

GRANT SELECT ON CalendarDate TO administrator;

--------------------------------------------------------------------------------
-- FillCalendar ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Заполняет календарь датами за указанный период.
 * @param {id} pCalendar - Календарь
 * @param {date} pDateFrom - Дата начала периода
 * @param {date} pDateTo - Дата окончания периода
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @return {(id|exception)} - Id или ошибку
 */
CREATE OR REPLACE FUNCTION FillCalendar (
  pCalendar   numeric,
  pDateFrom   date,
  pDateTo     date,
  pUserId     numeric DEFAULT null
) RETURNS     void
AS $$
DECLARE
  nId         numeric;

  i           integer;
  r           db.calendar%rowtype;

  nMonth      integer;
  nDay        integer;
  nWeek       integer;

  aHoliday    integer[][];

  dtCurDate   date;
  flag        bit(4);
BEGIN
  SELECT * INTO r FROM db.calendar WHERE id = pCalendar;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('календарь', 'id', pCalendar);
  END IF;

  dtCurDate := pDateFrom;
  WHILE dtCurDate <= pDateTo
  LOOP
    flag := B'0000';
    aHoliday := r.holiday;

    nMonth := EXTRACT(MONTH FROM dtCurDate);
    nDay := EXTRACT(DAY FROM dtCurDate);
    nWeek := EXTRACT(ISODOW FROM dtCurDate);

    IF array_position(r.dayoff, nWeek) IS NOT NULL THEN
      flag := set_bit(flag, 2, 1);
      flag := set_bit(flag, 3, 1);
    END IF;

    i := 1;
    WHILE (i <= array_length(aHoliday, 1)) AND NOT (flag & B'0100' = B'0100')
    LOOP
      IF aHoliday[i][1] = nMonth AND aHoliday[i][2] = nDay THEN
        flag := set_bit(flag, 1, 1);
        flag := set_bit(flag, 3, 1);
      END IF;
      i := i + 1;
    END LOOP;

    IF flag = B'0000' THEN
      nMonth := EXTRACT(MONTH FROM dtCurDate + 1);
      nDay := EXTRACT(DAY FROM dtCurDate + 1);
      nWeek := EXTRACT(ISODOW FROM dtCurDate + 1);

      IF array_position(r.dayoff, nWeek) IS NOT NULL THEN
        flag := set_bit(flag, 0, 1);
      END IF;

      i := 1;
      WHILE (i <= array_length(aHoliday, 1)) AND NOT (flag & B'1000' = B'1000')
      LOOP
        IF aHoliday[i][1] = nMonth AND aHoliday[i][2] = nDay THEN
          flag := set_bit(flag, 0, 1);
        END IF;
        i := i + 1;
      END LOOP;
    END IF;

    nId := GetCalendarDate(pCalendar, dtCurDate, pUserId);
    IF nId IS NOT NULL THEN
      PERFORM EditCalendarDate(nId, pCalendar, dtCurDate, flag, r.work_start, r.work_count, r.rest_start, r.rest_count, pUserId);
    ELSE
      nId := AddCalendarDate(pCalendar, dtCurDate, flag, r.work_start, r.work_count, r.rest_start, r.rest_count, pUserId);
    END IF;

    dtCurDate := dtCurDate + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
