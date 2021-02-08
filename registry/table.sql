--------------------------------------------------------------------------------
-- REGISTRY --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE registry.key (
    id			numeric(10) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REGISTRY'),
    root		numeric(10),
    parent		numeric(10),
    key			text NOT NULL,
    level		integer NOT NULL,
    CONSTRAINT fk_registry_key_root FOREIGN KEY (root) REFERENCES registry.key(id),
    CONSTRAINT fk_registry_key_parent FOREIGN KEY (parent) REFERENCES registry.key(id)
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
CREATE INDEX ON registry.key (level);

CREATE UNIQUE INDEX ON registry.key (root, parent, key);

--------------------------------------------------------------------------------
-- REGISTRY_VALUE --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE registry.value (
    id			numeric(10) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REGISTRY'),
    key			numeric(10) NOT NULL,
    vname		text NOT NULL,
    vtype		integer NOT NULL,
    vinteger	integer,
    vnumeric	numeric,
    vdatetime	timestamp,
    vstring		text,
    vboolean	boolean,
    CONSTRAINT ch_registry_value_type CHECK (vtype BETWEEN 0 AND 4),
    CONSTRAINT fk_registry_value_key FOREIGN KEY (key) REFERENCES registry.key(id)
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

