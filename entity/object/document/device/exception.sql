--------------------------------------------------------------------------------
-- FUNCTION DeviceExists -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeviceExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Устройство с идентификатором "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION UnknownTransaction -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UnknownTransaction (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Неизвестная транзакия: "%".', pId;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

