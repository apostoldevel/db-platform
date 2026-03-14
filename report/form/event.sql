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
  PERFORM WriteToEventLog('M', 1000, 'create', 'Форма отчёта создана.', pObject);
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
  PERFORM WriteToEventLog('M', 1000, 'open', 'Форма отчёта открыта.', pObject);
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
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Форма отчёта изменена.', pObject);
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
  PERFORM WriteToEventLog('M', 1000, 'save', 'Форма отчёта сохранена.', pObject);
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
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Форма отчёта включена.', pObject);
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
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Форма отчёта выключена.', pObject);
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
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Форма отчёта удалена.', pObject);
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
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Форма отчёта восстановлена.', pObject);
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

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Форма отчёта уничтожена.');
END;
$$ LANGUAGE plpgsql;
