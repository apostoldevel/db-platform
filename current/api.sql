--------------------------------------------------------------------------------
-- CURRENT ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.current_session ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current session record.
 * @return {SETOF session} - Active session details
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.current_session()
RETURNS     SETOF session
AS $$
  SELECT * FROM session WHERE code = current_session()
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_user ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current user account record.
 * @return {SETOF users} - User account for the active session and scope
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.current_user (
) RETURNS   SETOF users
AS $$
  SELECT * FROM users WHERE id = current_userid() AND scope = current_scope()
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_userid ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the authenticated user's identifier.
 * @return {uuid} - User ID (users.id) from the current session context
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.current_userid()
RETURNS         uuid
AS $$
BEGIN
  RETURN current_userid();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_username --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the authenticated user's login name.
 * @return {text} - Username (users.username) from the current session context
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.current_username()
RETURNS         text
AS $$
BEGIN
  RETURN current_username();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_area ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current session area record.
 * @return {SETOF area} - Active area (scope visibility zone) details
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.current_area (
) RETURNS        SETOF area
AS $$
  SELECT * FROM area WHERE id = current_area();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_interface -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current session interface record.
 * @return {SETOF interface} - Active interface details
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.current_interface (
) RETURNS         SETOF interface
AS $$
  SELECT * FROM interface WHERE id = current_interface();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_locale ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current session locale record.
 * @return {SETOF locale} - Active locale (language) details
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.current_locale (
) RETURNS         SETOF locale
AS $$
  SELECT * FROM locale WHERE id = current_locale();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.oper_date ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the current operational (business) date.
 * @return {timestamptz} - Operational date from the session context
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.oper_date()
RETURNS         timestamptz
AS $$
BEGIN
  RETURN GetOperDate();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
