--------------------------------------------------------------------------------
-- KLADR -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.kladr (
    code        varchar(13) PRIMARY KEY,
    name        varchar(40) NOT NULL,
    socr        varchar(10),
    index       varchar(6),
    gninmb      varchar(4),
    uno         varchar(4),
    ocatd       varchar(11),
    status      varchar(1)
);

COMMENT ON TABLE db.kladr IS 'KLADR address classifier of the Russian Federation. Stores regions, districts, cities, and settlements.';

COMMENT ON COLUMN db.kladr.code IS 'Address code: SS RRR GGG PPP AA. SS = subject (region) of the RF; RRR = district; GGG = city; PPP = settlement; AA = actuality flag.';
COMMENT ON COLUMN db.kladr.name IS 'Name of the address object (region, district, city, or settlement).';
COMMENT ON COLUMN db.kladr.socr IS 'Abbreviated type of the address object (e.g. "г" for city, "обл" for region).';
COMMENT ON COLUMN db.kladr.index IS 'Postal code (6-digit Russian ZIP).';
COMMENT ON COLUMN db.kladr.gninmb IS 'Federal Tax Service (FTS/IFNS) inspection code.';
COMMENT ON COLUMN db.kladr.uno IS 'FTS territorial division code.';
COMMENT ON COLUMN db.kladr.ocatd IS 'OKATO code (national territory classification).';
COMMENT ON COLUMN db.kladr.status IS 'Object status: administrative centre indicator (0 = not a centre).';

CREATE UNIQUE INDEX ON db.kladr (code);

GRANT SELECT ON db.kladr TO administrator;

--------------------------------------------------------------------------------
-- STREET ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.street (
    code        varchar(17) PRIMARY KEY,
    name        varchar(40) NOT NULL,
    socr        varchar(10),
    index       varchar(6),
    gninmb      varchar(4),
    uno         varchar(4),
    ocatd       varchar(11)
);

COMMENT ON TABLE db.street IS 'KLADR street-level address classifier. Extends the main KLADR table with street codes.';

COMMENT ON COLUMN db.street.code IS 'Street code: SS RRR GGG PPP UUUU AA. SS = subject; RRR = district; GGG = city; PPP = settlement; UUUU = street; AA = actuality flag.';
COMMENT ON COLUMN db.street.name IS 'Street name.';
COMMENT ON COLUMN db.street.socr IS 'Abbreviated street type (e.g. "ул" for street, "пер" for lane).';
COMMENT ON COLUMN db.street.index IS 'Postal code (6-digit Russian ZIP).';
COMMENT ON COLUMN db.street.gninmb IS 'Federal Tax Service (FTS/IFNS) inspection code.';
COMMENT ON COLUMN db.street.uno IS 'FTS territorial division code.';
COMMENT ON COLUMN db.street.ocatd IS 'OKATO code (national territory classification).';

CREATE UNIQUE INDEX ON db.street (code);

GRANT SELECT ON db.street TO administrator;

--------------------------------------------------------------------------------
-- ADDRESS TREE ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.address_tree (
    id          serial PRIMARY KEY,
    parent      integer REFERENCES db.address_tree(id),
    code        varchar(17) NOT NULL,
    name        text NOT NULL,
    short       text,
    index       varchar(6),
    level       integer NOT NULL
);

COMMENT ON TABLE db.address_tree IS 'Hierarchical address tree built from KLADR data. Each row is a node: country > region > district > city > settlement > street.';

COMMENT ON COLUMN db.address_tree.id IS 'Surrogate primary key.';
COMMENT ON COLUMN db.address_tree.parent IS 'Parent node reference (NULL for the root country node).';
COMMENT ON COLUMN db.address_tree.code IS 'Composite address code: FF SS RRR GGG PPP UUUU. FF = country; SS = subject; RRR = district; GGG = city; PPP = settlement; UUUU = street.';
COMMENT ON COLUMN db.address_tree.name IS 'Display name of the address object.';
COMMENT ON COLUMN db.address_tree.short IS 'Abbreviated type prefix/suffix (e.g. "г", "ул").';
COMMENT ON COLUMN db.address_tree.index IS 'Postal code (6-digit Russian ZIP).';
COMMENT ON COLUMN db.address_tree.level IS 'Depth level in the tree: 0 = country, 1 = region, 2 = district, 3 = city, 4 = settlement, 5 = street.';

CREATE INDEX ON db.address_tree (parent);
CREATE UNIQUE INDEX ON db.address_tree (code);
