--------------------------------------------------------------------------------
-- VERSION ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventVersionCreate ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'create' event for a version.
 * @param {uuid} pObject - Version object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventVersionCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1001, 'lifecycle', 'create', 'Version created.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventVersionOpen ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'open' event for a version.
 * @param {uuid} pObject - Version object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventVersionOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1002, 'lifecycle', 'open', 'Version opened.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventVersionEdit ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'edit' event for a version.
 * @param {uuid} pObject - Version object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventVersionEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1003, 'lifecycle', 'edit', 'Version updated.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventVersionSave ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'save' event for a version.
 * @param {uuid} pObject - Version object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventVersionSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1004, 'lifecycle', 'save', 'Version saved.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventVersionEnable ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'enable' event for a version.
 * @param {uuid} pObject - Version object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventVersionEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2001, 'workflow', 'enable', 'Version enabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventVersionDisable ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'disable' event for a version.
 * @param {uuid} pObject - Version object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventVersionDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2002, 'workflow', 'disable', 'Version disabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventVersionDelete ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'delete' (soft) event for a version.
 * @param {uuid} pObject - Version object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventVersionDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2003, 'workflow', 'delete', 'Version deleted.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventVersionRestore ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'restore' event for a version.
 * @param {uuid} pObject - Version object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventVersionRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2004, 'workflow', 'restore', 'Version restored.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventVersionDrop ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'drop' event: permanently delete version data from db.version.
 * @param {uuid} pObject - Version object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventVersionDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.version WHERE id = pObject;

  PERFORM WriteToEventLog('W', 2005, 'workflow', 'drop', 'Version dropped.', pObject);
END;
$$ LANGUAGE plpgsql;
