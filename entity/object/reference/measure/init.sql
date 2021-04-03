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
  PERFORM AddType(uClass, 'quantity.measure', 'Количество', 'Единица измерения количества вещества.');
  PERFORM AddType(uClass, 'length.measure', 'Длина', 'Числовая характеристика протяжённости линий.');
  PERFORM AddType(uClass, 'weight.measure', 'Масса', 'Единица измерения массы тела.');
  PERFORM AddType(uClass, 'time.measure', 'Время', 'Единица измерения времени.');
  PERFORM AddType(uClass, 'power.measure', 'Мощность', 'Единица измерения мощности.');
  PERFORM AddType(uClass, 'amperage.measure', 'Сила тока', 'Единица измерения силы тока.');
  PERFORM AddType(uClass, 'voltage.measure', 'Напряжение', 'Единица измерения напряжения.');

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
  nEntity       uuid;
BEGIN
  -- Сущность
  nEntity := AddEntity('measure', 'Мера');

  -- Класс
  PERFORM CreateClassMeasure(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('measure', AddEndpoint('SELECT * FROM rest.measure($1, $2);'));

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
