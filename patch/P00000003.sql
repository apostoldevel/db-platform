\ir '../entity/object/reference/measure/create.psql'

--------------------------------------------------------------------------------

\connect :dbname admin

SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT CreateEntityMeasure(GetClass('reference'));

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

SELECT SignOut();

\connect :dbname kernel