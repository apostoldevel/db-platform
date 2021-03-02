\ir '../entity/reference/measure/create.psql'
\ir '../entity/reference/property/create.psql'

--------------------------------------------------------------------------------
-- db.model_property -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.model_property (
    model		uuid NOT NULL REFERENCES db.model(id) ON DELETE CASCADE,
    property	uuid NOT NULL REFERENCES db.property(id) ON DELETE RESTRICT,
    measure		uuid REFERENCES db.measure(id),
    value		variant,
    format		text,
    sequence	integer NOT NULL,
    PRIMARY KEY (model, property)
);

COMMENT ON TABLE db.model_property IS 'Свойства модели.';

COMMENT ON COLUMN db.model_property.model IS 'Модель.';
COMMENT ON COLUMN db.model_property.property IS 'Свойство.';
COMMENT ON COLUMN db.model_property.measure IS 'Мера.';
COMMENT ON COLUMN db.model_property.value IS 'Значение.';
COMMENT ON COLUMN db.model_property.format IS 'Формат.';
COMMENT ON COLUMN db.model_property.sequence IS 'Очерёдность';

CREATE INDEX ON db.model_property (model);
CREATE INDEX ON db.model_property (property);
CREATE INDEX ON db.model_property (measure);

--------------------------------------------------------------------------------

\connect :dbname admin

SELECT CreateEntityMeasure(GetClass('reference'));
SELECT CreateEntityProperty(GetClass('reference'));

SELECT CreateMeasure(null, GetType('quantity.measure'), 'pieces.measure', 'Шт', 'Штук');

SELECT CreateMeasure(null, GetType('time.measure'), 'second.measure', 'сек', 'Секунда');
SELECT CreateMeasure(null, GetType('time.measure'), 'minute.measure', 'мин', 'Минута');
SELECT CreateMeasure(null, GetType('time.measure'), 'hour.measure', 'час', 'Час');
SELECT CreateMeasure(null, GetType('time.measure'), 'day.measure', 'д', 'День');
SELECT CreateMeasure(null, GetType('time.measure'), 'week.measure', 'нед', 'Неделя');
SELECT CreateMeasure(null, GetType('time.measure'), 'month.measure', 'мес', 'Месяц');
SELECT CreateMeasure(null, GetType('time.measure'), 'quarter.measure', 'кв', 'Квартал');
SELECT CreateMeasure(null, GetType('time.measure'), 'year.measure', 'год', 'Год');

SELECT CreateMeasure(null, GetType('power.measure'), 'W.measure', 'Вт', 'Ватт');
SELECT CreateMeasure(null, GetType('power.measure'), 'kW.measure', 'кВт', 'Киловатт');
SELECT CreateMeasure(null, GetType('power.measure'), 'MW.measure', 'МВт', 'Мегаватт');
SELECT CreateMeasure(null, GetType('power.measure'), 'GW.measure', 'ГВт', 'Гигаватт');

\connect :dbname kernel