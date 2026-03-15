--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddOutboxMethods ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddOutboxMethods (
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

      uState := SetState(null, pClass, rec_type.id, rec_type.code, 'Created');

        PERFORM EditStateText(uState, 'Создано', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Erstellt', GetLocale('de'));
        PERFORM EditStateText(uState, 'Créé', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Creato', GetLocale('it'));
        PERFORM EditStateText(uState, 'Creado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('submit'), null, 'Prepare');
        PERFORM EditMethodText(uMethod, 'Подготовить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Vorbereiten', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Préparer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Preparare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Preparar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

    WHEN 'enabled' THEN

      uState := SetState(null, pClass, rec_type.id, 'prepared', 'Prepared');

        PERFORM EditStateText(uState, 'Подготовлено', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Vorbereitet', GetLocale('de'));
        PERFORM EditStateText(uState, 'Préparé', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Preparato', GetLocale('it'));
        PERFORM EditStateText(uState, 'Preparado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('send'), pvisible => false);
        PERFORM EditMethodText(uMethod, 'Отправить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Senden', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Envoyer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Inviare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Enviar', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('done'), pvisible => false);
        PERFORM EditMethodText(uMethod, 'Сделано', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Erledigt', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Terminé', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Fatto', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Hecho', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('fail'), pvisible => false);
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

      uState := SetState(null, pClass, rec_type.id, 'sending', 'Sending');

        PERFORM EditStateText(uState, 'Отправка', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Wird gesendet', GetLocale('de'));
        PERFORM EditStateText(uState, 'En cours d''envoi', GetLocale('fr'));
        PERFORM EditStateText(uState, 'In invio', GetLocale('it'));
        PERFORM EditStateText(uState, 'Enviando', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('done'), pvisible => false);
        PERFORM EditMethodText(uMethod, 'Сделано', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Erledigt', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Terminé', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Fatto', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Hecho', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('fail'), pvisible => false);
        PERFORM EditMethodText(uMethod, 'Неудача', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Fehlgeschlagen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Échoué', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Fallito', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Fallido', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

    WHEN 'disabled' THEN

      uState := SetState(null, pClass, rec_type.id, 'submitted', 'Sent');

        PERFORM EditStateText(uState, 'Отправлено', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Gesendet', GetLocale('de'));
        PERFORM EditStateText(uState, 'Envoyé', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Inviato', GetLocale('it'));
        PERFORM EditStateText(uState, 'Enviado', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('repeat'), null, 'Repeat');
        PERFORM EditMethodText(uMethod, 'Повторить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Wiederholen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Répéter', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Ripetere', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Repetir', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

      uState := SetState(null, pClass, rec_type.id, 'failed', 'Failed');

        PERFORM EditStateText(uState, 'Ошибка', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Fehlgeschlagen', GetLocale('de'));
        PERFORM EditStateText(uState, 'Échoué', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Fallito', GetLocale('it'));
        PERFORM EditStateText(uState, 'Fallido', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('repeat'), null, 'Repeat');
        PERFORM EditMethodText(uMethod, 'Повторить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Wiederholen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Répéter', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Ripetere', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Repetir', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

    WHEN 'deleted' THEN

      uState := SetState(null, pClass, rec_type.id, rec_type.code, 'Deleted');

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

  -- State transitions

  FOR rec_state IN SELECT * FROM State WHERE class = pClass
  LOOP
    CASE rec_state.code
    WHEN 'created' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'submit' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'prepared'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'prepared' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'send' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'sending'));
        END IF;

        IF rec_method.actioncode = 'done' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'submitted'));
        END IF;

        IF rec_method.actioncode = 'fail' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'failed'));
        END IF;

        IF rec_method.actioncode = 'cancel' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'created'));
        END IF;
      END LOOP;

    WHEN 'sending' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'done' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'submitted'));
        END IF;

        IF rec_method.actioncode = 'fail' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'failed'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'submitted' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'repeat' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'prepared'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'failed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'repeat' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'prepared'));
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
-- AddOutboxEvents -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddOutboxEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message created', 'EventOutboxCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message opened', 'EventOutboxOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message edited', 'EventOutboxEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message saved', 'EventOutboxSave();');
    END IF;

    IF r.code = 'submit' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message submitted', 'EventOutboxSubmit();');
    END IF;

    IF r.code = 'send' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message sending', 'EventOutboxSend();');
    END IF;

    IF r.code = 'cancel' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message canceled', 'EventOutboxCancel();');
    END IF;

    IF r.code = 'done' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message done', 'EventOutboxDone();');
    END IF;

    IF r.code = 'fail' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message failed', 'EventOutboxFail();');
    END IF;

    IF r.code = 'repeat' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message will be repeated', 'EventOutboxRepeat();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message will be deleted', 'EventOutboxDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message restored', 'EventOutboxRestore();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Outbox message will be dropped', 'EventOutboxDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassOutbox -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassOutbox (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Class
  uClass := AddClass(pParent, pEntity, 'outbox', 'Outbox', false);

  PERFORM EditClassText(uClass, 'Исходящее', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Ausgang', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Boîte d''envoi', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Posta in uscita', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Bandeja de salida', GetLocale('es'));

  -- Type
  PERFORM AddType(uClass, 'message.outbox', 'Outbox', 'Outgoing message.');

  PERFORM EditTypeText(GetType('message.outbox'), 'Исходящие', 'Исходящие сообщение.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('message.outbox'), 'Ausgang', 'Ausgehende Nachricht.', GetLocale('de'));
  PERFORM EditTypeText(GetType('message.outbox'), 'Envoi', 'Message sortant.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('message.outbox'), 'In uscita', 'Messaggio in uscita.', GetLocale('it'));
  PERFORM EditTypeText(GetType('message.outbox'), 'Salida', 'Mensaje saliente.', GetLocale('es'));

  -- Event
  PERFORM AddOutboxEvents(uClass);

  -- Method
  PERFORM AddOutboxMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
