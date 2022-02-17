--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventReportReadyCreate ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyCreate (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
DECLARE
  uReport   uuid;
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Готовый отчёт создан.', pObject);

  SELECT report INTO uReport FROM db.report_ready WHERE id = pObject;

  IF GetObjectType(uReport) = GetType('sync.report') THEN
    PERFORM ExecuteObjectAction(pObject, GetAction('execute'));
  END IF;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyOpen --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyOpen (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Готовый отчёт открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyEdit --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyEdit (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  IF IsDisabled(pObject) THEN
	PERFORM ChangesNotAllowed();
  END IF;

  PERFORM WriteToEventLog('M', 1000, 'edit', 'Готовый отчёт изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadySave --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadySave (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Готовый отчёт сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyEnable ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyEnable (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Готовый отчёт включен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyDisable -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyDisable (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Готовый отчёт выключен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyDelete ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyDelete (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Готовый отчёт удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyRestore -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyRestore (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Готовый отчёт восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyExecute -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyExecute (
  pObject   uuid default context_object()
) RETURNS   void
AS $$
DECLARE
  r         record;

  uReport   uuid;
  jForm     jsonb;
BEGIN
  SELECT report, form INTO uReport, jForm FROM db.report_ready WHERE id = pObject;

  FOR r IN SELECT definition FROM db.report_routine WHERE report = uReport ORDER BY sequence
  LOOP
	EXECUTE 'SELECT report.' || r.definition || '($1, $2);' USING pObject, jForm;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyComplete ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyComplete (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'complete', 'Готовый отчёт завершён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyFail --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyFail (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'fail', 'Сбой при выполнении отчёта.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyAbort -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyAbort (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'abort', 'Выполнение отчёта прервано.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyCancel ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyCancel (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'cancel', 'Готовый отчёт отменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportReadyDrop --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReportReadyDrop (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
DECLARE
  r			record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.object_file WHERE object = pObject;
  DELETE FROM db.report_ready WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Готовый отчёт уничтожен.');
END;
$$ LANGUAGE plpgsql;
