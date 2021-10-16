SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT SetLocale(GetLocale(locale_code()));
SELECT SetDefaultLocale(GetLocale(locale_code()), id) FROM users;

--admin
SELECT AddMemberToArea('00000000-0000-4000-a001-000000000001', '00000000-0000-4003-a000-000000000000');
SELECT SetArea('00000000-0000-4003-a001-000000000001', '00000000-0000-4000-a001-000000000001');

-- apibot
SELECT AddMemberToArea('00000000-0000-4000-a002-000000000001', '00000000-0000-4003-a000-000000000000');
SELECT SetArea('00000000-0000-4003-a001-000000000001', '00000000-0000-4000-a002-000000000001');

-- mailbot
SELECT AddMemberToArea('00000000-0000-4000-a002-000000000002', '00000000-0000-4003-a000-000000000000');
SELECT SetArea('00000000-0000-4003-a001-000000000001', '00000000-0000-4000-a002-000000000002');

SELECT InitWorkFlow();
SELECT InitEntity();
SELECT InitAPI();

SELECT CreatePublisher('notify', 'Уведомления', 'Уведомления о системных событиях.');
SELECT CreatePublisher('notice', 'Извещения', 'Системные извещения.');
SELECT CreatePublisher('message', 'Сообщения', 'Уведомления о сообщениях.');
SELECT CreatePublisher('log', 'Журналы', 'Журналы событий.');
SELECT CreatePublisher('geo', 'Геолокация', 'Данные геолокации.');

SELECT CreateVendor(null, GetType('service.vendor'), 'system.vendor', 'Система', 'Системные услуги.');
SELECT CreateVendor(null, GetType('service.vendor'), 'mts.vendor', 'МТС', 'ПАО "МТС" (Мобитьные ТелеСистемы).');
SELECT CreateVendor(null, GetType('service.vendor'), 'google.vendor', 'Google', 'Google.');
SELECT CreateVendor(null, GetType('service.vendor'), 'sberbank.vendor', 'Сбербанк', 'Сбербанк.');

SELECT CreateAgent(null, GetType('system.agent'), 'system.agent', 'Система', GetVendor('system.vendor'), 'Агент для обработки системных сообщений.');
SELECT CreateAgent(null, GetType('system.agent'), 'notice.agent', 'Извещение', GetVendor('system.vendor'), 'Агент для обработки системных извещений.');

SELECT CreateAgent(null, GetType('email.agent'), 'smtp.agent', 'SMTP', GetVendor('system.vendor'), 'Агент для передачи электронной почты по протоколу SMTP.');
SELECT CreateAgent(null, GetType('email.agent'), 'pop3.agent', 'POP3', GetVendor('system.vendor'), 'Агент для получения электронной почты по протоколу POP3.');
SELECT CreateAgent(null, GetType('email.agent'), 'imap.agent', 'IMAP', GetVendor('system.vendor'), 'Агент для получения электронной почты по протоколу IMAP.');

SELECT CreateAgent(null, GetType('api.agent'), 'fcm.agent', 'FCM', GetVendor('google.vendor'), 'Агент для передачи push-уведомлений через Google Firebase Cloud Messaging.');
SELECT CreateAgent(null, GetType('api.agent'), 'm2m.agent', 'M2M', GetVendor('mts.vendor'), 'Агент для передачи коротких сообщений через МТС Коммуникатор.');
SELECT CreateAgent(null, GetType('api.agent'), 'sba.agent', 'SBA',  GetVendor('sberbank.vendor'), 'Агент для передачи данных в Интернет-Эквайринг от Сбербанка.');

SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_01_MINUTES', 'Каждую минуту', '1 minutes', MINDATE(), MAXDATE(), 'Каждую минуту.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_05_MINUTES', 'Каждые 5 минут', '5 minutes', MINDATE(), MAXDATE(), 'Каждые 5 минут.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_10_MINUTES', 'Каждые 10 минут', '10 minutes', MINDATE(), MAXDATE(), 'Каждые 10 минут.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_15_MINUTES', 'Каждые 15 минут', '15 minutes', MINDATE(), MAXDATE(), 'Каждые 15 минут.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_30_MINUTES', 'Каждые 30 минут', '30 minutes', MINDATE(), MAXDATE(), 'Каждые 30 минут.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_01_HOUR', 'Каждый час', '1 hour', MINDATE(), MAXDATE(), 'Каждый час.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_01_DAY', 'Каждый день', '1 day', MINDATE(), MAXDATE(), 'Каждый день.');

SELECT CreateProgram(null, GetType('plpgsql.program'), 'CHECK_OFFLINE', 'Проверяет статус активных пользователей', 'SELECT api.check_offline();', 'Проверяет статус активных пользователей.');
SELECT CreateJob(null, GetType('periodic.job'), GetScheduler('EACH_01_MINUTES'), GetProgram('CHECK_OFFLINE'), Now(), 'CHECK_OFFLINE_EACH_01_MINUTES', 'Проверяет статус активных пользователей', 'Проверяет статус активных пользователей каждую минуту.');

SELECT CreateProgram(null, GetType('plpgsql.program'), 'CHECK_SESSION', 'Проверяет сессии пользователей', 'SELECT api.check_session();', 'Проверяет сессии пользователей и закрывает неактивные.');
SELECT CreateJob(null, GetType('periodic.job'), GetScheduler('EACH_01_HOUR'), GetProgram('CHECK_SESSION'), Now(), 'CHECK_SESSION_EACH_01_HOUR', 'Проверяет сессии пользователей', 'Проверяет сессии пользователей и закрывает неактивные.');

SELECT SignOut();