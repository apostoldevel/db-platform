--------------------------------------------------------------------------------
-- FORM ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventFormCreate -------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'create' event for a form.
 * @param {uuid} pObject - Form object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventFormCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1001, 'lifecycle', 'create', 'Form created.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventFormOpen ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'open' event for a form.
 * @param {uuid} pObject - Form object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventFormOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1002, 'lifecycle', 'open', 'Form opened.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventFormEdit ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'edit' event for a form.
 * @param {uuid} pObject - Form object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventFormEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1003, 'lifecycle', 'edit', 'Form updated.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventFormSave ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'save' event for a form.
 * @param {uuid} pObject - Form object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventFormSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1004, 'lifecycle', 'save', 'Form saved.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventFormEnable -------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'enable' event for a form.
 * @param {uuid} pObject - Form object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventFormEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2001, 'workflow', 'enable', 'Form enabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventFormDisable ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'disable' event for a form.
 * @param {uuid} pObject - Form object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventFormDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2002, 'workflow', 'disable', 'Form disabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventFormDelete -------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'delete' (soft) event for a form.
 * @param {uuid} pObject - Form object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventFormDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2003, 'workflow', 'delete', 'Form deleted.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventFormRestore ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'restore' event for a form.
 * @param {uuid} pObject - Form object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventFormRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2004, 'workflow', 'restore', 'Form restored.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventFormDrop ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'drop' event: permanently delete form data from db.form.
 * @param {uuid} pObject - Form object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventFormDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.form WHERE id = pObject;

  PERFORM WriteToEventLog('W', 2005, 'workflow', 'drop', 'Form dropped.', pObject);
END;
$$ LANGUAGE plpgsql;
