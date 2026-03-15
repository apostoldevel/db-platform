--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddJobMethods ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddJobMethods (
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

        PERFORM EditStateText(uState, 'Создано', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Erstellt', GetLocale('de'));
        PERFORM EditStateText(uState, 'Créé', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Creato', GetLocale('it'));
        PERFORM EditStateText(uState, 'Creado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('enable'), null, 'Enable');
        PERFORM EditMethodText(uMethod, 'Включить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Aktivieren', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Activer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Attivare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Activar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('disable'), null, 'Disable');
        PERFORM EditMethodText(uMethod, 'Отключить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Deaktivieren', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Désactiver', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Disattivare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Desactivar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

    WHEN 'enabled' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, 'Enabled');

        PERFORM EditStateText(uState, 'Включено', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Aktiviert', GetLocale('de'));
        PERFORM EditStateText(uState, 'Activé', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Attivato', GetLocale('it'));
        PERFORM EditStateText(uState, 'Activado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('execute'), null, 'Execute');
        PERFORM EditMethodText(uMethod, 'Выполнить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Ausführen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Exécuter', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eseguire', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Ejecutar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('disable'), null, 'Disable');
        PERFORM EditMethodText(uMethod, 'Отключить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Deaktivieren', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Désactiver', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Disattivare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Desactivar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

      uState := AddState(pClass, rec_type.id, 'executed', 'Executing');

        PERFORM EditStateText(uState, 'Выполняется', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Wird ausgeführt', GetLocale('de'));
        PERFORM EditStateText(uState, 'En cours', GetLocale('fr'));
        PERFORM EditStateText(uState, 'In esecuzione', GetLocale('it'));
        PERFORM EditStateText(uState, 'En ejecución', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('complete'), null, 'Complete', null, false);
        PERFORM EditMethodText(uMethod, 'Завершить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Abschließen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Terminer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Completare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Completar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('done'), null, 'Done', null, false);
        PERFORM EditMethodText(uMethod, 'Сделано', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Erledigt', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Terminé', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Fatto', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Hecho', GetLocale('es'));

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

      uState := AddState(pClass, rec_type.id, 'aborted', 'Aborted');

        PERFORM EditStateText(uState, 'Прервано', GetLocale('ru'));
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

        uMethod := AddMethod(null, pClass, uState, GetAction('disable'), null, 'Disable');
        PERFORM EditMethodText(uMethod, 'Отключить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Deaktivieren', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Désactiver', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Disattivare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Desactivar', GetLocale('es'));

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

        uMethod := AddMethod(null, pClass, uState, GetAction('disable'), null, 'Disable');
        PERFORM EditMethodText(uMethod, 'Отключить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Deaktivieren', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Désactiver', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Disattivare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Desactivar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

    WHEN 'disabled' THEN

      uState := AddState(pClass, rec_type.id, 'disabled', 'Disabled');

        PERFORM EditStateText(uState, 'Отключено', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Deaktiviert', GetLocale('de'));
        PERFORM EditStateText(uState, 'Désactivé', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Disattivato', GetLocale('it'));
        PERFORM EditStateText(uState, 'Desactivado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('enable'), null, 'Enable');
        PERFORM EditMethodText(uMethod, 'Включить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Aktivieren', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Activer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Attivare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Activar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

      uState := AddState(pClass, rec_type.id, 'completed', 'Completed');

        PERFORM EditStateText(uState, 'Завершено', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Abgeschlossen', GetLocale('de'));
        PERFORM EditStateText(uState, 'Terminé', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Completato', GetLocale('it'));
        PERFORM EditStateText(uState, 'Completado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('enable'), null, 'Enable');
        PERFORM EditMethodText(uMethod, 'Включить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Aktivieren', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Activer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Attivare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Activar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

    WHEN 'deleted' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, 'Deleted');

        PERFORM EditStateText(uState, 'Удалено', GetLocale('ru'));
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
        IF rec_method.actioncode = 'enable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'enabled'));
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'enabled' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'executed'));
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'executed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'complete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'completed'));
        END IF;

        IF rec_method.actioncode = 'done' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'enabled'));
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

    WHEN 'failed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'executed'));
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'aborted' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'executed'));
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'disabled' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'enable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'enabled'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'completed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'executed'));
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
-- AddJobEvents ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddJobEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job created', 'EventJobCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job opened', 'EventJobOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job edited', 'EventJobEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job saved', 'EventJobSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job enabled', 'EventJobEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job disabled', 'EventJobDisable();');
    END IF;

    IF r.code = 'execute' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job executed', 'EventJobExecute();');
    END IF;

    IF r.code = 'complete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job completed', 'EventJobComplete();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
    END IF;

    IF r.code = 'done' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job done', 'EventJobDone();');
    END IF;

    IF r.code = 'fail' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job failed', 'EventJobFail();');
    END IF;

    IF r.code = 'abort' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job aborted', 'EventJobAbort();');
    END IF;

    IF r.code = 'cancel' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job canceled', 'EventJobCancel();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job will be deleted', 'EventJobDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job restored', 'EventJobRestore();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Job will be dropped', 'EventJobDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassJob --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassJob (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Class
  uClass := AddClass(pParent, pEntity, 'job', 'Job', false);

  PERFORM EditClassText(uClass, 'Задание', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Auftrag', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Tâche', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Attività', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Tarea', GetLocale('es'));

  -- Type
  PERFORM AddType(uClass, 'periodic.job', 'Periodic', 'Periodic job.');
  PERFORM EditTypeText(GetType('periodic.job'), 'Периодическое', 'Периодическое задание.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('periodic.job'), 'Periodisch', 'Periodischer Auftrag.', GetLocale('de'));
  PERFORM EditTypeText(GetType('periodic.job'), 'Périodique', 'Tâche périodique.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('periodic.job'), 'Periodico', 'Attività periodica.', GetLocale('it'));
  PERFORM EditTypeText(GetType('periodic.job'), 'Periódico', 'Tarea periódica.', GetLocale('es'));

  PERFORM AddType(uClass, 'disposable.job', 'One-time', 'One-time job.');
  PERFORM EditTypeText(GetType('disposable.job'), 'Разовое', 'Разовое задание.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('disposable.job'), 'Einmalig', 'Einmaliger Auftrag.', GetLocale('de'));
  PERFORM EditTypeText(GetType('disposable.job'), 'Ponctuel', 'Tâche ponctuelle.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('disposable.job'), 'Una tantum', 'Attività una tantum.', GetLocale('it'));
  PERFORM EditTypeText(GetType('disposable.job'), 'Puntual', 'Tarea puntual.', GetLocale('es'));

  -- Event
  PERFORM AddJobEvents(uClass);

  -- Method
  PERFORM AddJobMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityJob -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityJob (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Entity
  uEntity := AddEntity('job', 'Job');

  PERFORM EditEntityText(uEntity, 'Задание', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Auftrag', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Tâche', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Attività', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Tarea', null, GetLocale('es'));

  -- Class
  PERFORM CreateClassJob(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('job', AddEndpoint('SELECT * FROM rest.job($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
