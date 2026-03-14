--------------------------------------------------------------------------------
-- FUNCTION DoLogin ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute custom logic after a successful user login.
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
 * @brief Execute custom logic before a user logout.
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
 * @brief Execute custom logic after a new area is created.
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
 * @brief Execute custom logic after an area is updated.
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
 * @brief Execute custom logic before an area is deleted.
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
 * @brief Execute custom logic after a new role is created.
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
 * @brief Execute custom logic after a role is updated.
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
 * @brief Execute custom logic before a role is deleted.
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
