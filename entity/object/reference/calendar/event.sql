--------------------------------------------------------------------------------
-- CALENDAR --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventCalendarCreate ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCalendarCreate (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Календарь создан.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCalendarOpen -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCalendarOpen (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Календарь открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCalendarEdit -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCalendarEdit (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Календарь изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCalendarSave -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCalendarSave (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Календарь сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCalendarEnable ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCalendarEnable (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Календарь включен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCalendarDisable --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCalendarDisable (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Календарь выключен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCalendarDelete ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCalendarDelete (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Календарь удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCalendarRestore --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCalendarRestore (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Календарь восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCalendarDrop -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCalendarDrop (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
DECLARE
  r                record;
BEGIN
  SELECT label INTO r FROM Object WHERE id = pObject;

  DELETE FROM db.calendar WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Календарь уничтожен.');
END;
$$ LANGUAGE plpgsql;
