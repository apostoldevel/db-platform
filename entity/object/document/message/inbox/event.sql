--------------------------------------------------------------------------------
-- INBOX MESSAGE ---------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventInboxCreate ------------------------------------------------------------
--------------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION EventInboxEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Входящее сообщение изменёно.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxSave --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventInboxSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Входящее сообщение сохранёно.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxEnable ------------------------------------------------------------
--------------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION EventInboxDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Входящее сообщение удалёно.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventInboxRestore -----------------------------------------------------------
--------------------------------------------------------------------------------

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
