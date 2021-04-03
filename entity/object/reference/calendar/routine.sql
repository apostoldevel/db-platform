--------------------------------------------------------------------------------
-- CreateCalendar --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт календарь
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {uuid} pWeek - Количество используемых (рабочих) дней в неделе
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
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pWeek         integer,
  pDayOff       integer[],
  pHoliday      integer[][],
  pWorkStart    interval,
  pWorkCount    interval,
  pRestStart    interval,
  pRestCount    interval,
  pDescription  text DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uReference    uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'calendar' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.calendar (id, reference, week, dayoff, holiday, work_start, work_count, rest_start, rest_count)
  VALUES (uReference, uReference, pWeek, pDayOff, pHoliday, pWorkStart, pWorkCount, pRestStart, pRestCount);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditCalendar ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует календарь
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {integer} pWeek - Количество используемых (рабочих) дней в неделе
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
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pWeek         integer DEFAULT null,
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
  uClass        uuid;
  uMethod       uuid;
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

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetCalendar --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCalendar (
  pCode       text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'calendar');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddCalendarDate ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddCalendarDate (
  pCalendar     uuid,
  pDate         date,
  pFlag         bit,
  pWorkStart    interval,
  pWorkCount    interval,
  pRestStart    interval,
  pRestCount    interval,
  pUserId       uuid DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  r             db.calendar%rowtype;
BEGIN
  SELECT * INTO r FROM db.calendar WHERE id = pCalendar;

  INSERT INTO db.cdate (calendar, date, flag, work_start, work_count, rest_start, rest_count, userid)
  VALUES (pCalendar, pDate, pFlag, coalesce(pWorkStart, r.work_start), coalesce(pWorkCount, r.work_count),
                                   coalesce(pRestStart, r.rest_start), coalesce(pRestCount, r.rest_count), pUserId)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditCalendarDate ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditCalendarDate (
  pId           uuid,
  pCalendar     uuid DEFAULT null,
  pDate         date DEFAULT null,
  pFlag         bit DEFAULT null,
  pWorkStart    interval DEFAULT null,
  pWorkCount    interval DEFAULT null,
  pRestStart    interval DEFAULT null,
  pRestCount    interval DEFAULT null,
  pUserId       uuid DEFAULT null
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
         userid = CheckNull(coalesce(pUserId, userid, null_uuid()))
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteCalendarDate -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteCalendarDate (
  pId         uuid
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
  pCalendar   uuid,
  pDate       date,
  pUserId     uuid DEFAULT null
) RETURNS     uuid
AS $$
DECLARE
  uId         uuid;
BEGIN
  SELECT id INTO uId FROM db.cdate WHERE calendar = pCalendar AND date = pDate AND userid IS NOT DISTINCT FROM pUserId;
  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION calendar_date ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION calendar_date (
  pCalendar   uuid,
  pDateFrom   date,
  pDateTo     date,
  pUserId     uuid DEFAULT null
) RETURNS     SETOF calendar_date
AS $$
  SELECT *
    FROM calendar_date
   WHERE calendar = pCalendar
     AND date BETWEEN pDateFrom AND pDateTo
     AND userid IS NOT DISTINCT FROM pUserId
   UNION
  SELECT *
    FROM calendar_date
   WHERE calendar = pCalendar
     AND date BETWEEN pDateFrom AND pDateTo
     AND userid IS NULL
     AND date NOT IN (SELECT date FROM calendar_date WHERE calendar = pCalendar AND date BETWEEN pDateFrom AND pDateTo AND userid IS NOT DISTINCT FROM pUserId)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FillCalendar ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Заполняет календарь датами за указанный период.
 * @param {id} pCalendar - Календарь
 * @param {date} pDateFrom - Дата начала периода
 * @param {date} pDateTo - Дата окончания периода
 * @param {uuid} pUserId - Идентификатор учётной записи пользователя
 * @return {(id|exception)} - Id или ошибку
 */
CREATE OR REPLACE FUNCTION FillCalendar (
  pCalendar   uuid,
  pDateFrom   date,
  pDateTo     date,
  pUserId     uuid DEFAULT null
) RETURNS     void
AS $$
DECLARE
  uId         uuid;

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

    uId := GetCalendarDate(pCalendar, dtCurDate, pUserId);
    IF uId IS NOT NULL THEN
      PERFORM EditCalendarDate(uId, pCalendar, dtCurDate, flag, r.work_start, r.work_count, r.rest_start, r.rest_count, pUserId);
    ELSE
      uId := AddCalendarDate(pCalendar, dtCurDate, flag, r.work_start, r.work_count, r.rest_start, r.rest_count, pUserId);
    END IF;

    dtCurDate := dtCurDate + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
