--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddInboxMethods -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddInboxMethods (
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

      uState := SetState(null, pClass, rec_type.id, rec_type.code, 'New');

        PERFORM EditStateText(uState, 'Новое', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Neu', GetLocale('de'));
        PERFORM EditStateText(uState, 'Nouveau', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Nuovo', GetLocale('it'));
        PERFORM EditStateText(uState, 'Nuevo', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('enable'), null, 'Open');
        PERFORM EditMethodText(uMethod, 'Открыть', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Öffnen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Ouvrir', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Aprire', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Abrir', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('disable'), null, 'Read');
        PERFORM EditMethodText(uMethod, 'Прочитать', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Lesen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Lire', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Leggere', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Leer', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

    WHEN 'enabled' THEN

      uState := SetState(null, pClass, rec_type.id, rec_type.code, 'Opened');

        PERFORM EditStateText(uState, 'Открыто', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Geöffnet', GetLocale('de'));
        PERFORM EditStateText(uState, 'Ouvert', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Aperto', GetLocale('it'));
        PERFORM EditStateText(uState, 'Abierto', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('disable'), null, 'Read');
        PERFORM EditMethodText(uMethod, 'Прочитать', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Lesen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Lire', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Leggere', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Leer', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, 'Delete');
        PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

    WHEN 'disabled' THEN

      uState := SetState(null, pClass, rec_type.id, rec_type.code, 'Read');

        PERFORM EditStateText(uState, 'Прочитано', GetLocale('ru'));
        PERFORM EditStateText(uState, 'Gelesen', GetLocale('de'));
        PERFORM EditStateText(uState, 'Lu', GetLocale('fr'));
        PERFORM EditStateText(uState, 'Letto', GetLocale('it'));
        PERFORM EditStateText(uState, 'Leído', GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('enable'), null, 'Open');
        PERFORM EditMethodText(uMethod, 'Открыть', GetLocale('ru'));
        PERFORM EditMethodText(uMethod, 'Öffnen', GetLocale('de'));
        PERFORM EditMethodText(uMethod, 'Ouvrir', GetLocale('fr'));
        PERFORM EditMethodText(uMethod, 'Aprire', GetLocale('it'));
        PERFORM EditMethodText(uMethod, 'Abrir', GetLocale('es'));

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
-- AddInboxEvents --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddInboxEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Inbox message created', 'EventInboxCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Inbox message opened', 'EventInboxOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Inbox message edited', 'EventInboxEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Inbox message saved', 'EventInboxSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Inbox message opened', 'EventInboxEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Inbox message read', 'EventInboxDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Inbox message will be deleted', 'EventInboxDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Inbox message restored', 'EventInboxRestore();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Inbox message will be dropped', 'EventInboxDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassInbox ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassInbox (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Class
  uClass := AddClass(pParent, pEntity, 'inbox', 'Inbox', false);

  PERFORM EditClassText(uClass, 'Входящее', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Eingang', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Boîte de réception', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Posta in arrivo', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Bandeja de entrada', GetLocale('es'));

  -- Type
  PERFORM AddType(uClass, 'message.inbox', 'Inbox', 'Incoming message.');

  PERFORM EditTypeText(GetType('message.inbox'), 'Входящие', 'Входящие сообщение.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('message.inbox'), 'Eingang', 'Eingehende Nachricht.', GetLocale('de'));
  PERFORM EditTypeText(GetType('message.inbox'), 'Réception', 'Message entrant.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('message.inbox'), 'In arrivo', 'Messaggio in arrivo.', GetLocale('it'));
  PERFORM EditTypeText(GetType('message.inbox'), 'Entrada', 'Mensaje entrante.', GetLocale('es'));

  -- Event
  PERFORM AddInboxEvents(uClass);

  -- Method
  PERFORM AddInboxMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
