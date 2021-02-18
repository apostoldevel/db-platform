--------------------------------------------------------------------------------
-- MODEL -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventModelCreate ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventModelCreate (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Модель создана.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventModelOpen --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventModelOpen (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Модель открыта.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventModelEdit --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventModelEdit (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Модель изменена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventModelSave --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventModelSave (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Модель сохранена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventModelEnable ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventModelEnable (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Модель включена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventModelDisable -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventModelDisable (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Модель выключена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventModelDelete ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventModelDelete (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Модель удалена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventModelRestore -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventModelRestore (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Модель восстановлена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventModelDrop --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventModelDrop (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
DECLARE
  r			record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.model WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Модель уничтожена.');
END;
$$ LANGUAGE plpgsql;
