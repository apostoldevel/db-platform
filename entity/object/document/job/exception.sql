--------------------------------------------------------------------------------
-- FUNCTION JobExists ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JobExists (
  pCode      text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Задание с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
