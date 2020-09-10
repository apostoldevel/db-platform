--------------------------------------------------------------------------------
-- DOCUMENT --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventDocumentCreate ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDocumentCreate (
  pObject	numeric DEFAULT context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1010, 'Документ создан.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentOpen -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDocumentOpen (
  pObject	numeric DEFAULT context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1011, 'Документ открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentEdit -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDocumentEdit (
  pObject	numeric DEFAULT context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1012, 'Документ изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentSave -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDocumentSave (
  pObject	numeric DEFAULT context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1013, 'Документ сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentEnable ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDocumentEnable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1014, 'Документ включен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentDisable --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDocumentDisable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1015, 'Документ выключен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentDelete ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDocumentDelete (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1016, 'Документ удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentRestore --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDocumentRestore (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1017, 'Документ восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentDrop -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDocumentDrop (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  r         record;
BEGIN
  SELECT label INTO r FROM db.object WHERE id = pObject;

  DELETE FROM db.document WHERE id = pObject;

  PERFORM WriteToEventLog('W', 2010, '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Документ уничтожен.');
END;
$$ LANGUAGE plpgsql;
