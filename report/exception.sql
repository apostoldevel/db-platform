--------------------------------------------------------------------------------
-- FUNCTION ShipExists ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ShipExists (
  pCode      text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Судно с идентификатором "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
