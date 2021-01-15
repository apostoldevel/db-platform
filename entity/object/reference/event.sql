--------------------------------------------------------------------------------
-- REFERENCE -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventReferenceCreate --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReferenceCreate (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Справочник создан.', pObject);
  PERFORM DoEnable(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceOpen ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReferenceOpen (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Справочник открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceEdit ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReferenceEdit (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Справочник изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceSave ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReferenceSave (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Справочник сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceEnable --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReferenceEnable (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Справочник включен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceDisable -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReferenceDisable (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Справочник выключен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceDelete --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReferenceDelete (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Справочник удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceRestore -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReferenceRestore (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Справочник восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceDrop ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventReferenceDrop (
  pObject        numeric default context_object()
) RETURNS        void
AS $$
DECLARE
  r                record;
BEGIN
  SELECT label INTO r FROM Object WHERE id = pObject;

  DELETE FROM db.reference WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Справочник уничтожен.');
END;
$$ LANGUAGE plpgsql;
