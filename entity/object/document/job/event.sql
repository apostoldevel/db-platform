--------------------------------------------------------------------------------
-- JOB -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventJobCreate --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobCreate (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Задание создано.', pObject);
  PERFORM DoEnable(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobOpen ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobOpen (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Задание открыто на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobEdit ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobEdit (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Задание изменено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobSave ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobSave (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Задание сохранено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobEnable --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobEnable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Задание открыто.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobDisable -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobDisable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Задание закрыто.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobDelete --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobDelete (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Задание удалено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobRestore -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobRestore (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Задание восстановлено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobExecute -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobExecute (
  pObject		numeric default context_object()
) RETURNS		void
AS $$
DECLARE
  r				record;
  nScheduler	numeric;
  iPeriod		interval;
  nProgram		numeric;
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'execute', 'Задание выполняется.', pObject);

  SELECT scheduler, program INTO nScheduler, nProgram FROM db.job WHERE id = pObject;

  SELECT period INTO iPeriod FROM db.scheduler WHERE id = nScheduler;
  UPDATE db.job SET daterun = Now() + coalesce(iPeriod, '0 seconds'::interval) WHERE id = pObject;

  FOR r IN SELECT * FROM db.program WHERE id = nProgram
  LOOP
	EXECUTE r.body;
  END LOOP;

  IF GetObjectTypeCode(pObject) = 'periodic.job' THEN
  	PERFORM ExecuteObjectAction(pObject, GetAction('done'));
  ELSE
  	PERFORM ExecuteObjectAction(pObject, GetAction('complete'));
  END IF;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobComplete ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobComplete (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'complete', 'Задание завершено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobDone ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobDone (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'done', 'Задание выполнено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobFail ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobFail (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'fail', 'Сбой при выполнении задания.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobAbort ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobAbort (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'abort', 'Задание прервано.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobCancel --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobCancel (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'cancel', 'Задание отменено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobDrop ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventJobDrop (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  r		    record;
BEGIN
  SELECT label INTO r FROM db.object WHERE id = pObject;

  DELETE FROM db.job WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Задание уничтожено.');
END;
$$ LANGUAGE plpgsql;
