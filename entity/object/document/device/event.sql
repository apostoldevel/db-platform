--------------------------------------------------------------------------------
-- DEVICE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventDeviceCreate -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceCreate (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Устройство создано.', pObject);
  PERFORM DoEnable(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceOpen -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceOpen (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Устройство открыто на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceEdit -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceEdit (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Устройство изменено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceSave -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceSave (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Устройство сохранено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceEnable -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceEnable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Устройство включено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceHeartbeat --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceHeartbeat (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'heartbeat', 'Устройство на связи.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceAvailable --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceAvailable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'available', 'Устройство отправило статус: Available.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceUnavailable ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceUnavailable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'unavailable', 'Устройство отправило статус: Unavailable.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceFaulted ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceFaulted (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'faulted', 'Устройство отправило статус: Faulted.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceDisable ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceDisable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Устройство отключено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceDelete -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceDelete (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Устройство удалено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceRestore ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceRestore (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Устройство восстановлено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDeviceDrop -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventDeviceDrop (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  r		    record;
  nCount    integer;
BEGIN
  SELECT label INTO r FROM db.object WHERE id = pObject;

  SELECT Count(id) INTO nCount FROM db.device_value WHERE device = pObject;
  IF nCount > 0 THEN
    RAISE EXCEPTION 'ERR-40000: Обнаружены данные, операция прервана.';
  END IF;

  DELETE FROM db.device WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Устройство уничтожено.');
END;
$$ LANGUAGE plpgsql;
