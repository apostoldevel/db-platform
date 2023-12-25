--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.report_tree --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.report_tree (
    id              uuid PRIMARY KEY,
    reference       uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    root            uuid NOT NULL REFERENCES db.report_tree(id),
    node            uuid REFERENCES db.report_tree(id),
    level           integer NOT NULL,
    sequence        integer NOT NULL
);

COMMENT ON TABLE db.report_tree IS 'Дерево отчётов.';

COMMENT ON COLUMN db.report_tree.id IS 'Идентификатор.';
COMMENT ON COLUMN db.report_tree.reference IS 'Справочник.';
COMMENT ON COLUMN db.report_tree.root IS 'Корневой узел.';
COMMENT ON COLUMN db.report_tree.node IS 'Родительский узел.';
COMMENT ON COLUMN db.report_tree.level IS 'Уровень вложенности.';
COMMENT ON COLUMN db.report_tree.sequence IS 'Очерёдность';

CREATE INDEX ON db.report_tree (reference);
CREATE INDEX ON db.report_tree (root);
CREATE INDEX ON db.report_tree (node);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_report_tree_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.reference INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_report_tree_insert
  BEFORE INSERT ON db.report_tree
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_report_tree_insert();
