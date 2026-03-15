--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddFormEvents ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddFormEvents (
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
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Form created', 'EventFormCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Form opened', 'EventFormOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Form edited', 'EventFormEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Form saved', 'EventFormSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Form enabled', 'EventFormEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Form disabled', 'EventFormDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Form will be deleted', 'EventFormDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Form restored', 'EventFormRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Form will be dropped', 'EventFormDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassForm -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassForm (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'form', 'Form', false);
  PERFORM EditClassText(uClass, 'Форма', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Formular', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Formulaire', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Modulo', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Formulario', GetLocale('es'));

  -- Тип
  PERFORM AddType(uClass, 'none.form', 'Untyped', 'Untyped.');
  PERFORM EditTypeText(GetType('none.form'), 'Без типа', 'Без типа.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('none.form'), 'Ohne Typ', 'Ohne Typ.', GetLocale('de'));
  PERFORM EditTypeText(GetType('none.form'), 'Sans type', 'Sans type.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('none.form'), 'Senza tipo', 'Senza tipo.', GetLocale('it'));
  PERFORM EditTypeText(GetType('none.form'), 'Sin tipo', 'Sin tipo.', GetLocale('es'));

  PERFORM AddType(uClass, 'journal.form', 'Journal', 'Journal form.');
  PERFORM EditTypeText(GetType('journal.form'), 'Журнал', 'Форма журнала.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('journal.form'), 'Journal', 'Journalformular.', GetLocale('de'));
  PERFORM EditTypeText(GetType('journal.form'), 'Journal', 'Formulaire de journal.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('journal.form'), 'Registro', 'Modulo registro.', GetLocale('it'));
  PERFORM EditTypeText(GetType('journal.form'), 'Diario', 'Formulario de diario.', GetLocale('es'));

  PERFORM AddType(uClass, 'tracker.form', 'Daily report', 'Daily report form.');
  PERFORM EditTypeText(GetType('tracker.form'), 'Суточный отчёт', 'Форма суточного отчёта.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('tracker.form'), 'Tagesbericht', 'Tagesberichtsformular.', GetLocale('de'));
  PERFORM EditTypeText(GetType('tracker.form'), 'Rapport journalier', 'Formulaire de rapport journalier.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('tracker.form'), 'Report giornaliero', 'Modulo report giornaliero.', GetLocale('it'));
  PERFORM EditTypeText(GetType('tracker.form'), 'Informe diario', 'Formulario de informe diario.', GetLocale('es'));

  -- Событие
  PERFORM AddFormEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass,
    ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete'],
    ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалена', 'Открыть', 'Закрыть', 'Удалить']);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityForm ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityForm (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('form', 'Form');
  PERFORM EditEntityText(uEntity, 'Форма', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Formular', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Formulaire', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Modulo', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Formulario', null, GetLocale('es'));

  -- Класс
  PERFORM CreateClassForm(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('form', AddEndpoint('SELECT * FROM rest.form($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
