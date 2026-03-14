--------------------------------------------------------------------------------
-- OUTBOX MESSAGE --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventOutboxCreate -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "create" workflow event for an outbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Исходящее сообщение создано.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxOpen -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "open" workflow event for an outbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Исходящее сообщение открыто на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxEdit -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "edit" workflow event for an outbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Исходящее сообщение изменено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxSave -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "save" workflow event for an outbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Исходящее сообщение сохранено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxEnable -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "enable" workflow event for an outbox message (ready to send).
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Исходящее сообщение готово к отправке.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxSubmit -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "submit" workflow event for an outbox message (queued for delivery).
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxSubmit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'submit', 'Исходящее сообщение передано на отправку.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxSend -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "send" workflow event for an outbox message (delivery in progress).
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxSend (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'send', 'Исходящее сообщение отправляется.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxCancel -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "cancel" workflow event for an outbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxCancel (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'cancel', 'Исходящее сообщение отменено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxDone -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "done" workflow event for an outbox message (delivery completed).
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxDone (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'done', 'Исходящее сообщение отправено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxFail -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "fail" workflow event when outbox message delivery fails.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxFail (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'fail', 'Сбой при отправке сообщения.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxRepeat -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "repeat" workflow event to retry outbox message delivery.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxRepeat (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'repeat', 'Повторная отправка сообщения.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxDisable ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "disable" workflow event for an outbox message (closed).
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Исходящее сообщение закрыто.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxDelete -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "delete" (soft) workflow event for an outbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Исходящее сообщение удалено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxRestore ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "restore" workflow event for an outbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Исходящее сообщение восстановлено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxDrop -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "drop" workflow event: log permanent destruction of an outbox message.
 * @param {uuid} pObject - Message identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventOutboxDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Исходящее сообщение уничтожено.');
END;
$$ LANGUAGE plpgsql;
