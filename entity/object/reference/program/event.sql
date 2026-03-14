--------------------------------------------------------------------------------
-- PROGRAM ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventProgramCreate ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'create' event for a program.
 * @param {uuid} pObject - Program object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventProgramCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Программа создана.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventProgramOpen ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'open' event for a program.
 * @param {uuid} pObject - Program object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventProgramOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Программа открыта на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventProgramEdit ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'edit' event for a program.
 * @param {uuid} pObject - Program object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventProgramEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Программа изменена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventProgramSave ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'save' event for a program.
 * @param {uuid} pObject - Program object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventProgramSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Программа сохранена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventProgramEnable ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'enable' event for a program.
 * @param {uuid} pObject - Program object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventProgramEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Программа открыта.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventProgramDisable ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'disable' event for a program.
 * @param {uuid} pObject - Program object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventProgramDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Программа закрыта.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventProgramDelete ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'delete' (soft) event for a program.
 * @param {uuid} pObject - Program object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventProgramDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Программа удалена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventProgramRestore ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'restore' event for a program.
 * @param {uuid} pObject - Program object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventProgramRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Программа восстановлена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventProgramDrop ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Handle the 'drop' event: permanently delete program data from db.program.
 * @param {uuid} pObject - Program object ID
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventProgramDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.program WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Программа уничтожена.');
END;
$$ LANGUAGE plpgsql;
