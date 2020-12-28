--------------------------------------------------------------------------------
-- ADDRESS ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventAddressCreate ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressCreate (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1010, 'Адрес создан.', pObject);
  PERFORM DoEnable(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressOpen ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressOpen (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1011, 'Адрес открыт на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressEdit ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressEdit (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1012, 'Адрес изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressSave ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressSave (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1013, 'Адрес сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressEnable ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressEnable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1014, 'Адрес открыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressDisable ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressDisable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1015, 'Адрес закрыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressDelete ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressDelete (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1016, 'Адрес удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressRestore ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressRestore (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1017, 'Адрес восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventAddressDrop ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventAddressDrop (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  r		record;
BEGIN
  SELECT label INTO r FROM db.object WHERE id = pObject;

  DELETE FROM db.object_link WHERE linked = pObject;
  DELETE FROM db.address WHERE id = pObject;

  PERFORM WriteToEventLog('W', 2010, '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Адрес уничтожен.');
END;
$$ LANGUAGE plpgsql;
