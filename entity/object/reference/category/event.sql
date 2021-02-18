--------------------------------------------------------------------------------
-- CATEGORY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventCategoryCreate ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCategoryCreate (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Категория создана.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCategoryOpen -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCategoryOpen (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Категория открыта.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCategoryEdit -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCategoryEdit (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Категория изменена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCategorySave -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCategorySave (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Категория сохранена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCategoryEnable ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCategoryEnable (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Категория включена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCategoryDisable --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCategoryDisable (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Категория выключена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCategoryDelete ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCategoryDelete (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Категория удалена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCategoryRestore --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCategoryRestore (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Категория восстановлена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventCategoryDrop -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventCategoryDrop (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
DECLARE
  r			record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.category WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Категория уничтожена.');
END;
$$ LANGUAGE plpgsql;
