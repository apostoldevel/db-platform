--------------------------------------------------------------------------------
-- ADDRESS ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventAddressCreate ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressCreate (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Адрес создан.', pObject);
  PERFORM DoEnable(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressOpen ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressOpen (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Адрес открыт на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressEdit ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressEdit (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Адрес изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressSave ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressSave (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Адрес сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressEnable ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressEnable (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Адрес открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressDisable ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressDisable (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Адрес закрыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressDelete ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressDelete (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Адрес удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressRestore ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressRestore (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Адрес восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressDrop ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressDrop (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
DECLARE
  r			record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.object_link WHERE linked = pObject;
  DELETE FROM db.address WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Адрес уничтожен.');
END;
$$ LANGUAGE plpgsql;
