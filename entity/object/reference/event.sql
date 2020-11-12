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
  PERFORM WriteToEventLog('M', 1010, 'Справочник создан.', pObject);
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
  PERFORM WriteToEventLog('M', 1011, 'Справочник открыт.', pObject);
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
  PERFORM WriteToEventLog('M', 1012, 'Справочник изменён.', pObject);
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
  PERFORM WriteToEventLog('M', 1013, 'Справочник сохранён.', pObject);
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
  PERFORM WriteToEventLog('M', 1014, 'Справочник включен.', pObject);
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
  PERFORM WriteToEventLog('M', 1015, 'Справочник выключен.', pObject);
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
  PERFORM WriteToEventLog('M', 1016, 'Справочник удалён.', pObject);
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
  PERFORM WriteToEventLog('M', 1017, 'Справочник восстановлен.', pObject);
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

  PERFORM WriteToEventLog('W', 2010, '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Справочник уничтожен.');
END;
$$ LANGUAGE plpgsql;
