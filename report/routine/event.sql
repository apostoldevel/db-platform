--------------------------------------------------------------------------------
-- REPORT FORM -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventReportRoutineCreate ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'create' workflow event for a report routine.
 * @param {uuid} pObject - Report routine object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportRoutineCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Функция отчёта создана.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineOpen ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'open' workflow event for a report routine.
 * @param {uuid} pObject - Report routine object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportRoutineOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Функция отчёта открыта.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineEdit ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'edit' workflow event for a report routine.
 * @param {uuid} pObject - Report routine object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportRoutineEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Функция отчёта изменена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineSave ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'save' workflow event for a report routine.
 * @param {uuid} pObject - Report routine object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportRoutineSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Функция отчёта сохранена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineEnable ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'enable' workflow event for a report routine.
 * @param {uuid} pObject - Report routine object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportRoutineEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Функция отчёта включена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineDisable ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'disable' workflow event for a report routine.
 * @param {uuid} pObject - Report routine object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportRoutineDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Функция отчёта выключена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineDelete ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'delete' workflow event for a report routine.
 * @param {uuid} pObject - Report routine object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportRoutineDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Функция отчёта удалена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineRestore ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'restore' workflow event for a report routine.
 * @param {uuid} pObject - Report routine object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportRoutineRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Функция отчёта восстановлена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportRoutineDrop ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'drop' workflow event — permanently destroy a report routine.
 * @param {uuid} pObject - Report routine object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportRoutineDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.report_routine WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Функция отчёта уничтожена.');
END;
$$ LANGUAGE plpgsql;
