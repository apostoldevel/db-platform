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
  PERFORM WriteToEventLog('M', 1001, 'lifecycle', 'create', 'Report tree created.', pObject);
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
  PERFORM WriteToEventLog('M', 1002, 'lifecycle', 'open', 'Report tree opened.', pObject);
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
  PERFORM WriteToEventLog('M', 1003, 'lifecycle', 'edit', 'Report tree updated.', pObject);
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
  PERFORM WriteToEventLog('M', 1004, 'lifecycle', 'save', 'Report tree saved.', pObject);
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
  PERFORM WriteToEventLog('M', 2001, 'workflow', 'enable', 'Report tree enabled.', pObject);
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
  PERFORM WriteToEventLog('M', 2002, 'workflow', 'disable', 'Report tree disabled.', pObject);
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
  PERFORM WriteToEventLog('M', 2003, 'workflow', 'delete', 'Report tree deleted.', pObject);
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
  PERFORM WriteToEventLog('M', 2004, 'workflow', 'restore', 'Report tree restored.', pObject);
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

  PERFORM WriteToEventLog('W', 2005, 'workflow', 'drop', 'Report tree dropped.', pObject);
END;
$$ LANGUAGE plpgsql;
