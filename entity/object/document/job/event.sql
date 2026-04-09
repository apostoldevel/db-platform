--------------------------------------------------------------------------------
-- JOB -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventJobCreate --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "create" workflow event for a job; auto-enables the job.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1001, 'lifecycle', 'create', 'Job created.', pObject);
  PERFORM DoEnable(pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobOpen ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "open" workflow event for a job.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1002, 'lifecycle', 'open', 'Job opened.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobEdit ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "edit" workflow event for a job.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1003, 'lifecycle', 'edit', 'Job updated.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobSave ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "save" workflow event for a job.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1004, 'lifecycle', 'save', 'Job saved.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobEnable --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "enable" workflow event for a job (marks it as active).
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2001, 'workflow', 'enable', 'Job enabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobDisable -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "disable" workflow event for a job (marks it as inactive).
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2002, 'workflow', 'disable', 'Job disabled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobDelete --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "delete" (soft) workflow event for a job.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2003, 'workflow', 'delete', 'Job deleted.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobRestore -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "restore" workflow event for a job.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2004, 'workflow', 'restore', 'Job restored.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobExecute -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "execute" workflow event when a job begins running.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobExecute (
  pObject        uuid default context_object()
) RETURNS        void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2010, 'workflow.job', 'execute', 'Job in progress.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobComplete ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "complete" workflow event when a job finishes successfully.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobComplete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2011, 'workflow.job', 'complete', 'Job completed.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobDone ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "done" workflow event: reschedule the job based on scheduler period.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobDone (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  uScheduler uuid;
  dtDateRun  timestamptz;

  iPeriod    interval;
BEGIN
  SELECT scheduler, daterun INTO uScheduler, dtDateRun FROM db.job WHERE id = pObject;
  SELECT period INTO iPeriod FROM db.scheduler WHERE id = uScheduler;

  iPeriod := coalesce(iPeriod, '0 seconds'::interval);

  IF dtDateRun > Now() THEN
    dtDateRun := Now();
  END IF;

  dtDateRun := dtDateRun + iPeriod;

  IF dtDateRun < Now() THEN
    dtDateRun := Now();
  END IF;

  UPDATE db.job SET daterun = dtDateRun WHERE id = pObject;

  PERFORM WriteToEventLog('M', 2012, 'workflow.job', 'done', 'Job done.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobFail ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "fail" workflow event when a job execution fails.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobFail (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('W', 2021, 'workflow.job', 'fail', 'Job failed.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobAbort ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "abort" workflow event when a job is forcefully stopped.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobAbort (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('W', 2025, 'workflow.job', 'abort', 'Job aborted.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobCancel --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "cancel" workflow event when a job is cancelled.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobCancel (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 2020, 'workflow.job', 'cancel', 'Job cancelled.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventJobDrop ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Handle the "drop" workflow event: permanently delete a job from db.job.
 * @param {uuid} pObject - Job identifier (defaults to context object)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EventJobDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.job WHERE id = pObject;

  PERFORM WriteToEventLog('W', 2005, 'workflow', 'drop', 'Job dropped.', pObject);
END;
$$ LANGUAGE plpgsql;
