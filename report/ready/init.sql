--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddReportReadyMethods -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddReportReadyMethods (
  pClass            uuid
)
RETURNS             void
AS $$
DECLARE
  uState            uuid;
  uMethod           uuid;

  rec_type          record;
  rec_state         record;
  rec_method        record;
BEGIN
  -- Methods (without state)

  PERFORM DefaultMethods(pClass);

  -- Methods (with state)

  FOR rec_type IN SELECT * FROM StateType
  LOOP

    CASE rec_type.code
    WHEN 'created' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, 'Created');

        PERFORM EditStateText(uState, 'Создан', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Erstellt', GetLocale('de'));
        PERFORM EditStateText(uState, 'Créé', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Creato', GetLocale('it'));
        PERFORM EditStateText(uState, 'Creado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('execute'), null, 'Execute');
        PERFORM EditMethodText(uMethod, 'Выполнить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Ausführen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Exécuter', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eseguire', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Ejecutar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

    WHEN 'enabled' THEN

      uState := AddState(pClass, rec_type.id, 'progress', 'In progress');

        PERFORM EditStateText(uState, 'Выполняется', GetLocale('ru'));
        PERFORM EditStateText(uState, 'In Bearbeitung', GetLocale('de'));
        PERFORM EditStateText(uState, 'En cours', GetLocale('fr'));
        PERFORM EditStateText(uState, 'In corso', GetLocale('it'));
        PERFORM EditStateText(uState, 'En progreso', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('complete'), null, 'Complete', null, false);
        PERFORM EditMethodText(uMethod, 'Завершить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Abschließen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Terminer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Completare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Completar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('fail'), null, 'Fail', null, false);
        PERFORM EditMethodText(uMethod, 'Неудача', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Fehlgeschlagen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Échoué', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Fallito', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Fallido', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('cancel'), null, 'Cancel');
        PERFORM EditMethodText(uMethod, 'Отменить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Abbrechen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Annuler', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Annullare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Cancelar', GetLocale('es'));

      uState := AddState(pClass, rec_type.id, 'canceled', 'Canceling');

        PERFORM EditStateText(uState, 'Отменяется', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Wird abgebrochen', GetLocale('de'));
        PERFORM EditStateText(uState, 'En annulation', GetLocale('fr'));
        PERFORM EditStateText(uState, 'In annullamento', GetLocale('it'));
        PERFORM EditStateText(uState, 'Cancelando', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('abort'), null, 'Abort', null, false);
        PERFORM EditMethodText(uMethod, 'Прервать', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Abbrechen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Abandonner', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Interrompere', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Abortar', GetLocale('es'));

    WHEN 'disabled' THEN

      uState := AddState(pClass, rec_type.id, 'completed', 'Completed');

        PERFORM EditStateText(uState, 'Завершён', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Abgeschlossen', GetLocale('de'));
        PERFORM EditStateText(uState, 'Terminé', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Completato', GetLocale('it'));
        PERFORM EditStateText(uState, 'Completado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('execute'), null, 'Execute');
        PERFORM EditMethodText(uMethod, 'Выполнить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Ausführen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Exécuter', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eseguire', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Ejecutar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

      uState := AddState(pClass, rec_type.id, 'aborted', 'Aborted');

        PERFORM EditStateText(uState, 'Прерван', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Abgebrochen', GetLocale('de'));
        PERFORM EditStateText(uState, 'Abandonné', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Interrotto', GetLocale('it'));
        PERFORM EditStateText(uState, 'Abortado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('execute'), null, 'Execute');
        PERFORM EditMethodText(uMethod, 'Выполнить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Ausführen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Exécuter', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eseguire', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Ejecutar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

      uState := AddState(pClass, rec_type.id, 'failed', 'Failed');

        PERFORM EditStateText(uState, 'Ошибка', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Fehlgeschlagen', GetLocale('de'));
        PERFORM EditStateText(uState, 'Échoué', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Fallito', GetLocale('it'));
        PERFORM EditStateText(uState, 'Fallido', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('execute'), null, 'Execute');
        PERFORM EditMethodText(uMethod, 'Выполнить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Ausführen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Exécuter', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eseguire', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Ejecutar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

    WHEN 'deleted' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, 'Deleted');

        PERFORM EditStateText(uState, 'Удалён', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Gelöscht', GetLocale('de'));
        PERFORM EditStateText(uState, 'Supprimé', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Eliminato', GetLocale('it'));
        PERFORM EditStateText(uState, 'Eliminado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('restore'), null, 'Restore');
        PERFORM EditMethodText(uMethod, 'Восстановить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Wiederherstellen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Restaurer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Ripristinare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Restaurar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('drop'), null, 'Drop');
        PERFORM EditMethodText(uMethod, 'Уничтожить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Vernichten', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Détruire', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Distruggere', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Destruir', GetLocale('es'));

    END CASE;

  END LOOP;

  PERFORM DefaultTransition(pClass);

  -- Transitions between states

  FOR rec_state IN SELECT * FROM State WHERE class = pClass
  LOOP
    CASE rec_state.code
    WHEN 'created' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'progress'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'progress' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'complete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'completed'));
        END IF;

        IF rec_method.actioncode = 'fail' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'failed'));
        END IF;

        IF rec_method.actioncode = 'cancel' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'canceled'));
        END IF;
      END LOOP;

    WHEN 'canceled' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'abort' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'aborted'));
        END IF;
      END LOOP;

    WHEN 'completed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'progress'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'aborted' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'progress'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'failed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'progress'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'deleted' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'restore' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'created'));
        END IF;
      END LOOP;
    END CASE;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddReportReadyEvents --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddReportReadyEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report created', 'EventReportReadyCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report opened', 'EventReportReadyOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report edited', 'EventReportReadyEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report saved', 'EventReportReadySave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report enabled', 'EventReportReadyEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report disabled', 'EventReportReadyDisable();');
    END IF;

    IF r.code = 'execute' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report in progress', 'EventReportReadyExecute();');
    END IF;

    IF r.code = 'complete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report completed', 'EventReportReadyComplete();');
    END IF;

    IF r.code = 'fail' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report failed', 'EventReportReadyFail();');
    END IF;

    IF r.code = 'abort' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report aborted', 'EventReportReadyAbort();');
    END IF;

    IF r.code = 'cancel' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report canceled', 'EventReportReadyCancel();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report will be deleted', 'EventReportReadyDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report restored', 'EventReportReadyRestore();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Ready report will be dropped', 'EventReportReadyDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassReportReady ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassReportReady (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Class
  uClass := AddClass(pParent, pEntity, 'report_ready', 'Ready report', false);

  PERFORM EditClassText(uClass, 'Готовый отчёт', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Fertiger Bericht', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Rapport prêt', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Report pronto', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Informe listo', GetLocale('es'));

  -- Type
  PERFORM AddType(uClass, 'sync.report_ready', 'Synchronous', 'Synchronous report.');
  PERFORM EditTypeText(GetType('sync.report_ready'), 'Синхронный', 'Синхронный отчёт.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('sync.report_ready'), 'Synchron', 'Synchroner Bericht.', GetLocale('de'));
  PERFORM EditTypeText(GetType('sync.report_ready'), 'Synchrone', 'Rapport synchrone.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('sync.report_ready'), 'Sincrono', 'Report sincrono.', GetLocale('it'));
  PERFORM EditTypeText(GetType('sync.report_ready'), 'Síncrono', 'Informe síncrono.', GetLocale('es'));

  PERFORM AddType(uClass, 'async.report_ready', 'Asynchronous', 'Asynchronous report.');
  PERFORM EditTypeText(GetType('async.report_ready'), 'Асинхронный', 'Асинхронный отчёт.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('async.report_ready'), 'Asynchron', 'Asynchroner Bericht.', GetLocale('de'));
  PERFORM EditTypeText(GetType('async.report_ready'), 'Asynchrone', 'Rapport asynchrone.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('async.report_ready'), 'Asincrono', 'Report asincrono.', GetLocale('it'));
  PERFORM EditTypeText(GetType('async.report_ready'), 'Asíncrono', 'Informe asíncrono.', GetLocale('es'));

  -- Event
  PERFORM AddReportReadyEvents(uClass);

  -- Method
  PERFORM AddReportReadyMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityReportReady -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityReportReady (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Entity
  uEntity := AddEntity('report_ready', 'Ready report');

  PERFORM EditEntityText(uEntity, 'Готовый отчёт', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Fertiger Bericht', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Rapport prêt', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Report pronto', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Informe listo', null, GetLocale('es'));

  -- Class
  PERFORM CreateClassReportReady(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('report/ready', AddEndpoint('SELECT * FROM rest.report_ready($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
