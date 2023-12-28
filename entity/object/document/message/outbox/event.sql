--------------------------------------------------------------------------------
-- OUTBOX MESSAGE --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventOutboxCreate -----------------------------------------------------------
--------------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION EventOutboxEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Исходящее сообщение изменёно.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxSave -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventOutboxSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Исходящее сообщение сохранёно.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxEnable -----------------------------------------------------------
--------------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION EventOutboxDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Исходящее сообщение удалёно.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventOutboxRestore ----------------------------------------------------------
--------------------------------------------------------------------------------

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
