DROP VIEW Report CASCADE;

DROP FUNCTION api.add_report(uuid, uuid, uuid, uuid, text, text, text, jsonb);
DROP FUNCTION api.update_report(uuid, uuid, uuid, uuid, uuid, text, text, text, jsonb);

DROP FUNCTION CreateReport(uuid, uuid, uuid, uuid, text, text, text, jsonb);
DROP FUNCTION EditReport(uuid, uuid, uuid, uuid, uuid, text, text, text, jsonb);

ALTER TABLE db.report
  ADD COLUMN binding uuid REFERENCES db.class_tree(id);

COMMENT ON COLUMN db.report.binding IS 'Связь с классом объекта (для отчётов объекта).';

CREATE INDEX ON db.report (binding);
