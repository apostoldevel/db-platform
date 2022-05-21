DROP VIEW Document CASCADE;
DROP VIEW DocumentAreaTree CASCADE;
DROP VIEW CurrentDocument CASCADE;
--

DROP VIEW ObjectJob CASCADE;
DROP VIEW ServiceJob CASCADE;
--

DROP VIEW ObjectMessage CASCADE;
DROP VIEW ServiceMessage CASCADE;
--

DROP FUNCTION IF EXISTS CreateDocument(uuid, uuid, text, text, text, uuid);
DROP FUNCTION IF EXISTS EditDocument(uuid, uuid, uuid, text, text, text, uuid);

DROP FUNCTION IF EXISTS SetAction(text, text, text);

--------------------------------------------------------------------------------
-- PRIORITY --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.priority (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    code		text NOT NULL
);

COMMENT ON TABLE db.priority IS 'Приоритет.';

COMMENT ON COLUMN db.priority.id IS 'Идентификатор';
COMMENT ON COLUMN db.priority.code IS 'Код';

CREATE UNIQUE INDEX ON db.priority (code);

--------------------------------------------------------------------------------
-- db.priority_text ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.priority_text (
    priority    uuid NOT NULL REFERENCES db.priority(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    name        text NOT NULL,
    description text,
    PRIMARY KEY (priority, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.priority_text IS 'Текст приоритета.';

COMMENT ON COLUMN db.priority_text.priority IS 'Идентификатор приоритета';
COMMENT ON COLUMN db.priority_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.priority_text.name IS 'Наименование';
COMMENT ON COLUMN db.priority_text.description IS 'Описание';

--------------------------------------------------------------------------------

CREATE INDEX ON db.priority_text (priority);
CREATE INDEX ON db.priority_text (locale);
--

\ir '../workflow/update.psql'

--

SELECT EditPriorityText(AddPriority('00000000-0000-4000-b004-000000000000', 'low', 'Низкий'), 'Low', null, GetLocale('en'));
SELECT EditPriorityText(AddPriority('00000000-0000-4000-b004-000000000001', 'medium', 'Средний'), 'Medium', null, GetLocale('en'));
SELECT EditPriorityText(AddPriority('00000000-0000-4000-b004-000000000002', 'high', 'Высокий'), 'High', null, GetLocale('en'));
SELECT EditPriorityText(AddPriority('00000000-0000-4000-b004-000000000003', 'critical', 'Критический'), 'Critical', null, GetLocale('en'));
--

ALTER TABLE db.document ADD COLUMN priority uuid NOT NULL REFERENCES db.priority(id) DEFAULT '00000000-0000-4000-b004-000000000001';

COMMENT ON COLUMN db.document.priority IS 'Приоритет';

CREATE INDEX ON db.document (priority);

--

CREATE OR REPLACE FUNCTION db.ft_document_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.object INTO NEW.id;
  END IF;

  IF current_area_type() = '00000000-0000-4002-a000-000000000000'::uuid THEN
    PERFORM RootAreaError();
  END IF;

  IF NEW.priority IS NULL THEN
    SELECT '00000000-0000-4000-b004-000000000001'::uuid INTO NEW.priority;
  END IF;

  IF NEW.area IS NULL THEN
    SELECT current_area() INTO NEW.area;
  END IF;

  SELECT scope INTO NEW.scope FROM db.area WHERE id = NEW.area;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
