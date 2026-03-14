--------------------------------------------------------------------------------
-- INBOX MESSAGE ---------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventInboxCreate ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "create" workflow event for an inbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventInboxCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Входящее сообщение создано.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxOpen --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "open" workflow event for an inbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventInboxOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Входящее сообщение открыто на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxEdit --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "edit" workflow event for an inbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventInboxEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Входящее сообщение изменено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxSave --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "save" workflow event for an inbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventInboxSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Входящее сообщение сохранено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxEnable ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "enable" workflow event for an inbox message (marks as reviewed).
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventInboxEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Входящее сообщение просмотрено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxDisable -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "disable" workflow event for an inbox message (marks as read).
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventInboxDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Входящее сообщение прочитано.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxDelete ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "delete" (soft) workflow event for an inbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventInboxDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Входящее сообщение удалено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxRestore -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "restore" workflow event for an inbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventInboxRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Входящее сообщение восстановлено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxDrop --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "drop" workflow event: log permanent destruction of an inbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventInboxDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Входящее сообщение уничтожено.');
END;
$$ LANGUAGE plpgsql;
