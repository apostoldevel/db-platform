--------------------------------------------------------------------------------
-- AGENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventAgentCreate ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'create' event for an agent.
 * @param {uuid} pObject - Agent object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventAgentCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Агент создан.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAgentOpen --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'open' event for an agent.
 * @param {uuid} pObject - Agent object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventAgentOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Агент открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAgentEdit --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'edit' event for an agent.
 * @param {uuid} pObject - Agent object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventAgentEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Агент изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAgentSave --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'save' event for an agent.
 * @param {uuid} pObject - Agent object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventAgentSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Агент сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAgentEnable ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'enable' event for an agent.
 * @param {uuid} pObject - Agent object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventAgentEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Агент включен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAgentDisable -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'disable' event for an agent.
 * @param {uuid} pObject - Agent object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventAgentDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Агент выключен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAgentDelete ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'delete' (soft) event for an agent.
 * @param {uuid} pObject - Agent object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventAgentDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Агент удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAgentRestore -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'restore' event for an agent.
 * @param {uuid} pObject - Agent object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventAgentRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Агент восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAgentDrop --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'drop' event: permanently delete agent data from db.agent.
 * @param {uuid} pObject - Agent object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventAgentDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.agent WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Агент уничтожен.');
END;
$$ LANGUAGE plpgsql;
