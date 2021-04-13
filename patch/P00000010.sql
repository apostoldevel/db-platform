DROP FUNCTION IF EXISTS api.outbox(text);
DROP FUNCTION IF EXISTS api.outbox(uuid, uuid);

--------------------------------------------------------------------------------

DROP FUNCTION IF EXISTS GetType(text, uuid);
DROP FUNCTION IF EXISTS GetReference(text, uuid);

--------------------------------------------------------------------------------

\ir '../workflow/routine.sql'
\ir '../entity/object/reference/routine.sql'
\ir '../entity/object/reference/measure/routine.sql'

--------------------------------------------------------------------------------

DROP VIEW ObjectDevice CASCADE;

--------------------------------------------------------------------------------

\connect :dbname admin

SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT SetArea(GetArea(current_database()));

SELECT SetType(GetClass('measure'), 'time.measure', 'Время', 'Единицы времени.');
SELECT SetType(GetClass('measure'), 'length.measure', 'Длина', 'Единицы длины.');
SELECT SetType(GetClass('measure'), 'weight.measure', 'Масса', 'Единицы массы.');
SELECT SetType(GetClass('measure'), 'volume.measure', 'Объём', 'Единицы объёма.');
SELECT SetType(GetClass('measure'), 'area.measure', 'Площадь', 'Единицы площади.');
SELECT SetType(GetClass('measure'), 'technical.measure', 'Технические', 'Технические единицы.');
SELECT SetType(GetClass('measure'), 'economic.measure', 'Экономические', 'Экономические единицы.');

SELECT EditReference(id, pType => GetType('economic.measure')) FROM (SELECT id FROM Object WHERE type = GetType('quantity.measure')) x;
SELECT EditReference(id, pType => GetType('technical.measure')) FROM (SELECT id FROM Object WHERE type = GetType('power.measure')) x;
SELECT EditReference(id, pType => GetType('technical.measure')) FROM (SELECT id FROM Object WHERE type = GetType('amperage.measure')) x;
SELECT EditReference(id, pType => GetType('technical.measure')) FROM (SELECT id FROM Object WHERE type = GetType('voltage.measure')) x;

SELECT DeleteType(GetType('quantity.measure'));
SELECT DeleteType(GetType('power.measure'));
SELECT DeleteType(GetType('amperage.measure'));
SELECT DeleteType(GetType('voltage.measure'));

SELECT SignOut();

\connect :dbname kernel