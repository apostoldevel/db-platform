--------------------------------------------------------------------------------
-- FUNCTION ClientCodeExists  --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClientCodeExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Клиент с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION AccountNotClient  --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AccountNotClient (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Учётная запись не принадлежит клиенту.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION EmailAddressNotSet  ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EmailAddressNotSet (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Не задан адрес электронной почты.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION EmailAddressNotVerified  -------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EmailAddressNotVerified (
  pEmail    text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Адрес электронной почты "%" не подтверждён.', pEmail;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION PhoneNumberNotSet  -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION PhoneNumberNotSet (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Не задан номер телефона.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION PhoneNumberNotVerified  --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION PhoneNumberNotVerified (
  pPhone    text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Телефон "%" не подтверждён.', pPhone;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
