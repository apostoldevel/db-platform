--------------------------------------------------------------------------------
-- REPORT FORM -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventReportFormCreate -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'create' workflow event for a report form.
 * @param {uuid} pObject - Report form object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportFormCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1001, 'lifecycle', 'create', 'Report form created.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportFormOpen ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'open' workflow event for a report form.
 * @param {uuid} pObject - Report form object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportFormOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1002, 'lifecycle', 'open', 'Report form opened.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportFormEdit ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'edit' workflow event for a report form.
 * @param {uuid} pObject - Report form object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportFormEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1003, 'lifecycle', 'edit', 'Report form updated.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportFormSave ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'save' workflow event for a report form.
 * @param {uuid} pObject - Report form object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportFormSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1004, 'lifecycle', 'save', 'Report form saved.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportFormEnable -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'enable' workflow event for a report form.
 * @param {uuid} pObject - Report form object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportFormEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2001, 'workflow', 'enable', 'Report form enabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportFormDisable ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'disable' workflow event for a report form.
 * @param {uuid} pObject - Report form object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportFormDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2002, 'workflow', 'disable', 'Report form disabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportFormDelete -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'delete' workflow event for a report form.
 * @param {uuid} pObject - Report form object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportFormDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2003, 'workflow', 'delete', 'Report form deleted.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportFormRestore ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'restore' workflow event for a report form.
 * @param {uuid} pObject - Report form object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportFormRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2004, 'workflow', 'restore', 'Report form restored.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportFormDrop ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'drop' workflow event — permanently destroy a report form.
 * @param {uuid} pObject - Report form object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportFormDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.report_form WHERE id = pObject;

  PERFORM WriteToEventLog('W', 2005, 'workflow', 'drop', 'Report form dropped.', pObject);
END;
$$ LANGUAGE plpgsql;
