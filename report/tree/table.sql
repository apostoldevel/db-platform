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

COMMENT ON TABLE db.report_tree IS 'Report tree — hierarchical structure that organises reports into navigable groups.';

COMMENT ON COLUMN db.report_tree.id IS 'Primary key (matches reference.id).';
COMMENT ON COLUMN db.report_tree.reference IS 'Parent reference entity (catalog record).';
COMMENT ON COLUMN db.report_tree.root IS 'Root node of this tree (self-referencing for root nodes).';
COMMENT ON COLUMN db.report_tree.node IS 'Parent node in the hierarchy (NULL for root nodes).';
COMMENT ON COLUMN db.report_tree.level IS 'Nesting depth (0 = root).';
COMMENT ON COLUMN db.report_tree.sequence IS 'Display order among siblings.';

CREATE INDEX ON db.report_tree (reference);
CREATE INDEX ON db.report_tree (root);
CREATE INDEX ON db.report_tree (node);

--------------------------------------------------------------------------------

/**
 * @brief Auto-set primary key from parent reference id on new report tree rows.
 * @return {trigger}
 * @since 1.0.0
 */
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
