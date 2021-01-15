--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventObjectCreate -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventObjectCreate (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Объект создан.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectOpen -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventObjectOpen (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Объект открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectEdit -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventObjectEdit (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Объект изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectSave -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventObjectSave (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Объект сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectEnable -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventObjectEnable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Объект включен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectDisable ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventObjectDisable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Объект выключен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectDelete -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventObjectDelete (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Объект удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectRestore ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventObjectRestore (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Объект восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectDrop -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventObjectDrop (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  r			record;
BEGIN
  SELECT label INTO r FROM db.object WHERE id = pObject;

  DELETE FROM db.object_link  WHERE object = pObject;
  DELETE FROM db.object_file  WHERE object = pObject;
  DELETE FROM db.object_data  WHERE object = pObject;
  DELETE FROM db.object_state WHERE object = pObject;
  DELETE FROM db.method_stack WHERE object = pObject;
  DELETE FROM db.notification WHERE object = pObject;
  DELETE FROM db.log          WHERE object = pObject;

  DELETE FROM db.object WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Объект уничтожен.');
END;
$$ LANGUAGE plpgsql;
