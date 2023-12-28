--------------------------------------------------------------------------------
-- JOB -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.job ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.job (
    id              uuid PRIMARY KEY,
    document        uuid NOT NULL REFERENCES db.document(id) ON DELETE CASCADE,
    scope           uuid NOT NULL REFERENCES db.scope(id) ON DELETE RESTRICT,
    code            text NOT NULL,
    scheduler       uuid NOT NULL REFERENCES db.scheduler(id),
    program         uuid NOT NULL REFERENCES db.program(id),
    dateRun         timestamptz NOT NULL DEFAULT Now()
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.job IS 'Задание.';

COMMENT ON COLUMN db.job.id IS 'Идентификатор';
COMMENT ON COLUMN db.job.document IS 'Документ';
COMMENT ON COLUMN db.job.scope IS 'Область видимости базы данных';
COMMENT ON COLUMN db.job.code IS 'Код';
COMMENT ON COLUMN db.job.scheduler IS 'Планировщик';
COMMENT ON COLUMN db.job.program IS 'Программа';
COMMENT ON COLUMN db.job.dateRun IS 'Дата запуска.';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.job (scope, code);

CREATE INDEX ON db.job (document);
CREATE INDEX ON db.job (scope);
CREATE INDEX ON db.job (scheduler);
CREATE INDEX ON db.job (program);
CREATE INDEX ON db.job (dateRun);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_job_insert()
RETURNS trigger AS $$
DECLARE
  iPeriod        interval;
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS NULL THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  IF NEW.scheduler IS NOT NULL THEN
    SELECT period INTO iPeriod FROM db.scheduler WHERE id = NEW.scheduler;
    NEW.dateRun := Now() + coalesce(iPeriod, '0 seconds'::interval);
  END IF;

  IF NEW.dateRun IS NULL THEN
    NEW.dateRun := Now();
  END IF;

  IF NEW.scope IS NULL THEN
    NEW.scope := current_scope();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_job_insert
  BEFORE INSERT ON db.job
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_job_insert();
