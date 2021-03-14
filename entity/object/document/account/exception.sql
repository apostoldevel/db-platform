--------------------------------------------------------------------------------
-- FUNCTION AccountCodeExists --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AccountCodeExists (
  pCode		text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Счёт "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION AccountNotFound ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AccountNotFound (
  pCode		text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Счёт "%" не найден.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION AccountNotAssociated -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AccountNotAssociated (
  pCode     text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Счёт "%" не связан с клиентом.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
