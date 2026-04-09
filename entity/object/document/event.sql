--------------------------------------------------------------------------------
-- DOCUMENT --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventDocumentCreate ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "create" workflow event for a document.
 * @param {uuid} pObject - Document identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventDocumentCreate (
  pObject    uuid DEFAULT context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1001, 'lifecycle', 'create', 'Document created.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentOpen -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "open" workflow event for a document.
 * @param {uuid} pObject - Document identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventDocumentOpen (
  pObject    uuid DEFAULT context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1002, 'lifecycle', 'open', 'Document opened.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentEdit -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "edit" workflow event for a document.
 * @param {uuid} pObject - Document identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventDocumentEdit (
  pObject    uuid DEFAULT context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1003, 'lifecycle', 'edit', 'Document updated.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentSave -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "save" workflow event for a document.
 * @param {uuid} pObject - Document identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventDocumentSave (
  pObject    uuid DEFAULT context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1004, 'lifecycle', 'save', 'Document saved.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentEnable ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "enable" workflow event for a document.
 * @param {uuid} pObject - Document identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventDocumentEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2001, 'workflow', 'enable', 'Document enabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentDisable --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "disable" workflow event for a document.
 * @param {uuid} pObject - Document identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventDocumentDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2002, 'workflow', 'disable', 'Document disabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentDelete ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "delete" (soft) workflow event for a document.
 * @param {uuid} pObject - Document identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventDocumentDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2003, 'workflow', 'delete', 'Document deleted.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentRestore --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "restore" workflow event for a document.
 * @param {uuid} pObject - Document identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventDocumentRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2004, 'workflow', 'restore', 'Document restored.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventDocumentDrop -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "drop" workflow event: permanently delete a document from db.document.
 * @param {uuid} pObject - Document identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventDocumentDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r         record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.document WHERE id = pObject;

  PERFORM WriteToEventLog('W', 2005, 'workflow', 'drop', 'Document dropped.', pObject);
END;
$$ LANGUAGE plpgsql;
