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
  WITH access AS (
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
