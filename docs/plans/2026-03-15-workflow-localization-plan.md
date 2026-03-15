# Workflow & Entity Localization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make all workflow and entity UI-facing strings multilingual (en, ru, de, fr, it, es) across 19 init.sql files.

**Architecture:** Switch base language from Russian to English in all `Add*()` calls. Add `Edit*Text()` calls for ru, de, fr, it, es. No DDL or routine changes — init.sql files only.

**Tech Stack:** PL/pgSQL, existing `Edit*Text()` functions, `GetLocale()` helper.

---

## Translation Reference Tables

These tables are used by ALL tasks below. Implementers must use exact translations from here.

### T1: State Types (4)

| code | en | ru | de | fr | it | es |
|------|----|----|----|----|----|----|
| created | Created | Создан | Erstellt | Créé | Creato | Creado |
| enabled | Enabled | Включен | Aktiviert | Activé | Attivato | Activado |
| disabled | Disabled | Отключен | Deaktiviert | Désactivé | Disattivato | Desactivado |
| deleted | Deleted | Удалён | Gelöscht | Supprimé | Eliminato | Eliminado |

### T2: Event Types (3)

| code | en | ru | de | fr | it | es |
|------|----|----|----|----|----|----|
| parent | Parent class events | События класса родителя | Ereignisse der Elternklasse | Événements de la classe parente | Eventi della classe genitore | Eventos de la clase padre |
| event | Event | Событие | Ereignis | Événement | Evento | Evento |
| plpgsql | PL/pgSQL code | PL/pgSQL код | PL/pgSQL-Code | Code PL/pgSQL | Codice PL/pgSQL | Código PL/pgSQL |

### T3: Actions (54)

| code | en | ru | de | fr | it | es |
|------|----|----|----|----|----|----|
| anything | Anything | Ничто | Beliebig | N'importe quoi | Qualsiasi | Cualquiera |
| abort | Abort | Прервать | Abbrechen | Abandonner | Interrompere | Abortar |
| accept | Accept | Принять | Akzeptieren | Accepter | Accettare | Aceptar |
| add | Add | Добавить | Hinzufügen | Ajouter | Aggiungere | Añadir |
| alarm | Alarm | Тревога | Alarm | Alarme | Allarme | Alarma |
| approve | Approve | Утвердить | Genehmigen | Approuver | Approvare | Aprobar |
| available | Available | Доступен | Verfügbar | Disponible | Disponibile | Disponible |
| cancel | Cancel | Отменить | Abbrechen | Annuler | Annullare | Cancelar |
| check | Check | Проверить | Prüfen | Vérifier | Verificare | Verificar |
| complete | Complete | Завершить | Abschließen | Terminer | Completare | Completar |
| confirm | Confirm | Подтвердить | Bestätigen | Confirmer | Confermare | Confirmar |
| create | Create | Создать | Erstellen | Créer | Creare | Crear |
| delete | Delete | Удалить | Löschen | Supprimer | Eliminare | Eliminar |
| disable | Disable | Отключить | Deaktivieren | Désactiver | Disattivare | Desactivar |
| done | Done | Сделано | Erledigt | Terminé | Fatto | Hecho |
| drop | Drop | Уничтожить | Vernichten | Détruire | Distruggere | Destruir |
| edit | Edit | Изменить | Bearbeiten | Modifier | Modificare | Editar |
| enable | Enable | Включить | Aktivieren | Activer | Attivare | Activar |
| execute | Execute | Выполнить | Ausführen | Exécuter | Eseguire | Ejecutar |
| expire | Expire | Истекло | Abgelaufen | Expiré | Scaduto | Expirado |
| fail | Fail | Неудача | Fehlgeschlagen | Échoué | Fallito | Fallido |
| faulted | Faulted | Ошибка | Fehlerhaft | Défaillant | Guasto | Averiado |
| finishing | Finishing | Завершение | Abschluss | Finalisation | Completamento | Finalización |
| heartbeat | Heartbeat | Сердцебиение | Herzschlag | Battement | Battito | Latido |
| invite | Invite | Пригласить | Einladen | Inviter | Invitare | Invitar |
| open | Open | Открыть | Öffnen | Ouvrir | Aprire | Abrir |
| plan | Plan | Планировать | Planen | Planifier | Pianificare | Planificar |
| post | Post | Публиковать | Veröffentlichen | Publier | Pubblicare | Publicar |
| postpone | Postpone | Отложить | Verschieben | Reporter | Rimandare | Posponer |
| preparing | Preparing | Подготовка | Vorbereitung | Préparation | Preparazione | Preparación |
| reconfirm | Reconfirm | Повторно подтвердить | Erneut bestätigen | Reconfirmer | Riconfermare | Reconfirmar |
| remove | Remove | Удалить | Entfernen | Retirer | Rimuovere | Quitar |
| repeat | Repeat | Повторить | Wiederholen | Répéter | Ripetere | Repetir |
| reserve | Reserve | Резервировать | Reservieren | Réserver | Riservare | Reservar |
| reserved | Reserved | Зарезервирован | Reserviert | Réservé | Riservato | Reservado |
| restore | Restore | Восстановить | Wiederherstellen | Restaurer | Ripristinare | Restaurar |
| return | Return | Вернуть | Zurückgeben | Retourner | Restituire | Devolver |
| save | Save | Сохранить | Speichern | Enregistrer | Salvare | Guardar |
| send | Send | Отправить | Senden | Envoyer | Inviare | Enviar |
| sign | Sign | Подписать | Unterschreiben | Signer | Firmare | Firmar |
| start | Start | Запустить | Starten | Démarrer | Avviare | Iniciar |
| stop | Stop | Остановить | Stoppen | Arrêter | Fermare | Detener |
| submit | Submit | Отправить | Einreichen | Soumettre | Inviare | Enviar |
| unavailable | Unavailable | Недоступен | Nicht verfügbar | Indisponible | Non disponibile | No disponible |
| update | Update | Обновить | Aktualisieren | Mettre à jour | Aggiornare | Actualizar |
| reject | Reject | Отклонить | Ablehnen | Rejeter | Rifiutare | Rechazar |
| pay | Pay | Оплатить | Bezahlen | Payer | Pagare | Pagar |
| continue | Continue | Продолжить | Fortsetzen | Continuer | Continuare | Continuar |
| agree | Agree | Согласовать | Zustimmen | Accepter | Concordare | Acordar |
| close | Close | Закрыть | Schließen | Fermer | Chiudere | Cerrar |
| activate | Activate | Активировать | Aktivieren | Activer | Attivare | Activar |
| refund | Refund | Возврат денег | Rückerstattung | Remboursement | Rimborso | Reembolso |
| download | Download | Загрузить | Herunterladen | Télécharger | Scaricare | Descargar |
| prepare | Preparation | Подготовить | Vorbereiten | Préparer | Preparare | Preparar |

### T4: Priorities (4)

| code | en | ru | de | fr | it | es |
|------|----|----|----|----|----|----|
| low | Low | Низкий | Niedrig | Faible | Basso | Bajo |
| medium | Medium | Средний | Mittel | Moyen | Medio | Medio |
| high | High | Высокий | Hoch | Élevé | Alto | Alto |
| critical | Critical | Критический | Kritisch | Critique | Critico | Crítico |

### T5: Default Methods (10)

| action | en | ru | de | fr | it | es |
|--------|----|----|----|----|----|----|
| create | Create | Создать | Erstellen | Créer | Creare | Crear |
| open | Open | Открыть | Öffnen | Ouvrir | Aprire | Abrir |
| edit | Edit | Изменить | Bearbeiten | Modifier | Modificare | Editar |
| save | Save | Сохранить | Speichern | Enregistrer | Salvare | Guardar |
| update | Update | Обновить | Aktualisieren | Mettre à jour | Aggiornare | Actualizar |
| enable | Enable | Включить | Aktivieren | Activer | Attivare | Activar |
| disable | Disable | Выключить | Deaktivieren | Désactiver | Disattivare | Desactivar |
| delete | Delete | Удалить | Löschen | Supprimer | Eliminare | Eliminar |
| restore | Restore | Восстановить | Wiederherstellen | Restaurer | Ripristinare | Restaurar |
| drop | Drop | Уничтожить | Vernichten | Détruire | Distruggere | Destruir |

### T6: Default States/Methods for AddDefaultMethods (9 array elements)

Default arrays used when no custom pNames is passed:

| # | en | ru | de | fr | it | es |
|---|----|----|----|----|----|----|
| 1 | Created | Создан | Erstellt | Créé | Creato | Creado |
| 2 | Opened | Открыт | Geöffnet | Ouvert | Aperto | Abierto |
| 3 | Closed | Закрыт | Geschlossen | Fermé | Chiuso | Cerrado |
| 4 | Deleted | Удалён | Gelöscht | Supprimé | Eliminato | Eliminado |
| 5 | Open | Открыть | Öffnen | Ouvrir | Aprire | Abrir |
| 6 | Close | Закрыть | Schließen | Fermer | Chiudere | Cerrar |
| 7 | Delete | Удалить | Löschen | Supprimer | Eliminare | Eliminar |
| 8 | Restore | Восстановить | Wiederherstellen | Restaurer | Ripristinare | Restaurar |
| 9 | Drop | Уничтожить | Vernichten | Détruire | Distruggere | Destruir |

### T7: Entity Names

| entity | en | ru | de | fr | it | es |
|--------|----|----|----|----|----|----|
| object | Object | Объект | Objekt | Objet | Oggetto | Objeto |
| reference | Reference | Справочник | Referenz | Référence | Riferimento | Referencia |
| document | Document | Документ | Dokument | Document | Documento | Documento |
| agent | Agent | Агент | Agent | Agent | Agente | Agente |
| form | Form | Форма | Formular | Formulaire | Modulo | Formulario |
| program | Program | Программа | Programm | Programme | Programma | Programa |
| scheduler | Scheduler | Планировщик | Planer | Planificateur | Pianificatore | Planificador |
| vendor | Vendor | Производитель | Anbieter | Fournisseur | Fornitore | Proveedor |
| version | Version | Версия | Version | Version | Versione | Versión |
| job | Job | Задание | Auftrag | Tâche | Attività | Tarea |
| message | Message | Сообщение | Nachricht | Message | Messaggio | Mensaje |
| inbox | Inbox | Входящее | Eingang | Boîte de réception | Posta in arrivo | Bandeja de entrada |
| outbox | Outbox | Исходящее | Ausgang | Boîte d'envoi | Posta in uscita | Bandeja de salida |
| report | Report | Отчёт | Bericht | Rapport | Report | Informe |
| report_tree | Report tree | Дерево отчётов | Berichtsbaum | Arbre de rapports | Albero dei report | Árbol de informes |
| report_form | Report form | Форма отчёта | Berichtsformular | Formulaire de rapport | Modulo di report | Formulario de informe |
| report_routine | Report routine | Функция отчёта | Berichtsfunktion | Fonction de rapport | Funzione di report | Función de informe |
| report_ready | Ready report | Готовый отчёт | Fertiger Bericht | Rapport prêt | Report pronto | Informe listo |

### T8: Type Names

| code | en_name | en_desc | ru_name | ru_desc | de_name | de_desc | fr_name | fr_desc | it_name | it_desc | es_name | es_desc |
|------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|
| system.agent | System messages | Agent for delivering system messages | Системные сообщения | Агент для доставки системных сообщений | Systemnachrichten | Agent für Systemnachrichten | Messages système | Agent de messages système | Messaggi di sistema | Agente per messaggi di sistema | Mensajes del sistema | Agente de mensajes del sistema |
| api.agent | API | Agent for API (REST/SOAP/RPC) requests to external systems | API | Агент для выполнения API (REST/SOAP/RPC) запросов к внешним системам | API | Agent für API-Anfragen an externe Systeme | API | Agent pour requêtes API vers systèmes externes | API | Agente per richieste API a sistemi esterni | API | Agente para solicitudes API a sistemas externos |
| email.agent | Email | Agent for processing email | Электронная почта | Агент для обработки электронной почты | E-Mail | Agent für E-Mail-Verarbeitung | E-mail | Agent de traitement des e-mails | E-mail | Agente per elaborazione e-mail | Correo electrónico | Agente de procesamiento de correo |
| stream.agent | Data stream | Agent for processing data streams | Потоковые данные | Агент для обработки потоковых данных | Datenstrom | Agent für Datenströme | Flux de données | Agent de flux de données | Flusso dati | Agente per flussi dati | Flujo de datos | Agente de flujos de datos |
| none.form | Untyped | Untyped | Без типа | Без типа | Ohne Typ | Ohne Typ | Sans type | Sans type | Senza tipo | Senza tipo | Sin tipo | Sin tipo |
| journal.form | Journal | Journal form | Журнал | Форма журнала | Journal | Journalformular | Journal | Formulaire de journal | Registro | Modulo registro | Diario | Formulario de diario |
| tracker.form | Daily report | Daily report form | Суточный отчёт | Форма суточного отчёта | Tagesbericht | Tagesberichtsformular | Rapport journalier | Formulaire de rapport journalier | Report giornaliero | Modulo report giornaliero | Informe diario | Formulario de informe diario |
| plpgsql.program | PL/pgSQL | PL/pgSQL program code | PL/pgSQL | Код программы на PL/pgSQL | PL/pgSQL | PL/pgSQL-Programmcode | PL/pgSQL | Code de programme PL/pgSQL | PL/pgSQL | Codice programma PL/pgSQL | PL/pgSQL | Código de programa PL/pgSQL |
| job.scheduler | Scheduler | Job scheduler | Планировщик | Планировщик задач | Planer | Aufgabenplaner | Planificateur | Planificateur de tâches | Pianificatore | Pianificatore attività | Planificador | Planificador de tareas |
| service.vendor | Service | Service provider | Услуга | Поставщик услуги | Dienstleistung | Dienstanbieter | Service | Fournisseur de services | Servizio | Fornitore di servizi | Servicio | Proveedor de servicios |
| device.vendor | Hardware | Hardware manufacturer | Оборудование | Производитель оборудования | Hardware | Hardwarehersteller | Matériel | Fabricant de matériel | Hardware | Produttore hardware | Hardware | Fabricante de hardware |
| car.vendor | Automobile | Automobile manufacturer | Автомобиль | Производитель автомобилей | Automobil | Automobilhersteller | Automobile | Constructeur automobile | Automobile | Costruttore automobili | Automóvil | Fabricante de automóviles |
| api.version | API | API version | API | Версия API | API | API-Version | API | Version API | API | Versione API | API | Versión API |
| periodic.job | Periodic | Periodic job | Периодическое | Периодическое задание | Periodisch | Periodischer Auftrag | Périodique | Tâche périodique | Periodico | Attività periodica | Periódico | Tarea periódica |
| disposable.job | One-time | One-time job | Разовое | Разовое задание | Einmalig | Einmaliger Auftrag | Ponctuel | Tâche ponctuelle | Una tantum | Attività una tantum | Puntual | Tarea puntual |
| message.inbox | Inbox | Incoming message | Входящие | Входящие сообщение | Eingang | Eingehende Nachricht | Réception | Message entrant | In arrivo | Messaggio in arrivo | Entrada | Mensaje entrante |
| message.outbox | Outbox | Outgoing message | Исходящие | Исходящие сообщение | Ausgang | Ausgehende Nachricht | Envoi | Message sortant | In uscita | Messaggio in uscita | Salida | Mensaje saliente |
| object.report | Object | Reports for objects | Объект | Отчеты для объектов | Objekt | Berichte für Objekte | Objet | Rapports pour objets | Oggetto | Report per oggetti | Objeto | Informes para objetos |
| report.report | Report | Standard reports | Отчёт | Обычные отчёты | Bericht | Standardberichte | Rapport | Rapports standards | Report | Report standard | Informe | Informes estándar |
| import.report | Import | Data import reports | Загрузка | Отчёты загрузки данных | Import | Datenimportberichte | Import | Rapports d'import | Importazione | Report di importazione | Importación | Informes de importación |
| export.report | Export | Data export reports | Выгрузка | Отчёты выгрузки данных | Export | Datenexportberichte | Export | Rapports d'export | Esportazione | Report di esportazione | Exportación | Informes de exportación |
| root.report_tree | Section | The root of the report tree | Корень | Корень дерева отчётов | Abschnitt | Wurzel des Berichtsbaums | Section | Racine de l'arbre de rapports | Sezione | Radice dell'albero dei report | Sección | Raíz del árbol de informes |
| node.report_tree | Node | Report tree node | Узел | Узел дерева отчётов | Knoten | Berichtsbaumknoten | Nœud | Nœud de l'arbre de rapports | Nodo | Nodo dell'albero dei report | Nodo | Nodo del árbol de informes |
| report.report_tree | Report | Report | Отчёт | Отчёт | Bericht | Bericht | Rapport | Rapport | Report | Report | Informe | Informe |
| json.report_form | JSON | Report form in JSON format | JSON | Форма отчёта в формате JSON | JSON | Berichtsformular im JSON-Format | JSON | Formulaire de rapport au format JSON | JSON | Modulo di report in formato JSON | JSON | Formulario de informe en formato JSON |
| plpgsql.report_routine | PL/pgSQL | Report routine in PL/pgSQL | PL/pgSQL | Функция отчёта на PL/pgSQL | PL/pgSQL | Berichtsfunktion in PL/pgSQL | PL/pgSQL | Fonction de rapport en PL/pgSQL | PL/pgSQL | Funzione di report in PL/pgSQL | PL/pgSQL | Función de informe en PL/pgSQL |
| sync.report_ready | Synchronous | Synchronous report | Синхронный | Синхронный отчёт | Synchron | Synchroner Bericht | Synchrone | Rapport synchrone | Sincrono | Report sincrono | Síncrono | Informe síncrono |
| async.report_ready | Asynchronous | Asynchronous report | Асинхронный | Асинхронный отчёт | Asynchron | Asynchroner Bericht | Asynchrone | Rapport asynchrone | Asincrono | Report asincrono | Asíncrono | Informe asíncrono |

### T9: Common Event Labels

This is the standard pattern for `AddEvent()`. The 4th parameter is the label. The base language switches to English.

| ru | en |
|----|----|
| События класса родителя | Parent class events |
| Смена состояния | State change |

Per-entity event labels follow the pattern: `{Entity_en} {action_past_participle}`. Example: "Agent created", "Agent opened", etc. The exact labels per entity are listed in each task.

---

## Tasks

### Task 1: workflow/init.sql — InitWorkFlow() state types, event types

**Files:**
- Modify: `workflow/init.sql:359-387`

**Step 1:** In `InitWorkFlow()`, add 4 more locale INSERT statements for each state_type (de, fr, it, es). Use translations from **T1**.

Current pattern (2 locales):
```sql
INSERT INTO db.state_type_text (type, name, locale) VALUES ('...001', 'Created', GetLocale('en'));
INSERT INTO db.state_type_text (type, name, locale) VALUES ('...001', 'Создан', GetLocale('ru'));
```

New pattern (6 locales):
```sql
INSERT INTO db.state_type_text (type, name, locale) VALUES ('...001', 'Created', GetLocale('en'));
INSERT INTO db.state_type_text (type, name, locale) VALUES ('...001', 'Создан', GetLocale('ru'));
INSERT INTO db.state_type_text (type, name, locale) VALUES ('...001', 'Erstellt', GetLocale('de'));
INSERT INTO db.state_type_text (type, name, locale) VALUES ('...001', 'Créé', GetLocale('fr'));
INSERT INTO db.state_type_text (type, name, locale) VALUES ('...001', 'Creato', GetLocale('it'));
INSERT INTO db.state_type_text (type, name, locale) VALUES ('...001', 'Creado', GetLocale('es'));
```

Do the same for all 4 state types and all 3 event types. Use **T1** and **T2** for translations.

**Step 2:** Commit.

```bash
git add workflow/init.sql
git commit -m "feat(i18n): add de/fr/it/es translations for state types and event types"
```

### Task 2: workflow/init.sql — InitWorkFlow() actions and priorities

**Files:**
- Modify: `workflow/init.sql:391-568`

**Step 1:** In the actions section, switch the base language to English and add 5 Edit*Text calls per action.

Current pattern:
```sql
uAction := AddAction('...', 'abort', 'Прервать');
PERFORM EditActionText(uAction, 'Abort', null, uLocale);
```

New pattern (remove the `uLocale := GetLocale('en')` variable, use inline GetLocale calls):
```sql
uAction := AddAction('...', 'abort', 'Abort');
PERFORM EditActionText(uAction, 'Прервать', null, GetLocale('ru'));
PERFORM EditActionText(uAction, 'Abbrechen', null, GetLocale('de'));
PERFORM EditActionText(uAction, 'Abandonner', null, GetLocale('fr'));
PERFORM EditActionText(uAction, 'Interrompere', null, GetLocale('it'));
PERFORM EditActionText(uAction, 'Abortar', null, GetLocale('es'));
```

Apply this pattern to all 54 actions using translations from **T3**.

**Step 2:** Apply the same pattern to all 4 priorities using **T4**.

**Step 3:** Commit.

```bash
git add workflow/init.sql
git commit -m "feat(i18n): localize 54 actions and 4 priorities to 6 languages"
```

### Task 3: workflow/init.sql — DefaultMethods() function

**Files:**
- Modify: `workflow/init.sql:9-52`

**Step 1:** Switch `DefaultMethods()` to use English as base and add 5 locale calls per method.

Current pattern:
```sql
uLocale := GetLocale('en');
uMethod := AddMethod(null, pClass, null, GetAction('create'), null, 'Создать');
PERFORM EditMethodText(uMethod, 'Create', uLocale);
```

New pattern:
```sql
uMethod := AddMethod(null, pClass, null, GetAction('create'), null, 'Create');
PERFORM EditMethodText(uMethod, 'Создать', GetLocale('ru'));
PERFORM EditMethodText(uMethod, 'Erstellen', GetLocale('de'));
PERFORM EditMethodText(uMethod, 'Créer', GetLocale('fr'));
PERFORM EditMethodText(uMethod, 'Creare', GetLocale('it'));
PERFORM EditMethodText(uMethod, 'Crear', GetLocale('es'));
```

Apply to all 10 methods using **T5**. Remove the `uLocale` variable declaration and assignment.

**Step 2:** Commit.

```bash
git add workflow/init.sql
git commit -m "feat(i18n): localize DefaultMethods() to 6 languages"
```

### Task 4: workflow/init.sql — AddDefaultMethods() and UpdateDefaultMethods()

**Files:**
- Modify: `workflow/init.sql:99-345`

**Step 1:** In `AddDefaultMethods()`, swap the parameter defaults so English is primary:

Change function signature:
```sql
CREATE OR REPLACE FUNCTION AddDefaultMethods (
  pClass        uuid,
  pNamesEN      text[] DEFAULT null,
  pNamesRU      text[] DEFAULT null
)
```

Swap the default arrays: `pNamesEN` gets the English defaults, `pNamesRU` gets the Russian defaults.

Change the body to use `pNamesEN` as primary (in AddState/AddMethod) and `pNamesRU` via EditStateText/EditMethodText for Russian locale:
```sql
uState := AddState(pClass, rec_type.id, rec_type.code, pNamesEN[1]);
PERFORM EditStateText(uState, pNamesRU[1], GetLocale('ru'));
PERFORM EditStateText(uState, pNamesDE[1], GetLocale('de'));
...
```

Actually — since AddDefaultMethods is called from MANY entity init.sql files with custom arrays, and adding 4 more language arrays to the signature would break callers, instead:

**Better approach:** Keep the `pNamesRU` and `pNamesEN` parameters as-is for backward compatibility. Switch so that `pNamesEN` is used in AddState/AddMethod (base), `pNamesRU` via EditStateText for ru locale. Then add calls to `UpdateDefaultMethods()` for de, fr, it, es inside the function body.

Wait — `AddDefaultMethods()` callers pass custom Russian arrays (e.g., `ARRAY['Создана', 'Открыта', ...]`). We need to also accept English arrays at all call sites.

**Cleanest approach:** Rename params to clarify, switch base to English. Update ALL callers (entity init.sql files) to pass English arrays as first positional arg:

```sql
CREATE OR REPLACE FUNCTION AddDefaultMethods (
  pClass        uuid,
  pNamesEN      text[] DEFAULT null,
  pNamesRU      text[] DEFAULT null
)
```

Default values:
- `pNamesEN`: `ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete']`
- `pNamesRU`: `ARRAY['Создан', 'Открыт', 'Закрыт', 'Удалён', 'Открыть', 'Закрыть', 'Удалить']`

Body uses pNamesEN as base, EditStateText/EditMethodText with pNamesRU for ru locale.

Add 4 more locale calls using **T6** translations (hardcoded de/fr/it/es arrays inside the function).

**Step 2:** Update `UpdateDefaultMethods()` to support de, fr, it, es defaults:

Add ELSIF branches for each locale with translated arrays from **T6**.

**Step 3:** Commit.

```bash
git add workflow/init.sql
git commit -m "feat(i18n): localize AddDefaultMethods and UpdateDefaultMethods to 6 languages"
```

### Task 5: entity/object/init.sql — Object entity, class, events

**Files:**
- Modify: `entity/object/init.sql`

**Step 1:** In `CreateEntityObject()`, switch AddEntity to English:

```sql
uEntity := AddEntity('object', 'Object');
PERFORM EditEntityText(GetEntity('object'), 'Объект', null, GetLocale('ru'));
PERFORM EditEntityText(GetEntity('object'), 'Objekt', null, GetLocale('de'));
PERFORM EditEntityText(GetEntity('object'), 'Objet', null, GetLocale('fr'));
PERFORM EditEntityText(GetEntity('object'), 'Oggetto', null, GetLocale('it'));
PERFORM EditEntityText(GetEntity('object'), 'Objeto', null, GetLocale('es'));
```

**Step 2:** In `CreateClassObject()`, switch AddClass to English:

```sql
uClass := AddClass(pParent, pEntity, 'object', 'Object', true);
PERFORM EditClassText(uClass, 'Объект', GetLocale('ru'));
PERFORM EditClassText(uClass, 'Objekt', GetLocale('de'));
PERFORM EditClassText(uClass, 'Objet', GetLocale('fr'));
PERFORM EditClassText(uClass, 'Oggetto', GetLocale('it'));
PERFORM EditClassText(uClass, 'Objeto', GetLocale('es'));
```

**Step 3:** In `AddObjectEvents()`, switch all AddEvent labels to English:

```sql
-- 'Создать' → 'Create'
-- 'Смена состояния' → 'State change'
-- 'Открыть' → 'Open'
-- 'Изменить' → 'Edit'
-- 'Сохранить' → 'Save'
-- 'Включить' → 'Enable'
-- 'Выключить' → 'Disable'
-- 'Удалить' → 'Delete'
-- 'Восстановить' → 'Restore'
-- 'Уничтожить' → 'Drop'
```

Note: Event labels in `AddEvent()` are replicated to ALL locales by `AddEvent()` internally. Unlike other functions where we can call `Edit*Text` after, there is no `EditEventText` called here since events are internal handlers. The event label is descriptive metadata, not end-user-facing UI. Switch to English only.

**Step 4:** Commit.

```bash
git add entity/object/init.sql
git commit -m "feat(i18n): localize object entity, class, and events to English base"
```

### Task 6: entity/object/reference/init.sql + entity/object/document/init.sql

**Files:**
- Modify: `entity/object/reference/init.sql`
- Modify: `entity/object/document/init.sql`

Apply the same pattern as Task 5:
- `AddEntity('reference', 'Reference')` + EditEntityText for ru/de/fr/it/es (use **T7**)
- `AddClass(... 'reference', 'Reference', true)` + EditClassText for 5 locales
- Switch all AddEvent labels in `AddReferenceEvents()` and `AddDocumentEvents()` to English

Event label translations (reference):
- 'События класса родителя' → 'Parent class events'
- 'Справочник создан' → 'Reference created'
- 'Справочник открыт' → 'Reference opened'
- 'Справочник изменён' → 'Reference edited'
- 'Справочник сохранён' → 'Reference saved'
- 'Справочник доступен' → 'Reference enabled'
- 'Справочник недоступен' → 'Reference disabled'
- 'Справочник будет удалён' → 'Reference will be deleted'
- 'Справочник восстановлен' → 'Reference restored'
- 'Справочник будет уничтожен' → 'Reference will be dropped'

Event label translations (document):
- 'Документ создан' → 'Document created'
- 'Документ открыт' → 'Document opened'
- 'Документ изменён' → 'Document edited'
- 'Документ сохранён' → 'Document saved'
- 'Документ включен' → 'Document enabled'
- 'Документ отключен' → 'Document disabled'
- 'Документ будет удалён' → 'Document will be deleted'
- 'Документ восстановлен' → 'Document restored'
- 'Документ будет уничтожен' → 'Document will be dropped'

Commit:
```bash
git add entity/object/reference/init.sql entity/object/document/init.sql
git commit -m "feat(i18n): localize reference and document entities to 6 languages"
```

### Task 7: entity/object/reference — agent, vendor, scheduler, version

**Files:**
- Modify: `entity/object/reference/agent/init.sql`
- Modify: `entity/object/reference/vendor/init.sql`
- Modify: `entity/object/reference/scheduler/init.sql`
- Modify: `entity/object/reference/version/init.sql`

For each file, apply:
1. Switch `AddEntity()` to English + add EditEntityText for 5 locales (use **T7**)
2. Switch `AddClass()` to English + add EditClassText for 5 locales (use **T7**)
3. Switch `AddType()` to English + add EditTypeText for 5 locales (use **T8**)
4. Switch all `AddEvent()` labels to English

Event label pattern for each entity (replace {Entity} with Agent/Vendor/Scheduler/Version):
- '{Сущность} создан(а)' → '{Entity} created'
- '{Сущность} открыт(а)' → '{Entity} opened'
- '{Сущность} изменён(а)' → '{Entity} edited'
- '{Сущность} сохранён(а)' → '{Entity} saved'
- '{Сущность} доступен(а)' → '{Entity} enabled'
- '{Сущность} недоступен(а)' → '{Entity} disabled'
- '{Сущность} будет удалён(а)' → '{Entity} will be deleted'
- '{Сущность} восстановлен(а)' → '{Entity} restored'
- '{Сущность} будет уничтожен(а)' → '{Entity} will be dropped'

Commit:
```bash
git add entity/object/reference/agent/init.sql entity/object/reference/vendor/init.sql entity/object/reference/scheduler/init.sql entity/object/reference/version/init.sql
git commit -m "feat(i18n): localize agent, vendor, scheduler, version entities to 6 languages"
```

### Task 8: entity/object/reference — form, program

**Files:**
- Modify: `entity/object/reference/form/init.sql`
- Modify: `entity/object/reference/program/init.sql`

Same pattern as Task 7. Additionally, these files call `AddDefaultMethods()` with custom Russian arrays:

```sql
PERFORM AddDefaultMethods(uClass, ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалена', 'Открыть', 'Закрыть', 'Удалить']);
```

After Task 4 changes the signature to `(pClass, pNamesEN, pNamesRU)`, update these calls:

```sql
PERFORM AddDefaultMethods(uClass,
  ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete'],
  ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалена', 'Открыть', 'Закрыть', 'Удалить']);
```

Commit:
```bash
git add entity/object/reference/form/init.sql entity/object/reference/program/init.sql
git commit -m "feat(i18n): localize form and program entities to 6 languages"
```

### Task 9: entity/object/document/job/init.sql

**Files:**
- Modify: `entity/object/document/job/init.sql`

This is the most complex entity file. It has:
- `AddJobMethods()` — custom state machine with 9 states
- `AddJobEvents()` — 15 event handlers
- `CreateClassJob()` — class + 2 types
- `CreateEntityJob()` — entity

**Step 1:** In `AddJobMethods()`, switch all `AddState()` labels to English and add EditStateText for 5 locales:

| code | en | ru | de | fr | it | es |
|------|----|----|----|----|----|----|
| created | Created | Создано | Erstellt | Créé | Creato | Creado |
| enabled | Enabled | Включено | Aktiviert | Activé | Attivato | Activado |
| executed | Executing | Выполняется | Wird ausgeführt | En cours | In esecuzione | En ejecución |
| canceled | Canceling | Отменяется | Wird abgebrochen | En annulation | In annullamento | Cancelando |
| aborted | Aborted | Прервано | Abgebrochen | Abandonné | Interrotto | Abortado |
| failed | Failed | Ошибка | Fehlgeschlagen | Échoué | Fallito | Fallido |
| disabled | Disabled | Отключено | Deaktiviert | Désactivé | Disattivato | Desactivado |
| completed | Completed | Завершено | Abgeschlossen | Terminé | Completato | Completado |
| deleted | Deleted | Удалено | Gelöscht | Supprimé | Eliminato | Eliminado |

**Step 2:** Switch all event labels in `AddJobEvents()` to English.

**Step 3:** Switch AddEntity, AddClass, AddType to English + EditText for 5 locales (use **T7**, **T8**).

Commit:
```bash
git add entity/object/document/job/init.sql
git commit -m "feat(i18n): localize job entity with custom state machine to 6 languages"
```

### Task 10: entity/object/document/message — message, inbox, outbox

**Files:**
- Modify: `entity/object/document/message/init.sql`
- Modify: `entity/object/document/message/inbox/init.sql`
- Modify: `entity/object/document/message/outbox/init.sql`

**Inbox states:**

| code | en | ru | de | fr | it | es |
|------|----|----|----|----|----|----|
| created | New | Новое | Neu | Nouveau | Nuovo | Nuevo |
| enabled | Opened | Открыто | Geöffnet | Ouvert | Aperto | Abierto |
| disabled | Read | Прочитано | Gelesen | Lu | Letto | Leído |
| deleted | Deleted | Удалено | Gelöscht | Supprimé | Eliminato | Eliminado |

Inbox custom methods: 'Открыть'→'Open', 'Прочитать'→'Read', 'Удалить'→'Delete', 'Восстановить'→'Restore', 'Уничтожить'→'Drop'

**Outbox states:**

| code | en | ru | de | fr | it | es |
|------|----|----|----|----|----|----|
| created | Created | Создано | Erstellt | Créé | Creato | Creado |
| prepared | Prepared | Подготовлено | Vorbereitet | Préparé | Preparato | Preparado |
| sending | Sending | Отправка | Wird gesendet | En cours d'envoi | In invio | Enviando |
| submitted | Sent | Отправлено | Gesendet | Envoyé | Inviato | Enviado |
| failed | Failed | Ошибка | Fehlgeschlagen | Échoué | Fallito | Fallido |
| deleted | Deleted | Удалено | Gelöscht | Supprimé | Eliminato | Eliminado |

Switch all event labels, entity/class/type names to English with EditText for 5 locales.

Note: `AddInboxMethods()` and `AddOutboxMethods()` use `SetState()` instead of `AddState()` — the pattern is the same, just replace Russian labels with English and add EditStateText.

Commit:
```bash
git add entity/object/document/message/init.sql entity/object/document/message/inbox/init.sql entity/object/document/message/outbox/init.sql
git commit -m "feat(i18n): localize message, inbox, outbox entities to 6 languages"
```

### Task 11: report — report, tree, form, routine, ready

**Files:**
- Modify: `report/init.sql`
- Modify: `report/tree/init.sql`
- Modify: `report/form/init.sql`
- Modify: `report/routine/init.sql`
- Modify: `report/ready/init.sql`

Apply the same pattern. Switch all Russian text to English base + EditText for 5 locales. Use **T7**, **T8** for translations.

**report/tree/init.sql** already has EditClassText/EditTypeText for English — restructure to make English the base.

**report/ready/init.sql** has a custom state machine similar to job:

| code | en | ru | de | fr | it | es |
|------|----|----|----|----|----|----|
| created | Created | Создан | Erstellt | Créé | Creato | Creado |
| progress | In progress | Выполняется | In Bearbeitung | En cours | In corso | En progreso |
| canceled | Canceling | Отменяется | Wird abgebrochen | En annulation | In annullamento | Cancelando |
| completed | Completed | Завершён | Abgeschlossen | Terminé | Completato | Completado |
| aborted | Aborted | Прерван | Abgebrochen | Abandonné | Interrotto | Abortado |
| failed | Failed | Ошибка | Fehlgeschlagen | Échoué | Fallito | Fallido |
| deleted | Deleted | Удалён | Gelöscht | Supprimé | Eliminato | Eliminado |

**report/form/init.sql** and **report/routine/init.sql** call AddDefaultMethods with custom Russian arrays — update like Task 8.

Commit:
```bash
git add report/init.sql report/tree/init.sql report/form/init.sql report/routine/init.sql report/ready/init.sql
git commit -m "feat(i18n): localize report entities to 6 languages"
```

### Task 12: VERSION bump, CLAUDE.md, migration doc, INDEX updates

**Files:**
- Modify: `VERSION` (1.2.0 → 1.2.1)
- Modify: `CLAUDE.md` (version reference)
- Create: `docs/migration-1.2.1.md`
- Modify: `workflow/INDEX.md` (update Init / Seed Data section to mention 6 locales)

**Step 1:** Bump VERSION to 1.2.1.

**Step 2:** Create `docs/migration-1.2.1.md` — an AI agent instruction guide for localizing the configuration layer. The document must be self-contained: an AI agent reading ONLY this file should be able to localize any downstream project's init.sql files to 6 locales.

```markdown
# Migration Guide: v1.2.0 → v1.2.1 — Configuration Layer Localization

> **Audience:** AI agents tasked with localizing `configuration/<dbname>/` init.sql files.
> This document teaches you how to apply the same 6-locale pattern (en, ru, de, fr, it, es)
> that platform v1.2.1 uses internally.

## What Changed in Platform v1.2.1

English is now the **base language** for all `Add*()` calls in platform init.sql files.
Previously Russian text was replicated to all locales by `Add*()` internals; now English
is the universal fallback. Russian and 4 other locales are set via `Edit*Text()` calls.

**No schema changes.** No table, view, or function signature changes. Only init.sql
seed data is affected. Safe to apply with `--install`.

### Breaking Change: AddDefaultMethods() Signature

```sql
-- OLD (v1.2.0): first positional array = Russian
PERFORM AddDefaultMethods(uClass, ARRAY['Создан', ...], ARRAY['Created', ...]);

-- NEW (v1.2.1): first positional array = English, second = Russian
PERFORM AddDefaultMethods(uClass, ARRAY['Created', ...], ARRAY['Создан', ...]);
```

If you pass only one array, it is now treated as **English** (was Russian).

---

## Configuration Layer: Current State

A typical configuration project (e.g., ChargeMeCar) uses these patterns:

1. **`AddEntity(code, 'Russian name')`** — Russian in all Add*() calls
2. **`AddClass(parent, entity, code, 'Russian name', bool)`** — Russian
3. **`AddType(class, code, 'Russian name', 'Russian description')`** — Russian,
   with optional `EditTypeText(uType, 'English', 'Desc', GetLocale('en'))` inline
4. **`AddState(class, type, code, 'Russian label')`** — Russian only
5. **`AddMethod(null, class, state, action, null, 'Russian label')`** — Russian only
6. **`AddEvent(class, type, action, 'Russian description')`** — Russian only
7. **`AddDefaultMethods(uClass, ARRAY[ru...], ARRAY[en...])`** — Russian + English
8. **Bulk UPDATE in FillDataBase()** — patches `db.*_text` tables with English via
   hardcoded locale UUID `'00000000-0000-4001-a000-000000000001'`

---

## Step-by-Step: How to Localize a Configuration Project

### Phase 1: Audit

1. Find all init.sql files: `find configuration/<dbname>/ -name init.sql`
2. For each file, identify:
   - `AddEntity()` calls → need EditEntityText for 5 locales
   - `AddClass()` calls → need EditClassText for 5 locales
   - `AddType()` calls → need EditTypeText for 5 locales
   - `AddState()` calls → need EditStateText for 5 locales
   - `AddMethod()` calls → need EditMethodText for 5 locales (only custom methods; AddDefaultMethods handles its own)
   - `AddEvent()` calls → switch label to English (events are internal metadata, no per-locale Edit needed)
   - `AddDefaultMethods()` calls → swap parameter order (English first)
3. Check main init.sql for bulk UPDATE translation patches → replace with Edit*Text pattern

### Phase 2: Transform Each Entity init.sql

#### Pattern A: AddEntity + EditEntityText

**Before:**
```sql
uEntity := AddEntity('account', 'Счёт');
```

**After:**
```sql
uEntity := AddEntity('account', 'Account');
PERFORM EditEntityText(uEntity, 'Счёт', null, GetLocale('ru'));
PERFORM EditEntityText(uEntity, 'Konto', null, GetLocale('de'));
PERFORM EditEntityText(uEntity, 'Compte', null, GetLocale('fr'));
PERFORM EditEntityText(uEntity, 'Conto', null, GetLocale('it'));
PERFORM EditEntityText(uEntity, 'Cuenta', null, GetLocale('es'));
```

#### Pattern B: AddClass + EditClassText

**Before:**
```sql
uClass := AddClass(pParent, pEntity, 'account', 'Лицевой счёт', false);
```

**After:**
```sql
uClass := AddClass(pParent, pEntity, 'account', 'Account', false);
PERFORM EditClassText(uClass, 'Лицевой счёт', GetLocale('ru'));
PERFORM EditClassText(uClass, 'Konto', GetLocale('de'));
PERFORM EditClassText(uClass, 'Compte', GetLocale('fr'));
PERFORM EditClassText(uClass, 'Conto', GetLocale('it'));
PERFORM EditClassText(uClass, 'Cuenta', GetLocale('es'));
```

#### Pattern C: AddType + EditTypeText

**Before:**
```sql
uType := AddType(uClass, 'active.account', 'Активный', 'Активный счёт.');
PERFORM EditTypeText(uType, 'Active', 'Active account.', GetLocale('en'));
```

**After:**
```sql
uType := AddType(uClass, 'active.account', 'Active', 'Active account.');
PERFORM EditTypeText(uType, 'Активный', 'Активный счёт.', GetLocale('ru'));
PERFORM EditTypeText(uType, 'Aktiv', 'Aktives Konto.', GetLocale('de'));
PERFORM EditTypeText(uType, 'Actif', 'Compte actif.', GetLocale('fr'));
PERFORM EditTypeText(uType, 'Attivo', 'Conto attivo.', GetLocale('it'));
PERFORM EditTypeText(uType, 'Activo', 'Cuenta activa.', GetLocale('es'));
```

#### Pattern D: AddState + EditStateText (custom state machines)

**Before:**
```sql
nState := AddState(pClass, rec_type.id, rec_type.code, 'Создана');
```

**After:**
```sql
nState := AddState(pClass, rec_type.id, rec_type.code, 'Created');
PERFORM EditStateText(nState, 'Создана', GetLocale('ru'));
PERFORM EditStateText(nState, 'Erstellt', GetLocale('de'));
PERFORM EditStateText(nState, 'Créée', GetLocale('fr'));
PERFORM EditStateText(nState, 'Creata', GetLocale('it'));
PERFORM EditStateText(nState, 'Creada', GetLocale('es'));
```

#### Pattern E: AddMethod + EditMethodText (custom methods only)

**Before:**
```sql
PERFORM AddMethod(null, pClass, nState, GetAction('enable'), null, 'Включить');
```

**After:**
```sql
uMethod := AddMethod(null, pClass, nState, GetAction('enable'), null, 'Enable');
PERFORM EditMethodText(uMethod, 'Включить', GetLocale('ru'));
PERFORM EditMethodText(uMethod, 'Aktivieren', GetLocale('de'));
PERFORM EditMethodText(uMethod, 'Activer', GetLocale('fr'));
PERFORM EditMethodText(uMethod, 'Attivare', GetLocale('it'));
PERFORM EditMethodText(uMethod, 'Activar', GetLocale('es'));
```

Note: if the original code uses `PERFORM AddMethod(...)` (discards return value),
change to `uMethod := AddMethod(...)` to capture the UUID for Edit*Text calls.
Declare `uMethod uuid;` in the DECLARE block if not already present.

#### Pattern F: AddEvent — English label only

**Before:**
```sql
PERFORM AddEvent(pClass, uEvent, r.id, 'Счёт создан', 'EventAccountCreate();');
```

**After:**
```sql
PERFORM AddEvent(pClass, uEvent, r.id, 'Account created', 'EventAccountCreate();');
```

Events are internal metadata (handler labels), not end-user UI. Switch to English only.

#### Pattern G: AddDefaultMethods — swap parameter order

**Before (v1.2.0):**
```sql
PERFORM AddDefaultMethods(uClass,
  ARRAY['Создан', 'Открыт', 'Закрыт', 'Удалён', 'Открыть', 'Закрыть', 'Удалить'],
  ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete']);
```

**After (v1.2.1):**
```sql
PERFORM AddDefaultMethods(uClass,
  ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete'],
  ARRAY['Создан', 'Открыт', 'Закрыт', 'Удалён', 'Открыть', 'Закрыть', 'Удалить']);
```

If no custom arrays were passed (just `AddDefaultMethods(uClass)`), no change needed —
the function's defaults are already swapped in v1.2.1.

### Phase 3: Remove Bulk UPDATE Patches

If the main `init.sql` (or `FillDataBase()`) contains bulk UPDATE statements like:

```sql
UPDATE db.entity_text SET name = 'Object' WHERE name = 'Объект'
  AND locale = '00000000-0000-4001-a000-000000000001'::uuid;
```

**Remove them.** These patches are no longer needed because:
- Platform entities now have English as base (v1.2.1)
- Configuration entities should use Edit*Text() inline (Phase 2)

Only keep UPDATEs for business data (e.g., reference names like vendor names,
service names) that are NOT part of the entity/workflow definition.

### Phase 4: Add Missing Locales (de, fr, it, es)

After Phase 2 handles ru (which was previously the base), add the remaining 4 locales.
Use the same Edit*Text pattern for de, fr, it, es.

For AddDefaultMethods entities where you only changed the parameter order (Pattern G),
the platform's `UpdateDefaultMethods()` already handles de/fr/it/es internally.
No additional calls needed for default states/methods.

For custom state machines (Pattern D, E), you must add EditStateText and EditMethodText
for all 5 non-English locales.

---

## Edit*Text Function Reference

| Function | Signature | For |
|----------|-----------|-----|
| `EditEntityText` | `(id, name, description, locale)` | Entity names |
| `EditClassText` | `(id, label, locale)` | Class labels |
| `EditTypeText` | `(id, name, description, locale)` | Type names + descriptions |
| `EditStateText` | `(id, label, locale)` | State labels |
| `EditMethodText` | `(id, label, locale)` | Method labels |
| `EditActionText` | `(id, name, description, locale)` | Action names (platform only) |
| `EditEventTypeText` | `(id, name, description, locale)` | Event type names (platform only) |
| `EditPriorityText` | `(id, name, description, locale)` | Priority names (platform only) |

Locale helper: `GetLocale('en')`, `GetLocale('ru')`, `GetLocale('de')`,
`GetLocale('fr')`, `GetLocale('it')`, `GetLocale('es')`.

---

## Checklist for AI Agent

- [ ] All `AddEntity()` calls use English as primary, with 5 `EditEntityText()` calls
- [ ] All `AddClass()` calls use English as primary, with 5 `EditClassText()` calls
- [ ] All `AddType()` calls use English as primary, with 5 `EditTypeText()` calls
- [ ] All `AddState()` calls use English as primary, with 5 `EditStateText()` calls
- [ ] Custom `AddMethod()` calls use English as primary, with 5 `EditMethodText()` calls
- [ ] All `AddEvent()` labels switched to English
- [ ] `AddDefaultMethods()` calls have swapped parameter order (English first, Russian second)
- [ ] Bulk UPDATE translation patches in FillDataBase() removed or replaced
- [ ] `PERFORM AddMethod(...)` changed to `uMethod := AddMethod(...)` where Edit*Text needed
- [ ] All `uMethod uuid` variables declared in DECLARE blocks
- [ ] No hardcoded locale UUIDs — use `GetLocale('xx')` everywhere
- [ ] Tested with `--install` (full reinstall with seed data)
```

**Step 3:** Update workflow/INDEX.md Init section.

**Step 4:** Commit and push.

```bash
git add VERSION CLAUDE.md docs/migration-1.2.1.md workflow/INDEX.md
git commit -m "chore: bump version to 1.2.1 and add migration guide"
git push
```
