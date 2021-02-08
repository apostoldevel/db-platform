--------------------------------------------------------------------------------
-- AddressTree -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AddressTree (Id, Parent, Code, Name, Short, Index, Level)
AS
  SELECT id, parent, code, name, short, index, level
    FROM db.address_tree;

GRANT ALL ON AddressTree TO administrator;
