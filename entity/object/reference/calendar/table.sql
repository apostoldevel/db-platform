--------------------------------------------------------------------------------
-- db.calendar -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.calendar (
    id            uuid PRIMARY KEY,
    reference     uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    week          integer NOT NULL DEFAULT 5,
    dayoff        integer[] DEFAULT ARRAY[6,7],
    holiday       integer[][] DEFAULT ARRAY[[1,1], [1,7], [2,23], [3,8], [5,1], [5,9], [6,12], [11,4]],
    work_start    interval DEFAULT '9 hour',
    work_count    interval DEFAULT '8 hour',
    rest_start    interval DEFAULT '13 hour',
    rest_count    interval DEFAULT '1 hour',
    CHECK (week BETWEEN 1 AND 7),
    CHECK (min_array(dayoff) >= 1 AND max_array(dayoff) <= 7)
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

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_calendar_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.reference INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_calendar_insert
  BEFORE INSERT ON db.calendar
  FOR EACH ROW
  EXECUTE PROCEDURE ft_calendar_insert();

--------------------------------------------------------------------------------
-- db.cdate --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.cdate (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    calendar        uuid NOT NULL REFERENCES db.calendar(id) ON DELETE CASCADE,
    date            date NOT NULL,
    flag            bit(4) NOT NULL DEFAULT B'0000',
    work_start      interval,
    work_count      interval,
    rest_start      interval,
    rest_count      interval,
    userid          uuid REFERENCES db.user(id)
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

--------------------------------------------------------------------------------

CREATE INDEX ON db.cdate (calendar);
CREATE INDEX ON db.cdate (date);
CREATE INDEX ON db.cdate (userid);

CREATE UNIQUE INDEX ON db.cdate (calendar, date, userid);
