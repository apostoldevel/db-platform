--------------------------------------------------------------------------------
-- CALENDAR --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.calendar ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Календарь
 * @field {numeric} id - Идентификатор
 * @field {numeric} object - Идентификатор справочника
 * @field {numeric} parent - Идентификатор объекта родителя
 * @field {numeric} class - Идентификатор класса
 * @field {varchar} code - Код
 * @field {varchar} name - Наименование
 * @field {text} description - Описание
 * @field {numeric} week - Количество используемых (рабочих) дней в неделе
 * @field {integer[]} dayoff - Массив выходных дней в неделе. Допустимые значения [1..7, ...]
 * @field {integer[][]} holiday - Массив праздничных дней в году. Допустимые значения [[1..12,1..31], ...]
 * @field {interval} workstart - Начало рабочего дня
 * @field {interval} workcount - Количество рабочих часов
 * @field {interval} reststart - Начало перерыва
 * @field {interval} restcount - Количество часов перерыва
 * @field {numeric} state - Идентификатор состояния
 * @field {timestamp} lastupdate - Дата последнего обновления
 * @field {numeric} owner - Идентификатор учётной записи владельца
 * @field {timestamp} created - Дата создания
 * @field {numeric} oper - Идентификатор учётной записи оператора
 * @field {timestamp} operdate - Дата операции
 */
CREATE OR REPLACE VIEW api.calendar
AS
  SELECT * FROM ObjectCalendar;

GRANT SELECT ON api.calendar TO administrator;

--------------------------------------------------------------------------------
-- api.add_calendar ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создает календарь.
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pWeek - Количество используемых (рабочих) дней в неделе
 * @param {jsonb} pDayOff - Массив выходных дней в неделе. Допустимые значения [1..7, ...]
 * @param {jsonb} pHoliday - Двухмерный массив праздничных дней в году в формате [[MM,DD], ...]. Допустимые значения [[1..12,1..31], ...]
 * @param {interval} pWorkStart - Начало рабочего дня
 * @param {interval} pWorkCount - Количество рабочих часов
 * @param {interval} pRestStart - Начало перерыва
 * @param {interval} pRestCount - Количество часов перерыва
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_calendar (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pName         varchar,
  pWeek         numeric,
  pDayOff       jsonb,
  pHoliday      jsonb,
  pWorkStart    interval,
  pWorkCount    interval,
  pRestStart    interval,
  pRestCount    interval,
  pDescription  text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  aHoliday      integer[][2];
  r             record;
BEGIN
  IF pHoliday IS NOT NULL THEN

    aHoliday := ARRAY[[0,0]];

    IF jsonb_typeof(pHoliday) = 'array' THEN
      FOR r IN SELECT * FROM jsonb_array_elements(pHoliday)
      LOOP
        IF jsonb_typeof(r.value) = 'array' THEN
          aHoliday := array_cat(aHoliday, JsonbToIntArray(r.value));
        ELSE
          PERFORM IncorrectJsonType(jsonb_typeof(r.value), 'array');
        END IF;
      END LOOP;
    ELSE
      PERFORM IncorrectJsonType(jsonb_typeof(pHoliday), 'array');
    END IF;
  END IF;

  RETURN CreateCalendar(pParent, CodeToType(lower(coalesce(pType, 'workday')), 'calendar'), pCode, pName, pWeek, JsonbToIntArray(pDayOff), aHoliday[2:], pWorkStart, pWorkCount, pRestStart, pRestCount, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_calendar ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет календарь.
 * @param {numeric} pId - Идентификатор календаря (api.get_calendar)
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pWeek - Количество используемых (рабочих) дней в неделе
 * @param {jsonb} pDayOff - Массив выходных дней в неделе. Допустимые значения [1..7, ...]
 * @param {jsonb} pHoliday - Двухмерный массив праздничных дней в году в формате [[MM,DD], ...]. Допустимые значения [[1..12,1..31], ...]
 * @param {interval} pWorkStart - Начало рабочего дня
 * @param {interval} pWorkCount - Количество рабочих часов
 * @param {interval} pRestStart - Начало перерыва
 * @param {interval} pRestCount - Количество часов перерыва
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_calendar (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         varchar DEFAULT null,
  pCode         varchar DEFAULT null,
  pName         varchar DEFAULT null,
  pWeek         numeric DEFAULT null,
  pDayOff       jsonb DEFAULT null,
  pHoliday      jsonb DEFAULT null,
  pWorkStart    interval DEFAULT null,
  pWorkCount    interval DEFAULT null,
  pRestStart    interval DEFAULT null,
  pRestCount    interval DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  r             record;
  nId           numeric;
  nCalendar     numeric;
  aHoliday      integer[][2];
BEGIN
  SELECT c.id INTO nId FROM calendar c WHERE c.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('календарь', 'id', pId);
  END IF;

  nCalendar := pId;

  IF pHoliday IS NOT NULL THEN

    aHoliday := ARRAY[[0,0]];

    IF jsonb_typeof(pHoliday) = 'array' THEN
      FOR r IN SELECT * FROM jsonb_array_elements(pHoliday)
      LOOP
        IF jsonb_typeof(r.value) = 'array' THEN
          aHoliday := array_cat(aHoliday, JsonbToIntArray(r.value));
        ELSE
          PERFORM IncorrectJsonType(jsonb_typeof(r.value), 'array');
        END IF;
      END LOOP;
    ELSE
      PERFORM IncorrectJsonType(jsonb_typeof(pHoliday), 'array');
    END IF;
  END IF;

  PERFORM EditCalendar(nCalendar, pParent, pType, pCode, pName, pWeek, JsonbToIntArray(pDayOff), aHoliday[2:], pWorkStart, pWorkCount, pRestStart, pRestCount, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_calendar ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_calendar (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         varchar DEFAULT null,
  pCode         varchar DEFAULT null,
  pName         varchar DEFAULT null,
  pWeek         numeric DEFAULT null,
  pDayOff       jsonb DEFAULT null,
  pHoliday      jsonb DEFAULT null,
  pWorkStart    interval DEFAULT null,
  pWorkCount    interval DEFAULT null,
  pRestStart    interval DEFAULT null,
  pRestCount    interval DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       SETOF api.calendar
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_calendar(pParent, pType, pCode, pName, pWeek, pDayOff, pHoliday, pWorkStart, pWorkCount, pRestStart, pRestCount, pDescription);
  ELSE
    PERFORM api.update_calendar(pId, pParent, pType, pCode, pName, pWeek, pDayOff, pHoliday, pWorkStart, pWorkCount, pRestStart, pRestCount, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.calendar WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_calendar ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает календарь.
 * @param {numeric} pId - Идентификатор календаря
 * @return {api.calendar} - Календарь
 */
CREATE OR REPLACE FUNCTION api.get_calendar (
  pId           numeric
) RETURNS       SETOF api.calendar
AS $$
  SELECT * FROM api.calendar WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_calendar -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает календарь списком.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.calendar} - Календари
 */
CREATE OR REPLACE FUNCTION api.list_calendar (
  pSearch       jsonb DEFAULT null,
  pFilter       jsonb DEFAULT null,
  pLimit        integer DEFAULT null,
  pOffSet       integer DEFAULT null,
  pOrderBy      jsonb DEFAULT null
) RETURNS       SETOF api.calendar
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'calendar', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.fill_calendar --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Заполняет календарь датами.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDateFrom - Дата начала периода
 * @param {date} pDateTo - Дата окончания периода
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.fill_calendar (
  pCalendar     numeric,
  pDateFrom     date,
  pDateTo       date,
  pUserId       numeric DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM FillCalendar(pCalendar, pDateFrom, pDateTo, pUserId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW api.calendar_date ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.calendar_date
AS
  SELECT * FROM calendar_date;

GRANT SELECT ON api.calendar_date TO administrator;

--------------------------------------------------------------------------------
-- VIEW api.calendardate -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.calendardate
AS
  SELECT * FROM CalendarDate;

GRANT SELECT ON api.calendardate TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.list_calendar_date ---------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает даты календаря за указанный период и для заданного пользователя.
 * Даты календаря пользовоталя переопределяют даты календаря для всех пользователей (общие даты)
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDateFrom - Дата начала периода
 * @param {date} pDateTo - Дата окончания периода
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @return {SETOF api.calendar_date} - Даты календаря
 */
CREATE OR REPLACE FUNCTION api.list_calendar_date (
  pCalendar     numeric,
  pDateFrom     date,
  pDateTo       date,
  pUserId       numeric DEFAULT null
) RETURNS       SETOF api.calendar_date
AS $$
  SELECT * FROM calendar_date(pCalendar, coalesce(pDateFrom, date_trunc('year', now())::date), coalesce(pDateTo, (date_trunc('year', now()) + INTERVAL '1 year' - INTERVAL '1 day')::date), pUserId) ORDER BY date;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.list_calendar_user ---------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает только даты календаря заданного пользователя за указанный период.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDateFrom - Дата начала периода
 * @param {date} pDateTo - Дата окончания периода
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @return {SETOF api.calendar_date} - Даты календаря
 */
CREATE OR REPLACE FUNCTION api.list_calendar_user (
  pCalendar     numeric,
  pDateFrom     date,
  pDateTo       date,
  pUserId       numeric DEFAULT null
) RETURNS       SETOF api.calendar_date
AS $$
  SELECT *
    FROM calendar_date
   WHERE calendar = pCalendar
     AND (date >= coalesce(pDateFrom, date_trunc('year', now())::date) AND
          date <= coalesce(pDateTo, (date_trunc('year', now()) + INTERVAL '1 year' - INTERVAL '1 day')::date))
     AND userid = coalesce(pUserId, userid)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.get_calendar_date ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дату календаря для заданного пользователя.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDate - Дата
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @return {api.calendardate} - Дата календаря
 */
CREATE OR REPLACE FUNCTION api.get_calendar_date (
  pCalendar     numeric,
  pDate         date,
  pUserId       numeric DEFAULT null
) RETURNS       SETOF api.calendar_date
AS $$
  SELECT * FROM calendar_date(pCalendar, pDate, pDate, pUserId);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.set_calendar_date ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Заполняет календарь датами.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDate - Дата
 * @param {bit} pFlag - Флаг: 1000 - Предпраздничный; 0100 - Праздничный; 0010 - Выходной; 0001 - Нерабочий; 0000 - Рабочий.
 * @param {interval} pWorkStart - Начало рабочего дня
 * @param {interval} pWorkCount - Количество рабочих часов
 * @param {interval} pRestStart - Начало перерыва
 * @param {interval} pRestCount - Количество часов перерыва
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @out param {numeric} id - Идентификатор даты календаря
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.set_calendar_date (
  pCalendar     numeric,
  pDate         date,
  pFlag         bit DEFAULT null,
  pWorkStart    interval DEFAULT null,
  pWorkCount    interval DEFAULT null,
  pRestStart    interval DEFAULT null,
  pRestCount    interval DEFAULT null,
  pUserId       numeric DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
  r             record;
BEGIN
  nId := GetCalendarDate(pCalendar, pDate, pUserId);
  IF nId IS NOT NULL THEN
    SELECT * INTO r FROM db.cdate WHERE calendar = pCalendar AND date = pDate AND userid IS NULL;
    IF r.flag = coalesce(pFlag, r.flag) AND
       r.work_start = coalesce(pWorkStart, r.work_start) AND
       r.work_count = coalesce(pWorkCount, r.work_count) AND
       r.rest_start = coalesce(pRestStart, r.rest_start) AND
       r.rest_count = coalesce(pRestCount, r.rest_count) THEN
      PERFORM DeleteCalendarDate(nId);
    ELSE
      PERFORM EditCalendarDate(nId, pCalendar, pDate, pFlag, pWorkStart, pWorkCount, pRestStart, pRestCount, pUserId);
    END IF;
  ELSE
    nId := AddCalendarDate(pCalendar, pDate, pFlag, pWorkStart, pWorkCount, pRestStart, pRestCount, pUserId);
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.delete_calendar_date -------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет дату календаря.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDate - Дата
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 */
CREATE OR REPLACE FUNCTION api.delete_calendar_date (
  pCalendar     numeric,
  pDate         date,
  pUserId       numeric DEFAULT null
) RETURNS       void
AS $$
DECLARE
  nId           numeric;
BEGIN
  nId := GetCalendarDate(pCalendar, pDate, pUserId);
  IF nId IS NOT NULL THEN
    PERFORM DeleteCalendarDate(nId);
  ELSE
    RAISE EXCEPTION 'ERR-40000: В календаре нет указанной даты для заданного пользователя.';
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
