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

--------------------------------------------------------------------------------
-- FUNCTION DoDeleteArea -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoDeleteArea (
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
-- FUNCTION DoCreateRole -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoCreateRole (
  pRole     uuid
) RETURNS   void
AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoUpdateRole -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoUpdateRole (
  pRole     uuid
) RETURNS   void
AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoDeleteRole -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoDeleteRole (
  pRole     uuid
) RETURNS   void
AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
