--------------------------------------------------------------------------------
-- Error Catalog Seed Data -----------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Group 401: Authentication errors --------------------------------------------
--------------------------------------------------------------------------------

-- ERR-401-001: LoginFailed
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'en', 'Login failed', 'Authentication was rejected. The user has not signed in or the session has expired.', 'Sign in with valid credentials. If the problem persists, reset your password or contact support.');
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'ru', 'Не выполнен вход в систему');
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'de', 'Anmeldung fehlgeschlagen', 'Die Authentifizierung wurde abgelehnt. Der Benutzer hat sich nicht angemeldet oder die Sitzung ist abgelaufen.', 'Melden Sie sich mit gültigen Anmeldedaten an. Wenn das Problem weiterhin besteht, setzen Sie Ihr Passwort zurück oder wenden Sie sich an den Support.');
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'fr', 'Échec de la connexion', 'L''authentification a été rejetée. L''utilisateur ne s''est pas connecté ou la session a expiré.', 'Connectez-vous avec des identifiants valides. Si le problème persiste, réinitialisez votre mot de passe ou contactez le support.');
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'it', 'Accesso non riuscito', 'L''autenticazione è stata rifiutata. L''utente non ha effettuato l''accesso o la sessione è scaduta.', 'Accedere con credenziali valide. Se il problema persiste, reimpostare la password o contattare il supporto.');
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'es', 'Error de inicio de sesión', 'La autenticación fue rechazada. El usuario no ha iniciado sesión o la sesión ha expirado.', 'Inicie sesión con credenciales válidas. Si el problema persiste, restablezca su contraseña o contacte con el soporte.');

-- ERR-401-002: AuthenticateError
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'en', 'Authenticate Error. %s', 'The authentication subsystem encountered an error during the sign-in process. The placeholder contains the specific reason.', 'Review the detailed error message, verify your credentials, and try again. Contact support if the issue persists.');
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'ru', 'Вход в систему невозможен. %s');
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'de', 'Authentifizierungsfehler. %s', 'Das Authentifizierungssubsystem hat während des Anmeldevorgangs einen Fehler festgestellt. Der Platzhalter enthält den spezifischen Grund.', 'Überprüfen Sie die detaillierte Fehlermeldung, verifizieren Sie Ihre Anmeldedaten und versuchen Sie es erneut. Wenden Sie sich an den Support, wenn das Problem weiterhin besteht.');
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'fr', 'Erreur d''authentification. %s', 'Le sous-système d''authentification a rencontré une erreur lors du processus de connexion. L''espace réservé contient la raison spécifique.', 'Examinez le message d''erreur détaillé, vérifiez vos identifiants et réessayez. Contactez le support si le problème persiste.');
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'it', 'Errore di autenticazione. %s', 'Il sottosistema di autenticazione ha riscontrato un errore durante il processo di accesso. Il segnaposto contiene il motivo specifico.', 'Esaminare il messaggio di errore dettagliato, verificare le proprie credenziali e riprovare. Contattare il supporto se il problema persiste.');
SELECT RegisterError('ERR-401-002', 401, 'E', 'auth', 'es', 'Error de autenticación. %s', 'El subsistema de autenticación encontró un error durante el proceso de inicio de sesión. El marcador de posición contiene la razón específica.', 'Revise el mensaje de error detallado, verifique sus credenciales e intente de nuevo. Contacte con el soporte si el problema persiste.');

-- ERR-401-003: LoginError
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'en', 'Check the username is correct and enter the password again', 'The supplied username or password is incorrect. This typically occurs after one or more failed login attempts.', 'Verify the username is spelled correctly and re-enter the password. Use the password-reset flow if needed.');
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'ru', 'Проверьте правильность имени пользователя и повторите ввод пароля');
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'de', 'Überprüfen Sie den Benutzernamen und geben Sie das Passwort erneut ein', 'Der angegebene Benutzername oder das Passwort ist falsch. Dies tritt typischerweise nach einem oder mehreren fehlgeschlagenen Anmeldeversuchen auf.', 'Überprüfen Sie, ob der Benutzername korrekt geschrieben ist, und geben Sie das Passwort erneut ein. Nutzen Sie bei Bedarf die Passwort-Zurücksetzen-Funktion.');
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'fr', 'Vérifiez que le nom d''utilisateur est correct et entrez à nouveau le mot de passe', 'Le nom d''utilisateur ou le mot de passe fourni est incorrect. Cela se produit généralement après une ou plusieurs tentatives de connexion échouées.', 'Vérifiez que le nom d''utilisateur est correctement orthographié et saisissez à nouveau le mot de passe. Utilisez la procédure de réinitialisation du mot de passe si nécessaire.');
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'it', 'Verifica che il nome utente sia corretto e inserisci nuovamente la password', 'Il nome utente o la password forniti non sono corretti. Questo si verifica tipicamente dopo uno o più tentativi di accesso falliti.', 'Verificare che il nome utente sia scritto correttamente e reinserire la password. Utilizzare la procedura di reimpostazione della password se necessario.');
SELECT RegisterError('ERR-401-003', 401, 'E', 'auth', 'es', 'Verifique que el nombre de usuario sea correcto e ingrese la contraseña nuevamente', 'El nombre de usuario o la contraseña proporcionados son incorrectos. Esto ocurre típicamente después de uno o más intentos de inicio de sesión fallidos.', 'Verifique que el nombre de usuario esté escrito correctamente y vuelva a ingresar la contraseña. Utilice el flujo de restablecimiento de contraseña si es necesario.');

-- ERR-401-004: UserLockError
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'en', 'Account is blocked', 'The user account has been permanently blocked by an administrator due to security policy or repeated violations.', 'Contact an administrator to review the block reason and restore access if appropriate.');
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'ru', 'Учетная запись заблокирована');
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'de', 'Konto ist gesperrt', 'Das Benutzerkonto wurde von einem Administrator aufgrund von Sicherheitsrichtlinien oder wiederholten Verstößen dauerhaft gesperrt.', 'Wenden Sie sich an einen Administrator, um den Sperrgrund zu überprüfen und den Zugang gegebenenfalls wiederherzustellen.');
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'fr', 'Le compte est bloqué', 'Le compte utilisateur a été définitivement bloqué par un administrateur en raison de la politique de sécurité ou de violations répétées.', 'Contactez un administrateur pour examiner la raison du blocage et restaurer l''accès si approprié.');
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'it', 'L''account è bloccato', 'L''account utente è stato bloccato permanentemente da un amministratore a causa della politica di sicurezza o di violazioni ripetute.', 'Contattare un amministratore per esaminare il motivo del blocco e ripristinare l''accesso se appropriato.');
SELECT RegisterError('ERR-401-004', 401, 'E', 'auth', 'es', 'La cuenta está bloqueada', 'La cuenta de usuario ha sido bloqueada permanentemente por un administrador debido a la política de seguridad o violaciones repetidas.', 'Contacte con un administrador para revisar el motivo del bloqueo y restaurar el acceso si corresponde.');

-- ERR-401-005: UserTempLockError
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'en', 'Account is temporarily locked until %s', 'The account has been temporarily locked due to too many failed login attempts. Access will be restored at the time shown.', 'Wait until the lock expires, then sign in again. Contact an administrator to unlock the account immediately.');
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'ru', 'Учетная запись временно заблокирована до %s');
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'de', 'Konto ist vorübergehend gesperrt bis %s', 'Das Konto wurde aufgrund zu vieler fehlgeschlagener Anmeldeversuche vorübergehend gesperrt. Der Zugang wird zum angezeigten Zeitpunkt wiederhergestellt.', 'Warten Sie, bis die Sperre abgelaufen ist, und melden Sie sich erneut an. Wenden Sie sich an einen Administrator, um das Konto sofort zu entsperren.');
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'fr', 'Le compte est temporairement bloqué jusqu''à %s', 'Le compte a été temporairement verrouillé en raison d''un trop grand nombre de tentatives de connexion échouées. L''accès sera rétabli à l''heure indiquée.', 'Attendez l''expiration du verrouillage, puis reconnectez-vous. Contactez un administrateur pour déverrouiller le compte immédiatement.');
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'it', 'L''account è temporaneamente bloccato fino a %s', 'L''account è stato temporaneamente bloccato a causa di troppi tentativi di accesso falliti. L''accesso sarà ripristinato all''ora indicata.', 'Attendere la scadenza del blocco, quindi accedere nuovamente. Contattare un amministratore per sbloccare immediatamente l''account.');
SELECT RegisterError('ERR-401-005', 401, 'E', 'auth', 'es', 'La cuenta está temporalmente bloqueada hasta %s', 'La cuenta ha sido bloqueada temporalmente debido a demasiados intentos de inicio de sesión fallidos. El acceso se restaurará a la hora indicada.', 'Espere a que expire el bloqueo y luego inicie sesión de nuevo. Contacte con un administrador para desbloquear la cuenta inmediatamente.');

-- ERR-401-006: PasswordExpired
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'en', 'Password expired', 'The user''s password has exceeded its maximum age and must be changed before access is granted.', 'Change your password using the password-reset flow or ask an administrator to issue a temporary password.');
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'ru', 'Истек срок действия пароля');
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'de', 'Passwort abgelaufen', 'Das Passwort des Benutzers hat sein maximales Alter überschritten und muss geändert werden, bevor der Zugang gewährt wird.', 'Ändern Sie Ihr Passwort über die Passwort-Zurücksetzen-Funktion oder bitten Sie einen Administrator um ein temporäres Passwort.');
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'fr', 'Mot de passe expiré', 'Le mot de passe de l''utilisateur a dépassé sa durée de vie maximale et doit être changé avant que l''accès ne soit accordé.', 'Changez votre mot de passe via la procédure de réinitialisation ou demandez à un administrateur de fournir un mot de passe temporaire.');
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'it', 'Password scaduta', 'La password dell''utente ha superato la durata massima e deve essere cambiata prima che l''accesso venga concesso.', 'Cambiare la password tramite la procedura di reimpostazione o chiedere a un amministratore di fornire una password temporanea.');
SELECT RegisterError('ERR-401-006', 401, 'E', 'auth', 'es', 'Contraseña expirada', 'La contraseña del usuario ha excedido su antigüedad máxima y debe cambiarse antes de que se conceda el acceso.', 'Cambie su contraseña mediante el flujo de restablecimiento de contraseña o solicite a un administrador que emita una contraseña temporal.');

-- ERR-401-007: SignatureError
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'en', 'Signature is incorrect or missing', 'The request signature is either missing or does not match the expected value, indicating possible tampering.', 'Ensure the request is signed with the correct key and algorithm. Regenerate the signature and retry.');
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'ru', 'Подпись не верна или отсутствует');
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'de', 'Signatur ist falsch oder fehlt', 'Die Anforderungssignatur fehlt oder stimmt nicht mit dem erwarteten Wert überein, was auf eine mögliche Manipulation hindeutet.', 'Stellen Sie sicher, dass die Anfrage mit dem richtigen Schlüssel und Algorithmus signiert ist. Generieren Sie die Signatur neu und versuchen Sie es erneut.');
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'fr', 'La signature est incorrecte ou manquante', 'La signature de la requête est manquante ou ne correspond pas à la valeur attendue, ce qui indique une possible falsification.', 'Assurez-vous que la requête est signée avec la bonne clé et le bon algorithme. Régénérez la signature et réessayez.');
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'it', 'La firma è errata o mancante', 'La firma della richiesta è mancante o non corrisponde al valore atteso, indicando una possibile manomissione.', 'Assicurarsi che la richiesta sia firmata con la chiave e l''algoritmo corretti. Rigenerare la firma e riprovare.');
SELECT RegisterError('ERR-401-007', 401, 'E', 'auth', 'es', 'La firma es incorrecta o falta', 'La firma de la solicitud falta o no coincide con el valor esperado, lo que indica una posible manipulación.', 'Asegúrese de que la solicitud esté firmada con la clave y el algoritmo correctos. Regenere la firma e intente de nuevo.');

--------------------------------------------------------------------------------
-- Group 403: Token expiration -------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-403-001: TokenExpired
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'en', 'Token not FOUND or has expired', 'The access token was not found in the database or has passed its expiration time.', 'Obtain a new token by re-authenticating. Ensure your client refreshes tokens before they expire.');
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'ru', 'Маркер не найден или истек срок его действия');
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'de', 'Token nicht gefunden oder abgelaufen', 'Das Zugriffstoken wurde in der Datenbank nicht gefunden oder hat seine Gültigkeitsdauer überschritten.', 'Erhalten Sie ein neues Token durch erneute Authentifizierung. Stellen Sie sicher, dass Ihr Client Token vor Ablauf erneuert.');
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'fr', 'Le jeton est introuvable ou a expiré', 'Le jeton d''accès n''a pas été trouvé dans la base de données ou a dépassé sa date d''expiration.', 'Obtenez un nouveau jeton en vous réauthentifiant. Assurez-vous que votre client renouvelle les jetons avant leur expiration.');
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'it', 'Il token non è stato trovato o è scaduto', 'Il token di accesso non è stato trovato nel database o ha superato il tempo di scadenza.', 'Ottenere un nuovo token riautenticandosi. Assicurarsi che il client rinnovi i token prima della scadenza.');
SELECT RegisterError('ERR-403-001', 403, 'E', 'access', 'es', 'Token no encontrado o ha expirado', 'El token de acceso no se encontró en la base de datos o ha superado su tiempo de expiración.', 'Obtenga un nuevo token reautenticándose. Asegúrese de que su cliente renueve los tokens antes de que expiren.');

--------------------------------------------------------------------------------
-- Group 400: Access errors ----------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-001: AccessDenied
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'en', 'Access denied', 'The current user does not have the required permissions to perform the requested operation.', 'Verify the user''s role and permissions. Request the necessary access from an administrator.');
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'ru', 'Доступ запрещен');
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'de', 'Zugriff verweigert', 'Der aktuelle Benutzer verfügt nicht über die erforderlichen Berechtigungen, um die angeforderte Operation durchzuführen.', 'Überprüfen Sie die Rolle und die Berechtigungen des Benutzers. Fordern Sie den erforderlichen Zugang bei einem Administrator an.');
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'fr', 'Accès refusé', 'L''utilisateur actuel ne dispose pas des permissions requises pour effectuer l''opération demandée.', 'Vérifiez le rôle et les permissions de l''utilisateur. Demandez l''accès nécessaire à un administrateur.');
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'it', 'Accesso negato', 'L''utente corrente non dispone dei permessi necessari per eseguire l''operazione richiesta.', 'Verificare il ruolo e i permessi dell''utente. Richiedere l''accesso necessario a un amministratore.');
SELECT RegisterError('ERR-400-001', 400, 'E', 'access', 'es', 'Acceso denegado', 'El usuario actual no tiene los permisos necesarios para realizar la operación solicitada.', 'Verifique el rol y los permisos del usuario. Solicite el acceso necesario a un administrador.');

-- ERR-400-002: AccessDeniedForUser
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'en', 'Access denied for user %s', 'The specified user lacks the permissions required for this operation.', 'Grant the required permissions to the user or perform the operation under an authorized account.');
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'ru', 'Для пользователя %s данное действие запрещено');
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'de', 'Zugriff verweigert für Benutzer %s', 'Der angegebene Benutzer verfügt nicht über die für diese Operation erforderlichen Berechtigungen.', 'Gewähren Sie dem Benutzer die erforderlichen Berechtigungen oder führen Sie die Operation unter einem autorisierten Konto durch.');
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'fr', 'Accès refusé pour l''utilisateur %s', 'L''utilisateur spécifié ne dispose pas des permissions requises pour cette opération.', 'Accordez les permissions nécessaires à l''utilisateur ou effectuez l''opération sous un compte autorisé.');
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'it', 'Accesso negato per l''utente %s', 'L''utente specificato non dispone dei permessi necessari per questa operazione.', 'Concedere i permessi necessari all''utente o eseguire l''operazione con un account autorizzato.');
SELECT RegisterError('ERR-400-002', 400, 'E', 'access', 'es', 'Acceso denegado para el usuario %s', 'El usuario especificado carece de los permisos necesarios para esta operación.', 'Otorgue los permisos necesarios al usuario o realice la operación con una cuenta autorizada.');

-- ERR-400-003: ExecuteMethodError
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'en', 'Insufficient rights to execute method: %s', 'The user''s access control list does not include permission for the requested method on this object.', 'Check the method''s AMU entry and grant the user the required ACU permission, or use an account with sufficient rights.');
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'ru', 'Недостаточно прав для выполнения метода: %s');
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'de', 'Unzureichende Rechte zum Ausführen der Methode: %s', 'Die Zugriffssteuerungsliste des Benutzers enthält keine Berechtigung für die angeforderte Methode an diesem Objekt.', 'Überprüfen Sie den AMU-Eintrag der Methode und gewähren Sie dem Benutzer die erforderliche ACU-Berechtigung oder verwenden Sie ein Konto mit ausreichenden Rechten.');
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'fr', 'Droits insuffisants pour exécuter la méthode: %s', 'La liste de contrôle d''accès de l''utilisateur n''inclut pas la permission pour la méthode demandée sur cet objet.', 'Vérifiez l''entrée AMU de la méthode et accordez à l''utilisateur la permission ACU requise, ou utilisez un compte avec des droits suffisants.');
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'it', 'Diritti insufficienti per eseguire il metodo: %s', 'La lista di controllo degli accessi dell''utente non include il permesso per il metodo richiesto su questo oggetto.', 'Verificare la voce AMU del metodo e concedere all''utente il permesso ACU richiesto, oppure utilizzare un account con diritti sufficienti.');
SELECT RegisterError('ERR-400-003', 400, 'E', 'access', 'es', 'Derechos insuficientes para ejecutar el método: %s', 'La lista de control de acceso del usuario no incluye el permiso para el método solicitado en este objeto.', 'Verifique la entrada AMU del método y otorgue al usuario el permiso ACU requerido, o utilice una cuenta con derechos suficientes.');

--------------------------------------------------------------------------------
-- Group 400: Auth errors ------------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-004: NonceExpired
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'en', 'Request timed out', 'The request nonce has expired, meaning the request took too long to reach the server.', 'Retry the request immediately. Ensure the client clock is synchronized and network latency is acceptable.');
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'ru', 'Истекло время запроса');
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'de', 'Zeitüberschreitung der Anfrage', 'Der Anforderungs-Nonce ist abgelaufen, was bedeutet, dass die Anfrage zu lange gebraucht hat, um den Server zu erreichen.', 'Wiederholen Sie die Anfrage sofort. Stellen Sie sicher, dass die Client-Uhr synchronisiert ist und die Netzwerklatenz akzeptabel ist.');
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'fr', 'La requête a expiré', 'Le nonce de la requête a expiré, ce qui signifie que la requête a mis trop de temps à atteindre le serveur.', 'Réessayez la requête immédiatement. Assurez-vous que l''horloge du client est synchronisée et que la latence réseau est acceptable.');
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'it', 'La richiesta è scaduta', 'Il nonce della richiesta è scaduto, il che significa che la richiesta ha impiegato troppo tempo per raggiungere il server.', 'Riprovare la richiesta immediatamente. Assicurarsi che l''orologio del client sia sincronizzato e che la latenza di rete sia accettabile.');
SELECT RegisterError('ERR-400-004', 400, 'E', 'auth', 'es', 'Tiempo de solicitud agotado', 'El nonce de la solicitud ha expirado, lo que significa que la solicitud tardó demasiado en llegar al servidor.', 'Reintente la solicitud inmediatamente. Asegúrese de que el reloj del cliente esté sincronizado y la latencia de red sea aceptable.');

-- ERR-400-005: TokenError
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'en', 'Token invalid', 'The provided token is malformed or cannot be validated by the server.', 'Obtain a new token by re-authenticating. Verify the token format matches the expected scheme.');
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'ru', 'Маркер недействителен');
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'de', 'Token ungültig', 'Das bereitgestellte Token ist fehlerhaft oder kann vom Server nicht validiert werden.', 'Erhalten Sie ein neues Token durch erneute Authentifizierung. Überprüfen Sie, ob das Token-Format dem erwarteten Schema entspricht.');
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'fr', 'Jeton invalide', 'Le jeton fourni est malformé ou ne peut pas être validé par le serveur.', 'Obtenez un nouveau jeton en vous réauthentifiant. Vérifiez que le format du jeton correspond au schéma attendu.');
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'it', 'Token non valido', 'Il token fornito è malformato o non può essere validato dal server.', 'Ottenere un nuovo token riautenticandosi. Verificare che il formato del token corrisponda allo schema previsto.');
SELECT RegisterError('ERR-400-005', 400, 'E', 'auth', 'es', 'Token no válido', 'El token proporcionado está malformado o no puede ser validado por el servidor.', 'Obtenga un nuevo token reautenticándose. Verifique que el formato del token coincida con el esquema esperado.');

-- ERR-400-006: TokenBelong
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'en', 'Token belongs to the other client', 'The token presented was issued to a different OAuth client and cannot be used by the current one.', 'Use a token issued specifically for this client application. Re-authenticate under the correct client ID.');
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'ru', 'Маркер принадлежит другому клиенту');
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'de', 'Token gehört einem anderen Client', 'Das vorgelegte Token wurde für einen anderen OAuth-Client ausgestellt und kann vom aktuellen nicht verwendet werden.', 'Verwenden Sie ein Token, das speziell für diese Client-Anwendung ausgestellt wurde. Authentifizieren Sie sich erneut unter der richtigen Client-ID.');
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'fr', 'Le jeton appartient à un autre client', 'Le jeton présenté a été émis pour un autre client OAuth et ne peut pas être utilisé par le client actuel.', 'Utilisez un jeton émis spécifiquement pour cette application cliente. Réauthentifiez-vous sous le bon identifiant client.');
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'it', 'Il token appartiene a un altro client', 'Il token presentato è stato emesso per un altro client OAuth e non può essere utilizzato da quello corrente.', 'Utilizzare un token emesso specificamente per questa applicazione client. Riautenticarsi con l''ID client corretto.');
SELECT RegisterError('ERR-400-006', 400, 'E', 'auth', 'es', 'El token pertenece a otro cliente', 'El token presentado fue emitido para otro cliente OAuth y no puede ser utilizado por el actual.', 'Utilice un token emitido específicamente para esta aplicación cliente. Reautentíquese con el ID de cliente correcto.');

-- ERR-400-007: InvalidScope
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'en', 'Some requested areas were invalid: {valid=[%s], invalid=[%s]}', 'The OAuth scope request contains area identifiers that are not recognized by the system.', 'Remove the invalid scope values and retry with only the valid ones listed in the error message.');
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'ru', 'Некоторые из запрошенных областей недействительны: {верные=[%s], неверные=[%s]}');
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'de', 'Einige angeforderte Bereiche waren ungültig: {gültig=[%s], ungültig=[%s]}', 'Die OAuth-Bereichsanforderung enthält Bereichskennungen, die vom System nicht erkannt werden.', 'Entfernen Sie die ungültigen Bereichswerte und versuchen Sie es erneut nur mit den gültigen, die in der Fehlermeldung aufgeführt sind.');
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'fr', 'Certaines des étendues demandées n''étaient pas valides: {valide=[%s], invalide=[%s]}', 'La demande de portée OAuth contient des identifiants de zone qui ne sont pas reconnus par le système.', 'Supprimez les valeurs de portée non valides et réessayez uniquement avec celles valides indiquées dans le message d''erreur.');
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'it', 'Alcuni ambiti richiesti non erano validi: {valido=[%s], non valido=[%s]}', 'La richiesta di ambito OAuth contiene identificatori di area che non sono riconosciuti dal sistema.', 'Rimuovere i valori di ambito non validi e riprovare solo con quelli validi elencati nel messaggio di errore.');
SELECT RegisterError('ERR-400-007', 400, 'E', 'auth', 'es', 'Algunos ámbitos solicitados no eran válidos: {válido=[%s], no válido=[%s]}', 'La solicitud de ámbito OAuth contiene identificadores de área que no son reconocidos por el sistema.', 'Elimine los valores de ámbito no válidos y reintente solo con los válidos indicados en el mensaje de error.');

--------------------------------------------------------------------------------
-- Group 400: Entity errors ----------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-008: AbstractError
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'en', 'An abstract class cannot have objects', 'An attempt was made to instantiate an object from a class marked as abstract in the entity hierarchy.', 'Use a concrete subclass instead of the abstract class when creating objects.');
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'ru', 'У абстрактного класса не может быть объектов');
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'de', 'Eine abstrakte Klasse kann keine Objekte haben', 'Es wurde versucht, ein Objekt aus einer Klasse zu instanziieren, die in der Entitätshierarchie als abstrakt markiert ist.', 'Verwenden Sie eine konkrete Unterklasse anstelle der abstrakten Klasse beim Erstellen von Objekten.');
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'fr', 'Une classe abstraite ne peut pas avoir d''objets', 'Une tentative a été faite d''instancier un objet à partir d''une classe marquée comme abstraite dans la hiérarchie des entités.', 'Utilisez une sous-classe concrète au lieu de la classe abstraite lors de la création d''objets.');
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'it', 'Una classe astratta non può avere oggetti', 'È stato effettuato un tentativo di istanziare un oggetto da una classe contrassegnata come astratta nella gerarchia delle entità.', 'Utilizzare una sottoclasse concreta invece della classe astratta durante la creazione degli oggetti.');
SELECT RegisterError('ERR-400-008', 400, 'E', 'entity', 'es', 'Una clase abstracta no puede tener objetos', 'Se intentó instanciar un objeto de una clase marcada como abstracta en la jerarquía de entidades.', 'Utilice una subclase concreta en lugar de la clase abstracta al crear objetos.');

-- ERR-400-009: ChangeClassError
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'en', 'Object class change is not allowed', 'The system does not allow changing the class of an existing object after creation.', 'Create a new object with the desired class and migrate the data, then delete the old object.');
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'ru', 'Изменение класса объекта не допускается');
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'de', 'Änderung der Objektklasse ist nicht erlaubt', 'Das System erlaubt keine Änderung der Klasse eines bestehenden Objekts nach der Erstellung.', 'Erstellen Sie ein neues Objekt mit der gewünschten Klasse und migrieren Sie die Daten, dann löschen Sie das alte Objekt.');
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'fr', 'La modification de la classe d''un objet n''est pas autorisée', 'Le système ne permet pas de modifier la classe d''un objet existant après sa création.', 'Créez un nouvel objet avec la classe souhaitée et migrez les données, puis supprimez l''ancien objet.');
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'it', 'La modifica della classe di un oggetto non è consentita', 'Il sistema non consente di modificare la classe di un oggetto esistente dopo la creazione.', 'Creare un nuovo oggetto con la classe desiderata e migrare i dati, quindi eliminare il vecchio oggetto.');
SELECT RegisterError('ERR-400-009', 400, 'E', 'entity', 'es', 'No se permite cambiar la clase del objeto', 'El sistema no permite cambiar la clase de un objeto existente después de su creación.', 'Cree un nuevo objeto con la clase deseada y migre los datos, luego elimine el objeto antiguo.');

-- ERR-400-010: ChangeAreaError
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'en', 'Changing document area is not allowed', 'Once a document is assigned to an area, its area cannot be changed.', 'Create a new document in the target area and transfer the relevant data from the original.');
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'ru', 'Недопустимо изменение области видимости документа');
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'de', 'Änderung des Dokumentbereichs ist nicht erlaubt', 'Sobald ein Dokument einem Bereich zugewiesen ist, kann sein Bereich nicht mehr geändert werden.', 'Erstellen Sie ein neues Dokument im Zielbereich und übertragen Sie die relevanten Daten aus dem Original.');
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'fr', 'La modification de la zone d''un document n''est pas autorisée', 'Une fois qu''un document est attribué à une zone, sa zone ne peut plus être modifiée.', 'Créez un nouveau document dans la zone cible et transférez les données pertinentes depuis l''original.');
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'it', 'La modifica dell''area di un documento non è consentita', 'Una volta che un documento è assegnato a un''area, la sua area non può essere modificata.', 'Creare un nuovo documento nell''area di destinazione e trasferire i dati pertinenti dall''originale.');
SELECT RegisterError('ERR-400-010', 400, 'E', 'entity', 'es', 'No se permite cambiar el área del documento', 'Una vez que un documento es asignado a un área, su área no puede ser cambiada.', 'Cree un nuevo documento en el área de destino y transfiera los datos relevantes del original.');

-- ERR-400-011: IncorrectEntity
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'en', 'Object entity is set incorrectly', 'The entity type specified for the object does not match any registered entity in the system.', 'Verify the entity code and ensure it is registered in the entity hierarchy before creating the object.');
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'ru', 'Неверно задана сущность объекта');
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'de', 'Objektentität ist falsch gesetzt', 'Der für das Objekt angegebene Entitätstyp stimmt mit keiner registrierten Entität im System überein.', 'Überprüfen Sie den Entitätscode und stellen Sie sicher, dass er in der Entitätshierarchie registriert ist, bevor Sie das Objekt erstellen.');
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'fr', 'L''entité de l''objet est mal définie', 'Le type d''entité spécifié pour l''objet ne correspond à aucune entité enregistrée dans le système.', 'Vérifiez le code de l''entité et assurez-vous qu''il est enregistré dans la hiérarchie des entités avant de créer l''objet.');
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'it', 'L''entità dell''oggetto non è impostata correttamente', 'Il tipo di entità specificato per l''oggetto non corrisponde a nessuna entità registrata nel sistema.', 'Verificare il codice dell''entità e assicurarsi che sia registrato nella gerarchia delle entità prima di creare l''oggetto.');
SELECT RegisterError('ERR-400-011', 400, 'E', 'entity', 'es', 'La entidad del objeto está configurada incorrectamente', 'El tipo de entidad especificado para el objeto no coincide con ninguna entidad registrada en el sistema.', 'Verifique el código de la entidad y asegúrese de que esté registrada en la jerarquía de entidades antes de crear el objeto.');

-- ERR-400-012: IncorrectClassType
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'en', 'Invalid object type', 'The object type supplied does not correspond to any known type in the class registry.', 'Check the available object types and provide a valid type identifier.');
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'ru', 'Неверно задан тип объекта');
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'de', 'Ungültiger Objekttyp', 'Der angegebene Objekttyp entspricht keinem bekannten Typ im Klassenregister.', 'Überprüfen Sie die verfügbaren Objekttypen und geben Sie einen gültigen Typbezeichner an.');
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'fr', 'Type d''objet invalide', 'Le type d''objet fourni ne correspond à aucun type connu dans le registre des classes.', 'Vérifiez les types d''objets disponibles et fournissez un identifiant de type valide.');
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'it', 'Tipo di oggetto non valido', 'Il tipo di oggetto fornito non corrisponde a nessun tipo conosciuto nel registro delle classi.', 'Verificare i tipi di oggetto disponibili e fornire un identificatore di tipo valido.');
SELECT RegisterError('ERR-400-012', 400, 'E', 'entity', 'es', 'Tipo de objeto no válido', 'El tipo de objeto proporcionado no corresponde a ningún tipo conocido en el registro de clases.', 'Verifique los tipos de objeto disponibles y proporcione un identificador de tipo válido.');

-- ERR-400-013: IncorrectDocumentType
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'en', 'Invalid document type', 'The document type supplied does not correspond to any registered document type.', 'Check the available document types and provide a valid type identifier.');
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'ru', 'Неверно задан тип документа');
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'de', 'Ungültiger Dokumenttyp', 'Der angegebene Dokumenttyp entspricht keinem registrierten Dokumenttyp.', 'Überprüfen Sie die verfügbaren Dokumenttypen und geben Sie einen gültigen Typbezeichner an.');
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'fr', 'Type de document invalide', 'Le type de document fourni ne correspond à aucun type de document enregistré.', 'Vérifiez les types de documents disponibles et fournissez un identifiant de type valide.');
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'it', 'Tipo di documento non valido', 'Il tipo di documento fornito non corrisponde a nessun tipo di documento registrato.', 'Verificare i tipi di documento disponibili e fornire un identificatore di tipo valido.');
SELECT RegisterError('ERR-400-013', 400, 'E', 'entity', 'es', 'Tipo de documento no válido', 'El tipo de documento proporcionado no corresponde a ningún tipo de documento registrado.', 'Verifique los tipos de documento disponibles y proporcione un identificador de tipo válido.');

--------------------------------------------------------------------------------
-- Group 400: Validation errors ------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-014: IncorrectLocaleCode
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'en', 'Locale not FOUND by code: %s', 'No locale record exists for the given locale code.', 'Provide a valid locale code (e.g., en, ru, de). Check the locale table for supported codes.');
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'ru', 'Не найден идентификатор языка по коду: %s');
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'de', 'Sprache nicht gefunden nach Code: %s', 'Für den angegebenen Sprachcode existiert kein Sprachdatensatz.', 'Geben Sie einen gültigen Sprachcode an (z.B. en, ru, de). Überprüfen Sie die Sprachtabelle für unterstützte Codes.');
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'fr', 'Langue non trouvée par code: %s', 'Aucun enregistrement de langue n''existe pour le code de langue donné.', 'Fournissez un code de langue valide (p. ex. en, ru, de). Consultez la table des langues pour les codes pris en charge.');
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'it', 'Lingua non trovata per codice: %s', 'Non esiste alcun record di lingua per il codice di lingua specificato.', 'Fornire un codice di lingua valido (ad es. en, ru, de). Verificare la tabella delle lingue per i codici supportati.');
SELECT RegisterError('ERR-400-014', 400, 'E', 'validation', 'es', 'Idioma no encontrado por código: %s', 'No existe ningún registro de idioma para el código de idioma proporcionado.', 'Proporcione un código de idioma válido (p. ej., en, ru, de). Consulte la tabla de idiomas para los códigos admitidos.');

-- ERR-400-015: RootAreaError
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'en', 'Operations with documents in root area are prohibited', 'The root area is a system-level container; creating or modifying documents directly in it is forbidden.', 'Move the document to a child area before performing the operation.');
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'ru', 'Запрещены операции с документами в корневой области.');
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'de', 'Operationen mit Dokumenten im Stammbereich sind verboten', 'Der Stammbereich ist ein Container auf Systemebene; das Erstellen oder Ändern von Dokumenten direkt darin ist verboten.', 'Verschieben Sie das Dokument in einen Unterbereich, bevor Sie die Operation durchführen.');
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'fr', 'Les opérations sur les documents dans la zone racine sont interdites', 'La zone racine est un conteneur au niveau du système ; la création ou la modification de documents directement à l''intérieur est interdite.', 'Déplacez le document vers une zone enfant avant d''effectuer l''opération.');
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'it', 'Le operazioni con i documenti nell''area root sono vietate', 'L''area root è un contenitore a livello di sistema; la creazione o la modifica di documenti direttamente al suo interno è vietata.', 'Spostare il documento in un''area secondaria prima di eseguire l''operazione.');
SELECT RegisterError('ERR-400-015', 400, 'E', 'access', 'es', 'Las operaciones con documentos en el área raíz están prohibidas', 'El área raíz es un contenedor a nivel del sistema; crear o modificar documentos directamente en ella está prohibido.', 'Mueva el documento a un área secundaria antes de realizar la operación.');

-- ERR-400-016: AreaError
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'en', 'Area not FOUND by specified identifier', 'The area identifier provided does not match any existing area record in the database.', 'Verify the area UUID is correct. List available areas and use a valid identifier.');
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'ru', 'Область с указанным идентификатором не найдена');
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'de', 'Bereich nicht gefunden mit der angegebenen Kennung', 'Die angegebene Bereichskennung stimmt mit keinem vorhandenen Bereichsdatensatz in der Datenbank überein.', 'Überprüfen Sie, ob die Bereichs-UUID korrekt ist. Listen Sie die verfügbaren Bereiche auf und verwenden Sie eine gültige Kennung.');
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'fr', 'Zone non trouvée par l''identifiant spécifié', 'L''identifiant de zone fourni ne correspond à aucun enregistrement de zone existant dans la base de données.', 'Vérifiez que l''UUID de la zone est correct. Listez les zones disponibles et utilisez un identifiant valide.');
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'it', 'Area non trovata dall''identificatore specificato', 'L''identificatore di area fornito non corrisponde a nessun record di area esistente nel database.', 'Verificare che l''UUID dell''area sia corretto. Elencare le aree disponibili e utilizzare un identificatore valido.');
SELECT RegisterError('ERR-400-016', 400, 'E', 'entity', 'es', 'Área no encontrada por el identificador especificado', 'El identificador de área proporcionado no coincide con ningún registro de área existente en la base de datos.', 'Verifique que el UUID del área sea correcto. Liste las áreas disponibles y utilice un identificador válido.');

-- ERR-400-017: IncorrectAreaCode
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'en', 'Area not FOUND by code: %s', 'No area record was found matching the provided code.', 'Verify the area code is correct. List available areas and use a valid code.');
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'ru', 'Область не найдена по коду: %s');
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'de', 'Bereich nicht gefunden nach Code: %s', 'Kein Bereichsdatensatz wurde für den angegebenen Code gefunden.', 'Überprüfen Sie, ob der Bereichscode korrekt ist. Listen Sie die verfügbaren Bereiche auf und verwenden Sie einen gültigen Code.');
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'fr', 'Zone non trouvée par code: %s', 'Aucun enregistrement de zone n''a été trouvé correspondant au code fourni.', 'Vérifiez que le code de zone est correct. Listez les zones disponibles et utilisez un code valide.');
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'it', 'Area non trovata per codice: %s', 'Nessun record di area è stato trovato corrispondente al codice fornito.', 'Verificare che il codice dell''area sia corretto. Elencare le aree disponibili e utilizzare un codice valido.');
SELECT RegisterError('ERR-400-017', 400, 'E', 'entity', 'es', 'Área no encontrada por código: %s', 'No se encontró ningún registro de área que coincida con el código proporcionado.', 'Verifique que el código del área sea correcto. Liste las áreas disponibles y utilice un código válido.');

-- ERR-400-018: UserNotMemberArea
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'en', 'User "%s" does not have access to area "%s"', 'The specified user has not been granted membership in the given area.', 'Add the user to the area via the area membership management functions.');
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'ru', 'Пользователь "%s" не имеет доступа к области "%s"');
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'de', 'Benutzer "%s" hat keinen Zugriff auf den Bereich "%s"', 'Dem angegebenen Benutzer wurde keine Mitgliedschaft im angegebenen Bereich gewährt.', 'Fügen Sie den Benutzer über die Bereichsmitgliedschaftsverwaltungsfunktionen zum Bereich hinzu.');
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'fr', 'L''utilisateur "%s" n''a pas accès à la zone "%s"', 'L''utilisateur spécifié n''a pas obtenu l''adhésion à la zone donnée.', 'Ajoutez l''utilisateur à la zone via les fonctions de gestion des membres de zone.');
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'it', 'L''utente "%s" non ha accesso all''area "%s"', 'All''utente specificato non è stata concessa l''appartenenza all''area indicata.', 'Aggiungere l''utente all''area tramite le funzioni di gestione dell''appartenenza all''area.');
SELECT RegisterError('ERR-400-018', 400, 'E', 'access', 'es', 'El usuario "%s" no tiene acceso al área "%s"', 'Al usuario especificado no se le ha otorgado membresía en el área indicada.', 'Agregue al usuario al área mediante las funciones de gestión de membresía del área.');

-- ERR-400-019: InterfaceError
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'en', 'Interface not FOUND by specified identifier', 'The interface identifier provided does not match any registered interface.', 'Verify the interface UUID. List available interfaces and use a valid identifier.');
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'ru', 'Не найден интерфейс с указанным идентификатором');
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'de', 'Schnittstelle nicht gefunden mit der angegebenen Kennung', 'Die angegebene Schnittstellenkennung stimmt mit keiner registrierten Schnittstelle überein.', 'Überprüfen Sie die Schnittstellen-UUID. Listen Sie die verfügbaren Schnittstellen auf und verwenden Sie eine gültige Kennung.');
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'fr', 'Interface non trouvée par l''identifiant spécifié', 'L''identifiant d''interface fourni ne correspond à aucune interface enregistrée.', 'Vérifiez l''UUID de l''interface. Listez les interfaces disponibles et utilisez un identifiant valide.');
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'it', 'Interfaccia non trovata dall''identificatore specificato', 'L''identificatore di interfaccia fornito non corrisponde a nessuna interfaccia registrata.', 'Verificare l''UUID dell''interfaccia. Elencare le interfacce disponibili e utilizzare un identificatore valido.');
SELECT RegisterError('ERR-400-019', 400, 'E', 'entity', 'es', 'Interfaz no encontrada por el identificador especificado', 'El identificador de interfaz proporcionado no coincide con ninguna interfaz registrada.', 'Verifique el UUID de la interfaz. Liste las interfaces disponibles y utilice un identificador válido.');

-- ERR-400-020: UserNotMemberInterface
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'en', 'User "%s" does not have access to interface "%s"', 'The specified user has not been granted access to the given interface.', 'Add the user to the interface via the interface membership management functions.');
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'ru', 'У пользователя "%s" нет доступа к интерфейсу "%s"');
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'de', 'Benutzer "%s" hat keinen Zugriff auf die Schnittstelle "%s"', 'Dem angegebenen Benutzer wurde kein Zugang zur angegebenen Schnittstelle gewährt.', 'Fügen Sie den Benutzer über die Schnittstellenmitgliedschaftsverwaltungsfunktionen zur Schnittstelle hinzu.');
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'fr', 'L''utilisateur "%s" n''a pas accès à l''interface "%s"', 'L''utilisateur spécifié n''a pas obtenu l''accès à l''interface donnée.', 'Ajoutez l''utilisateur à l''interface via les fonctions de gestion des membres de l''interface.');
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'it', 'L''utente "%s" non ha accesso all''interfaccia "%s"', 'All''utente specificato non è stato concesso l''accesso all''interfaccia indicata.', 'Aggiungere l''utente all''interfaccia tramite le funzioni di gestione dell''appartenenza all''interfaccia.');
SELECT RegisterError('ERR-400-020', 400, 'E', 'access', 'es', 'El usuario "%s" no tiene acceso a la interfaz "%s"', 'Al usuario especificado no se le ha otorgado acceso a la interfaz indicada.', 'Agregue al usuario a la interfaz mediante las funciones de gestión de membresía de la interfaz.');

-- ERR-400-021: UnknownRoleName
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'en', 'Unknown role name: %s', 'The role name provided is not recognized by the system.', 'Check the list of registered roles and provide a valid role name.');
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'ru', 'Неизвестное имя роли: %s');
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'de', 'Unbekannter Rollenname: %s', 'Der angegebene Rollenname wird vom System nicht erkannt.', 'Überprüfen Sie die Liste der registrierten Rollen und geben Sie einen gültigen Rollennamen an.');
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'fr', 'Nom de rôle inconnu: %s', 'Le nom de rôle fourni n''est pas reconnu par le système.', 'Vérifiez la liste des rôles enregistrés et fournissez un nom de rôle valide.');
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'it', 'Nome ruolo sconosciuto: %s', 'Il nome del ruolo fornito non è riconosciuto dal sistema.', 'Verificare l''elenco dei ruoli registrati e fornire un nome di ruolo valido.');
SELECT RegisterError('ERR-400-021', 400, 'E', 'entity', 'es', 'Nombre de rol desconocido: %s', 'El nombre de rol proporcionado no es reconocido por el sistema.', 'Verifique la lista de roles registrados y proporcione un nombre de rol válido.');

-- ERR-400-022: RoleExists
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'en', 'Role "%s" already exists', 'A role with the given name already exists in the system and cannot be created again.', 'Use a different role name or modify the existing role instead of creating a duplicate.');
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'ru', 'Роль "%s" уже существует');
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'de', 'Rolle "%s" existiert bereits', 'Eine Rolle mit dem angegebenen Namen existiert bereits im System und kann nicht erneut erstellt werden.', 'Verwenden Sie einen anderen Rollennamen oder ändern Sie die vorhandene Rolle, anstatt ein Duplikat zu erstellen.');
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'fr', 'Le rôle "%s" existe déjà', 'Un rôle avec le nom donné existe déjà dans le système et ne peut pas être créé à nouveau.', 'Utilisez un nom de rôle différent ou modifiez le rôle existant au lieu de créer un doublon.');
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'it', 'Il ruolo "%s" esiste già', 'Un ruolo con il nome specificato esiste già nel sistema e non può essere creato di nuovo.', 'Utilizzare un nome di ruolo diverso o modificare il ruolo esistente invece di crearne un duplicato.');
SELECT RegisterError('ERR-400-022', 400, 'E', 'entity', 'es', 'El rol "%s" ya existe', 'Un rol con el nombre proporcionado ya existe en el sistema y no puede ser creado nuevamente.', 'Utilice un nombre de rol diferente o modifique el rol existente en lugar de crear un duplicado.');

-- ERR-400-023: UserNotFound
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'en', 'User "%s" does not exist', 'No user account was found with the specified username.', 'Verify the username spelling. Use the user search function to confirm the account exists.');
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'ru', 'Пользователь "%s" не существует');
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'de', 'Benutzer "%s" existiert nicht', 'Kein Benutzerkonto mit dem angegebenen Benutzernamen wurde gefunden.', 'Überprüfen Sie die Schreibweise des Benutzernamens. Verwenden Sie die Benutzersuche, um zu bestätigen, dass das Konto existiert.');
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'fr', 'L''utilisateur "%s" n''existe pas', 'Aucun compte utilisateur n''a été trouvé avec le nom d''utilisateur spécifié.', 'Vérifiez l''orthographe du nom d''utilisateur. Utilisez la fonction de recherche d''utilisateurs pour confirmer que le compte existe.');
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'it', 'L''utente "%s" non esiste', 'Nessun account utente è stato trovato con il nome utente specificato.', 'Verificare l''ortografia del nome utente. Utilizzare la funzione di ricerca utenti per confermare che l''account esiste.');
SELECT RegisterError('ERR-400-023', 400, 'E', 'entity', 'es', 'El usuario "%s" no existe', 'No se encontró ninguna cuenta de usuario con el nombre de usuario especificado.', 'Verifique la ortografía del nombre de usuario. Utilice la función de búsqueda de usuarios para confirmar que la cuenta existe.');

-- ERR-400-024: UserIdNotFound
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'en', 'User with id "%s" does not exist', 'No user account was found with the specified UUID.', 'Verify the user UUID is correct. Use the user search function to find the valid identifier.');
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'ru', 'Пользователь с идентификатором "%s" не существует');
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'de', 'Benutzer mit ID "%s" existiert nicht', 'Kein Benutzerkonto mit der angegebenen UUID wurde gefunden.', 'Überprüfen Sie, ob die Benutzer-UUID korrekt ist. Verwenden Sie die Benutzersuche, um den gültigen Bezeichner zu finden.');
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'fr', 'Utilisateur avec id "%s" n''existe pas', 'Aucun compte utilisateur n''a été trouvé avec l''UUID spécifié.', 'Vérifiez que l''UUID de l''utilisateur est correct. Utilisez la fonction de recherche d''utilisateurs pour trouver l''identifiant valide.');
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'it', 'Utente con id "%s" non esiste', 'Nessun account utente è stato trovato con l''UUID specificato.', 'Verificare che l''UUID dell''utente sia corretto. Utilizzare la funzione di ricerca utenti per trovare l''identificatore valido.');
SELECT RegisterError('ERR-400-024', 400, 'E', 'entity', 'es', 'El usuario con id "%s" no existe', 'No se encontró ninguna cuenta de usuario con el UUID especificado.', 'Verifique que el UUID del usuario sea correcto. Utilice la función de búsqueda de usuarios para encontrar el identificador válido.');

-- ERR-400-025: DeleteUserError
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'en', 'You cannot delete yourself', 'A user attempted to delete their own account, which is not allowed for safety reasons.', 'Ask another administrator to perform the deletion, or deactivate the account instead.');
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'ru', 'Вы не можете удалить себя');
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'de', 'Sie können sich nicht selbst löschen', 'Ein Benutzer hat versucht, sein eigenes Konto zu löschen, was aus Sicherheitsgründen nicht erlaubt ist.', 'Bitten Sie einen anderen Administrator, die Löschung durchzuführen, oder deaktivieren Sie das Konto stattdessen.');
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'fr', 'Vous ne pouvez pas vous supprimer', 'Un utilisateur a tenté de supprimer son propre compte, ce qui n''est pas autorisé pour des raisons de sécurité.', 'Demandez à un autre administrateur d''effectuer la suppression, ou désactivez le compte à la place.');
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'it', 'Non puoi eliminare te stesso', 'Un utente ha tentato di eliminare il proprio account, il che non è consentito per motivi di sicurezza.', 'Chiedere a un altro amministratore di eseguire l''eliminazione, oppure disattivare l''account.');
SELECT RegisterError('ERR-400-025', 400, 'E', 'access', 'es', 'No puede eliminarse a sí mismo', 'Un usuario intentó eliminar su propia cuenta, lo cual no está permitido por razones de seguridad.', 'Solicite a otro administrador que realice la eliminación, o desactive la cuenta en su lugar.');

-- ERR-400-026: AlreadyExists
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'en', '%s already exists', 'An entity with the same identifying attributes already exists in the system.', 'Use the existing record or choose different identifying attributes for the new entry.');
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'ru', '%s уже существует');
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'de', '%s existiert bereits', 'Eine Entität mit denselben identifizierenden Attributen existiert bereits im System.', 'Verwenden Sie den vorhandenen Datensatz oder wählen Sie andere identifizierende Attribute für den neuen Eintrag.');
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'fr', '%s existe déjà', 'Une entité avec les mêmes attributs d''identification existe déjà dans le système.', 'Utilisez l''enregistrement existant ou choisissez des attributs d''identification différents pour la nouvelle entrée.');
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'it', '%s esiste già', 'Un''entità con gli stessi attributi identificativi esiste già nel sistema.', 'Utilizzare il record esistente o scegliere attributi identificativi diversi per la nuova voce.');
SELECT RegisterError('ERR-400-026', 400, 'E', 'entity', 'es', '%s ya existe', 'Una entidad con los mismos atributos identificativos ya existe en el sistema.', 'Utilice el registro existente o elija atributos identificativos diferentes para la nueva entrada.');

-- ERR-400-027: RecordExists
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'en', 'Entry with code "%s" already exists', 'A record with the specified code already exists in the target table.', 'Choose a unique code or update the existing record instead.');
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'ru', 'Запись с кодом "%s" уже существует');
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'de', 'Eintrag mit Code "%s" existiert bereits', 'Ein Datensatz mit dem angegebenen Code existiert bereits in der Zieltabelle.', 'Wählen Sie einen eindeutigen Code oder aktualisieren Sie den vorhandenen Datensatz stattdessen.');
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'fr', 'L''entrée avec le code "%s" existe déjà', 'Un enregistrement avec le code spécifié existe déjà dans la table cible.', 'Choisissez un code unique ou mettez à jour l''enregistrement existant à la place.');
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'it', 'La voce con codice "%s" esiste già', 'Un record con il codice specificato esiste già nella tabella di destinazione.', 'Scegliere un codice univoco o aggiornare il record esistente.');
SELECT RegisterError('ERR-400-027', 400, 'E', 'entity', 'es', 'La entrada con código "%s" ya existe', 'Un registro con el código especificado ya existe en la tabla de destino.', 'Elija un código único o actualice el registro existente en su lugar.');

-- ERR-400-028: InvalidCodes
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'en', 'Some codes were invalid: {valid=[%s], invalid=[%s]}', 'The request contains codes that are not recognized by the system.', 'Remove the invalid codes listed in the error message and retry with only valid ones.');
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'ru', 'Некоторые коды недействительны: {верные=[%s], неверные=[%s]}');
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'de', 'Einige Codes waren ungültig: {gültig=[%s], ungültig=[%s]}', 'Die Anfrage enthält Codes, die vom System nicht erkannt werden.', 'Entfernen Sie die in der Fehlermeldung aufgeführten ungültigen Codes und versuchen Sie es erneut nur mit gültigen.');
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'fr', 'Certains codes n''étaient pas valides: {valide=[%s], invalide=[%s]}', 'La requête contient des codes qui ne sont pas reconnus par le système.', 'Supprimez les codes non valides indiqués dans le message d''erreur et réessayez uniquement avec les codes valides.');
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'it', 'Alcuni codici non erano validi: {valido=[%s], non valido=[%s]}', 'La richiesta contiene codici che non sono riconosciuti dal sistema.', 'Rimuovere i codici non validi elencati nel messaggio di errore e riprovare solo con quelli validi.');
SELECT RegisterError('ERR-400-028', 400, 'E', 'validation', 'es', 'Algunos códigos no eran válidos: {válido=[%s], no válido=[%s]}', 'La solicitud contiene códigos que no son reconocidos por el sistema.', 'Elimine los códigos no válidos indicados en el mensaje de error y reintente solo con los válidos.');

-- ERR-400-029: IncorrectCode
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'en', 'Invalid code "%s". Valid codes: [%s]', 'The code provided is not among the set of acceptable values.', 'Replace the invalid code with one of the valid codes listed in the error message.');
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'ru', 'Недопустимый код "%s". Допустимые коды: [%s]');
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'de', 'Ungültiger Code "%s". Gültige Codes: [%s]', 'Der angegebene Code gehört nicht zu den akzeptierten Werten.', 'Ersetzen Sie den ungültigen Code durch einen der gültigen Codes, die in der Fehlermeldung aufgeführt sind.');
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'fr', 'Code incorrect "%s". Codes valides: [%s]', 'Le code fourni ne fait pas partie des valeurs acceptées.', 'Remplacez le code non valide par l''un des codes valides indiqués dans le message d''erreur.');
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'it', 'Codice non valido "%s". Codici validi: [%s]', 'Il codice fornito non è tra i valori accettati.', 'Sostituire il codice non valido con uno dei codici validi elencati nel messaggio di errore.');
SELECT RegisterError('ERR-400-029', 400, 'E', 'validation', 'es', 'Código no válido "%s". Códigos válidos: [%s]', 'El código proporcionado no se encuentra entre los valores aceptados.', 'Reemplace el código no válido por uno de los códigos válidos indicados en el mensaje de error.');

-- ERR-400-030: ObjectNotFound
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'en', 'Not FOUND %s with %s: %s', 'The requested entity could not be found using the given lookup criteria.', 'Verify the search parameters are correct and that the record exists in the database.');
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'ru', 'Не найден(а/о) %s по %s: %s');
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'de', 'Nicht gefunden %s mit %s: %s', 'Die angeforderte Entität konnte mit den angegebenen Suchkriterien nicht gefunden werden.', 'Überprüfen Sie, ob die Suchparameter korrekt sind und der Datensatz in der Datenbank existiert.');
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'fr', 'Non trouvé %s avec %s: %s', 'L''entité demandée n''a pas pu être trouvée avec les critères de recherche donnés.', 'Vérifiez que les paramètres de recherche sont corrects et que l''enregistrement existe dans la base de données.');
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'it', 'Non trovato %s con %s: %s', 'L''entità richiesta non è stata trovata utilizzando i criteri di ricerca specificati.', 'Verificare che i parametri di ricerca siano corretti e che il record esista nel database.');
SELECT RegisterError('ERR-400-030', 400, 'E', 'entity', 'es', 'No encontrado %s con %s: %s', 'La entidad solicitada no pudo ser encontrada con los criterios de búsqueda proporcionados.', 'Verifique que los parámetros de búsqueda sean correctos y que el registro exista en la base de datos.');

-- ERR-400-031: ObjectIdIsNull
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'en', 'Not FOUND %s with %s: <null>', 'A required identifier was null when looking up the entity.', 'Provide a non-null value for the required identifier parameter.');
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'ru', 'Не найден(а/о) %s по %s: <null>');
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'de', 'Nicht gefunden %s mit %s: <null>', 'Ein erforderlicher Bezeichner war null bei der Suche nach der Entität.', 'Geben Sie einen nicht-null-Wert für den erforderlichen Bezeichnerparameter an.');
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'fr', 'Non trouvé %s avec %s: <null>', 'Un identifiant requis était null lors de la recherche de l''entité.', 'Fournissez une valeur non nulle pour le paramètre d''identifiant requis.');
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'it', 'Non trovato %s con %s: <null>', 'Un identificatore richiesto era null durante la ricerca dell''entità.', 'Fornire un valore non nullo per il parametro di identificatore richiesto.');
SELECT RegisterError('ERR-400-031', 400, 'E', 'entity', 'es', 'No encontrado %s con %s: <null>', 'Un identificador requerido era nulo al buscar la entidad.', 'Proporcione un valor no nulo para el parámetro de identificador requerido.');

--------------------------------------------------------------------------------
-- Group 400: Workflow errors --------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-032: MethodActionNotFound
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'en', 'Object [%s] method not FOUND, for action: %s [%s]. Current state: %s [%s]', 'No workflow method is available for the requested action given the object''s current state.', 'Check the object''s current state and available transitions. Ensure the action is valid for this state.');
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'ru', 'Не найден метод объекта [%s], для действия: %s [%s]. Текущее состояние: %s [%s]');
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'de', 'Methode des Objekts [%s] nicht gefunden, für Aktion: %s [%s]. Aktueller Status: %s [%s]', 'Für die angeforderte Aktion im aktuellen Status des Objekts ist keine Workflow-Methode verfügbar.', 'Überprüfen Sie den aktuellen Status des Objekts und die verfügbaren Übergänge. Stellen Sie sicher, dass die Aktion für diesen Status gültig ist.');
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'fr', 'Méthode de l''objet [%s] non trouvée, pour l''action: %s [%s]. État actuel: %s [%s]', 'Aucune méthode de workflow n''est disponible pour l''action demandée dans l''état actuel de l''objet.', 'Vérifiez l''état actuel de l''objet et les transitions disponibles. Assurez-vous que l''action est valide pour cet état.');
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'it', 'Metodo dell''oggetto [%s] non trovato, per azione: %s [%s]. Stato attuale: %s [%s]', 'Nessun metodo di workflow è disponibile per l''azione richiesta nello stato corrente dell''oggetto.', 'Verificare lo stato corrente dell''oggetto e le transizioni disponibili. Assicurarsi che l''azione sia valida per questo stato.');
SELECT RegisterError('ERR-400-032', 400, 'E', 'workflow', 'es', 'Método del objeto [%s] no encontrado, para acción: %s [%s]. Estado actual: %s [%s]', 'No hay ningún método de flujo de trabajo disponible para la acción solicitada en el estado actual del objeto.', 'Verifique el estado actual del objeto y las transiciones disponibles. Asegúrese de que la acción sea válida para este estado.');

-- ERR-400-033: MethodNotFound
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'en', 'Method "%s" of object "%s" not FOUND', 'The specified method does not exist for the given object in the workflow registry.', 'Verify the method name and object identifier. List available methods for the object.');
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'ru', 'Не найден метод "%s" объекта "%s"');
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'de', 'Methode "%s" des Objekts "%s" nicht gefunden', 'Die angegebene Methode existiert nicht für das angegebene Objekt im Workflow-Register.', 'Überprüfen Sie den Methodennamen und den Objektbezeichner. Listen Sie die verfügbaren Methoden für das Objekt auf.');
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'fr', 'Méthode "%s" de l''objet "%s" non trouvée', 'La méthode spécifiée n''existe pas pour l''objet donné dans le registre de workflow.', 'Vérifiez le nom de la méthode et l''identifiant de l''objet. Listez les méthodes disponibles pour l''objet.');
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'it', 'Metodo "%s" dell''oggetto "%s" non trovato', 'Il metodo specificato non esiste per l''oggetto indicato nel registro del workflow.', 'Verificare il nome del metodo e l''identificatore dell''oggetto. Elencare i metodi disponibili per l''oggetto.');
SELECT RegisterError('ERR-400-033', 400, 'E', 'workflow', 'es', 'Método "%s" del objeto "%s" no encontrado', 'El método especificado no existe para el objeto indicado en el registro de flujo de trabajo.', 'Verifique el nombre del método y el identificador del objeto. Liste los métodos disponibles para el objeto.');

-- ERR-400-034: MethodByCodeNotFound
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'en', 'No method FOUND by code "%s" for object "%s"', 'No method was found with the given code for the specified object.', 'Verify the method code. List available methods for the object to find the correct code.');
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'ru', 'Не найден метод по коду "%s" для объекта "%s"');
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'de', 'Keine Methode gefunden mit Code "%s" für Objekt "%s"', 'Für das angegebene Objekt wurde keine Methode mit dem angegebenen Code gefunden.', 'Überprüfen Sie den Methodencode. Listen Sie die verfügbaren Methoden für das Objekt auf, um den richtigen Code zu finden.');
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'fr', 'Aucune méthode trouvée par code "%s" pour l''objet "%s"', 'Aucune méthode n''a été trouvée avec le code donné pour l''objet spécifié.', 'Vérifiez le code de la méthode. Listez les méthodes disponibles pour l''objet afin de trouver le bon code.');
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'it', 'Nessun metodo trovato per codice "%s" per oggetto "%s"', 'Nessun metodo è stato trovato con il codice specificato per l''oggetto indicato.', 'Verificare il codice del metodo. Elencare i metodi disponibili per l''oggetto per trovare il codice corretto.');
SELECT RegisterError('ERR-400-034', 400, 'E', 'workflow', 'es', 'No se encontró método por código "%s" para el objeto "%s"', 'No se encontró ningún método con el código proporcionado para el objeto especificado.', 'Verifique el código del método. Liste los métodos disponibles para el objeto para encontrar el código correcto.');

-- ERR-400-035: ChangeObjectStateError
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'en', 'Failed to change object state: %s', 'The workflow engine failed to transition the object to a new state. The placeholder contains the specific reason.', 'Review the error details and ensure all preconditions for the state transition are met.');
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'ru', 'Не удалось изменить состояние объекта: %s');
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'de', 'Änderung des Objektstatus fehlgeschlagen: %s', 'Die Workflow-Engine konnte das Objekt nicht in einen neuen Status überführen. Der Platzhalter enthält den spezifischen Grund.', 'Überprüfen Sie die Fehlerdetails und stellen Sie sicher, dass alle Vorbedingungen für den Statusübergang erfüllt sind.');
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'fr', 'Échec de la modification de l''état de l''objet: %s', 'Le moteur de workflow n''a pas réussi à faire passer l''objet à un nouvel état. L''espace réservé contient la raison spécifique.', 'Examinez les détails de l''erreur et assurez-vous que toutes les conditions préalables pour la transition d''état sont remplies.');
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'it', 'Impossibile modificare lo stato dell''oggetto: %s', 'Il motore di workflow non è riuscito a portare l''oggetto in un nuovo stato. Il segnaposto contiene il motivo specifico.', 'Esaminare i dettagli dell''errore e assicurarsi che tutte le precondizioni per la transizione di stato siano soddisfatte.');
SELECT RegisterError('ERR-400-035', 400, 'E', 'workflow', 'es', 'Error al cambiar el estado del objeto: %s', 'El motor de flujo de trabajo no pudo realizar la transición del objeto a un nuevo estado. El marcador de posición contiene la razón específica.', 'Revise los detalles del error y asegúrese de que se cumplan todas las precondiciones para la transición de estado.');

-- ERR-400-036: ChangesNotAllowed
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'en', 'Changes are not allowed', 'The object is in a state where modifications are not permitted by the workflow.', 'Transition the object to an editable state before making changes.');
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'ru', 'Изменения не допускаются');
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'de', 'Änderungen sind nicht erlaubt', 'Das Objekt befindet sich in einem Status, in dem Änderungen durch den Workflow nicht erlaubt sind.', 'Überführen Sie das Objekt in einen bearbeitbaren Status, bevor Sie Änderungen vornehmen.');
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'fr', 'Les modifications ne sont pas autorisées', 'L''objet est dans un état où les modifications ne sont pas autorisées par le workflow.', 'Faites passer l''objet dans un état modifiable avant d''apporter des modifications.');
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'it', 'Le modifiche non sono consentite', 'L''oggetto si trova in uno stato in cui le modifiche non sono consentite dal workflow.', 'Portare l''oggetto in uno stato modificabile prima di apportare modifiche.');
SELECT RegisterError('ERR-400-036', 400, 'E', 'workflow', 'es', 'Los cambios no están permitidos', 'El objeto se encuentra en un estado en el que las modificaciones no están permitidas por el flujo de trabajo.', 'Transite el objeto a un estado editable antes de realizar cambios.');

-- ERR-400-037: StateByCodeNotFound
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'en', 'No state FOUND by code "%s" for object "%s"', 'No workflow state was found matching the given code for the specified object.', 'Verify the state code. List registered states for the object''s class to find the correct code.');
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'ru', 'Не найдено состояние по коду "%s" для объекта "%s"');
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'de', 'Kein Status gefunden mit Code "%s" für Objekt "%s"', 'Für das angegebene Objekt wurde kein Workflow-Status mit dem angegebenen Code gefunden.', 'Überprüfen Sie den Statuscode. Listen Sie die registrierten Status für die Klasse des Objekts auf, um den richtigen Code zu finden.');
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'fr', 'Aucun état trouvé par code "%s" pour l''objet "%s"', 'Aucun état de workflow n''a été trouvé correspondant au code donné pour l''objet spécifié.', 'Vérifiez le code de l''état. Listez les états enregistrés pour la classe de l''objet afin de trouver le bon code.');
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'it', 'Nessuno stato trovato per codice "%s" per oggetto "%s"', 'Nessuno stato di workflow è stato trovato corrispondente al codice specificato per l''oggetto indicato.', 'Verificare il codice dello stato. Elencare gli stati registrati per la classe dell''oggetto per trovare il codice corretto.');
SELECT RegisterError('ERR-400-037', 400, 'E', 'workflow', 'es', 'No se encontró estado por código "%s" para el objeto "%s"', 'No se encontró ningún estado de flujo de trabajo que coincida con el código proporcionado para el objeto especificado.', 'Verifique el código del estado. Liste los estados registrados para la clase del objeto para encontrar el código correcto.');

-- ERR-400-038: MethodIsEmpty
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'en', 'Method ID must not be empty', 'The method identifier parameter is required but was passed as null or empty.', 'Provide a valid non-empty method UUID in the request.');
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'ru', 'Идентификатор метода не должен быть пустым');
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'de', 'Methoden-ID darf nicht leer sein', 'Der Methodenbezeichner-Parameter ist erforderlich, wurde aber als null oder leer übergeben.', 'Geben Sie eine gültige, nicht leere Methoden-UUID in der Anfrage an.');
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'fr', 'L''ID de la méthode ne doit pas être vide', 'Le paramètre d''identifiant de méthode est requis mais a été transmis comme null ou vide.', 'Fournissez un UUID de méthode valide et non vide dans la requête.');
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'it', 'L''ID del metodo non deve essere vuoto', 'Il parametro dell''identificatore del metodo è richiesto ma è stato passato come null o vuoto.', 'Fornire un UUID del metodo valido e non vuoto nella richiesta.');
SELECT RegisterError('ERR-400-038', 400, 'E', 'validation', 'es', 'El ID del método no debe estar vacío', 'El parámetro de identificador del método es obligatorio pero se proporcionó como nulo o vacío.', 'Proporcione un UUID de método válido y no vacío en la solicitud.');

-- ERR-400-039: ActionIsEmpty
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'en', 'Action ID must not be empty', 'The action identifier parameter is required but was passed as null or empty.', 'Provide a valid non-empty action UUID in the request.');
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'ru', 'Идентификатор действия не должен быть пустым');
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'de', 'Aktions-ID darf nicht leer sein', 'Der Aktionsbezeichner-Parameter ist erforderlich, wurde aber als null oder leer übergeben.', 'Geben Sie eine gültige, nicht leere Aktions-UUID in der Anfrage an.');
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'fr', 'L''ID de l''action ne doit pas être vide', 'Le paramètre d''identifiant d''action est requis mais a été transmis comme null ou vide.', 'Fournissez un UUID d''action valide et non vide dans la requête.');
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'it', 'L''ID dell''azione non deve essere vuoto', 'Il parametro dell''identificatore dell''azione è richiesto ma è stato passato come null o vuoto.', 'Fornire un UUID dell''azione valido e non vuoto nella richiesta.');
SELECT RegisterError('ERR-400-039', 400, 'E', 'validation', 'es', 'El ID de la acción no debe estar vacío', 'El parámetro de identificador de la acción es obligatorio pero se proporcionó como nulo o vacío.', 'Proporcione un UUID de acción válido y no vacío en la solicitud.');

-- ERR-400-040: ExecutorIsEmpty
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'en', 'The executor must not be empty', 'The executor field is required for this operation but was not provided.', 'Specify a valid executor (user or process) for the operation.');
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'ru', 'Исполнитель не должен быть пустым');
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'de', 'Der Ausführende darf nicht leer sein', 'Das Ausführendenfeld ist für diese Operation erforderlich, wurde aber nicht angegeben.', 'Geben Sie einen gültigen Ausführenden (Benutzer oder Prozess) für die Operation an.');
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'fr', 'L''exécuteur ne doit pas être vide', 'Le champ exécuteur est requis pour cette opération mais n''a pas été fourni.', 'Spécifiez un exécuteur valide (utilisateur ou processus) pour l''opération.');
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'it', 'L''esecutore non deve essere vuoto', 'Il campo esecutore è richiesto per questa operazione ma non è stato fornito.', 'Specificare un esecutore valido (utente o processo) per l''operazione.');
SELECT RegisterError('ERR-400-040', 400, 'E', 'validation', 'es', 'El ejecutor no debe estar vacío', 'El campo de ejecutor es obligatorio para esta operación pero no fue proporcionado.', 'Especifique un ejecutor válido (usuario o proceso) para la operación.');

-- ERR-400-041: IncorrectDateInterval
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'en', 'The end date of the period cannot be less than the start date of the period', 'The date range is invalid because the end date precedes the start date.', 'Swap the dates or correct the range so the end date is on or after the start date.');
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'ru', 'Дата окончания периода не может быть меньше даты начала периода');
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'de', 'Das Enddatum des Zeitraums darf nicht vor dem Startdatum des Zeitraums liegen', 'Der Zeitraum ist ungültig, da das Enddatum vor dem Startdatum liegt.', 'Tauschen Sie die Daten aus oder korrigieren Sie den Zeitraum, sodass das Enddatum gleich oder nach dem Startdatum liegt.');
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'fr', 'La date de fin de la période ne peut pas être antérieure à la date de début de la période', 'La plage de dates est invalide car la date de fin précède la date de début.', 'Inversez les dates ou corrigez la plage afin que la date de fin soit égale ou postérieure à la date de début.');
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'it', 'La data di fine del periodo non può essere inferiore alla data di inizio del periodo', 'L''intervallo di date non è valido perché la data di fine precede la data di inizio.', 'Invertire le date o correggere l''intervallo in modo che la data di fine sia uguale o successiva alla data di inizio.');
SELECT RegisterError('ERR-400-041', 400, 'E', 'validation', 'es', 'La fecha de fin del período no puede ser anterior a la fecha de inicio del período', 'El rango de fechas no es válido porque la fecha de fin precede a la fecha de inicio.', 'Intercambie las fechas o corrija el rango para que la fecha de fin sea igual o posterior a la fecha de inicio.');

-- ERR-400-042: UserPasswordChange
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'en', 'Password change failed, password change is prohibited', 'The password change was rejected because the security policy prohibits this user from changing their password.', 'Contact an administrator to change the password or update the policy to allow password changes.');
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'ru', 'Не удалось изменить пароль, установлен запрет на изменение пароля');
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'de', 'Passwortänderung fehlgeschlagen, Passwortänderung ist verboten', 'Die Passwortänderung wurde abgelehnt, da die Sicherheitsrichtlinie diesem Benutzer das Ändern seines Passworts verbietet.', 'Wenden Sie sich an einen Administrator, um das Passwort zu ändern, oder aktualisieren Sie die Richtlinie, um Passwortänderungen zu erlauben.');
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'fr', 'Échec de la modification du mot de passe, la modification du mot de passe est interdite', 'Le changement de mot de passe a été rejeté car la politique de sécurité interdit à cet utilisateur de modifier son mot de passe.', 'Contactez un administrateur pour modifier le mot de passe ou mettez à jour la politique pour autoriser les changements de mot de passe.');
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'it', 'Modifica password non riuscita, la modifica della password è vietata', 'La modifica della password è stata rifiutata perché la politica di sicurezza vieta a questo utente di cambiare la propria password.', 'Contattare un amministratore per modificare la password o aggiornare la politica per consentire le modifiche della password.');
SELECT RegisterError('ERR-400-042', 400, 'E', 'access', 'es', 'Error al cambiar la contraseña, el cambio de contraseña está prohibido', 'El cambio de contraseña fue rechazado porque la política de seguridad prohíbe a este usuario cambiar su contraseña.', 'Contacte con un administrador para cambiar la contraseña o actualice la política para permitir cambios de contraseña.');

-- ERR-400-043: SystemRoleError
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'en', 'Change, delete operations for system roles are prohibited', 'System-defined roles are protected and cannot be modified or deleted.', 'Create a custom role with the desired permissions instead of modifying a system role.');
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'ru', 'Операции изменения, удаления для системных ролей запрещены');
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'de', 'Änderungs- und Löschoperationen für Systemrollen sind verboten', 'Systemdefinierte Rollen sind geschützt und können nicht geändert oder gelöscht werden.', 'Erstellen Sie eine benutzerdefinierte Rolle mit den gewünschten Berechtigungen, anstatt eine Systemrolle zu ändern.');
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'fr', 'Les opérations de modification, de suppression des rôles système sont interdites', 'Les rôles définis par le système sont protégés et ne peuvent être ni modifiés ni supprimés.', 'Créez un rôle personnalisé avec les permissions souhaitées au lieu de modifier un rôle système.');
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'it', 'Le operazioni di modifica, eliminazione per i ruoli di sistema sono vietate', 'I ruoli definiti dal sistema sono protetti e non possono essere modificati o eliminati.', 'Creare un ruolo personalizzato con i permessi desiderati invece di modificare un ruolo di sistema.');
SELECT RegisterError('ERR-400-043', 400, 'E', 'access', 'es', 'Las operaciones de modificación y eliminación de roles del sistema están prohibidas', 'Los roles definidos por el sistema están protegidos y no pueden ser modificados ni eliminados.', 'Cree un rol personalizado con los permisos deseados en lugar de modificar un rol del sistema.');

-- ERR-400-044: LoginIpTableError
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'en', 'Login is not possible. Limited access by IP-address: %s', 'The user''s IP address is not in the allowed list, so login is denied.', 'Connect from an allowed IP address or ask an administrator to update the IP whitelist.');
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'ru', 'Вход в систему невозможен. Ограничен доступ по IP-адресу: %s');
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'de', 'Anmeldung nicht möglich. Eingeschränkter Zugang nach IP-Adresse: %s', 'Die IP-Adresse des Benutzers befindet sich nicht in der erlaubten Liste, daher wird die Anmeldung verweigert.', 'Verbinden Sie sich von einer erlaubten IP-Adresse oder bitten Sie einen Administrator, die IP-Whitelist zu aktualisieren.');
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'fr', 'La connexion n''est pas possible. Accès limité par adresse IP: %s', 'L''adresse IP de l''utilisateur ne figure pas dans la liste autorisée, la connexion est donc refusée.', 'Connectez-vous depuis une adresse IP autorisée ou demandez à un administrateur de mettre à jour la liste blanche des IP.');
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'it', 'Accesso non possibile. Accesso limitato tramite indirizzo IP: %s', 'L''indirizzo IP dell''utente non è nell''elenco consentito, quindi l''accesso è negato.', 'Connettersi da un indirizzo IP consentito o chiedere a un amministratore di aggiornare la whitelist degli IP.');
SELECT RegisterError('ERR-400-044', 400, 'E', 'access', 'es', 'Inicio de sesión no posible. Acceso limitado por dirección IP: %s', 'La dirección IP del usuario no está en la lista permitida, por lo que se deniega el inicio de sesión.', 'Conéctese desde una dirección IP permitida o solicite a un administrador que actualice la lista blanca de IP.');

-- ERR-400-045: OperationNotPossible
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'en', 'Operation is not possible, there are related documents', 'The operation cannot proceed because other documents reference this object.', 'Remove or reassign the related documents before retrying the operation.');
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'ru', 'Операция невозможна, есть связанные документы');
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'de', 'Vorgang nicht möglich, es gibt zugehörige Dokumente', 'Die Operation kann nicht durchgeführt werden, da andere Dokumente auf dieses Objekt verweisen.', 'Entfernen oder übertragen Sie die zugehörigen Dokumente, bevor Sie die Operation erneut versuchen.');
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'fr', 'L''opération n''est pas possible, il existe des documents associés', 'L''opération ne peut pas être effectuée car d''autres documents font référence à cet objet.', 'Supprimez ou réattribuez les documents associés avant de réessayer l''opération.');
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'it', 'Operazione non possibile, sono presenti documenti correlati', 'L''operazione non può procedere perché altri documenti fanno riferimento a questo oggetto.', 'Rimuovere o riassegnare i documenti correlati prima di riprovare l''operazione.');
SELECT RegisterError('ERR-400-045', 400, 'E', 'workflow', 'es', 'La operación no es posible, hay documentos relacionados', 'La operación no puede continuar porque otros documentos hacen referencia a este objeto.', 'Elimine o reasigne los documentos relacionados antes de reintentar la operación.');

-- ERR-400-046: ViewNotFound
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'en', 'View "%s.%s" not FOUND', 'The specified database view does not exist in the given schema.', 'Verify the schema and view names. Run the update script to ensure all views are created.');
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'ru', 'Представление "%s.%s" не найдено');
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'de', 'Ansicht "%s.%s" nicht gefunden', 'Die angegebene Datenbankansicht existiert nicht im angegebenen Schema.', 'Überprüfen Sie den Schema- und Ansichtsnamen. Führen Sie das Update-Skript aus, um sicherzustellen, dass alle Ansichten erstellt sind.');
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'fr', 'Vue "%s.%s" non trouvée', 'La vue de base de données spécifiée n''existe pas dans le schéma donné.', 'Vérifiez les noms du schéma et de la vue. Exécutez le script de mise à jour pour vous assurer que toutes les vues sont créées.');
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'it', 'Vista "%s.%s" non trovata', 'La vista del database specificata non esiste nello schema indicato.', 'Verificare i nomi dello schema e della vista. Eseguire lo script di aggiornamento per assicurarsi che tutte le viste siano create.');
SELECT RegisterError('ERR-400-046', 400, 'E', 'entity', 'es', 'Vista "%s.%s" no encontrada', 'La vista de base de datos especificada no existe en el esquema indicado.', 'Verifique los nombres del esquema y la vista. Ejecute el script de actualización para asegurarse de que todas las vistas estén creadas.');

-- ERR-400-047: InvalidVerificationCodeType
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'en', 'Invalid verification type code: %s', 'The verification type code provided is not recognized by the verification subsystem.', 'Use a valid verification type code. Check the verification module for supported types.');
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'ru', 'Недопустимый код типа верификации: %s');
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'de', 'Ungültiger Verifizierungstypcode: %s', 'Der angegebene Verifizierungstypcode wird vom Verifizierungssubsystem nicht erkannt.', 'Verwenden Sie einen gültigen Verifizierungstypcode. Überprüfen Sie das Verifizierungsmodul für unterstützte Typen.');
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'fr', 'Code de type de vérification non valide: %s', 'Le code de type de vérification fourni n''est pas reconnu par le sous-système de vérification.', 'Utilisez un code de type de vérification valide. Consultez le module de vérification pour les types pris en charge.');
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'it', 'Codice tipo verifica non valido: %s', 'Il codice del tipo di verifica fornito non è riconosciuto dal sottosistema di verifica.', 'Utilizzare un codice di tipo di verifica valido. Verificare il modulo di verifica per i tipi supportati.');
SELECT RegisterError('ERR-400-047', 400, 'E', 'validation', 'es', 'Código de tipo de verificación no válido: %s', 'El código de tipo de verificación proporcionado no es reconocido por el subsistema de verificación.', 'Utilice un código de tipo de verificación válido. Consulte el módulo de verificación para los tipos admitidos.');

-- ERR-400-048: InvalidPhoneNumber
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'en', 'Invalid phone number: %s', 'The phone number format is invalid or does not match the expected pattern.', 'Provide the phone number in international format (e.g., +1234567890).');
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'ru', 'Неправильный номер телефона: %s');
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'de', 'Ungültige Telefonnummer: %s', 'Das Format der Telefonnummer ist ungültig oder entspricht nicht dem erwarteten Muster.', 'Geben Sie die Telefonnummer im internationalen Format an (z.B. +1234567890).');
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'fr', 'Numéro de téléphone non valide: %s', 'Le format du numéro de téléphone est invalide ou ne correspond pas au modèle attendu.', 'Fournissez le numéro de téléphone au format international (p. ex. +1234567890).');
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'it', 'Numero di telefono non valido: %s', 'Il formato del numero di telefono non è valido o non corrisponde al modello previsto.', 'Fornire il numero di telefono in formato internazionale (ad es. +1234567890).');
SELECT RegisterError('ERR-400-048', 400, 'E', 'validation', 'es', 'Número de teléfono no válido: %s', 'El formato del número de teléfono no es válido o no coincide con el patrón esperado.', 'Proporcione el número de teléfono en formato internacional (p. ej., +1234567890).');

-- ERR-400-049: ObjectIsNull
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'en', 'Object id not specified', 'The operation requires an object identifier but none was provided.', 'Include a valid object UUID in the request parameters.');
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'ru', 'Не указан идентификатор объекта');
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'de', 'Objekt-ID nicht angegeben', 'Die Operation erfordert einen Objektbezeichner, aber es wurde keiner angegeben.', 'Fügen Sie eine gültige Objekt-UUID in die Anfrageparameter ein.');
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'fr', 'ID d''objet non spécifié', 'L''opération nécessite un identifiant d''objet mais aucun n''a été fourni.', 'Incluez un UUID d''objet valide dans les paramètres de la requête.');
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'it', 'ID oggetto non specificato', 'L''operazione richiede un identificatore dell''oggetto ma non ne è stato fornito nessuno.', 'Includere un UUID dell''oggetto valido nei parametri della richiesta.');
SELECT RegisterError('ERR-400-049', 400, 'E', 'validation', 'es', 'ID de objeto no especificado', 'La operación requiere un identificador de objeto pero no se proporcionó ninguno.', 'Incluya un UUID de objeto válido en los parámetros de la solicitud.');

-- ERR-400-050: PerformActionError
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'en', 'You cannot perform this action', 'The current user is not authorized to perform this specific action on the object.', 'Verify your permissions for this action or request access from an administrator.');
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'ru', 'Вы не можете выполнить данное действие');
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'de', 'Sie können diese Aktion nicht ausführen', 'Der aktuelle Benutzer ist nicht berechtigt, diese spezifische Aktion auf dem Objekt durchzuführen.', 'Überprüfen Sie Ihre Berechtigungen für diese Aktion oder fordern Sie den Zugang bei einem Administrator an.');
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'fr', 'Vous ne pouvez pas effectuer cette action', 'L''utilisateur actuel n''est pas autorisé à effectuer cette action spécifique sur l''objet.', 'Vérifiez vos permissions pour cette action ou demandez l''accès à un administrateur.');
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'it', 'Non puoi eseguire questa azione', 'L''utente corrente non è autorizzato a eseguire questa azione specifica sull''oggetto.', 'Verificare i propri permessi per questa azione o richiedere l''accesso a un amministratore.');
SELECT RegisterError('ERR-400-050', 400, 'E', 'access', 'es', 'No puede realizar esta acción', 'El usuario actual no está autorizado para realizar esta acción específica sobre el objeto.', 'Verifique sus permisos para esta acción o solicite acceso a un administrador.');

-- ERR-400-051: IdentityNotConfirmed
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'en', 'Identity not confirmed', 'The user''s identity has not been confirmed through the required verification process.', 'Complete the identity verification process (e.g., email or phone confirmation) before proceeding.');
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'ru', 'Личность не подтверждена');
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'de', 'Identität nicht bestätigt', 'Die Identität des Benutzers wurde nicht durch den erforderlichen Verifizierungsprozess bestätigt.', 'Schließen Sie den Identitätsverifizierungsprozess ab (z.B. E-Mail- oder Telefonbestätigung), bevor Sie fortfahren.');
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'fr', 'Identité non confirmée', 'L''identité de l''utilisateur n''a pas été confirmée par le processus de vérification requis.', 'Complétez le processus de vérification d''identité (p. ex. confirmation par e-mail ou téléphone) avant de continuer.');
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'it', 'Identità non confermata', 'L''identità dell''utente non è stata confermata attraverso il processo di verifica richiesto.', 'Completare il processo di verifica dell''identità (ad es. conferma via e-mail o telefono) prima di procedere.');
SELECT RegisterError('ERR-400-051', 400, 'E', 'auth', 'es', 'Identidad no confirmada', 'La identidad del usuario no ha sido confirmada a través del proceso de verificación requerido.', 'Complete el proceso de verificación de identidad (p. ej., confirmación por correo electrónico o teléfono) antes de continuar.');

-- ERR-400-052: ReadOnlyError
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'en', 'Modify operations for read-only roles are not allowed', 'The current role is read-only and does not permit create, update, or delete operations.', 'Switch to a role with write permissions or ask an administrator to upgrade the role.');
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'ru', 'Операции изменения для ролей только для чтения запрещены');
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'de', 'Änderungsoperationen für schreibgeschützte Rollen sind nicht erlaubt', 'Die aktuelle Rolle ist schreibgeschützt und erlaubt keine Erstellungs-, Aktualisierungs- oder Löschoperationen.', 'Wechseln Sie zu einer Rolle mit Schreibberechtigungen oder bitten Sie einen Administrator, die Rolle zu erweitern.');
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'fr', 'Les opérations de modification pour les rôles en lecture seule ne sont pas autorisées', 'Le rôle actuel est en lecture seule et ne permet pas les opérations de création, de mise à jour ou de suppression.', 'Passez à un rôle avec des permissions d''écriture ou demandez à un administrateur de mettre à niveau le rôle.');
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'it', 'Le operazioni di modifica per i ruoli di sola lettura non sono consentite', 'Il ruolo corrente è di sola lettura e non consente operazioni di creazione, aggiornamento o eliminazione.', 'Passare a un ruolo con permessi di scrittura o chiedere a un amministratore di aggiornare il ruolo.');
SELECT RegisterError('ERR-400-052', 400, 'E', 'access', 'es', 'Las operaciones de modificación para roles de solo lectura no están permitidas', 'El rol actual es de solo lectura y no permite operaciones de creación, actualización o eliminación.', 'Cambie a un rol con permisos de escritura o solicite a un administrador que actualice el rol.');

-- ERR-400-053: ActionAlreadyCompleted
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'en', 'You have already completed this action', 'The requested action has already been executed by this user and cannot be repeated.', 'No further action is needed. If a different outcome is required, use the appropriate reversal or correction workflow.');
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'ru', 'Вы уже выполнили это действие');
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'de', 'Sie haben diese Aktion bereits abgeschlossen', 'Die angeforderte Aktion wurde von diesem Benutzer bereits ausgeführt und kann nicht wiederholt werden.', 'Keine weitere Aktion erforderlich. Wenn ein anderes Ergebnis benötigt wird, verwenden Sie den entsprechenden Umkehr- oder Korrektur-Workflow.');
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'fr', 'Vous avez déjà terminé cette action', 'L''action demandée a déjà été exécutée par cet utilisateur et ne peut pas être répétée.', 'Aucune action supplémentaire n''est nécessaire. Si un résultat différent est requis, utilisez le workflow d''annulation ou de correction approprié.');
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'it', 'Hai già completato questa azione', 'L''azione richiesta è già stata eseguita da questo utente e non può essere ripetuta.', 'Nessuna ulteriore azione necessaria. Se è richiesto un risultato diverso, utilizzare il workflow di annullamento o correzione appropriato.');
SELECT RegisterError('ERR-400-053', 400, 'E', 'workflow', 'es', 'Ya ha completado esta acción', 'La acción solicitada ya fue ejecutada por este usuario y no puede repetirse.', 'No se requiere ninguna acción adicional. Si se necesita un resultado diferente, utilice el flujo de trabajo de reversión o corrección apropiado.');

--------------------------------------------------------------------------------
-- Group 400: JSON validation errors -------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-060: JsonIsEmpty
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'en', 'JSON must not be empty', 'The request body must contain a non-empty JSON payload, but it was empty or null.', 'Include a valid JSON object in the request body.');
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'ru', 'JSON не должен быть пустым');
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'de', 'JSON darf nicht leer sein', 'Der Anfragetext muss einen nicht leeren JSON-Payload enthalten, er war jedoch leer oder null.', 'Fügen Sie ein gültiges JSON-Objekt in den Anfragetext ein.');
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'fr', 'JSON ne doit pas être vide', 'Le corps de la requête doit contenir un payload JSON non vide, mais il était vide ou null.', 'Incluez un objet JSON valide dans le corps de la requête.');
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'it', 'JSON non deve essere vuoto', 'Il corpo della richiesta deve contenere un payload JSON non vuoto, ma era vuoto o null.', 'Includere un oggetto JSON valido nel corpo della richiesta.');
SELECT RegisterError('ERR-400-060', 400, 'E', 'validation', 'es', 'JSON no debe estar vacío', 'El cuerpo de la solicitud debe contener un payload JSON no vacío, pero estaba vacío o era nulo.', 'Incluya un objeto JSON válido en el cuerpo de la solicitud.');

-- ERR-400-061: IncorrectJsonKey
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'en', '(%s) Invalid key "%s". Valid keys: [%s]', 'The JSON payload contains a key that is not recognized for this endpoint.', 'Remove the invalid key and use only the keys listed in the error message.');
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'ru', '(%s) Недопустимый ключ "%s". Допустимые ключи: [%s]');
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'de', '(%s) Ungültiger Schlüssel "%s". Gültige Schlüssel: [%s]', 'Der JSON-Payload enthält einen Schlüssel, der für diesen Endpunkt nicht erkannt wird.', 'Entfernen Sie den ungültigen Schlüssel und verwenden Sie nur die in der Fehlermeldung aufgeführten Schlüssel.');
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'fr', '(%s) Clé non valide "%s". Clés valides: [%s]', 'Le payload JSON contient une clé qui n''est pas reconnue pour ce point de terminaison.', 'Supprimez la clé non valide et utilisez uniquement les clés indiquées dans le message d''erreur.');
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'it', '(%s) Chiave non valida "%s". Chiavi valide: [%s]', 'Il payload JSON contiene una chiave che non è riconosciuta per questo endpoint.', 'Rimuovere la chiave non valida e utilizzare solo le chiavi elencate nel messaggio di errore.');
SELECT RegisterError('ERR-400-061', 400, 'E', 'validation', 'es', '(%s) Clave no válida "%s". Claves válidas: [%s]', 'El payload JSON contiene una clave que no es reconocida para este punto final.', 'Elimine la clave no válida y utilice solo las claves indicadas en el mensaje de error.');

-- ERR-400-062: JsonKeyNotFound
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'en', '(%s) Required key not FOUND: %s', 'A required key is missing from the JSON payload.', 'Add the missing key to the JSON payload and retry the request.');
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'ru', '(%s) Не найден обязательный ключ: %s');
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'de', '(%s) Erforderlicher Schlüssel nicht gefunden: %s', 'Ein erforderlicher Schlüssel fehlt im JSON-Payload.', 'Fügen Sie den fehlenden Schlüssel zum JSON-Payload hinzu und wiederholen Sie die Anfrage.');
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'fr', '(%s) Clé requise non trouvée: %s', 'Une clé requise est manquante dans le payload JSON.', 'Ajoutez la clé manquante au payload JSON et réessayez la requête.');
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'it', '(%s) Chiave richiesta non trovata: %s', 'Una chiave richiesta è mancante nel payload JSON.', 'Aggiungere la chiave mancante al payload JSON e riprovare la richiesta.');
SELECT RegisterError('ERR-400-062', 400, 'E', 'validation', 'es', '(%s) Clave requerida no encontrada: %s', 'Falta una clave requerida en el payload JSON.', 'Agregue la clave faltante al payload JSON y reintente la solicitud.');

-- ERR-400-063: IncorrectJsonType
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'en', 'Invalid type "%s", expected "%s"', 'The JSON value type does not match the expected type for this field.', 'Change the value to the expected type (e.g., string instead of integer) and retry.');
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'ru', 'Неверный тип "%s", ожидается "%s"');
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'de', 'Ungültiger Typ "%s", erwartet "%s"', 'Der JSON-Werttyp stimmt nicht mit dem erwarteten Typ für dieses Feld überein.', 'Ändern Sie den Wert in den erwarteten Typ (z.B. Zeichenkette statt Ganzzahl) und versuchen Sie es erneut.');
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'fr', 'Type non valide "%s", attendu "%s"', 'Le type de la valeur JSON ne correspond pas au type attendu pour ce champ.', 'Changez la valeur pour le type attendu (p. ex. chaîne au lieu d''entier) et réessayez.');
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'it', 'Tipo non valido "%s", previsto "%s"', 'Il tipo del valore JSON non corrisponde al tipo previsto per questo campo.', 'Cambiare il valore nel tipo previsto (ad es. stringa invece di intero) e riprovare.');
SELECT RegisterError('ERR-400-063', 400, 'E', 'validation', 'es', 'Tipo no válido "%s", esperado "%s"', 'El tipo del valor JSON no coincide con el tipo esperado para este campo.', 'Cambie el valor al tipo esperado (p. ej., cadena en lugar de entero) y reintente.');

-- ERR-400-064: IncorrectKeyInArray
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'en', 'Invalid key "%s" in array "%s". Valid keys: [%s]', 'A JSON array element contains a key that is not valid for that array context.', 'Remove the invalid key from the array element. Use only the valid keys listed in the error message.');
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'ru', 'Недопустимый ключ "%s" в массиве "%s". Допустимые ключи: [%s]');
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'de', 'Ungültiger Schlüssel "%s" im Array "%s". Gültige Schlüssel: [%s]', 'Ein JSON-Array-Element enthält einen Schlüssel, der für diesen Array-Kontext nicht gültig ist.', 'Entfernen Sie den ungültigen Schlüssel aus dem Array-Element. Verwenden Sie nur die gültigen Schlüssel, die in der Fehlermeldung aufgeführt sind.');
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'fr', 'Clé non valide "%s" dans le tableau "%s". Clés valides: [%s]', 'Un élément du tableau JSON contient une clé qui n''est pas valide pour ce contexte de tableau.', 'Supprimez la clé non valide de l''élément du tableau. Utilisez uniquement les clés valides indiquées dans le message d''erreur.');
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'it', 'Chiave non valida "%s" nell''array "%s". Chiavi valide: [%s]', 'Un elemento dell''array JSON contiene una chiave che non è valida per il contesto di questo array.', 'Rimuovere la chiave non valida dall''elemento dell''array. Utilizzare solo le chiavi valide elencate nel messaggio di errore.');
SELECT RegisterError('ERR-400-064', 400, 'E', 'validation', 'es', 'Clave no válida "%s" en el arreglo "%s". Claves válidas: [%s]', 'Un elemento del arreglo JSON contiene una clave que no es válida para el contexto de este arreglo.', 'Elimine la clave no válida del elemento del arreglo. Utilice solo las claves válidas indicadas en el mensaje de error.');

-- ERR-400-065: IncorrectValueInArray
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'en', 'Invalid value "%s" in array "%s". Valid values: [%s]', 'A JSON array element contains a value that is not among the accepted options.', 'Replace the invalid value with one of the valid values listed in the error message.');
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'ru', 'Недопустимое значение "%s" в массиве "%s". Допустимые значения: [%s]');
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'de', 'Ungültiger Wert "%s" im Array "%s". Gültige Werte: [%s]', 'Ein JSON-Array-Element enthält einen Wert, der nicht zu den akzeptierten Optionen gehört.', 'Ersetzen Sie den ungültigen Wert durch einen der gültigen Werte, die in der Fehlermeldung aufgeführt sind.');
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'fr', 'Valeur non valide "%s" dans le tableau "%s". Valeurs valides: [%s]', 'Un élément du tableau JSON contient une valeur qui ne fait pas partie des options acceptées.', 'Remplacez la valeur non valide par l''une des valeurs valides indiquées dans le message d''erreur.');
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'it', 'Valore non valido "%s" nell''array "%s". Valori validi: [%s]', 'Un elemento dell''array JSON contiene un valore che non è tra le opzioni accettate.', 'Sostituire il valore non valido con uno dei valori validi elencati nel messaggio di errore.');
SELECT RegisterError('ERR-400-065', 400, 'E', 'validation', 'es', 'Valor no válido "%s" en el arreglo "%s". Valores válidos: [%s]', 'Un elemento del arreglo JSON contiene un valor que no se encuentra entre las opciones aceptadas.', 'Reemplace el valor no válido por uno de los valores válidos indicados en el mensaje de error.');

-- ERR-400-066: ValueOutOfRange
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'en', 'Value [%s] is out of range', 'The provided value falls outside the acceptable range for this field.', 'Adjust the value to fall within the valid range and retry.');
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'ru', 'Значение [%s] выходит за пределы допустимого диапазона');
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'de', 'Wert [%s] liegt außerhalb des zulässigen Bereichs', 'Der angegebene Wert liegt außerhalb des zulässigen Bereichs für dieses Feld.', 'Passen Sie den Wert an, damit er innerhalb des gültigen Bereichs liegt, und versuchen Sie es erneut.');
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'fr', 'La valeur [%s] est hors limites', 'La valeur fournie se situe en dehors de la plage acceptable pour ce champ.', 'Ajustez la valeur pour qu''elle se situe dans la plage valide et réessayez.');
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'it', 'Valore [%s] fuori intervallo', 'Il valore fornito si trova al di fuori dell''intervallo accettabile per questo campo.', 'Adeguare il valore affinché rientri nell''intervallo valido e riprovare.');
SELECT RegisterError('ERR-400-066', 400, 'E', 'validation', 'es', 'El valor [%s] está fuera de rango', 'El valor proporcionado está fuera del rango aceptable para este campo.', 'Ajuste el valor para que esté dentro del rango válido y reintente.');

-- ERR-400-067: DateValidityPeriod
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'en', 'The start date must not exceed the end date', 'The date range is invalid because the start date is later than the end date.', 'Correct the dates so the start date is on or before the end date.');
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'ru', 'Дата начала не должна превышать дату окончания');
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'de', 'Das Startdatum darf das Enddatum nicht überschreiten', 'Der Zeitraum ist ungültig, da das Startdatum nach dem Enddatum liegt.', 'Korrigieren Sie die Daten, sodass das Startdatum gleich oder vor dem Enddatum liegt.');
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'fr', 'La date de début ne doit pas dépasser la date de fin', 'La plage de dates est invalide car la date de début est postérieure à la date de fin.', 'Corrigez les dates de sorte que la date de début soit égale ou antérieure à la date de fin.');
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'it', 'La data di inizio non deve superare la data di fine', 'L''intervallo di date non è valido perché la data di inizio è successiva alla data di fine.', 'Correggere le date in modo che la data di inizio sia uguale o precedente alla data di fine.');
SELECT RegisterError('ERR-400-067', 400, 'E', 'validation', 'es', 'La fecha de inicio no debe exceder la fecha de fin', 'El rango de fechas no es válido porque la fecha de inicio es posterior a la fecha de fin.', 'Corrija las fechas para que la fecha de inicio sea igual o anterior a la fecha de fin.');

--------------------------------------------------------------------------------
-- Group 400: OAuth 2.0 errors ------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-070: IssuerNotFound
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'en', 'OAuth 2.0: Issuer not FOUND: %s', 'The JWT issuer claim does not match any registered OAuth 2.0 provider in the system.', 'Register the issuer in the OAuth 2.0 configuration or use a token from a known issuer.');
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'ru', 'OAuth 2.0: Не найден эмитент: %s');
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'de', 'OAuth 2.0: Aussteller nicht gefunden: %s', 'Der JWT-Ausstelleranspruch stimmt mit keinem registrierten OAuth 2.0-Anbieter im System überein.', 'Registrieren Sie den Aussteller in der OAuth 2.0-Konfiguration oder verwenden Sie ein Token von einem bekannten Aussteller.');
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'fr', 'OAuth 2.0: Émetteur non trouvé: %s', 'La revendication d''émetteur JWT ne correspond à aucun fournisseur OAuth 2.0 enregistré dans le système.', 'Enregistrez l''émetteur dans la configuration OAuth 2.0 ou utilisez un jeton provenant d''un émetteur connu.');
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'it', 'OAuth 2.0: Emittente non trovato: %s', 'Il claim dell''emittente JWT non corrisponde a nessun provider OAuth 2.0 registrato nel sistema.', 'Registrare l''emittente nella configurazione OAuth 2.0 o utilizzare un token proveniente da un emittente conosciuto.');
SELECT RegisterError('ERR-400-070', 400, 'E', 'auth', 'es', 'OAuth 2.0: Emisor no encontrado: %s', 'La reclamación del emisor JWT no coincide con ningún proveedor OAuth 2.0 registrado en el sistema.', 'Registre el emisor en la configuración de OAuth 2.0 o utilice un token de un emisor conocido.');

-- ERR-400-071: AudienceNotFound
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'en', 'OAuth 2.0: Client not FOUND', 'The JWT audience claim does not match any registered OAuth 2.0 client.', 'Verify the client is registered in the OAuth 2.0 configuration. Register it if necessary.');
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'ru', 'OAuth 2.0: Клиент не найден');
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'de', 'OAuth 2.0: Client nicht gefunden', 'Der JWT-Zielgruppenanspruch stimmt mit keinem registrierten OAuth 2.0-Client überein.', 'Überprüfen Sie, ob der Client in der OAuth 2.0-Konfiguration registriert ist. Registrieren Sie ihn bei Bedarf.');
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'fr', 'OAuth 2.0: Client non trouvé', 'La revendication d''audience JWT ne correspond à aucun client OAuth 2.0 enregistré.', 'Vérifiez que le client est enregistré dans la configuration OAuth 2.0. Enregistrez-le si nécessaire.');
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'it', 'OAuth 2.0: Client non trovato', 'Il claim dell''audience JWT non corrisponde a nessun client OAuth 2.0 registrato.', 'Verificare che il client sia registrato nella configurazione OAuth 2.0. Registrarlo se necessario.');
SELECT RegisterError('ERR-400-071', 400, 'E', 'auth', 'es', 'OAuth 2.0: Cliente no encontrado', 'La reclamación de audiencia JWT no coincide con ningún cliente OAuth 2.0 registrado.', 'Verifique que el cliente esté registrado en la configuración de OAuth 2.0. Regístrelo si es necesario.');

-- ERR-400-072: GuestAreaError
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'en', 'Operations with documents in guest area are prohibited', 'The guest area is restricted; creating or modifying documents in it is not allowed.', 'Move the document to an appropriate non-guest area before performing the operation.');
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'ru', 'Запрещены операции с документами в гостевой области.');
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'de', 'Operationen mit Dokumenten im Gastbereich sind verboten', 'Der Gastbereich ist eingeschränkt; das Erstellen oder Ändern von Dokumenten darin ist nicht erlaubt.', 'Verschieben Sie das Dokument in einen geeigneten Nicht-Gastbereich, bevor Sie die Operation durchführen.');
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'fr', 'Les opérations sur les documents dans la zone invité sont interdites', 'La zone invité est restreinte ; la création ou la modification de documents à l''intérieur n''est pas autorisée.', 'Déplacez le document vers une zone non invité appropriée avant d''effectuer l''opération.');
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'it', 'Le operazioni con i documenti nell''area ospiti sono vietate', 'L''area ospiti è limitata; la creazione o la modifica di documenti al suo interno non è consentita.', 'Spostare il documento in un''area non ospiti appropriata prima di eseguire l''operazione.');
SELECT RegisterError('ERR-400-072', 400, 'E', 'access', 'es', 'Las operaciones con documentos en el área de invitados están prohibidas', 'El área de invitados está restringida; crear o modificar documentos en ella no está permitido.', 'Mueva el documento a un área apropiada que no sea de invitados antes de realizar la operación.');

-- ERR-400-073: NotFound
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'en', 'Not found', 'The requested resource could not be found.', 'Verify the identifier or path is correct and the resource exists.');
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'ru', 'Не найдено');
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'de', 'Nicht gefunden', 'Die angeforderte Ressource konnte nicht gefunden werden.', 'Überprüfen Sie, ob der Bezeichner oder Pfad korrekt ist und die Ressource existiert.');
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'fr', 'Non trouvé', 'La ressource demandée n''a pas pu être trouvée.', 'Vérifiez que l''identifiant ou le chemin est correct et que la ressource existe.');
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'it', 'Non trovato', 'La risorsa richiesta non è stata trovata.', 'Verificare che l''identificatore o il percorso sia corretto e che la risorsa esista.');
SELECT RegisterError('ERR-400-073', 400, 'E', 'entity', 'es', 'No encontrado', 'El recurso solicitado no pudo ser encontrado.', 'Verifique que el identificador o la ruta sea correcta y que el recurso exista.');

-- ERR-400-074: DefaultAreaDocumentError
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'en', 'The document can only be changed in the "Default" area', 'The document belongs to a non-default area and can only be modified when accessed through the Default area.', 'Switch to the Default area context before modifying this document.');
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'ru', 'Документ можно изменить только в области «По умолчанию»');
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'de', 'Das Dokument kann nur im Bereich "Standard" geändert werden', 'Das Dokument gehört zu einem Nicht-Standardbereich und kann nur geändert werden, wenn es über den Standardbereich aufgerufen wird.', 'Wechseln Sie zum Standardbereich-Kontext, bevor Sie dieses Dokument ändern.');
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'fr', 'Le document ne peut être modifié que dans la zone ''Par défaut''', 'Le document appartient à une zone non par défaut et ne peut être modifié que lorsqu''il est accédé via la zone Par défaut.', 'Passez au contexte de la zone Par défaut avant de modifier ce document.');
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'it', 'Il documento può essere modificato solo nell''area "Predefinito"', 'Il documento appartiene a un''area non predefinita e può essere modificato solo quando vi si accede tramite l''area Predefinita.', 'Passare al contesto dell''area Predefinita prima di modificare questo documento.');
SELECT RegisterError('ERR-400-074', 400, 'E', 'access', 'es', 'El documento solo se puede cambiar en el área "Predeterminado"', 'El documento pertenece a un área no predeterminada y solo puede ser modificado cuando se accede a través del área Predeterminada.', 'Cambie al contexto del área Predeterminada antes de modificar este documento.');

--------------------------------------------------------------------------------
-- Group 400: Registry errors --------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-080: IncorrectRegistryKey
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'en', 'Invalid key "%s". Valid keys: [%s]', 'The registry key provided is not recognized in the system registry.', 'Use one of the valid keys listed in the error message.');
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'ru', 'Недопустимый ключ "%s". Допустимые ключи: [%s]');
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'de', 'Ungültiger Schlüssel "%s". Gültige Schlüssel: [%s]', 'Der angegebene Registrierungsschlüssel wird im Systemregister nicht erkannt.', 'Verwenden Sie einen der gültigen Schlüssel, die in der Fehlermeldung aufgeführt sind.');
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'fr', 'Clé non valide "%s". Clés valides: [%s]', 'La clé de registre fournie n''est pas reconnue dans le registre du système.', 'Utilisez l''une des clés valides indiquées dans le message d''erreur.');
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'it', 'Chiave non valida "%s". Chiavi valide: [%s]', 'La chiave di registro fornita non è riconosciuta nel registro di sistema.', 'Utilizzare una delle chiavi valide elencate nel messaggio di errore.');
SELECT RegisterError('ERR-400-080', 400, 'E', 'validation', 'es', 'Clave no válida "%s". Claves válidas: [%s]', 'La clave de registro proporcionada no es reconocida en el registro del sistema.', 'Utilice una de las claves válidas indicadas en el mensaje de error.');

-- ERR-400-081: IncorrectRegistryDataType
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'en', 'Invalid data type: %s', 'The data type specified for the registry value is not supported.', 'Use a supported data type (e.g., text, integer, boolean, numeric, datetime).');
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'ru', 'Неверный тип данных: %s');
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'de', 'Ungültiger Datentyp: %s', 'Der für den Registrierungswert angegebene Datentyp wird nicht unterstützt.', 'Verwenden Sie einen unterstützten Datentyp (z.B. text, integer, boolean, numeric, datetime).');
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'fr', 'Type de données non valide: %s', 'Le type de données spécifié pour la valeur du registre n''est pas pris en charge.', 'Utilisez un type de données pris en charge (p. ex. text, integer, boolean, numeric, datetime).');
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'it', 'Tipo di dati non valido: %s', 'Il tipo di dati specificato per il valore del registro non è supportato.', 'Utilizzare un tipo di dati supportato (ad es. text, integer, boolean, numeric, datetime).');
SELECT RegisterError('ERR-400-081', 400, 'E', 'validation', 'es', 'Tipo de datos no válido: %s', 'El tipo de datos especificado para el valor del registro no es compatible.', 'Utilice un tipo de datos compatible (p. ej., text, integer, boolean, numeric, datetime).');

--------------------------------------------------------------------------------
-- Group 400: Route errors -----------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-090: RouteIsEmpty
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'en', 'Path must not be empty', 'The REST path parameter is required but was passed as empty or null.', 'Provide a non-empty path string in the request.');
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'ru', 'Путь не должен быть пустым');
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'de', 'Pfad darf nicht leer sein', 'Der REST-Pfadparameter ist erforderlich, wurde aber als leer oder null übergeben.', 'Geben Sie eine nicht leere Pfadzeichenkette in der Anfrage an.');
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'fr', 'Le chemin ne doit pas être vide', 'Le paramètre de chemin REST est requis mais a été transmis comme vide ou null.', 'Fournissez une chaîne de chemin non vide dans la requête.');
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'it', 'Il percorso non deve essere vuoto', 'Il parametro del percorso REST è richiesto ma è stato passato come vuoto o null.', 'Fornire una stringa di percorso non vuota nella richiesta.');
SELECT RegisterError('ERR-400-090', 400, 'E', 'validation', 'es', 'La ruta no debe estar vacía', 'El parámetro de ruta REST es obligatorio pero se proporcionó como vacío o nulo.', 'Proporcione una cadena de ruta no vacía en la solicitud.');

-- ERR-400-091: RouteNotFound
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'en', 'Route not found: %s', 'No REST route is registered for the given path.', 'Check the available API routes and use a valid path. Register the route in init.sql if it is missing.');
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'ru', 'Не найден маршрут: %s');
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'de', 'Route nicht gefunden: %s', 'Für den angegebenen Pfad ist keine REST-Route registriert.', 'Überprüfen Sie die verfügbaren API-Routen und verwenden Sie einen gültigen Pfad. Registrieren Sie die Route in init.sql, falls sie fehlt.');
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'fr', 'Route non trouvée: %s', 'Aucune route REST n''est enregistrée pour le chemin donné.', 'Vérifiez les routes API disponibles et utilisez un chemin valide. Enregistrez la route dans init.sql si elle manque.');
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'it', 'Route non trovata: %s', 'Nessuna route REST è registrata per il percorso specificato.', 'Verificare le route API disponibili e utilizzare un percorso valido. Registrare la route in init.sql se mancante.');
SELECT RegisterError('ERR-400-091', 400, 'E', 'entity', 'es', 'Ruta no encontrada: %s', 'No hay ninguna ruta REST registrada para la ruta proporcionada.', 'Verifique las rutas API disponibles y utilice una ruta válida. Registre la ruta en init.sql si falta.');

-- ERR-400-092: EndPointNotSet
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'en', 'Endpoint not set for path: %s', 'A route exists for the given path but no endpoint function has been configured.', 'Register an endpoint function for this route in the REST configuration.');
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'ru', 'Конечная точка не указана для пути: %s');
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'de', 'Endpunkt nicht festgelegt für Pfad: %s', 'Für den angegebenen Pfad existiert eine Route, aber es wurde keine Endpunktfunktion konfiguriert.', 'Registrieren Sie eine Endpunktfunktion für diese Route in der REST-Konfiguration.');
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'fr', 'Point de terminaison non défini pour le chemin: %s', 'Une route existe pour le chemin donné mais aucune fonction de point de terminaison n''a été configurée.', 'Enregistrez une fonction de point de terminaison pour cette route dans la configuration REST.');
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'it', 'Endpoint non impostato per percorso: %s', 'Esiste una route per il percorso specificato ma non è stata configurata alcuna funzione endpoint.', 'Registrare una funzione endpoint per questa route nella configurazione REST.');
SELECT RegisterError('ERR-400-092', 400, 'E', 'entity', 'es', 'Punto final no establecido para la ruta: %s', 'Existe una ruta para la ruta proporcionada pero no se ha configurado ninguna función de punto final.', 'Registre una función de punto final para esta ruta en la configuración REST.');

--------------------------------------------------------------------------------
-- Group 400: System errors ----------------------------------------------------
--------------------------------------------------------------------------------

-- ERR-400-100: SomethingWentWrong
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'en', 'Oops, something went wrong. Our engineers are already working on fixing the error', 'An unexpected internal error occurred that does not fit any specific error category.', 'Retry the operation. If the error persists, check the server logs and report the issue to the development team.');
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'ru', 'Упс, что-то пошло не так. Наши инженеры уже работают над решением проблемы');
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'de', 'Hoppla, etwas ist schiefgelaufen. Unsere Ingenieure arbeiten bereits an der Behebung des Fehlers', 'Ein unerwarteter interner Fehler ist aufgetreten, der keiner bestimmten Fehlerkategorie zugeordnet werden kann.', 'Versuchen Sie die Operation erneut. Wenn der Fehler weiterhin besteht, überprüfen Sie die Serverprotokolle und melden Sie das Problem dem Entwicklungsteam.');
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'fr', 'Oups, quelque chose s''est mal passé. Nos ingénieurs travaillent déjà à la résolution du problème', 'Une erreur interne inattendue s''est produite qui ne correspond à aucune catégorie d''erreur spécifique.', 'Réessayez l''opération. Si l''erreur persiste, consultez les journaux du serveur et signalez le problème à l''équipe de développement.');
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'it', 'Ops, qualcosa è andato storto. I nostri ingegneri stanno già lavorando alla risoluzione del problema', 'Si è verificato un errore interno imprevisto che non rientra in nessuna categoria di errore specifica.', 'Riprovare l''operazione. Se l''errore persiste, controllare i log del server e segnalare il problema al team di sviluppo.');
SELECT RegisterError('ERR-400-100', 400, 'E', 'system', 'es', 'Vaya, algo salió mal. Nuestros ingenieros ya están trabajando en la solución del problema', 'Ocurrió un error interno inesperado que no encaja en ninguna categoría de error específica.', 'Reintente la operación. Si el error persiste, revise los registros del servidor y reporte el problema al equipo de desarrollo.');
