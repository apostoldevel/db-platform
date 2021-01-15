--------------------------------------------------------------------------------
-- SCHEDULER -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventSchedulerCreate --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventSchedulerCreate (
  pObject	numeric DEFAULT context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Планировщик создан.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerOpen ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventSchedulerOpen (
  pObject	numeric DEFAULT context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Планировщик открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerEdit ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventSchedulerEdit (
  pObject	numeric DEFAULT context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Планировщик изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerSave ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventSchedulerSave (
  pObject	numeric DEFAULT context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Планировщик сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerEnable --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventSchedulerEnable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Планировщик включен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerDisable -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventSchedulerDisable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Планировщик выключен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerDelete --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventSchedulerDelete (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Планировщик удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerRestore -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventSchedulerRestore (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Планировщик восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerDrop ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventSchedulerDrop (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  r         record;
BEGIN
  SELECT label INTO r FROM db.object WHERE id = pObject;

  DELETE FROM db.scheduler WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Планировщик уничтожен.');
END;
$$ LANGUAGE plpgsql;
