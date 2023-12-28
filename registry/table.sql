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

COMMENT ON TABLE registry.key IS 'Реестр (ключ).';

COMMENT ON COLUMN registry.key.id IS 'Идентификатор';
COMMENT ON COLUMN registry.key.root IS 'Идентификатор корневого узла';
COMMENT ON COLUMN registry.key.parent IS 'Идентификатор родительского узла';
COMMENT ON COLUMN registry.key.key IS 'Ключ';
COMMENT ON COLUMN registry.key.level IS 'Уровень вложенности';

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

COMMENT ON TABLE registry.value IS 'Реестр (значение).';

COMMENT ON COLUMN registry.value.id IS 'Идентификатор';
COMMENT ON COLUMN registry.value.key IS 'Идентификатор ключа';
COMMENT ON COLUMN registry.value.vname IS 'Имя значения';
COMMENT ON COLUMN registry.value.vtype IS 'Тип данных';
COMMENT ON COLUMN registry.value.vinteger IS 'Целое число: vtype = 0';
COMMENT ON COLUMN registry.value.vnumeric IS 'Число с произвольной точностью: vtype = 1';
COMMENT ON COLUMN registry.value.vdatetime IS 'Дата и время: vtype = 2';
COMMENT ON COLUMN registry.value.vstring IS 'Строка: vtype = 3';
COMMENT ON COLUMN registry.value.vboolean IS 'Логический: vtype = 4';

--------------------------------------------------------------------------------

CREATE INDEX ON registry.value (key);
CREATE INDEX ON registry.value (vname);

CREATE UNIQUE INDEX ON registry.value (key, vname);
