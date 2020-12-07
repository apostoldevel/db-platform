--------------------------------------------------------------------------------
-- FUNCTION JobExists ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JobExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Задание с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
