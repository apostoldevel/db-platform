--------------------------------------------------------------------------------
-- KLADR -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.kladr (
    code		varchar(13) PRIMARY KEY,
    name		varchar(40) NOT NULL,
    socr		varchar(10),
    index		varchar(6),
    gninmb		varchar(4),
    uno		    varchar(4),
    ocatd		varchar(11),
    status      varchar(1)
);

COMMENT ON TABLE db.kladr IS 'Классификаторы адресов Российской Федерации.';

COMMENT ON COLUMN db.kladr.code IS 'Код: СС РРР ГГГ ППП АА. Где: СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; АА - признак актуальности.';
COMMENT ON COLUMN db.kladr.name IS 'Наименование объекта';
COMMENT ON COLUMN db.kladr.socr IS 'Сокращённое наименование типа объекта';
COMMENT ON COLUMN db.kladr.index IS 'Почтовый индекс';
COMMENT ON COLUMN db.kladr.gninmb IS 'Код ИФНС';
COMMENT ON COLUMN db.kladr.uno IS 'Код территориального участка ИФНС';
COMMENT ON COLUMN db.kladr.ocatd IS 'Код ОКАТО';
COMMENT ON COLUMN db.kladr.status IS 'Статус объекта (признак центр)';

CREATE UNIQUE INDEX ON db.kladr (code);

GRANT SELECT ON db.kladr TO administrator;

--------------------------------------------------------------------------------
-- STREET ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.street (
    code		varchar(17) PRIMARY KEY,
    name		varchar(40) NOT NULL,
    socr		varchar(10),
    index		varchar(6),
    gninmb		varchar(4),
    uno		    varchar(4),
    ocatd		varchar(11)
);

COMMENT ON TABLE db.street IS 'Классификаторы адресов Российской Федерации (Улицы).';

COMMENT ON COLUMN db.street.code IS 'Код: СС РРР ГГГ ППП УУУУ АА. Где: СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; УУУУ - код улицы; АА - признак актуальности.';
COMMENT ON COLUMN db.street.name IS 'Наименование объекта';
COMMENT ON COLUMN db.street.socr IS 'Сокращённое наименование типа объекта';
COMMENT ON COLUMN db.street.index IS 'Почтовый индекс';
COMMENT ON COLUMN db.street.gninmb IS 'Код ИФНС';
COMMENT ON COLUMN db.street.uno IS 'Код территориального участка ИФНС';
COMMENT ON COLUMN db.street.ocatd IS 'Код ОКАТО';

CREATE UNIQUE INDEX ON db.street (code);

GRANT SELECT ON db.street TO administrator;
