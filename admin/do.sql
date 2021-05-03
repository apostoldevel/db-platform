--------------------------------------------------------------------------------
-- FUNCTION DoLogin ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoLogin (
  pUserId   uuid
) RETURNS   void
AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoLogout -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoLogout (
  pUserId   uuid
) RETURNS   void
AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoCreateArea -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoCreateArea (
  pArea     uuid
) RETURNS   void
AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoUpdateArea -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoUpdateArea (
  pArea     uuid
) RETURNS   void
AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
