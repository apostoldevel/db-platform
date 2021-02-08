--------------------------------------------------------------------------------
-- JOB -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.job ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.job (
    id			    numeric(12) PRIMARY KEY,
    document	    numeric(12) NOT NULL,
    code		    text NOT NULL,
    scheduler       numeric(12) NOT NULL,
    program         numeric(12) NOT NULL,
    dateRun         timestamptz NOT NULL DEFAULT Now(),
    CONSTRAINT fk_job_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_job_scheduler FOREIGN KEY (scheduler) REFERENCES db.scheduler(id),
    CONSTRAINT fk_job_program FOREIGN KEY (program) REFERENCES db.program(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.job IS 'Задание.';

COMMENT ON COLUMN db.job.id IS 'Идентификатор';
COMMENT ON COLUMN db.job.document IS 'Документ';
COMMENT ON COLUMN db.job.code IS 'Код';
COMMENT ON COLUMN db.job.scheduler IS 'Планировщик';
COMMENT ON COLUMN db.job.program IS 'Программа';
COMMENT ON COLUMN db.job.dateRun IS 'Дата запуска.';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.job (code);

CREATE INDEX ON db.job (document);
CREATE INDEX ON db.job (scheduler);
CREATE INDEX ON db.job (program);
CREATE INDEX ON db.job (dateRun);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_job_insert()
RETURNS trigger AS $$
DECLARE
  iPeriod		interval;
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
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

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_job_insert
  BEFORE INSERT ON db.job
  FOR EACH ROW
  EXECUTE PROCEDURE ft_job_insert();
