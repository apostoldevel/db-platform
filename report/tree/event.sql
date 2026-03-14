--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventReportMethodForAllChild ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Propagate a workflow action to all direct children of a tree node.
 * @param {uuid} pNode - Parent tree node identifier
 * @param {uuid} pAction - Workflow action to execute on each child
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportMethodForAllChild (
  pNode     uuid default context_object(),
  pAction   uuid default context_action()
) RETURNS   void
AS $$
DECLARE
  r         record;

  uClass    uuid;
  uState    uuid;
  uMethod   uuid;
BEGIN
  FOR r IN SELECT id FROM db.report_tree WHERE node = pNode
  LOOP
    SELECT class, state INTO uClass, uState FROM db.object WHERE id = r.id;
    uMethod := GetMethod(uClass, pAction, uState);
    IF uMethod IS NOT NULL THEN
      PERFORM ExecuteMethod(r.id, uMethod);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportTreeCreate -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'create' workflow event for a report tree node.
 * @param {uuid} pObject - Tree node object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportTreeCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Дерево отчётов создано.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportTreeOpen ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'open' workflow event for a report tree node.
 * @param {uuid} pObject - Tree node object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportTreeOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Дерево отчётов открыто.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportTreeEdit ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'edit' workflow event for a report tree node.
 * @param {uuid} pObject - Tree node object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportTreeEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Дерево отчётов изменено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportTreeSave ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'save' workflow event for a report tree node.
 * @param {uuid} pObject - Tree node object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportTreeSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Дерево отчётов сохранено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportTreeEnable -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'enable' workflow event for a report tree node and propagate to children.
 * @param {uuid} pObject - Tree node object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportTreeEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Дерево отчётов активно.', pObject);
  PERFORM EventReportMethodForAllChild(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportTreeDisable ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'disable' workflow event for a report tree node and propagate to children.
 * @param {uuid} pObject - Tree node object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportTreeDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Дерево отчётов неактивно.', pObject);
  PERFORM EventReportMethodForAllChild(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportTreeDelete -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'delete' workflow event for a report tree node and propagate to children.
 * @param {uuid} pObject - Tree node object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportTreeDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Дерево отчётов удалено.', pObject);
  PERFORM EventReportMethodForAllChild(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportTreeRestore ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'restore' workflow event for a report tree node and propagate to children.
 * @param {uuid} pObject - Tree node object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportTreeRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Дерево отчётов восстановлено.', pObject);
  PERFORM EventReportMethodForAllChild(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventReportTreeDrop ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the 'drop' workflow event — permanently destroy a tree node and propagate to children.
 * @param {uuid} pObject - Tree node object identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventReportTreeDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  PERFORM EventReportMethodForAllChild(pObject);

  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.report_tree WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Дерево отчётов уничтожено.');
END;
$$ LANGUAGE plpgsql;
