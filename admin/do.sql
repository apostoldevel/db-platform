--------------------------------------------------------------------------------
-- FUNCTION DoLogin ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Hook called after a successful user login. Override to add custom post-login logic.
 * @param {uuid} pUserId - Authenticated user identifier
 * @return {void}
 * @since 1.0.0
 */
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
/**
 * @brief Hook called before a user logout. Override to add custom pre-logout logic.
 * @param {uuid} pUserId - User identifier being logged out
 * @return {void}
 * @since 1.0.0
 */
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
/**
 * @brief Hook called after a new area is created. Override to add custom post-create logic.
 * @param {uuid} pArea - Newly created area identifier
 * @return {void}
 * @since 1.0.0
 */
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
/**
 * @brief Hook called after an area is updated. Override to add custom post-update logic.
 * @param {uuid} pArea - Updated area identifier
 * @return {void}
 * @since 1.0.0
 */
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
/**
 * @brief Hook called before an area is deleted. Override to add custom pre-delete logic.
 * @param {uuid} pArea - Area identifier being deleted
 * @return {void}
 * @since 1.0.0
 */
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
/**
 * @brief Hook called after a new role is created. Override to add custom post-create logic.
 * @param {uuid} pRole - Newly created role identifier
 * @return {void}
 * @since 1.0.0
 */
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
/**
 * @brief Hook called after a role is updated. Override to add custom post-update logic.
 * @param {uuid} pRole - Updated role identifier
 * @return {void}
 * @since 1.0.0
 */
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
/**
 * @brief Hook called before a role is deleted. Override to add custom pre-delete logic.
 * @param {uuid} pRole - Role identifier being deleted
 * @return {void}
 * @since 1.0.0
 */
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
