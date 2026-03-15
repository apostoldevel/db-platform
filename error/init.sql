--------------------------------------------------------------------------------
-- Error Catalog Seed Data -----------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Group 401: Authentication errors --------------------------------------------
--------------------------------------------------------------------------------

-- ERR-401-001: LoginFailed
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'en', 'Login failed', 'Authentication was rejected. The user has not signed in or the session has expired.', 'Sign in with valid credentials. If the problem persists, reset your password or contact support.');
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'ru', 'Не выполнен вход в систему');
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'de', 'Anmeldung fehlgeschlagen');
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'fr', 'Échec de la connexion');
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'it', 'Accesso non riuscito');
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'es', 'Error de inicio de sesión');

-- ERR-401-002: AuthenticateError
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'en', 'Authenticate Error. %s', 'The authentication subsystem encountered an error during the sign-in process. The placeholder contains the specific reason.', 'Review the detailed error message, verify your credentials, and try again. Contact support if the issue persists.');
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'ru', 'Вход в систему невозможен. %s');
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'de', 'Authentifizierungsfehler. %s');
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'fr', 'Erreur d''authentification. %s');
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'it', 'Errore di autenticazione. %s');
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'es', 'Error de autenticación. %s');

-- ERR-401-003: LoginError
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'en', 'Check the username is correct and enter the password again', 'The supplied username or password is incorrect. This typically occurs after one or more failed login attempts.', 'Verify the username is spelled correctly and re-enter the password. Use the password-reset flow if needed.');
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'ru', 'Проверьте правильность имени пользователя и повторите ввод пароля');
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'de', 'Überprüfen Sie den Benutzernamen und geben Sie das Passwort erneut ein');
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'fr', 'Vérifiez que le nom d''utilisateur est correct et entrez à nouveau le mot de passe');
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'it', 'Verifica che il nome utente sia corretto e inserisci nuovamente la password');
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'es', 'Verifique que el nombre de usuario sea correcto e ingrese la contraseña nuevamente');

-- ERR-401-004: UserLockError
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'en', 'Account is blocked', 'The user account has been permanently blocked by an administrator due to security policy or repeated violations.', 'Contact an administrator to review the block reason and restore access if appropriate.');
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'ru', 'Учетная запись заблокирована');
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'de', 'Konto ist gesperrt');
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'fr', 'Le compte est bloqué');
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'it', 'L''account è bloccato');
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'es', 'La cuenta está bloqueada');

-- ERR-401-005: UserTempLockError
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'en', 'Account is temporarily locked until %s', 'The account has been temporarily locked due to too many failed login attempts. Access will be restored at the time shown.', 'Wait until the lock expires, then sign in again. Contact an administrator to unlock the account immediately.');
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'ru', 'Учетная запись временно заблокирована до %s');
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'de', 'Konto ist vorübergehend gesperrt bis %s');
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'fr', 'Le compte est temporairement bloqué jusqu''à %s');
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'it', 'L''account è temporaneamente bloccato fino a %s');
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'es', 'La cuenta está temporalmente bloqueada hasta %s');

-- ERR-401-006: PasswordExpired
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'en', 'Password expired', 'The user''s password has exceeded its maximum age and must be changed before access is granted.', 'Change your password using the password-reset flow or ask an administrator to issue a temporary password.');
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'ru', 'Истек срок действия пароля');
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'de', 'Passwort abgelaufen');
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'fr', 'Mot de passe expiré');
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'it', 'Password scaduta');
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'es', 'Contraseña expirada');

-- ERR-401-007: SignatureError
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'en', 'Signature is incorrect or missing', 'The request signature is either missing or does not match the expected value, indicating possible tampering.', 'Ensure the request is signed with the correct key and algorithm. Regenerate the signature and retry.');
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'ru', 'Подпись не верна или отсутствует');
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'de', 'Signatur ist falsch oder fehlt');
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'fr', 'La signature est incorrecte ou manquante');
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'it', 'La firma è errata o mancante');
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'es', 'La firma es incorrecta o falta');

--------------------------------------------------------------------------------
-- Group 403: Token expiration -------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-403-001: TokenExpired
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'en', 'Token not FOUND or has expired', 'The access token was not found in the database or has passed its expiration time.', 'Obtain a new token by re-authenticating. Ensure your client refreshes tokens before they expire.');
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'ru', 'Маркер не найден или истек срок его действия');
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'de', 'Token nicht gefunden oder abgelaufen');
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'fr', 'Le jeton est introuvable ou a expiré');
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'it', 'Il token non è stato trovato o è scaduto');
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'es', 'Token no encontrado o ha expirado');

--------------------------------------------------------------------------------
-- Group 400: Access errors ----------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-001: AccessDenied
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'en', 'Access denied', 'The current user does not have the required permissions to perform the requested operation.', 'Verify the user''s role and permissions. Request the necessary access from an administrator.');
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'ru', 'Доступ запрещен');
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'de', 'Zugriff verweigert');
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'fr', 'Accès refusé');
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'it', 'Accesso negato');
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'es', 'Acceso denegado');

-- ERR-400-002: AccessDeniedForUser
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'en', 'Access denied for user %s', 'The specified user lacks the permissions required for this operation.', 'Grant the required permissions to the user or perform the operation under an authorized account.');
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'ru', 'Для пользователя %s данное действие запрещено');
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'de', 'Zugriff verweigert für Benutzer %s');
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'fr', 'Accès refusé pour l''utilisateur %s');
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'it', 'Accesso negato per l''utente %s');
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'es', 'Acceso denegado para el usuario %s');

-- ERR-400-003: ExecuteMethodError
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'en', 'Insufficient rights to execute method: %s', 'The user''s access control list does not include permission for the requested method on this object.', 'Check the method''s AMU entry and grant the user the required ACU permission, or use an account with sufficient rights.');
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'ru', 'Недостаточно прав для выполнения метода: %s');
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'de', 'Unzureichende Rechte zum Ausführen der Methode: %s');
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'fr', 'Droits insuffisants pour exécuter la méthode: %s');
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'it', 'Diritti insufficienti per eseguire il metodo: %s');
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'es', 'Derechos insuficientes para ejecutar el método: %s');

--------------------------------------------------------------------------------
-- Group 400: Auth errors ------------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-004: NonceExpired
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'en', 'Request timed out', 'The request nonce has expired, meaning the request took too long to reach the server.', 'Retry the request immediately. Ensure the client clock is synchronized and network latency is acceptable.');
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'ru', 'Истекло время запроса');
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'de', 'Zeitüberschreitung der Anfrage');
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'fr', 'La requête a expiré');
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'it', 'La richiesta è scaduta');
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'es', 'Tiempo de solicitud agotado');

-- ERR-400-005: TokenError
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'en', 'Token invalid', 'The provided token is malformed or cannot be validated by the server.', 'Obtain a new token by re-authenticating. Verify the token format matches the expected scheme.');
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'ru', 'Маркер недействителен');
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'de', 'Token ungültig');
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'fr', 'Jeton invalide');
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'it', 'Token non valido');
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'es', 'Token no válido');

-- ERR-400-006: TokenBelong
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'en', 'Token belongs to the other client', 'The token presented was issued to a different OAuth client and cannot be used by the current one.', 'Use a token issued specifically for this client application. Re-authenticate under the correct client ID.');
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'ru', 'Маркер принадлежит другому клиенту');
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'de', 'Token gehört einem anderen Client');
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'fr', 'Le jeton appartient à un autre client');
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'it', 'Il token appartiene a un altro client');
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'es', 'El token pertenece a otro cliente');

-- ERR-400-007: InvalidScope
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'en', 'Some requested areas were invalid: {valid=[%s], invalid=[%s]}', 'The OAuth scope request contains area identifiers that are not recognized by the system.', 'Remove the invalid scope values and retry with only the valid ones listed in the error message.');
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'ru', 'Некоторые из запрошенных областей недействительны: {верные=[%s], неверные=[%s]}');
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'de', 'Einige angeforderte Bereiche waren ungültig: {gültig=[%s], ungültig=[%s]}');
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'fr', 'Certaines des étendues demandées n''étaient pas valides: {valide=[%s], invalide=[%s]}');
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'it', 'Alcuni ambiti richiesti non erano validi: {valido=[%s], non valido=[%s]}');
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'es', 'Algunos ámbitos solicitados no eran válidos: {válido=[%s], no válido=[%s]}');

--------------------------------------------------------------------------------
-- Group 400: Entity errors ----------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-008: AbstractError
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'en', 'An abstract class cannot have objects', 'An attempt was made to instantiate an object from a class marked as abstract in the entity hierarchy.', 'Use a concrete subclass instead of the abstract class when creating objects.');
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'ru', 'У абстрактного класса не может быть объектов');
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'de', 'Eine abstrakte Klasse kann keine Objekte haben');
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'fr', 'Une classe abstraite ne peut pas avoir d''objets');
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'it', 'Una classe astratta non può avere oggetti');
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'es', 'Una clase abstracta no puede tener objetos');

-- ERR-400-009: ChangeClassError
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'en', 'Object class change is not allowed', 'The system does not allow changing the class of an existing object after creation.', 'Create a new object with the desired class and migrate the data, then delete the old object.');
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'ru', 'Изменение класса объекта не допускается');
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'de', 'Änderung der Objektklasse ist nicht erlaubt');
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'fr', 'La modification de la classe d''un objet n''est pas autorisée');
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'it', 'La modifica della classe di un oggetto non è consentita');
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'es', 'No se permite cambiar la clase del objeto');

-- ERR-400-010: ChangeAreaError
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'en', 'Changing document area is not allowed', 'Once a document is assigned to an area, its area cannot be changed.', 'Create a new document in the target area and transfer the relevant data from the original.');
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'ru', 'Недопустимо изменение области видимости документа');
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'de', 'Änderung des Dokumentbereichs ist nicht erlaubt');
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'fr', 'La modification de la zone d''un document n''est pas autorisée');
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'it', 'La modifica dell''area di un documento non è consentita');
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'es', 'No se permite cambiar el área del documento');

-- ERR-400-011: IncorrectEntity
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'en', 'Object entity is set incorrectly', 'The entity type specified for the object does not match any registered entity in the system.', 'Verify the entity code and ensure it is registered in the entity hierarchy before creating the object.');
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'ru', 'Неверно задана сущность объекта');
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'de', 'Objektentität ist falsch gesetzt');
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'fr', 'L''entité de l''objet est mal définie');
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'it', 'L''entità dell''oggetto non è impostata correttamente');
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'es', 'La entidad del objeto está configurada incorrectamente');

-- ERR-400-012: IncorrectClassType
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'en', 'Invalid object type', 'The object type supplied does not correspond to any known type in the class registry.', 'Check the available object types and provide a valid type identifier.');
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'ru', 'Неверно задан тип объекта');
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'de', 'Ungültiger Objekttyp');
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'fr', 'Type d''objet invalide');
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'it', 'Tipo di oggetto non valido');
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'es', 'Tipo de objeto no válido');

-- ERR-400-013: IncorrectDocumentType
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'en', 'Invalid document type', 'The document type supplied does not correspond to any registered document type.', 'Check the available document types and provide a valid type identifier.');
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'ru', 'Неверно задан тип документа');
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'de', 'Ungültiger Dokumenttyp');
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'fr', 'Type de document invalide');
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'it', 'Tipo di documento non valido');
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'es', 'Tipo de documento no válido');

--------------------------------------------------------------------------------
-- Group 400: Validation errors ------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-014: IncorrectLocaleCode
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'en', 'Locale not FOUND by code: %s', 'No locale record exists for the given locale code.', 'Provide a valid locale code (e.g., en, ru, de). Check the locale table for supported codes.');
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'ru', 'Не найден идентификатор языка по коду: %s');
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'de', 'Sprache nicht gefunden nach Code: %s');
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'fr', 'Langue non trouvée par code: %s');
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'it', 'Lingua non trovata per codice: %s');
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'es', 'Idioma no encontrado por código: %s');

-- ERR-400-015: RootAreaError
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'en', 'Operations with documents in root area are prohibited', 'The root area is a system-level container; creating or modifying documents directly in it is forbidden.', 'Move the document to a child area before performing the operation.');
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'ru', 'Запрещены операции с документами в корневой области.');
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'de', 'Operationen mit Dokumenten im Stammbereich sind verboten');
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'fr', 'Les opérations sur les documents dans la zone racine sont interdites');
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'it', 'Le operazioni con i documenti nell''area root sono vietate');
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'es', 'Las operaciones con documentos en el área raíz están prohibidas');

-- ERR-400-016: AreaError
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'en', 'Area not FOUND by specified identifier', 'The area identifier provided does not match any existing area record in the database.', 'Verify the area UUID is correct. List available areas and use a valid identifier.');
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'ru', 'Область с указанным идентификатором не найдена');
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'de', 'Bereich nicht gefunden mit der angegebenen Kennung');
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'fr', 'Zone non trouvée par l''identifiant spécifié');
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'it', 'Area non trovata dall''identificatore specificato');
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'es', 'Área no encontrada por el identificador especificado');

-- ERR-400-017: IncorrectAreaCode
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'en', 'Area not FOUND by code: %s', 'No area record was found matching the provided code.', 'Verify the area code is correct. List available areas and use a valid code.');
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'ru', 'Область не найдена по коду: %s');
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'de', 'Bereich nicht gefunden nach Code: %s');
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'fr', 'Zone non trouvée par code: %s');
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'it', 'Area non trovata per codice: %s');
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'es', 'Área no encontrada por código: %s');

-- ERR-400-018: UserNotMemberArea
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'en', 'User "%s" does not have access to area "%s"', 'The specified user has not been granted membership in the given area.', 'Add the user to the area via the area membership management functions.');
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'ru', 'Пользователь "%s" не имеет доступа к области "%s"');
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'de', 'Benutzer "%s" hat keinen Zugriff auf den Bereich "%s"');
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'fr', 'L''utilisateur "%s" n''a pas accès à la zone "%s"');
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'it', 'L''utente "%s" non ha accesso all''area "%s"');
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'es', 'El usuario "%s" no tiene acceso al área "%s"');

-- ERR-400-019: InterfaceError
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'en', 'Interface not FOUND by specified identifier', 'The interface identifier provided does not match any registered interface.', 'Verify the interface UUID. List available interfaces and use a valid identifier.');
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'ru', 'Не найден интерфейс с указанным идентификатором');
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'de', 'Schnittstelle nicht gefunden mit der angegebenen Kennung');
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'fr', 'Interface non trouvée par l''identifiant spécifié');
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'it', 'Interfaccia non trovata dall''identificatore specificato');
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'es', 'Interfaz no encontrada por el identificador especificado');

-- ERR-400-020: UserNotMemberInterface
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'en', 'User "%s" does not have access to interface "%s"', 'The specified user has not been granted access to the given interface.', 'Add the user to the interface via the interface membership management functions.');
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'ru', 'У пользователя "%s" нет доступа к интерфейсу "%s"');
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'de', 'Benutzer "%s" hat keinen Zugriff auf die Schnittstelle "%s"');
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'fr', 'L''utilisateur "%s" n''a pas accès à l''interface "%s"');
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'it', 'L''utente "%s" non ha accesso all''interfaccia "%s"');
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'es', 'El usuario "%s" no tiene acceso a la interfaz "%s"');

-- ERR-400-021: UnknownRoleName
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'en', 'Unknown role name: %s', 'The role name provided is not recognized by the system.', 'Check the list of registered roles and provide a valid role name.');
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'ru', 'Неизвестное имя роли: %s');
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'de', 'Unbekannter Rollenname: %s');
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'fr', 'Nom de rôle inconnu: %s');
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'it', 'Nome ruolo sconosciuto: %s');
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'es', 'Nombre de rol desconocido: %s');

-- ERR-400-022: RoleExists
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'en', 'Role "%s" already exists', 'A role with the given name already exists in the system and cannot be created again.', 'Use a different role name or modify the existing role instead of creating a duplicate.');
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'ru', 'Роль "%s" уже существует');
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'de', 'Rolle "%s" existiert bereits');
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'fr', 'Le rôle "%s" existe déjà');
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'it', 'Il ruolo "%s" esiste già');
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'es', 'El rol "%s" ya existe');

-- ERR-400-023: UserNotFound
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'en', 'User "%s" does not exist', 'No user account was found with the specified username.', 'Verify the username spelling. Use the user search function to confirm the account exists.');
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'ru', 'Пользователь "%s" не существует');
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'de', 'Benutzer "%s" existiert nicht');
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'fr', 'L''utilisateur "%s" n''existe pas');
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'it', 'L''utente "%s" non esiste');
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'es', 'El usuario "%s" no existe');

-- ERR-400-024: UserIdNotFound
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'en', 'User with id "%s" does not exist', 'No user account was found with the specified UUID.', 'Verify the user UUID is correct. Use the user search function to find the valid identifier.');
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'ru', 'Пользователь с идентификатором "%s" не существует');
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'de', 'Benutzer mit ID "%s" existiert nicht');
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'fr', 'Utilisateur avec id "%s" n''existe pas');
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'it', 'Utente con id "%s" non esiste');
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'es', 'El usuario con id "%s" no existe');

-- ERR-400-025: DeleteUserError
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'en', 'You cannot delete yourself', 'A user attempted to delete their own account, which is not allowed for safety reasons.', 'Ask another administrator to perform the deletion, or deactivate the account instead.');
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'ru', 'Вы не можете удалить себя');
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'de', 'Sie können sich nicht selbst löschen');
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'fr', 'Vous ne pouvez pas vous supprimer');
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'it', 'Non puoi eliminare te stesso');
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'es', 'No puede eliminarse a sí mismo');

-- ERR-400-026: AlreadyExists
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'en', '%s already exists', 'An entity with the same identifying attributes already exists in the system.', 'Use the existing record or choose different identifying attributes for the new entry.');
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'ru', '%s уже существует');
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'de', '%s existiert bereits');
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'fr', '%s existe déjà');
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'it', '%s esiste già');
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'es', '%s ya existe');

-- ERR-400-027: RecordExists
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'en', 'Entry with code "%s" already exists', 'A record with the specified code already exists in the target table.', 'Choose a unique code or update the existing record instead.');
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'ru', 'Запись с кодом "%s" уже существует');
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'de', 'Eintrag mit Code "%s" existiert bereits');
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'fr', 'L''entrée avec le code "%s" existe déjà');
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'it', 'La voce con codice "%s" esiste già');
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'es', 'La entrada con código "%s" ya existe');

-- ERR-400-028: InvalidCodes
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'en', 'Some codes were invalid: {valid=[%s], invalid=[%s]}', 'The request contains codes that are not recognized by the system.', 'Remove the invalid codes listed in the error message and retry with only valid ones.');
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'ru', 'Некоторые коды недействительны: {верные=[%s], неверные=[%s]}');
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'de', 'Einige Codes waren ungültig: {gültig=[%s], ungültig=[%s]}');
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'fr', 'Certains codes n''étaient pas valides: {valide=[%s], invalide=[%s]}');
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'it', 'Alcuni codici non erano validi: {valido=[%s], non valido=[%s]}');
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'es', 'Algunos códigos no eran válidos: {válido=[%s], no válido=[%s]}');

-- ERR-400-029: IncorrectCode
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'en', 'Invalid code "%s". Valid codes: [%s]', 'The code provided is not among the set of acceptable values.', 'Replace the invalid code with one of the valid codes listed in the error message.');
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'ru', 'Недопустимый код "%s". Допустимые коды: [%s]');
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'de', 'Ungültiger Code "%s". Gültige Codes: [%s]');
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'fr', 'Code incorrect "%s". Codes valides: [%s]');
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'it', 'Codice non valido "%s". Codici validi: [%s]');
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'es', 'Código no válido "%s". Códigos válidos: [%s]');

-- ERR-400-030: ObjectNotFound
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'en', 'Not FOUND %s with %s: %s', 'The requested entity could not be found using the given lookup criteria.', 'Verify the search parameters are correct and that the record exists in the database.');
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'ru', 'Не найден(а/о) %s по %s: %s');
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'de', 'Nicht gefunden %s mit %s: %s');
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'fr', 'Non trouvé %s avec %s: %s');
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'it', 'Non trovato %s con %s: %s');
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'es', 'No encontrado %s con %s: %s');

-- ERR-400-031: ObjectIdIsNull
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'en', 'Not FOUND %s with %s: <null>', 'A required identifier was null when looking up the entity.', 'Provide a non-null value for the required identifier parameter.');
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'ru', 'Не найден(а/о) %s по %s: <null>');
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'de', 'Nicht gefunden %s mit %s: <null>');
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'fr', 'Non trouvé %s avec %s: <null>');
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'it', 'Non trovato %s con %s: <null>');
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'es', 'No encontrado %s con %s: <null>');

--------------------------------------------------------------------------------
-- Group 400: Workflow errors --------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-032: MethodActionNotFound
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'en', 'Object [%s] method not FOUND, for action: %s [%s]. Current state: %s [%s]', 'No workflow method is available for the requested action given the object''s current state.', 'Check the object''s current state and available transitions. Ensure the action is valid for this state.');
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'ru', 'Не найден метод объекта [%s], для действия: %s [%s]. Текущее состояние: %s [%s]');
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'de', 'Methode des Objekts [%s] nicht gefunden, für Aktion: %s [%s]. Aktueller Status: %s [%s]');
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'fr', 'Méthode de l''objet [%s] non trouvée, pour l''action: %s [%s]. État actuel: %s [%s]');
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'it', 'Metodo dell''oggetto [%s] non trovato, per azione: %s [%s]. Stato attuale: %s [%s]');
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'es', 'Método del objeto [%s] no encontrado, para acción: %s [%s]. Estado actual: %s [%s]');

-- ERR-400-033: MethodNotFound
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'en', 'Method "%s" of object "%s" not FOUND', 'The specified method does not exist for the given object in the workflow registry.', 'Verify the method name and object identifier. List available methods for the object.');
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'ru', 'Не найден метод "%s" объекта "%s"');
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'de', 'Methode "%s" des Objekts "%s" nicht gefunden');
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'fr', 'Méthode "%s" de l''objet "%s" non trouvée');
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'it', 'Metodo "%s" dell''oggetto "%s" non trovato');
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'es', 'Método "%s" del objeto "%s" no encontrado');

-- ERR-400-034: MethodByCodeNotFound
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'en', 'No method FOUND by code "%s" for object "%s"', 'No method was found with the given code for the specified object.', 'Verify the method code. List available methods for the object to find the correct code.');
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'ru', 'Не найден метод по коду "%s" для объекта "%s"');
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'de', 'Keine Methode gefunden mit Code "%s" für Objekt "%s"');
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'fr', 'Aucune méthode trouvée par code "%s" pour l''objet "%s"');
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'it', 'Nessun metodo trovato per codice "%s" per oggetto "%s"');
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'es', 'No se encontró método por código "%s" para el objeto "%s"');

-- ERR-400-035: ChangeObjectStateError
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'en', 'Failed to change object state: %s', 'The workflow engine failed to transition the object to a new state. The placeholder contains the specific reason.', 'Review the error details and ensure all preconditions for the state transition are met.');
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'ru', 'Не удалось изменить состояние объекта: %s');
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'de', 'Änderung des Objektstatus fehlgeschlagen: %s');
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'fr', 'Échec de la modification de l''état de l''objet: %s');
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'it', 'Impossibile modificare lo stato dell''oggetto: %s');
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'es', 'Error al cambiar el estado del objeto: %s');

-- ERR-400-036: ChangesNotAllowed
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'en', 'Changes are not allowed', 'The object is in a state where modifications are not permitted by the workflow.', 'Transition the object to an editable state before making changes.');
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'ru', 'Изменения не допускаются');
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'de', 'Änderungen sind nicht erlaubt');
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'fr', 'Les modifications ne sont pas autorisées');
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'it', 'Le modifiche non sono consentite');
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'es', 'Los cambios no están permitidos');

-- ERR-400-037: StateByCodeNotFound
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'en', 'No state FOUND by code "%s" for object "%s"', 'No workflow state was found matching the given code for the specified object.', 'Verify the state code. List registered states for the object''s class to find the correct code.');
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'ru', 'Не найдено состояние по коду "%s" для объекта "%s"');
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'de', 'Kein Status gefunden mit Code "%s" für Objekt "%s"');
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'fr', 'Aucun état trouvé par code "%s" pour l''objet "%s"');
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'it', 'Nessuno stato trovato per codice "%s" per oggetto "%s"');
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'es', 'No se encontró estado por código "%s" para el objeto "%s"');

-- ERR-400-038: MethodIsEmpty
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'en', 'Method ID must not be empty', 'The method identifier parameter is required but was passed as null or empty.', 'Provide a valid non-empty method UUID in the request.');
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'ru', 'Идентификатор метода не должен быть пустым');
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'de', 'Methoden-ID darf nicht leer sein');
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'fr', 'L''ID de la méthode ne doit pas être vide');
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'it', 'L''ID del metodo non deve essere vuoto');
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'es', 'El ID del método no debe estar vacío');

-- ERR-400-039: ActionIsEmpty
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'en', 'Action ID must not be empty', 'The action identifier parameter is required but was passed as null or empty.', 'Provide a valid non-empty action UUID in the request.');
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'ru', 'Идентификатор действия не должен быть пустым');
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'de', 'Aktions-ID darf nicht leer sein');
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'fr', 'L''ID de l''action ne doit pas être vide');
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'it', 'L''ID dell''azione non deve essere vuoto');
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'es', 'El ID de la acción no debe estar vacío');

-- ERR-400-040: ExecutorIsEmpty
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'en', 'The executor must not be empty', 'The executor field is required for this operation but was not provided.', 'Specify a valid executor (user or process) for the operation.');
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'ru', 'Исполнитель не должен быть пустым');
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'de', 'Der Ausführende darf nicht leer sein');
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'fr', 'L''exécuteur ne doit pas être vide');
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'it', 'L''esecutore non deve essere vuoto');
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'es', 'El ejecutor no debe estar vacío');

-- ERR-400-041: IncorrectDateInterval
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'en', 'The end date of the period cannot be less than the start date of the period', 'The date range is invalid because the end date precedes the start date.', 'Swap the dates or correct the range so the end date is on or after the start date.');
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'ru', 'Дата окончания периода не может быть меньше даты начала периода');
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'de', 'Das Enddatum des Zeitraums darf nicht vor dem Startdatum des Zeitraums liegen');
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'fr', 'La date de fin de la période ne peut pas être antérieure à la date de début de la période');
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'it', 'La data di fine del periodo non può essere inferiore alla data di inizio del periodo');
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'es', 'La fecha de fin del período no puede ser anterior a la fecha de inicio del período');

-- ERR-400-042: UserPasswordChange
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'en', 'Password change failed, password change is prohibited', 'The password change was rejected because the security policy prohibits this user from changing their password.', 'Contact an administrator to change the password or update the policy to allow password changes.');
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'ru', 'Не удалось изменить пароль, установлен запрет на изменение пароля');
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'de', 'Passwortänderung fehlgeschlagen, Passwortänderung ist verboten');
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'fr', 'Échec de la modification du mot de passe, la modification du mot de passe est interdite');
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'it', 'Modifica password non riuscita, la modifica della password è vietata');
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'es', 'Error al cambiar la contraseña, el cambio de contraseña está prohibido');

-- ERR-400-043: SystemRoleError
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'en', 'Change, delete operations for system roles are prohibited', 'System-defined roles are protected and cannot be modified or deleted.', 'Create a custom role with the desired permissions instead of modifying a system role.');
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'ru', 'Операции изменения, удаления для системных ролей запрещены');
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'de', 'Änderungs- und Löschoperationen für Systemrollen sind verboten');
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'fr', 'Les opérations de modification, de suppression des rôles système sont interdites');
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'it', 'Le operazioni di modifica, eliminazione per i ruoli di sistema sono vietate');
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'es', 'Las operaciones de modificación y eliminación de roles del sistema están prohibidas');

-- ERR-400-044: LoginIpTableError
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'en', 'Login is not possible. Limited access by IP-address: %s', 'The user''s IP address is not in the allowed list, so login is denied.', 'Connect from an allowed IP address or ask an administrator to update the IP whitelist.');
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'ru', 'Вход в систему невозможен. Ограничен доступ по IP-адресу: %s');
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'de', 'Anmeldung nicht möglich. Eingeschränkter Zugang nach IP-Adresse: %s');
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'fr', 'La connexion n''est pas possible. Accès limité par adresse IP: %s');
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'it', 'Accesso non possibile. Accesso limitato tramite indirizzo IP: %s');
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'es', 'Inicio de sesión no posible. Acceso limitado por dirección IP: %s');

-- ERR-400-045: OperationNotPossible
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'en', 'Operation is not possible, there are related documents', 'The operation cannot proceed because other documents reference this object.', 'Remove or reassign the related documents before retrying the operation.');
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'ru', 'Операция невозможна, есть связанные документы');
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'de', 'Vorgang nicht möglich, es gibt zugehörige Dokumente');
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'fr', 'L''opération n''est pas possible, il existe des documents associés');
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'it', 'Operazione non possibile, sono presenti documenti correlati');
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'es', 'La operación no es posible, hay documentos relacionados');

-- ERR-400-046: ViewNotFound
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'en', 'View "%s.%s" not FOUND', 'The specified database view does not exist in the given schema.', 'Verify the schema and view names. Run the update script to ensure all views are created.');
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'ru', 'Представление "%s.%s" не найдено');
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'de', 'Ansicht "%s.%s" nicht gefunden');
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'fr', 'Vue "%s.%s" non trouvée');
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'it', 'Vista "%s.%s" non trovata');
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'es', 'Vista "%s.%s" no encontrada');

-- ERR-400-047: InvalidVerificationCodeType
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'en', 'Invalid verification type code: %s', 'The verification type code provided is not recognized by the verification subsystem.', 'Use a valid verification type code. Check the verification module for supported types.');
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'ru', 'Недопустимый код типа верификации: %s');
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'de', 'Ungültiger Verifizierungstypcode: %s');
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'fr', 'Code de type de vérification non valide: %s');
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'it', 'Codice tipo verifica non valido: %s');
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'es', 'Código de tipo de verificación no válido: %s');

-- ERR-400-048: InvalidPhoneNumber
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'en', 'Invalid phone number: %s', 'The phone number format is invalid or does not match the expected pattern.', 'Provide the phone number in international format (e.g., +1234567890).');
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'ru', 'Неправильный номер телефона: %s');
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'de', 'Ungültige Telefonnummer: %s');
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'fr', 'Numéro de téléphone non valide: %s');
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'it', 'Numero di telefono non valido: %s');
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'es', 'Número de teléfono no válido: %s');

-- ERR-400-049: ObjectIsNull
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'en', 'Object id not specified', 'The operation requires an object identifier but none was provided.', 'Include a valid object UUID in the request parameters.');
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'ru', 'Не указан идентификатор объекта');
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'de', 'Objekt-ID nicht angegeben');
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'fr', 'ID d''objet non spécifié');
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'it', 'ID oggetto non specificato');
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'es', 'ID de objeto no especificado');

-- ERR-400-050: PerformActionError
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'en', 'You cannot perform this action', 'The current user is not authorized to perform this specific action on the object.', 'Verify your permissions for this action or request access from an administrator.');
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'ru', 'Вы не можете выполнить данное действие');
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'de', 'Sie können diese Aktion nicht ausführen');
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'fr', 'Vous ne pouvez pas effectuer cette action');
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'it', 'Non puoi eseguire questa azione');
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'es', 'No puede realizar esta acción');

-- ERR-400-051: IdentityNotConfirmed
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'en', 'Identity not confirmed', 'The user''s identity has not been confirmed through the required verification process.', 'Complete the identity verification process (e.g., email or phone confirmation) before proceeding.');
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'ru', 'Личность не подтверждена');
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'de', 'Identität nicht bestätigt');
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'fr', 'Identité non confirmée');
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'it', 'Identità non confermata');
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'es', 'Identidad no confirmada');

-- ERR-400-052: ReadOnlyError
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'en', 'Modify operations for read-only roles are not allowed', 'The current role is read-only and does not permit create, update, or delete operations.', 'Switch to a role with write permissions or ask an administrator to upgrade the role.');
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'ru', 'Операции изменения для ролей только для чтения запрещены');
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'de', 'Änderungsoperationen für schreibgeschützte Rollen sind nicht erlaubt');
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'fr', 'Les opérations de modification pour les rôles en lecture seule ne sont pas autorisées');
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'it', 'Le operazioni di modifica per i ruoli di sola lettura non sono consentite');
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'es', 'Las operaciones de modificación para roles de solo lectura no están permitidas');

-- ERR-400-053: ActionAlreadyCompleted
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'en', 'You have already completed this action', 'The requested action has already been executed by this user and cannot be repeated.', 'No further action is needed. If a different outcome is required, use the appropriate reversal or correction workflow.');
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'ru', 'Вы уже выполнили это действие');
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'de', 'Sie haben diese Aktion bereits abgeschlossen');
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'fr', 'Vous avez déjà terminé cette action');
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'it', 'Hai già completato questa azione');
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'es', 'Ya ha completado esta acción');

--------------------------------------------------------------------------------
-- Group 400: JSON validation errors -------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-060: JsonIsEmpty
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'en', 'JSON must not be empty', 'The request body must contain a non-empty JSON payload, but it was empty or null.', 'Include a valid JSON object in the request body.');
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'ru', 'JSON не должен быть пустым');
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'de', 'JSON darf nicht leer sein');
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'fr', 'JSON ne doit pas être vide');
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'it', 'JSON non deve essere vuoto');
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'es', 'JSON no debe estar vacío');

-- ERR-400-061: IncorrectJsonKey
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'en', '(%s) Invalid key "%s". Valid keys: [%s]', 'The JSON payload contains a key that is not recognized for this endpoint.', 'Remove the invalid key and use only the keys listed in the error message.');
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'ru', '(%s) Недопустимый ключ "%s". Допустимые ключи: [%s]');
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'de', '(%s) Ungültiger Schlüssel "%s". Gültige Schlüssel: [%s]');
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'fr', '(%s) Clé non valide "%s". Clés valides: [%s]');
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'it', '(%s) Chiave non valida "%s". Chiavi valide: [%s]');
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'es', '(%s) Clave no válida "%s". Claves válidas: [%s]');

-- ERR-400-062: JsonKeyNotFound
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'en', '(%s) Required key not FOUND: %s', 'A required key is missing from the JSON payload.', 'Add the missing key to the JSON payload and retry the request.');
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'ru', '(%s) Не найден обязательный ключ: %s');
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'de', '(%s) Erforderlicher Schlüssel nicht gefunden: %s');
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'fr', '(%s) Clé requise non trouvée: %s');
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'it', '(%s) Chiave richiesta non trovata: %s');
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'es', '(%s) Clave requerida no encontrada: %s');

-- ERR-400-063: IncorrectJsonType
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'en', 'Invalid type "%s", expected "%s"', 'The JSON value type does not match the expected type for this field.', 'Change the value to the expected type (e.g., string instead of integer) and retry.');
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'ru', 'Неверный тип "%s", ожидается "%s"');
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'de', 'Ungültiger Typ "%s", erwartet "%s"');
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'fr', 'Type non valide "%s", attendu "%s"');
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'it', 'Tipo non valido "%s", previsto "%s"');
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'es', 'Tipo no válido "%s", esperado "%s"');

-- ERR-400-064: IncorrectKeyInArray
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'en', 'Invalid key "%s" in array "%s". Valid keys: [%s]', 'A JSON array element contains a key that is not valid for that array context.', 'Remove the invalid key from the array element. Use only the valid keys listed in the error message.');
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'ru', 'Недопустимый ключ "%s" в массиве "%s". Допустимые ключи: [%s]');
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'de', 'Ungültiger Schlüssel "%s" im Array "%s". Gültige Schlüssel: [%s]');
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'fr', 'Clé non valide "%s" dans le tableau "%s". Clés valides: [%s]');
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'it', 'Chiave non valida "%s" nell''array "%s". Chiavi valide: [%s]');
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'es', 'Clave no válida "%s" en el arreglo "%s". Claves válidas: [%s]');

-- ERR-400-065: IncorrectValueInArray
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'en', 'Invalid value "%s" in array "%s". Valid values: [%s]', 'A JSON array element contains a value that is not among the accepted options.', 'Replace the invalid value with one of the valid values listed in the error message.');
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'ru', 'Недопустимое значение "%s" в массиве "%s". Допустимые значения: [%s]');
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'de', 'Ungültiger Wert "%s" im Array "%s". Gültige Werte: [%s]');
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'fr', 'Valeur non valide "%s" dans le tableau "%s". Valeurs valides: [%s]');
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'it', 'Valore non valido "%s" nell''array "%s". Valori validi: [%s]');
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'es', 'Valor no válido "%s" en el arreglo "%s". Valores válidos: [%s]');

-- ERR-400-066: ValueOutOfRange
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'en', 'Value [%s] is out of range', 'The provided value falls outside the acceptable range for this field.', 'Adjust the value to fall within the valid range and retry.');
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'ru', 'Значение [%s] выходит за пределы допустимого диапазона');
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'de', 'Wert [%s] liegt außerhalb des zulässigen Bereichs');
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'fr', 'La valeur [%s] est hors limites');
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'it', 'Valore [%s] fuori intervallo');
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'es', 'El valor [%s] está fuera de rango');

-- ERR-400-067: DateValidityPeriod
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'en', 'The start date must not exceed the end date', 'The date range is invalid because the start date is later than the end date.', 'Correct the dates so the start date is on or before the end date.');
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'ru', 'Дата начала не должна превышать дату окончания');
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'de', 'Das Startdatum darf das Enddatum nicht überschreiten');
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'fr', 'La date de début ne doit pas dépasser la date de fin');
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'it', 'La data di inizio non deve superare la data di fine');
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'es', 'La fecha de inicio no debe exceder la fecha de fin');

--------------------------------------------------------------------------------
-- Group 400: OAuth 2.0 errors ------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-070: IssuerNotFound
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'en', 'OAuth 2.0: Issuer not FOUND: %s', 'The JWT issuer claim does not match any registered OAuth 2.0 provider in the system.', 'Register the issuer in the OAuth 2.0 configuration or use a token from a known issuer.');
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'ru', 'OAuth 2.0: Не найден эмитент: %s');
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'de', 'OAuth 2.0: Aussteller nicht gefunden: %s');
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'fr', 'OAuth 2.0: Émetteur non trouvé: %s');
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'it', 'OAuth 2.0: Emittente non trovato: %s');
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'es', 'OAuth 2.0: Emisor no encontrado: %s');

-- ERR-400-071: AudienceNotFound
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'en', 'OAuth 2.0: Client not FOUND', 'The JWT audience claim does not match any registered OAuth 2.0 client.', 'Verify the client is registered in the OAuth 2.0 configuration. Register it if necessary.');
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'ru', 'OAuth 2.0: Клиент не найден');
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'de', 'OAuth 2.0: Client nicht gefunden');
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'fr', 'OAuth 2.0: Client non trouvé');
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'it', 'OAuth 2.0: Client non trovato');
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'es', 'OAuth 2.0: Cliente no encontrado');

-- ERR-400-072: GuestAreaError
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'en', 'Operations with documents in guest area are prohibited', 'The guest area is restricted; creating or modifying documents in it is not allowed.', 'Move the document to an appropriate non-guest area before performing the operation.');
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'ru', 'Запрещены операции с документами в гостевой области.');
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'de', 'Operationen mit Dokumenten im Gastbereich sind verboten');
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'fr', 'Les opérations sur les documents dans la zone invité sont interdites');
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'it', 'Le operazioni con i documenti nell''area ospiti sono vietate');
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'es', 'Las operaciones con documentos en el área de invitados están prohibidas');

-- ERR-400-073: NotFound
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'en', 'Not found', 'The requested resource could not be found.', 'Verify the identifier or path is correct and the resource exists.');
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'ru', 'Не найдено');
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'de', 'Nicht gefunden');
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'fr', 'Non trouvé');
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'it', 'Non trovato');
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'es', 'No encontrado');

-- ERR-400-074: DefaultAreaDocumentError
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'en', 'The document can only be changed in the "Default" area', 'The document belongs to a non-default area and can only be modified when accessed through the Default area.', 'Switch to the Default area context before modifying this document.');
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'ru', 'Документ можно изменить только в области «По умолчанию»');
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'de', 'Das Dokument kann nur im Bereich "Standard" geändert werden');
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'fr', 'Le document ne peut être modifié que dans la zone ''Par défaut''');
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'it', 'Il documento può essere modificato solo nell''area "Predefinito"');
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'es', 'El documento solo se puede cambiar en el área "Predeterminado"');

--------------------------------------------------------------------------------
-- Group 400: Registry errors --------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-080: IncorrectRegistryKey
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'en', 'Invalid key "%s". Valid keys: [%s]', 'The registry key provided is not recognized in the system registry.', 'Use one of the valid keys listed in the error message.');
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'ru', 'Недопустимый ключ "%s". Допустимые ключи: [%s]');
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'de', 'Ungültiger Schlüssel "%s". Gültige Schlüssel: [%s]');
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'fr', 'Clé non valide "%s". Clés valides: [%s]');
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'it', 'Chiave non valida "%s". Chiavi valide: [%s]');
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'es', 'Clave no válida "%s". Claves válidas: [%s]');

-- ERR-400-081: IncorrectRegistryDataType
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'en', 'Invalid data type: %s', 'The data type specified for the registry value is not supported.', 'Use a supported data type (e.g., text, integer, boolean, numeric, datetime).');
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'ru', 'Неверный тип данных: %s');
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'de', 'Ungültiger Datentyp: %s');
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'fr', 'Type de données non valide: %s');
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'it', 'Tipo di dati non valido: %s');
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'es', 'Tipo de datos no válido: %s');

--------------------------------------------------------------------------------
-- Group 400: Route errors -----------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-090: RouteIsEmpty
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'en', 'Path must not be empty', 'The REST path parameter is required but was passed as empty or null.', 'Provide a non-empty path string in the request.');
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'ru', 'Путь не должен быть пустым');
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'de', 'Pfad darf nicht leer sein');
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'fr', 'Le chemin ne doit pas être vide');
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'it', 'Il percorso non deve essere vuoto');
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'es', 'La ruta no debe estar vacía');

-- ERR-400-091: RouteNotFound
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'en', 'Route not found: %s', 'No REST route is registered for the given path.', 'Check the available API routes and use a valid path. Register the route in init.sql if it is missing.');
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'ru', 'Не найден маршрут: %s');
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'de', 'Route nicht gefunden: %s');
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'fr', 'Route non trouvée: %s');
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'it', 'Route non trovata: %s');
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'es', 'Ruta no encontrada: %s');

-- ERR-400-092: EndPointNotSet
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'en', 'Endpoint not set for path: %s', 'A route exists for the given path but no endpoint function has been configured.', 'Register an endpoint function for this route in the REST configuration.');
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'ru', 'Конечная точка не указана для пути: %s');
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'de', 'Endpunkt nicht festgelegt für Pfad: %s');
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'fr', 'Point de terminaison non défini pour le chemin: %s');
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'it', 'Endpoint non impostato per percorso: %s');
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'es', 'Punto final no establecido para la ruta: %s');

--------------------------------------------------------------------------------
-- Group 400: System errors ----------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-100: SomethingWentWrong
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'en', 'Oops, something went wrong. Our engineers are already working on fixing the error', 'An unexpected internal error occurred that does not fit any specific error category.', 'Retry the operation. If the error persists, check the server logs and report the issue to the development team.');
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'ru', 'Упс, что-то пошло не так. Наши инженеры уже работают над решением проблемы');
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'de', 'Hoppla, etwas ist schiefgelaufen. Unsere Ingenieure arbeiten bereits an der Behebung des Fehlers');
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'fr', 'Oups, quelque chose s''est mal passé. Nos ingénieurs travaillent déjà à la résolution du problème');
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'it', 'Ops, qualcosa è andato storto. I nostri ingegneri stanno già lavorando alla risoluzione del problema');
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'es', 'Vaya, algo salió mal. Nuestros ingenieros ya están trabajando en la solución del problema');
