--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddReportFormEvents ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddReportFormEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report form created', 'EventReportFormCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report form opened', 'EventReportFormOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report form edited', 'EventReportFormEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report form saved', 'EventReportFormSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report form enabled', 'EventReportFormEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report form disabled', 'EventReportFormDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report form will be deleted', 'EventReportFormDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report form restored', 'EventReportFormRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report form will be dropped', 'EventReportFormDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassReportForm -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassReportForm (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Class
  uClass := AddClass(pParent, pEntity, 'report_form', 'Report form', false);

  PERFORM EditClassText(uClass, 'Форма отчёта', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Berichtsformular', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Formulaire de rapport', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Modulo di report', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Formulario de informe', GetLocale('es'));

  -- Type
  PERFORM AddType(uClass, 'json.report_form', 'JSON', 'Report form in JSON format.');
  PERFORM EditTypeText(GetType('json.report_form'), 'JSON', 'Форма отчёта в формате JSON.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('json.report_form'), 'JSON', 'Berichtsformular im JSON-Format.', GetLocale('de'));
  PERFORM EditTypeText(GetType('json.report_form'), 'JSON', 'Formulaire de rapport au format JSON.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('json.report_form'), 'JSON', 'Modulo di report in formato JSON.', GetLocale('it'));
  PERFORM EditTypeText(GetType('json.report_form'), 'JSON', 'Formulario de informe en formato JSON.', GetLocale('es'));

  -- Event
  PERFORM AddReportFormEvents(uClass);

  -- Method
  PERFORM AddDefaultMethods(uClass,
    ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete'],
    ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалена', 'Открыть', 'Закрыть', 'Удалить']);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityReportForm ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityReportForm (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Entity
  uEntity := AddEntity('report_form', 'Report form');

  PERFORM EditEntityText(uEntity, 'Форма отчёта', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Berichtsformular', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Formulaire de rapport', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Modulo di report', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Formulario de informe', null, GetLocale('es'));

  -- Class
  PERFORM CreateClassReportForm(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('report/form', AddEndpoint('SELECT * FROM rest.report_form($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
