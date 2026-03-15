--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddReportTreeEvents ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddReportTreeEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report tree created', 'EventReportTreeCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report tree opened', 'EventReportTreeOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report tree edited', 'EventReportTreeEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report tree saved', 'EventReportTreeSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report tree enabled', 'EventReportTreeEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report tree disabled', 'EventReportTreeDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report tree will be deleted', 'EventReportTreeDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report tree restored', 'EventReportTreeRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report tree will be dropped', 'EventReportTreeDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassReportTree -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassReportTree (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Class
  uClass := AddClass(pParent, pEntity, 'report_tree', 'Report tree', false);

  PERFORM EditClassText(uClass, 'Дерево отчётов', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Berichtsbaum', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Arbre de rapports', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Albero dei report', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Árbol de informes', GetLocale('es'));

  -- Type
  PERFORM AddType(uClass, 'root.report_tree', 'Section', 'The root of the report tree.');
  PERFORM EditTypeText(GetType('root.report_tree'), 'Корень', 'Корень дерева отчётов.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('root.report_tree'), 'Abschnitt', 'Wurzel des Berichtsbaums.', GetLocale('de'));
  PERFORM EditTypeText(GetType('root.report_tree'), 'Section', 'Racine de l''arbre de rapports.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('root.report_tree'), 'Sezione', 'Radice dell''albero dei report.', GetLocale('it'));
  PERFORM EditTypeText(GetType('root.report_tree'), 'Sección', 'Raíz del árbol de informes.', GetLocale('es'));

  PERFORM AddType(uClass, 'node.report_tree', 'Node', 'Report tree node.');
  PERFORM EditTypeText(GetType('node.report_tree'), 'Узел', 'Узел дерева отчётов.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('node.report_tree'), 'Knoten', 'Berichtsbaumknoten.', GetLocale('de'));
  PERFORM EditTypeText(GetType('node.report_tree'), 'Nœud', 'Nœud de l''arbre de rapports.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('node.report_tree'), 'Nodo', 'Nodo dell''albero dei report.', GetLocale('it'));
  PERFORM EditTypeText(GetType('node.report_tree'), 'Nodo', 'Nodo del árbol de informes.', GetLocale('es'));

  PERFORM AddType(uClass, 'report.report_tree', 'Report', 'Report.');
  PERFORM EditTypeText(GetType('report.report_tree'), 'Отчёт', 'Отчёт.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('report.report_tree'), 'Bericht', 'Bericht.', GetLocale('de'));
  PERFORM EditTypeText(GetType('report.report_tree'), 'Rapport', 'Rapport.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('report.report_tree'), 'Report', 'Report.', GetLocale('it'));
  PERFORM EditTypeText(GetType('report.report_tree'), 'Informe', 'Informe.', GetLocale('es'));

  -- Event
  PERFORM AddReportTreeEvents(uClass);

  -- Method
  PERFORM AddDefaultMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityReportTree ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityReportTree (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Entity
  uEntity := AddEntity('report_tree', 'Report tree');

  PERFORM EditEntityText(uEntity, 'Дерево отчётов', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Berichtsbaum', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Arbre de rapports', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Albero dei report', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Árbol de informes', null, GetLocale('es'));

  -- Class
  PERFORM CreateClassReportTree(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('report/tree', AddEndpoint('SELECT * FROM rest.report_tree($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
