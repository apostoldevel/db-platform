--------------------------------------------------------------------------------
-- REPORT FORM -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventReportRoutineCreate ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportRoutineCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Функция отчёта создана.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineOpen ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportRoutineOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Функция отчёта открыта.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineEdit ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportRoutineEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Функция отчёта изменена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineSave ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportRoutineSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Функция отчёта сохранена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineEnable ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportRoutineEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Функция отчёта включена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineDisable ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportRoutineDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Функция отчёта выключена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineDelete ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportRoutineDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Функция отчёта удалена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineRestore ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportRoutineRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Функция отчёта восстановлена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineDrop ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportRoutineDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.report_routine WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Функция отчёта уничтожена.');
END;
$$ LANGUAGE plpgsql;
