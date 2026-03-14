--------------------------------------------------------------------------------
-- SCHEDULER -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventSchedulerCreate --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'create' event for a scheduler.
 * @param {uuid} pObject - Scheduler object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventSchedulerCreate (
  pObject    uuid DEFAULT context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Планировщик создан.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerOpen ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'open' event for a scheduler.
 * @param {uuid} pObject - Scheduler object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventSchedulerOpen (
  pObject    uuid DEFAULT context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Планировщик открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerEdit ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'edit' event for a scheduler.
 * @param {uuid} pObject - Scheduler object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventSchedulerEdit (
  pObject    uuid DEFAULT context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Планировщик изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerSave ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'save' event for a scheduler.
 * @param {uuid} pObject - Scheduler object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventSchedulerSave (
  pObject    uuid DEFAULT context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Планировщик сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerEnable --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'enable' event for a scheduler.
 * @param {uuid} pObject - Scheduler object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventSchedulerEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Планировщик включен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerDisable -------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'disable' event for a scheduler.
 * @param {uuid} pObject - Scheduler object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventSchedulerDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Планировщик выключен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerDelete --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'delete' (soft) event for a scheduler.
 * @param {uuid} pObject - Scheduler object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventSchedulerDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Планировщик удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerRestore -------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'restore' event for a scheduler.
 * @param {uuid} pObject - Scheduler object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventSchedulerRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Планировщик восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventSchedulerDrop ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'drop' event: permanently delete scheduler data from db.scheduler.
 * @param {uuid} pObject - Scheduler object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventSchedulerDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r         record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.scheduler WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Планировщик уничтожен.');
END;
$$ LANGUAGE plpgsql;
