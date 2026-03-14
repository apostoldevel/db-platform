--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventObjectCreate -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Log the 'create' event for an object.
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventObjectCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Объект создан.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectOpen -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Log the 'open' event for an object.
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventObjectOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Объект открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectEdit -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Log the 'edit' event for an object.
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventObjectEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Объект изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectSave -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Log the 'save' event for an object.
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventObjectSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Объект сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectEnable -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Log the 'enable' event for an object.
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventObjectEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Объект включен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectDisable ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Log the 'disable' event for an object.
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventObjectDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Объект выключен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectDelete -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Log the 'delete' event for an object.
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventObjectDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Объект удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectRestore ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Log the 'restore' event for an object.
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventObjectRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Объект восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventObjectDrop -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Permanently destroy an object and all related data (cascade cleanup).
 * @param {uuid} pObject - Object identifier (defaults to context_object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventObjectDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r            record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.comment      WHERE object = pObject;
  DELETE FROM db.notice       WHERE object = pObject;
  DELETE FROM db.object_link  WHERE object = pObject;
  DELETE FROM db.object_file  WHERE object = pObject;
  DELETE FROM db.object_data  WHERE object = pObject;
  DELETE FROM db.object_state WHERE object = pObject;
  DELETE FROM db.method_stack WHERE object = pObject;
  DELETE FROM db.notification WHERE object = pObject;
  DELETE FROM db.log          WHERE object = pObject;

  UPDATE db.object SET parent = null WHERE parent = pObject;
  DELETE FROM db.object WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Объект уничтожен.');
END;
$$ LANGUAGE plpgsql;
