--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddReportEvents -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddReportEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report created', 'EventReportCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report opened', 'EventReportOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report edited', 'EventReportEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report saved', 'EventReportSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report enabled', 'EventReportEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report disabled', 'EventReportDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report will be deleted', 'EventReportDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report restored', 'EventReportRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report will be dropped', 'EventReportDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassReport -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassReport (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Class
  uClass := AddClass(pParent, pEntity, 'report', 'Report', false);

  PERFORM EditClassText(uClass, 'Отчёт', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Bericht', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Rapport', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Report', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Informe', GetLocale('es'));

  -- Type
  PERFORM AddType(uClass, 'object.report', 'Object', 'Reports for objects.');
  PERFORM EditTypeText(GetType('object.report'), 'Объект', 'Отчеты для объектов.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('object.report'), 'Objekt', 'Berichte für Objekte.', GetLocale('de'));
  PERFORM EditTypeText(GetType('object.report'), 'Objet', 'Rapports pour objets.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('object.report'), 'Oggetto', 'Report per oggetti.', GetLocale('it'));
  PERFORM EditTypeText(GetType('object.report'), 'Objeto', 'Informes para objetos.', GetLocale('es'));

  PERFORM AddType(uClass, 'report.report', 'Report', 'Standard reports.');
  PERFORM EditTypeText(GetType('report.report'), 'Отчёт', 'Обычные отчёты.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('report.report'), 'Bericht', 'Standardberichte.', GetLocale('de'));
  PERFORM EditTypeText(GetType('report.report'), 'Rapport', 'Rapports standards.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('report.report'), 'Report', 'Report standard.', GetLocale('it'));
  PERFORM EditTypeText(GetType('report.report'), 'Informe', 'Informes estándar.', GetLocale('es'));

  PERFORM AddType(uClass, 'import.report', 'Import', 'Data import reports.');
  PERFORM EditTypeText(GetType('import.report'), 'Загрузка', 'Отчёты загрузки данных.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('import.report'), 'Import', 'Datenimportberichte.', GetLocale('de'));
  PERFORM EditTypeText(GetType('import.report'), 'Import', 'Rapports d''import.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('import.report'), 'Importazione', 'Report di importazione.', GetLocale('it'));
  PERFORM EditTypeText(GetType('import.report'), 'Importación', 'Informes de importación.', GetLocale('es'));

  PERFORM AddType(uClass, 'export.report', 'Export', 'Data export reports.');
  PERFORM EditTypeText(GetType('export.report'), 'Выгрузка', 'Отчёты выгрузки данных.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('export.report'), 'Export', 'Datenexportberichte.', GetLocale('de'));
  PERFORM EditTypeText(GetType('export.report'), 'Export', 'Rapports d''export.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('export.report'), 'Esportazione', 'Report di esportazione.', GetLocale('it'));
  PERFORM EditTypeText(GetType('export.report'), 'Exportación', 'Informes de exportación.', GetLocale('es'));

  -- Event
  PERFORM AddReportEvents(uClass);

  -- Method
  PERFORM AddDefaultMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityReport ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityReport (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Entity
  uEntity := AddEntity('report', 'Report');

  PERFORM EditEntityText(uEntity, 'Отчёт', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Bericht', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Rapport', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Report', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Informe', null, GetLocale('es'));

  -- Class
  PERFORM CreateClassReport(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('report', AddEndpoint('SELECT * FROM rest.report($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
