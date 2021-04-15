--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddMeasureEvents ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMeasureEvents (
  pClass        uuid
)
RETURNS         void
AS $$
DECLARE
  r             record;

  uParent       uuid;
  uEvent        uuid;
BEGIN
  uParent := GetEventType('parent');
  uEvent := GetEventType('event');

  FOR r IN SELECT * FROM Action
  LOOP

    IF r.code = 'create' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Мера создана', 'EventMeasureCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Мера открыта', 'EventMeasureOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Мера изменена', 'EventMeasureEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Мера сохранена', 'EventMeasureSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Мера доступна', 'EventMeasureEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Мера недоступна', 'EventMeasureDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Мера будет удалена', 'EventMeasureDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Мера восстановлена', 'EventMeasureRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Мера будет уничтожена', 'EventMeasureDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassMeasure ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassMeasure (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'measure', 'Мера', false);

  -- Тип
  PERFORM AddType(uClass, 'time.measure', 'Время', 'Единицы времени.');
  PERFORM AddType(uClass, 'length.measure', 'Длина', 'Единицы длины.');
  PERFORM AddType(uClass, 'weight.measure', 'Масса', 'Единицы массы.');
  PERFORM AddType(uClass, 'volume.measure', 'Объём', 'Единицы объёма.');
  PERFORM AddType(uClass, 'area.measure', 'Площадь', 'Единицы площади.');
  PERFORM AddType(uClass, 'technical.measure', 'Технические', 'Технические единицы.');
  PERFORM AddType(uClass, 'economic.measure', 'Экономические', 'Экономические единицы.');

  -- Событие
  PERFORM AddMeasureEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass, ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалена', 'Открыть', 'Закрыть', 'Удалить']);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityMeasure ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityMeasure (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('measure', 'Мера');

  -- Класс
  PERFORM CreateClassMeasure(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('measure', AddEndpoint('SELECT * FROM rest.measure($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitMeasure -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitMeasure()
RETURNS         void
AS $$
BEGIN
  PERFORM CreateMeasure(null, GetType('volume.measure'), '111', 'см3', 'Кубический сантиметр');
  PERFORM CreateMeasure(null, GetType('volume.measure'), '112', 'л', 'Литр');
  PERFORM CreateMeasure(null, GetType('volume.measure'), '113', 'м3', 'Кубический метр');

  PERFORM CreateMeasure(null, GetType('weight.measure'), '161', 'мг', 'Миллиграмм');
  PERFORM CreateMeasure(null, GetType('weight.measure'), '163', 'г', 'Грамм');
  PERFORM CreateMeasure(null, GetType('weight.measure'), '166', 'кг', 'Килограмм');
  PERFORM CreateMeasure(null, GetType('weight.measure'), '168', 'т', 'Тонна');
  PERFORM CreateMeasure(null, GetType('weight.measure'), '206', 'ц', 'Центнер');
  PERFORM CreateMeasure(null, GetType('weight.measure'), '185', 'т грп', 'Грузоподъемность в метрических тоннах');

  PERFORM CreateMeasure(null, GetType('technical.measure'), '212', 'Вт', 'Ватт');
  PERFORM CreateMeasure(null, GetType('technical.measure'), '214', 'кВт', 'Киловатт');
  PERFORM CreateMeasure(null, GetType('technical.measure'), '215', 'МВт', 'Мегаватт');

  PERFORM CreateMeasure(null, GetType('technical.measure'), '222', 'В', 'Вольт');
  PERFORM CreateMeasure(null, GetType('technical.measure'), '223', 'кВ', 'Киловольт');

  PERFORM CreateMeasure(null, GetType('technical.measure'), '243', 'Вт.ч', 'Ватт-час');
  PERFORM CreateMeasure(null, GetType('technical.measure'), '245', 'кВ.ч', 'Киловатт-час');

  PERFORM CreateMeasure(null, GetType('time.measure'), '354', 'с', 'Секунда');
  PERFORM CreateMeasure(null, GetType('time.measure'), '355', 'мин', 'Минута');
  PERFORM CreateMeasure(null, GetType('time.measure'), '356', 'ч', 'Час');
  PERFORM CreateMeasure(null, GetType('time.measure'), '359', 'дн', 'День');
  PERFORM CreateMeasure(null, GetType('time.measure'), '360', 'нед', 'Неделя');
  PERFORM CreateMeasure(null, GetType('time.measure'), '361', 'дек', 'Декада');
  PERFORM CreateMeasure(null, GetType('time.measure'), '362', 'мес', 'Месяц');
  PERFORM CreateMeasure(null, GetType('time.measure'), '364', 'кварт', 'Квартал');
  PERFORM CreateMeasure(null, GetType('time.measure'), '365', 'полгода', 'Полугодие');
  PERFORM CreateMeasure(null, GetType('time.measure'), '366', 'г', 'Год');

  PERFORM CreateMeasure(null, GetType('economic.measure'), '616', 'боб', 'Бобина');
  PERFORM CreateMeasure(null, GetType('economic.measure'), '625', 'л.', 'Лист');
  PERFORM CreateMeasure(null, GetType('economic.measure'), '796', 'шт', 'Штука');
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
