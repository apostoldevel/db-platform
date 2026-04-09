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
  PERFORM WriteToEventLog('M', 1001, 'lifecycle', 'create', 'Agent created.', pObject);
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
  PERFORM WriteToEventLog('M', 1002, 'lifecycle', 'open', 'Agent opened.', pObject);
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
  PERFORM WriteToEventLog('M', 1003, 'lifecycle', 'edit', 'Agent updated.', pObject);
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
  PERFORM WriteToEventLog('M', 1004, 'lifecycle', 'save', 'Agent saved.', pObject);
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
  PERFORM WriteToEventLog('M', 2001, 'workflow', 'enable', 'Agent enabled.', pObject);
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
  PERFORM WriteToEventLog('M', 2002, 'workflow', 'disable', 'Agent disabled.', pObject);
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
  PERFORM WriteToEventLog('M', 2003, 'workflow', 'delete', 'Agent deleted.', pObject);
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
  PERFORM WriteToEventLog('M', 2004, 'workflow', 'restore', 'Agent restored.', pObject);
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

  PERFORM WriteToEventLog('W', 2005, 'workflow', 'drop', 'Agent dropped.', pObject);
END;
$$ LANGUAGE plpgsql;
