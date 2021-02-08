--------------------------------------------------------------------------------
-- SCHEDULER -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.scheduler ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.scheduler (
    id			    numeric(12) PRIMARY KEY,
    reference		numeric(12) NOT NULL,
    period          interval,
    dateStart       timestamptz DEFAULT Now() NOT NULL,
    dateStop        timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_scheduler_reference FOREIGN KEY (reference) REFERENCES db.reference(id)
);

COMMENT ON TABLE db.scheduler IS 'Планировщик.';

COMMENT ON COLUMN db.scheduler.id IS 'Идентификатор.';
COMMENT ON COLUMN db.scheduler.reference IS 'Справочник.';
COMMENT ON COLUMN db.scheduler.period IS 'Период выполнения.';
COMMENT ON COLUMN db.scheduler.dateStart IS 'Дата начала выполнения.';
COMMENT ON COLUMN db.scheduler.dateStop IS 'Дата окончания выполнения.';

CREATE INDEX ON db.scheduler (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_scheduler_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
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
  EXECUTE PROCEDURE ft_scheduler_insert();

