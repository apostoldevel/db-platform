--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddPropertyEvents -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddPropertyEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Свойство создано', 'EventPropertyCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Свойство открыто', 'EventPropertyOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Свойство изменено', 'EventPropertyEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Свойство сохранено', 'EventPropertySave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Свойство доступно', 'EventPropertyEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Свойство недоступно', 'EventPropertyDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Свойство будет удалено', 'EventPropertyDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Свойство восстановлено', 'EventPropertyRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Свойство будет уничтожено', 'EventPropertyDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassProperty ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassProperty (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'property', 'Свойство', false);

  -- Тип
  PERFORM AddType(uClass, 'string.property', 'Строка', 'Символьный тип.');
  PERFORM AddType(uClass, 'integer.property', 'Целое число', 'Целочисленный тип.');
  PERFORM AddType(uClass, 'numeric.property', 'Вещественное число', 'Число с произвольной точностью.');
--  PERFORM AddType(uClass, 'money.property', 'Денежная сумма', 'Денежный тип.');
  PERFORM AddType(uClass, 'datetime.property', 'Дата и время', 'Тип даты и времени.');
  PERFORM AddType(uClass, 'boolean.property', 'Логический', 'Логический тип.');
--  PERFORM AddType(uClass, 'enum.property', 'Перечисляемый', 'Тип перечислений.');
--  PERFORM AddType(uClass, 'uuid.property', 'UUID', 'Универсальный уникальный идентификатор.');
--  PERFORM AddType(uClass, 'json.property', 'JSON', 'Тип JSON.');
--  PERFORM AddType(uClass, 'xml.property', 'XML', 'Тип XML.');

  -- Событие
  PERFORM AddPropertyEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass, ARRAY['Создано', 'Доступно', 'Недоступно', 'Удалено', 'Открыть', 'Закрыть', 'Удалить']);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityProperty --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityProperty (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('property', 'Свойство');

  -- Класс
  PERFORM CreateClassProperty(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('property', AddEndpoint('SELECT * FROM rest.property($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
