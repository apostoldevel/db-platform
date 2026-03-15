--------------------------------------------------------------------------------
-- SESSION ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.set_session_area --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the current session area (scope visibility zone) by ID.
 * @param {uuid} pArea - Area identifier
 * @return {void}
 * @throws ObjectNotFound - When the area does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_session_area (
  pArea     uuid
) RETURNS   void
AS $$
DECLARE
  uId        uuid;
BEGIN
  SELECT id INTO uId FROM db.area WHERE id = pArea;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('scope', 'id', pArea);
  END IF;

  PERFORM SetArea(pArea);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_area --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the current session area (scope visibility zone) by code.
 * @param {text} pArea - Area code
 * @return {void}
 * @throws ObjectNotFound - When the area code does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_session_area (
  pArea     text
) RETURNS   void
AS $$
DECLARE
  uId       uuid;
BEGIN
  SELECT id INTO uId FROM db.area WHERE code = pArea;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('scope', 'code', pArea);
  END IF;

  PERFORM SetArea(uId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_interface ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the current session interface by ID.
 * @param {uuid} pInterface - Interface identifier
 * @return {void}
 * @throws ObjectNotFound - When the interface does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_session_interface (
  pInterface    uuid
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
BEGIN
  SELECT id INTO uId FROM db.interface WHERE id = pInterface;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('interface', 'id', pInterface);
  END IF;

  PERFORM SetInterface(pInterface);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_interface ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the current session interface by ID (resolves and stores).
 * @param {uuid} pInterface - Interface identifier
 * @return {void}
 * @throws ObjectNotFound - When the interface does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_session_interface (
  pInterface    uuid
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
BEGIN
  SELECT id INTO uId FROM db.interface WHERE id = pInterface;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('interface', 'id', pInterface);
  END IF;

  PERFORM SetInterface(uId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_oper_date ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the operational date for the current session (without time zone).
 * @param {timestamp} pOperDate - Operational (business) date
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_session_oper_date (
  pOperDate     timestamp
) RETURNS       void
AS $$
BEGIN
  PERFORM SetOperDate(pOperDate);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_oper_date ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the operational date for the current session (with time zone).
 * @param {timestamptz} pOperDate - Operational (business) date with time zone
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_session_oper_date (
  pOperDate   timestamptz
) RETURNS     void
AS $$
BEGIN
  PERFORM SetOperDate(pOperDate);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_locale ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the current session locale by ID.
 * @param {uuid} pLocale - Locale identifier
 * @return {void}
 * @throws ObjectNotFound - When the locale does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_session_locale (
  pLocale     uuid
) RETURNS     void
AS $$
DECLARE
  uId         uuid;
BEGIN
  SELECT id INTO uId FROM db.locale WHERE id = pLocale;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('locale', 'id', pLocale);
  END IF;

  PERFORM SetSessionLocale(pLocale);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_locale ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the current session locale by language code.
 * @param {text} pCode - ISO language code (e.g. 'en', 'ru')
 * @return {void}
 * @throws IncorrectCode - When the language code is not registered
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_session_locale (
  pCode     text DEFAULT 'ru'
) RETURNS   void
AS $$
DECLARE
  arCodes   text[];
  r         record;
BEGIN
  FOR r IN SELECT code FROM db.locale
  LOOP
    arCodes := array_append(arCodes, r.code);
  END LOOP;

  IF array_position(arCodes, pCode) IS NULL THEN
    PERFORM IncorrectCode(pCode, arCodes);
  END IF;

  PERFORM SetSessionLocale(GetLocale(pCode));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
