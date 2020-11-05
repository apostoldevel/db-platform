--------------------------------------------------------------------------------
-- FUNCTION TaskExists -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION TaskExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Задача с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
