--------------------------------------------------------------------------------
-- SCHEDULER -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.scheduler ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.scheduler (
    id              uuid PRIMARY KEY,
    reference       uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    period          interval,
    dateStart       timestamptz NOT NULL DEFAULT Now(),
    dateStop        timestamptz NOT NULL DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD')
);

COMMENT ON TABLE db.scheduler IS 'Job scheduler — defines execution interval and active date range for recurring tasks.';

COMMENT ON COLUMN db.scheduler.id IS 'Primary key (same as reference.id).';
COMMENT ON COLUMN db.scheduler.reference IS 'Parent reference catalog entry.';
COMMENT ON COLUMN db.scheduler.period IS 'Execution interval (e.g., ''1 hour'', ''5 minutes'').';
COMMENT ON COLUMN db.scheduler.dateStart IS 'Start of the active window (defaults to now).';
COMMENT ON COLUMN db.scheduler.dateStop IS 'End of the active window (defaults to far future).';

CREATE INDEX ON db.scheduler (reference);

--------------------------------------------------------------------------------

/**
 * @brief Auto-set primary key from parent reference id and default date range on new scheduler rows.
 * @return {trigger}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_scheduler_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.reference INTO NEW.id;
  END IF;

  IF NEW.dateStart IS NULL THEN
    NEW.dateStart := Now();
  END IF;

  IF NEW.dateStop IS NULL THEN
    NEW.dateStop := TO_DATE('4433-12-31', 'YYYY-MM-DD');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_scheduler_insert
  BEFORE INSERT ON db.scheduler
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_scheduler_insert();
