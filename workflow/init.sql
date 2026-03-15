--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- DefaultMethods --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DefaultMethods (
  pClass    uuid
)
RETURNS     void
AS $$
DECLARE
  uMethod   uuid;
BEGIN
  uMethod := AddMethod(null, pClass, null, GetAction('create'), null, 'Create');
  PERFORM EditMethodText(uMethod, 'Создать', GetLocale('ru'));
  PERFORM EditMethodText(uMethod, 'Erstellen', GetLocale('de'));
  PERFORM EditMethodText(uMethod, 'Créer', GetLocale('fr'));
  PERFORM EditMethodText(uMethod, 'Creare', GetLocale('it'));
  PERFORM EditMethodText(uMethod, 'Crear', GetLocale('es'));

  uMethod := AddMethod(null, pClass, null, GetAction('open'), null, 'Open');
  PERFORM EditMethodText(uMethod, 'Открыть', GetLocale('ru'));
  PERFORM EditMethodText(uMethod, 'Öffnen', GetLocale('de'));
  PERFORM EditMethodText(uMethod, 'Ouvrir', GetLocale('fr'));
  PERFORM EditMethodText(uMethod, 'Aprire', GetLocale('it'));
  PERFORM EditMethodText(uMethod, 'Abrir', GetLocale('es'));

  uMethod := AddMethod(null, pClass, null, GetAction('edit'), null, 'Edit');
  PERFORM EditMethodText(uMethod, 'Изменить', GetLocale('ru'));
  PERFORM EditMethodText(uMethod, 'Bearbeiten', GetLocale('de'));
  PERFORM EditMethodText(uMethod, 'Modifier', GetLocale('fr'));
  PERFORM EditMethodText(uMethod, 'Modificare', GetLocale('it'));
  PERFORM EditMethodText(uMethod, 'Editar', GetLocale('es'));

  uMethod := AddMethod(null, pClass, null, GetAction('save'), null, 'Save');
  PERFORM EditMethodText(uMethod, 'Сохранить', GetLocale('ru'));
  PERFORM EditMethodText(uMethod, 'Speichern', GetLocale('de'));
  PERFORM EditMethodText(uMethod, 'Enregistrer', GetLocale('fr'));
  PERFORM EditMethodText(uMethod, 'Salvare', GetLocale('it'));
  PERFORM EditMethodText(uMethod, 'Guardar', GetLocale('es'));

  uMethod := AddMethod(null, pClass, null, GetAction('update'), null, 'Update');
  PERFORM EditMethodText(uMethod, 'Обновить', GetLocale('ru'));
  PERFORM EditMethodText(uMethod, 'Aktualisieren', GetLocale('de'));
  PERFORM EditMethodText(uMethod, 'Mettre à jour', GetLocale('fr'));
  PERFORM EditMethodText(uMethod, 'Aggiornare', GetLocale('it'));
  PERFORM EditMethodText(uMethod, 'Actualizar', GetLocale('es'));

  uMethod := AddMethod(null, pClass, null, GetAction('enable'), null, 'Enable');
  PERFORM EditMethodText(uMethod, 'Включить', GetLocale('ru'));
  PERFORM EditMethodText(uMethod, 'Aktivieren', GetLocale('de'));
  PERFORM EditMethodText(uMethod, 'Activer', GetLocale('fr'));
  PERFORM EditMethodText(uMethod, 'Attivare', GetLocale('it'));
  PERFORM EditMethodText(uMethod, 'Activar', GetLocale('es'));

  uMethod := AddMethod(null, pClass, null, GetAction('disable'), null, 'Disable');
  PERFORM EditMethodText(uMethod, 'Выключить', GetLocale('ru'));
  PERFORM EditMethodText(uMethod, 'Deaktivieren', GetLocale('de'));
  PERFORM EditMethodText(uMethod, 'Désactiver', GetLocale('fr'));
  PERFORM EditMethodText(uMethod, 'Disattivare', GetLocale('it'));
  PERFORM EditMethodText(uMethod, 'Desactivar', GetLocale('es'));

  uMethod := AddMethod(null, pClass, null, GetAction('delete'), null, 'Delete');
  PERFORM EditMethodText(uMethod, 'Удалить', GetLocale('ru'));
  PERFORM EditMethodText(uMethod, 'Löschen', GetLocale('de'));
  PERFORM EditMethodText(uMethod, 'Supprimer', GetLocale('fr'));
  PERFORM EditMethodText(uMethod, 'Eliminare', GetLocale('it'));
  PERFORM EditMethodText(uMethod, 'Eliminar', GetLocale('es'));

  uMethod := AddMethod(null, pClass, null, GetAction('restore'), null, 'Restore');
  PERFORM EditMethodText(uMethod, 'Восстановить', GetLocale('ru'));
  PERFORM EditMethodText(uMethod, 'Wiederherstellen', GetLocale('de'));
  PERFORM EditMethodText(uMethod, 'Restaurer', GetLocale('fr'));
  PERFORM EditMethodText(uMethod, 'Ripristinare', GetLocale('it'));
  PERFORM EditMethodText(uMethod, 'Restaurar', GetLocale('es'));

  uMethod := AddMethod(null, pClass, null, GetAction('drop'), null, 'Drop');
  PERFORM EditMethodText(uMethod, 'Уничтожить', GetLocale('ru'));
  PERFORM EditMethodText(uMethod, 'Vernichten', GetLocale('de'));
  PERFORM EditMethodText(uMethod, 'Détruire', GetLocale('fr'));
  PERFORM EditMethodText(uMethod, 'Distruggere', GetLocale('it'));
  PERFORM EditMethodText(uMethod, 'Destruir', GetLocale('es'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DefaultTransition -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DefaultTransition (
  pClass            uuid
)
RETURNS             void
AS $$
DECLARE
  rec_method        record;
BEGIN
  -- Переходы в состояние

  FOR rec_method IN SELECT * FROM Method WHERE class = pClass AND state IS NULL
  LOOP
    IF rec_method.actioncode = 'create' THEN
      PERFORM AddTransition(null, rec_method.id, GetState(pClass, 'created'));
    END IF;

    IF rec_method.actioncode = 'enable' THEN
      PERFORM AddTransition(null, rec_method.id, GetState(pClass, 'enabled'));
    END IF;

    IF rec_method.actioncode = 'disable' THEN
      PERFORM AddTransition(null, rec_method.id, GetState(pClass, 'disabled'));
    END IF;

    IF rec_method.actioncode = 'delete' THEN
      PERFORM AddTransition(null, rec_method.id, GetState(pClass, 'deleted'));
    END IF;

    IF rec_method.actioncode = 'restore' THEN
      PERFORM AddTransition(null, rec_method.id, GetState(pClass, 'created'));
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddDefaultMethods -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddDefaultMethods (
  pClass        uuid,
  pNamesEN      text[] DEFAULT null,
  pNamesRU      text[] DEFAULT null
)
RETURNS         void
AS $$
DECLARE
  uState        uuid;
  uMethod       uuid;

  aDE           text[];
  aFR           text[];
  aIT           text[];
  aES           text[];

  rec_type      record;
  rec_state     record;
  rec_method    record;
BEGIN
  IF pNamesEN IS NULL THEN
    pNamesEN := array_cat(pNamesEN, ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete', 'Restore', 'Drop']);
  END IF;

  IF pNamesRU IS NULL THEN
    pNamesRU := array_cat(pNamesRU, ARRAY['Создан', 'Открыт', 'Закрыт', 'Удалён', 'Открыть', 'Закрыть', 'Удалить', 'Восстановить', 'Уничтожить']);
  END IF;

  aDE := ARRAY['Erstellt', 'Geöffnet', 'Geschlossen', 'Gelöscht', 'Öffnen', 'Schließen', 'Löschen', 'Wiederherstellen', 'Vernichten'];
  aFR := ARRAY['Créé', 'Ouvert', 'Fermé', 'Supprimé', 'Ouvrir', 'Fermer', 'Supprimer', 'Restaurer', 'Détruire'];
  aIT := ARRAY['Creato', 'Aperto', 'Chiuso', 'Eliminato', 'Aprire', 'Chiudere', 'Eliminare', 'Ripristinare', 'Distruggere'];
  aES := ARRAY['Creado', 'Abierto', 'Cerrado', 'Eliminado', 'Abrir', 'Cerrar', 'Eliminar', 'Restaurar', 'Destruir'];

  -- Операции (без учёта состояния)

  PERFORM DefaultMethods(pClass);

  -- Операции (с учётом состояния)

  FOR rec_type IN SELECT * FROM StateType
  LOOP

    CASE rec_type.code
    WHEN 'created' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, pNamesEN[1]);
      PERFORM EditStateText(uState, pNamesRU[1], GetLocale('ru'));
      PERFORM EditStateText(uState, aDE[1], GetLocale('de'));
      PERFORM EditStateText(uState, aFR[1], GetLocale('fr'));
      PERFORM EditStateText(uState, aIT[1], GetLocale('it'));
      PERFORM EditStateText(uState, aES[1], GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('enable'), null, pNamesEN[5]);
        PERFORM EditMethodText(uMethod, pNamesRU[5], GetLocale('ru'));
        PERFORM EditMethodText(uMethod, aDE[5], GetLocale('de'));
        PERFORM EditMethodText(uMethod, aFR[5], GetLocale('fr'));
        PERFORM EditMethodText(uMethod, aIT[5], GetLocale('it'));
        PERFORM EditMethodText(uMethod, aES[5], GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('disable'), null, pNamesEN[6]);
        PERFORM EditMethodText(uMethod, pNamesRU[6], GetLocale('ru'));
        PERFORM EditMethodText(uMethod, aDE[6], GetLocale('de'));
        PERFORM EditMethodText(uMethod, aFR[6], GetLocale('fr'));
        PERFORM EditMethodText(uMethod, aIT[6], GetLocale('it'));
        PERFORM EditMethodText(uMethod, aES[6], GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, pNamesEN[7]);
        PERFORM EditMethodText(uMethod, pNamesRU[7], GetLocale('ru'));
        PERFORM EditMethodText(uMethod, aDE[7], GetLocale('de'));
        PERFORM EditMethodText(uMethod, aFR[7], GetLocale('fr'));
        PERFORM EditMethodText(uMethod, aIT[7], GetLocale('it'));
        PERFORM EditMethodText(uMethod, aES[7], GetLocale('es'));

    WHEN 'enabled' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, pNamesEN[2]);
      PERFORM EditStateText(uState, pNamesRU[2], GetLocale('ru'));
      PERFORM EditStateText(uState, aDE[2], GetLocale('de'));
      PERFORM EditStateText(uState, aFR[2], GetLocale('fr'));
      PERFORM EditStateText(uState, aIT[2], GetLocale('it'));
      PERFORM EditStateText(uState, aES[2], GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('disable'), null, pNamesEN[6]);
        PERFORM EditMethodText(uMethod, pNamesRU[6], GetLocale('ru'));
        PERFORM EditMethodText(uMethod, aDE[6], GetLocale('de'));
        PERFORM EditMethodText(uMethod, aFR[6], GetLocale('fr'));
        PERFORM EditMethodText(uMethod, aIT[6], GetLocale('it'));
        PERFORM EditMethodText(uMethod, aES[6], GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, pNamesEN[7]);
        PERFORM EditMethodText(uMethod, pNamesRU[7], GetLocale('ru'));
        PERFORM EditMethodText(uMethod, aDE[7], GetLocale('de'));
        PERFORM EditMethodText(uMethod, aFR[7], GetLocale('fr'));
        PERFORM EditMethodText(uMethod, aIT[7], GetLocale('it'));
        PERFORM EditMethodText(uMethod, aES[7], GetLocale('es'));

    WHEN 'disabled' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, pNamesEN[3]);
      PERFORM EditStateText(uState, pNamesRU[3], GetLocale('ru'));
      PERFORM EditStateText(uState, aDE[3], GetLocale('de'));
      PERFORM EditStateText(uState, aFR[3], GetLocale('fr'));
      PERFORM EditStateText(uState, aIT[3], GetLocale('it'));
      PERFORM EditStateText(uState, aES[3], GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('enable'), null, pNamesEN[5]);
        PERFORM EditMethodText(uMethod, pNamesRU[5], GetLocale('ru'));
        PERFORM EditMethodText(uMethod, aDE[5], GetLocale('de'));
        PERFORM EditMethodText(uMethod, aFR[5], GetLocale('fr'));
        PERFORM EditMethodText(uMethod, aIT[5], GetLocale('it'));
        PERFORM EditMethodText(uMethod, aES[5], GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, pNamesEN[7]);
        PERFORM EditMethodText(uMethod, pNamesRU[7], GetLocale('ru'));
        PERFORM EditMethodText(uMethod, aDE[7], GetLocale('de'));
        PERFORM EditMethodText(uMethod, aFR[7], GetLocale('fr'));
        PERFORM EditMethodText(uMethod, aIT[7], GetLocale('it'));
        PERFORM EditMethodText(uMethod, aES[7], GetLocale('es'));

    WHEN 'deleted' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, pNamesEN[4]);
      PERFORM EditStateText(uState, pNamesRU[4], GetLocale('ru'));
      PERFORM EditStateText(uState, aDE[4], GetLocale('de'));
      PERFORM EditStateText(uState, aFR[4], GetLocale('fr'));
      PERFORM EditStateText(uState, aIT[4], GetLocale('it'));
      PERFORM EditStateText(uState, aES[4], GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('restore'), null, pNamesEN[8]);
        PERFORM EditMethodText(uMethod, pNamesRU[8], GetLocale('ru'));
        PERFORM EditMethodText(uMethod, aDE[8], GetLocale('de'));
        PERFORM EditMethodText(uMethod, aFR[8], GetLocale('fr'));
        PERFORM EditMethodText(uMethod, aIT[8], GetLocale('it'));
        PERFORM EditMethodText(uMethod, aES[8], GetLocale('es'));

        uMethod := AddMethod(null, pClass, uState, GetAction('drop'), null, pNamesEN[9]);
        PERFORM EditMethodText(uMethod, pNamesRU[9], GetLocale('ru'));
        PERFORM EditMethodText(uMethod, aDE[9], GetLocale('de'));
        PERFORM EditMethodText(uMethod, aFR[9], GetLocale('fr'));
        PERFORM EditMethodText(uMethod, aIT[9], GetLocale('it'));
        PERFORM EditMethodText(uMethod, aES[9], GetLocale('es'));

    END CASE;

  END LOOP;

  PERFORM DefaultTransition(pClass);

  -- Переходы из состояния в состояние

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
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateDefaultMethods --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UpdateDefaultMethods (
  pClass        uuid,
  pLocale       uuid,
  pNames        text[] DEFAULT null
)
RETURNS         void
AS $$
DECLARE
  rec_state     record;
  rec_method    record;
BEGIN
  IF pNames IS NULL THEN
    IF pLocale = GetLocale('ru') THEN
      pNames := array_cat(pNames, ARRAY['Создан', 'Открыт', 'Закрыт', 'Удалён', 'Открыть', 'Закрыть', 'Удалить', 'Восстановить', 'Уничтожить']);
    ELSIF pLocale = GetLocale('de') THEN
      pNames := array_cat(pNames, ARRAY['Erstellt', 'Geöffnet', 'Geschlossen', 'Gelöscht', 'Öffnen', 'Schließen', 'Löschen', 'Wiederherstellen', 'Vernichten']);
    ELSIF pLocale = GetLocale('fr') THEN
      pNames := array_cat(pNames, ARRAY['Créé', 'Ouvert', 'Fermé', 'Supprimé', 'Ouvrir', 'Fermer', 'Supprimer', 'Restaurer', 'Détruire']);
    ELSIF pLocale = GetLocale('it') THEN
      pNames := array_cat(pNames, ARRAY['Creato', 'Aperto', 'Chiuso', 'Eliminato', 'Aprire', 'Chiudere', 'Eliminare', 'Ripristinare', 'Distruggere']);
    ELSIF pLocale = GetLocale('es') THEN
      pNames := array_cat(pNames, ARRAY['Creado', 'Abierto', 'Cerrado', 'Eliminado', 'Abrir', 'Cerrar', 'Eliminar', 'Restaurar', 'Destruir']);
    ELSE
      pNames := array_cat(pNames, ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete', 'Restore', 'Drop']);
    END IF;
  END IF;

  FOR rec_state IN SELECT * FROM State WHERE class = pClass
  LOOP
    CASE rec_state.code
    WHEN 'created' THEN

      PERFORM EditStateText(rec_state.id, pNames[1], pLocale);

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'enable' THEN
          PERFORM EditMethodText(rec_method.id, pNames[5], pLocale);
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM EditMethodText(rec_method.id, pNames[6], pLocale);
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM EditMethodText(rec_method.id, pNames[7], pLocale);
        END IF;
      END LOOP;

    WHEN 'enabled' THEN

      PERFORM EditStateText(rec_state.id, pNames[2], pLocale);

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'disable' THEN
          PERFORM EditMethodText(rec_method.id, pNames[6], pLocale);
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM EditMethodText(rec_method.id, pNames[7], pLocale);
        END IF;
      END LOOP;

    WHEN 'disabled' THEN

      PERFORM EditStateText(rec_state.id, pNames[3], pLocale);

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'enable' THEN
          PERFORM EditMethodText(rec_method.id, pNames[5], pLocale);
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM EditMethodText(rec_method.id, pNames[7], pLocale);
        END IF;
      END LOOP;

    WHEN 'deleted' THEN

      PERFORM EditStateText(rec_state.id, pNames[4], pLocale);

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'restore' THEN
          PERFORM EditMethodText(rec_method.id, pNames[8], pLocale);
        END IF;

        IF rec_method.actioncode = 'drop' THEN
          PERFORM EditMethodText(rec_method.id, pNames[9], pLocale);
        END IF;
      END LOOP;
    END CASE;
  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitWorkFlow ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitWorkFlow()
RETURNS     void
AS $$
DECLARE
  uAction   uuid;
  uPriority uuid;
BEGIN
  INSERT INTO db.state_type (id, code) VALUES ('00000000-0000-4000-b001-000000000001', 'created');
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000001', 'Created', GetLocale('en'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000001', 'Создан', GetLocale('ru'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000001', 'Erstellt', GetLocale('de'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000001', 'Créé', GetLocale('fr'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000001', 'Creato', GetLocale('it'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000001', 'Creado', GetLocale('es'));

  INSERT INTO db.state_type (id, code) VALUES ('00000000-0000-4000-b001-000000000002', 'enabled');
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000002', 'Enabled', GetLocale('en'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000002', 'Включен', GetLocale('ru'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000002', 'Aktiviert', GetLocale('de'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000002', 'Activé', GetLocale('fr'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000002', 'Attivato', GetLocale('it'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000002', 'Activado', GetLocale('es'));

  INSERT INTO db.state_type (id, code) VALUES ('00000000-0000-4000-b001-000000000003', 'disabled');
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000003', 'Disabled', GetLocale('en'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000003', 'Отключен', GetLocale('ru'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000003', 'Deaktiviert', GetLocale('de'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000003', 'Désactivé', GetLocale('fr'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000003', 'Disattivato', GetLocale('it'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000003', 'Desactivado', GetLocale('es'));

  INSERT INTO db.state_type (id, code) VALUES ('00000000-0000-4000-b001-000000000004', 'deleted');
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000004', 'Deleted', GetLocale('en'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000004', 'Удалён', GetLocale('ru'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000004', 'Gelöscht', GetLocale('de'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000004', 'Supprimé', GetLocale('fr'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000004', 'Eliminato', GetLocale('it'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000004', 'Eliminado', GetLocale('es'));

  --------------------------------------------------------------------------------

  INSERT INTO db.event_type (id, code) VALUES ('00000000-0000-4000-b002-000000000001', 'parent');
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000001', 'Parent class events', GetLocale('en'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000001', 'События класса родителя', GetLocale('ru'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000001', 'Ereignisse der Elternklasse', GetLocale('de'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000001', 'Événements de la classe parente', GetLocale('fr'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000001', 'Eventi della classe genitore', GetLocale('it'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000001', 'Eventos de la clase padre', GetLocale('es'));

  INSERT INTO db.event_type (id, code) VALUES ('00000000-0000-4000-b002-000000000002', 'event');
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000002', 'Event', GetLocale('en'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000002', 'Событие', GetLocale('ru'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000002', 'Ereignis', GetLocale('de'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000002', 'Événement', GetLocale('fr'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000002', 'Evento', GetLocale('it'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000002', 'Evento', GetLocale('es'));

  INSERT INTO db.event_type (id, code) VALUES ('00000000-0000-4000-b002-000000000003', 'plpgsql');
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000003', 'PL/pgSQL code', GetLocale('en'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000003', 'PL/pgSQL код', GetLocale('ru'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000003', 'PL/pgSQL-Code', GetLocale('de'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000003', 'Code PL/pgSQL', GetLocale('fr'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000003', 'Codice PL/pgSQL', GetLocale('it'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000003', 'Código PL/pgSQL', GetLocale('es'));

  --------------------------------------------------------------------------------

  uAction := AddAction('00000000-0000-4000-b003-000000000000', 'anything', 'Anything');
  PERFORM EditActionText(uAction, 'Ничто', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Beliebig', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'N''importe quoi', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Qualsiasi', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Cualquiera', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000001', 'abort', 'Abort');
  PERFORM EditActionText(uAction, 'Прервать', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Abbrechen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Abandonner', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Interrompere', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Abortar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000002', 'accept', 'Accept');
  PERFORM EditActionText(uAction, 'Принять', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Akzeptieren', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Accepter', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Accettare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Aceptar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000003', 'add', 'Add');
  PERFORM EditActionText(uAction, 'Добавить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Hinzufügen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Ajouter', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Aggiungere', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Añadir', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000004', 'alarm', 'Alarm');
  PERFORM EditActionText(uAction, 'Тревога', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Alarm', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Alarme', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Allarme', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Alarma', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000005', 'approve', 'Approve');
  PERFORM EditActionText(uAction, 'Утвердить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Genehmigen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Approuver', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Approvare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Aprobar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000006', 'available', 'Available');
  PERFORM EditActionText(uAction, 'Доступен', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Verfügbar', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Disponible', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Disponibile', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Disponible', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000007', 'cancel', 'Cancel');
  PERFORM EditActionText(uAction, 'Отменить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Abbrechen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Annuler', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Annullare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Cancelar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000008', 'check', 'Check');
  PERFORM EditActionText(uAction, 'Проверить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Prüfen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Vérifier', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Verificare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Verificar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000009', 'complete', 'Complete');
  PERFORM EditActionText(uAction, 'Завершить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Abschließen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Terminer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Completare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Completar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000010', 'confirm', 'Confirm');
  PERFORM EditActionText(uAction, 'Подтвердить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Bestätigen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Confirmer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Confermare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Confirmar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000011', 'create', 'Create');
  PERFORM EditActionText(uAction, 'Создать', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Erstellen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Créer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Creare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Crear', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000012', 'delete', 'Delete');
  PERFORM EditActionText(uAction, 'Удалить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Löschen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Supprimer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Eliminare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Eliminar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000013', 'disable', 'Disable');
  PERFORM EditActionText(uAction, 'Отключить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Deaktivieren', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Désactiver', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Disattivare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Desactivar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000014', 'done', 'Done');
  PERFORM EditActionText(uAction, 'Сделано', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Erledigt', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Terminé', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Fatto', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Hecho', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000015', 'drop', 'Drop');
  PERFORM EditActionText(uAction, 'Уничтожить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Vernichten', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Détruire', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Distruggere', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Destruir', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000016', 'edit', 'Edit');
  PERFORM EditActionText(uAction, 'Изменить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Bearbeiten', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Modifier', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Modificare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Editar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000017', 'enable', 'Enable');
  PERFORM EditActionText(uAction, 'Включить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Aktivieren', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Activer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Attivare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Activar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000018', 'execute', 'Execute');
  PERFORM EditActionText(uAction, 'Выполнить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Ausführen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Exécuter', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Eseguire', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Ejecutar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000019', 'expire', 'Expire');
  PERFORM EditActionText(uAction, 'Истекло', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Abgelaufen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Expiré', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Scaduto', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Expirado', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000020', 'fail', 'Fail');
  PERFORM EditActionText(uAction, 'Неудача', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Fehlgeschlagen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Échoué', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Fallito', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Fallido', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000021', 'faulted', 'Faulted');
  PERFORM EditActionText(uAction, 'Ошибка', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Fehlerhaft', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Défaillant', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Guasto', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Averiado', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000022', 'finishing', 'Finishing');
  PERFORM EditActionText(uAction, 'Завершение', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Abschluss', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Finalisation', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Completamento', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Finalización', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000023', 'heartbeat', 'Heartbeat');
  PERFORM EditActionText(uAction, 'Сердцебиение', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Herzschlag', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Battement', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Battito', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Latido', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000024', 'invite', 'Invite');
  PERFORM EditActionText(uAction, 'Пригласить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Einladen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Inviter', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Invitare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Invitar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000025', 'open', 'Open');
  PERFORM EditActionText(uAction, 'Открыть', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Öffnen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Ouvrir', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Aprire', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Abrir', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000026', 'plan', 'Plan');
  PERFORM EditActionText(uAction, 'Планировать', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Planen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Planifier', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Pianificare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Planificar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000027', 'post', 'Post');
  PERFORM EditActionText(uAction, 'Публиковать', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Veröffentlichen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Publier', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Pubblicare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Publicar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000028', 'postpone', 'Postpone');
  PERFORM EditActionText(uAction, 'Отложить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Verschieben', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Reporter', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Rimandare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Posponer', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000029', 'preparing', 'Preparing');
  PERFORM EditActionText(uAction, 'Подготовка', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Vorbereitung', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Préparation', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Preparazione', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Preparación', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000030', 'reconfirm', 'Reconfirm');
  PERFORM EditActionText(uAction, 'Повторно подтвердить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Erneut bestätigen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Reconfirmer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Riconfermare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Reconfirmar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000031', 'remove', 'Remove');
  PERFORM EditActionText(uAction, 'Удалить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Entfernen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Retirer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Rimuovere', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Quitar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000032', 'repeat', 'Repeat');
  PERFORM EditActionText(uAction, 'Повторить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Wiederholen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Répéter', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Ripetere', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Repetir', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000033', 'reserve', 'Reserve');
  PERFORM EditActionText(uAction, 'Резервировать', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Reservieren', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Réserver', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Riservare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Reservar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000034', 'reserved', 'Reserved');
  PERFORM EditActionText(uAction, 'Зарезервирован', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Reserviert', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Réservé', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Riservato', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Reservado', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000035', 'restore', 'Restore');
  PERFORM EditActionText(uAction, 'Восстановить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Wiederherstellen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Restaurer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Ripristinare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Restaurar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000036', 'return', 'Return');
  PERFORM EditActionText(uAction, 'Вернуть', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Zurückgeben', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Retourner', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Restituire', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Devolver', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000037', 'save', 'Save');
  PERFORM EditActionText(uAction, 'Сохранить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Speichern', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Enregistrer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Salvare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Guardar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000038', 'send', 'Send');
  PERFORM EditActionText(uAction, 'Отправить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Senden', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Envoyer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Inviare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Enviar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000039', 'sign', 'Sign');
  PERFORM EditActionText(uAction, 'Подписать', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Unterschreiben', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Signer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Firmare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Firmar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000040', 'start', 'Start');
  PERFORM EditActionText(uAction, 'Запустить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Starten', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Démarrer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Avviare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Iniciar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000041', 'stop', 'Stop');
  PERFORM EditActionText(uAction, 'Остановить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Stoppen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Arrêter', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Fermare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Detener', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000042', 'submit', 'Submit');
  PERFORM EditActionText(uAction, 'Отправить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Einreichen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Soumettre', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Inviare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Enviar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000043', 'unavailable', 'Unavailable');
  PERFORM EditActionText(uAction, 'Недоступен', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Nicht verfügbar', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Indisponible', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Non disponibile', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'No disponible', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000044', 'update', 'Update');
  PERFORM EditActionText(uAction, 'Обновить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Aktualisieren', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Mettre à jour', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Aggiornare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Actualizar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000045', 'reject', 'Reject');
  PERFORM EditActionText(uAction, 'Отклонить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Ablehnen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Rejeter', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Rifiutare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Rechazar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000046', 'pay', 'Pay');
  PERFORM EditActionText(uAction, 'Оплатить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Bezahlen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Payer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Pagare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Pagar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000047', 'continue', 'Continue');
  PERFORM EditActionText(uAction, 'Продолжить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Fortsetzen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Continuer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Continuare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Continuar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000048', 'agree', 'Agree');
  PERFORM EditActionText(uAction, 'Согласовать', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Zustimmen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Accepter', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Concordare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Acordar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000049', 'close', 'Close');
  PERFORM EditActionText(uAction, 'Закрыть', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Schließen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Fermer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Chiudere', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Cerrar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000050', 'activate', 'Activate');
  PERFORM EditActionText(uAction, 'Активировать', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Aktivieren', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Activer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Attivare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Activar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000051', 'refund', 'Refund');
  PERFORM EditActionText(uAction, 'Возврат денег', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Rückerstattung', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Remboursement', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Rimborso', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Reembolso', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000052', 'download', 'Download');
  PERFORM EditActionText(uAction, 'Загрузить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Herunterladen', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Télécharger', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Scaricare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Descargar', null, GetLocale('es'));

  uAction := AddAction('00000000-0000-4000-b003-000000000053', 'prepare', 'Preparation');
  PERFORM EditActionText(uAction, 'Подготовить', null, GetLocale('ru'));
  PERFORM EditActionText(uAction, 'Vorbereiten', null, GetLocale('de'));
  PERFORM EditActionText(uAction, 'Préparer', null, GetLocale('fr'));
  PERFORM EditActionText(uAction, 'Preparare', null, GetLocale('it'));
  PERFORM EditActionText(uAction, 'Preparar', null, GetLocale('es'));

  --

  uPriority := AddPriority('00000000-0000-4000-b004-000000000000', 'low', 'Low');
  PERFORM EditPriorityText(uPriority, 'Низкий', null, GetLocale('ru'));
  PERFORM EditPriorityText(uPriority, 'Niedrig', null, GetLocale('de'));
  PERFORM EditPriorityText(uPriority, 'Faible', null, GetLocale('fr'));
  PERFORM EditPriorityText(uPriority, 'Basso', null, GetLocale('it'));
  PERFORM EditPriorityText(uPriority, 'Bajo', null, GetLocale('es'));

  uPriority := AddPriority('00000000-0000-4000-b004-000000000001', 'medium', 'Medium');
  PERFORM EditPriorityText(uPriority, 'Средний', null, GetLocale('ru'));
  PERFORM EditPriorityText(uPriority, 'Mittel', null, GetLocale('de'));
  PERFORM EditPriorityText(uPriority, 'Moyen', null, GetLocale('fr'));
  PERFORM EditPriorityText(uPriority, 'Medio', null, GetLocale('it'));
  PERFORM EditPriorityText(uPriority, 'Medio', null, GetLocale('es'));

  uPriority := AddPriority('00000000-0000-4000-b004-000000000002', 'high', 'High');
  PERFORM EditPriorityText(uPriority, 'Высокий', null, GetLocale('ru'));
  PERFORM EditPriorityText(uPriority, 'Hoch', null, GetLocale('de'));
  PERFORM EditPriorityText(uPriority, 'Élevé', null, GetLocale('fr'));
  PERFORM EditPriorityText(uPriority, 'Alto', null, GetLocale('it'));
  PERFORM EditPriorityText(uPriority, 'Alto', null, GetLocale('es'));

  uPriority := AddPriority('00000000-0000-4000-b004-000000000003', 'critical', 'Critical');
  PERFORM EditPriorityText(uPriority, 'Критический', null, GetLocale('ru'));
  PERFORM EditPriorityText(uPriority, 'Kritisch', null, GetLocale('de'));
  PERFORM EditPriorityText(uPriority, 'Critique', null, GetLocale('fr'));
  PERFORM EditPriorityText(uPriority, 'Critico', null, GetLocale('it'));
  PERFORM EditPriorityText(uPriority, 'Crítico', null, GetLocale('es'));
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
