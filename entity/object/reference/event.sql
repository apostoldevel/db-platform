--------------------------------------------------------------------------------
-- REFERENCE -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventReferenceCreate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'create' event for a reference: log creation and enable.
 * @param {uuid} pObject - Reference object ID (defaults to context)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReferenceCreate (
  pObject        uuid default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1001, 'lifecycle', 'create', 'Reference created.', pObject);
  PERFORM DoEnable(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceOpen ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'open' event for a reference.
 * @param {uuid} pObject - Reference object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReferenceOpen (
  pObject        uuid default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1002, 'lifecycle', 'open', 'Reference opened.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceEdit ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'edit' event for a reference.
 * @param {uuid} pObject - Reference object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReferenceEdit (
  pObject        uuid default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1003, 'lifecycle', 'edit', 'Reference updated.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceSave ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'save' event for a reference.
 * @param {uuid} pObject - Reference object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReferenceSave (
  pObject        uuid default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1004, 'lifecycle', 'save', 'Reference saved.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceEnable --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'enable' event for a reference.
 * @param {uuid} pObject - Reference object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReferenceEnable (
  pObject        uuid default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2001, 'workflow', 'enable', 'Reference enabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceDisable -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'disable' event for a reference.
 * @param {uuid} pObject - Reference object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReferenceDisable (
  pObject        uuid default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2002, 'workflow', 'disable', 'Reference disabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceDelete --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'delete' (soft) event for a reference.
 * @param {uuid} pObject - Reference object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReferenceDelete (
  pObject        uuid default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2003, 'workflow', 'delete', 'Reference deleted.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceRestore -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'restore' event for a reference.
 * @param {uuid} pObject - Reference object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReferenceRestore (
  pObject        uuid default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2004, 'workflow', 'restore', 'Reference restored.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReferenceDrop ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'drop' event: permanently delete reference data from db.reference.
 * @param {uuid} pObject - Reference object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReferenceDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.reference WHERE id = pObject;

  PERFORM WriteToEventLog('W', 2005, 'workflow', 'drop', 'Reference dropped.', pObject);
END;
$$ LANGUAGE plpgsql;
