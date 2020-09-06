--------------------------------------------------------------------------------
-- CURRENT ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.current_session ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает текущую сессии.
 * @return {session} - Сессия
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
 * Возвращает учётную запись текущего пользователя.
 * @return {users} - Учётная запись пользователя
 */
CREATE OR REPLACE FUNCTION api.current_user (
) RETURNS   SETOF users
AS $$
  SELECT * FROM users WHERE id = current_userid()
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_userid ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор авторизированного пользователя.
 * @return {numeric} - Идентификатор пользователя: users.id
 */
CREATE OR REPLACE FUNCTION api.current_userid()
RETURNS         numeric
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
 * Возвращает имя авторизированного пользователя.
 * @return {text} - Имя (username) пользователя: users.username
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
 * Возвращает данные текущей зоны.
 * @return {area} - Зона
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
 * Возвращает данные текущего интерфейса.
 * @return {interface} - Интерфейс
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
 * Возвращает данные текущего языка.
 * @return {locale} - Язык
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
 * Возвращает дату операционного дня.
 * @return {timestamp} - Дата операционного дня
 */
CREATE OR REPLACE FUNCTION api.oper_date()
RETURNS         timestamp
AS $$
BEGIN
  RETURN oper_date();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
