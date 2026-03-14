--------------------------------------------------------------------------------
-- REGISTRY --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE registry.key (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    root        uuid REFERENCES registry.key(id),
    parent      uuid REFERENCES registry.key(id),
    key         text NOT NULL,
    level       integer NOT NULL
);

COMMENT ON TABLE registry.key IS 'Registry key: hierarchical tree node in the configuration store.';

COMMENT ON COLUMN registry.key.id IS 'Primary key (UUID).';
COMMENT ON COLUMN registry.key.root IS 'Root node of the tree this key belongs to (NULL for root keys themselves).';
COMMENT ON COLUMN registry.key.parent IS 'Immediate parent key (NULL for root keys).';
COMMENT ON COLUMN registry.key.key IS 'Key name segment (e.g. "kernel", "Settings").';
COMMENT ON COLUMN registry.key.level IS 'Nesting depth: 0 = root, 1 = first child, etc.';

CREATE INDEX ON registry.key (root);
CREATE INDEX ON registry.key (parent);
CREATE INDEX ON registry.key (key);

CREATE UNIQUE INDEX ON registry.key (root, parent, key);

--------------------------------------------------------------------------------
-- REGISTRY_VALUE --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE registry.value (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    key         uuid NOT NULL REFERENCES registry.key(id) ON DELETE CASCADE,
    vname       text NOT NULL,
    vtype       integer NOT NULL,
    vinteger    integer,
    vnumeric    numeric,
    vdatetime   timestamp,
    vstring     text,
    vboolean    boolean,
    CHECK (vtype BETWEEN 0 AND 4)
);

COMMENT ON TABLE registry.value IS 'Registry value: typed datum attached to a registry key.';

COMMENT ON COLUMN registry.value.id IS 'Primary key (UUID).';
COMMENT ON COLUMN registry.value.key IS 'Parent registry key this value belongs to.';
COMMENT ON COLUMN registry.value.vname IS 'Value name (unique per key; "default" is the unnamed value).';
COMMENT ON COLUMN registry.value.vtype IS 'Data type discriminator: 0=integer, 1=numeric, 2=datetime, 3=text, 4=boolean.';
COMMENT ON COLUMN registry.value.vinteger IS 'Integer payload (used when vtype = 0).';
COMMENT ON COLUMN registry.value.vnumeric IS 'Arbitrary-precision numeric payload (used when vtype = 1).';
COMMENT ON COLUMN registry.value.vdatetime IS 'Timestamp payload (used when vtype = 2).';
COMMENT ON COLUMN registry.value.vstring IS 'Text payload (used when vtype = 3).';
COMMENT ON COLUMN registry.value.vboolean IS 'Boolean payload (used when vtype = 4).';

--------------------------------------------------------------------------------

CREATE INDEX ON registry.value (key);
CREATE INDEX ON registry.value (vname);

CREATE UNIQUE INDEX ON registry.value (key, vname);
