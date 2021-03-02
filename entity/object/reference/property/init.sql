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

  nParent       uuid;
  nEvent        uuid;
BEGIN
  nParent := GetEventType('parent');
  nEvent := GetEventType('event');

  FOR r IN SELECT * FROM Action
  LOOP

    IF r.code = 'create' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Свойство создано', 'EventPropertyCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Свойство открыто', 'EventPropertyOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Свойство изменено', 'EventPropertyEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Свойство сохранено', 'EventPropertySave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Свойство доступно', 'EventPropertyEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Свойство недоступно', 'EventPropertyDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Свойство будет удалено', 'EventPropertyDelete();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Свойство восстановлено', 'EventPropertyRestore();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Свойство будет уничтожено', 'EventPropertyDrop();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
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
  nClass        uuid;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'property', 'Свойство', false);

  -- Тип
  PERFORM AddType(nClass, 'string.property', 'Строка', 'Символьный тип.');
  PERFORM AddType(nClass, 'integer.property', 'Целое число', 'Целочисленный тип.');
  PERFORM AddType(nClass, 'numeric.property', 'Вещественное число', 'Число с произвольной точностью.');
--  PERFORM AddType(nClass, 'money.property', 'Денежная сумма', 'Денежный тип.');
  PERFORM AddType(nClass, 'datetime.property', 'Дата и время', 'Тип даты и времени.');
  PERFORM AddType(nClass, 'boolean.property', 'Логический', 'Логический тип.');
--  PERFORM AddType(nClass, 'enum.property', 'Перечисляемый', 'Тип перечислений.');
--  PERFORM AddType(nClass, 'uuid.property', 'UUID', 'Универсальный уникальный идентификатор.');
--  PERFORM AddType(nClass, 'json.property', 'JSON', 'Тип JSON.');
--  PERFORM AddType(nClass, 'xml.property', 'XML', 'Тип XML.');

  -- Событие
  PERFORM AddPropertyEvents(nClass);

  -- Метод
  PERFORM AddDefaultMethods(nClass, ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалена', 'Открыть', 'Закрыть', 'Удалить']);

  RETURN nClass;
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
  nEntity       uuid;
BEGIN
  -- Сущность
  nEntity := AddEntity('property', 'Свойство');

  -- Класс
  PERFORM CreateClassProperty(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('property', AddEndpoint('SELECT * FROM rest.property($1, $2);'));

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
