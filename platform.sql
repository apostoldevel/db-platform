SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT SetDefaultArea(GetArea('default'));
SELECT SetArea(GetArea('default'));

SELECT InitWorkFlow();
SELECT InitEntity();
SELECT InitAPI();

SELECT CreatePublisher('notify', 'Уведомления', 'Уведомления о системных событиях.');
SELECT CreatePublisher('log', 'Журналы', 'Журналы событий.');
SELECT CreatePublisher('geo', 'Геолокация', 'Данные геолокации.');
SELECT CreatePublisher('message', 'Сообщения', 'Сообщения пользователей.');

SELECT FillCalendar(CreateCalendar(null, GetType('workday.calendar'), 'default.calendar', 'Календарь рабочих дней', 5, ARRAY[6,7], ARRAY[[1,1], [1,7], [2,23], [3,8], [5,1], [5,9], [6,12], [11,4]], '9 hour', '8 hour', '13 hour', '1 hour', 'Календарь рабочих дней.'), date(date_trunc('year', Now())), date((date_trunc('year', Now()) + interval '1 year') - interval '1 day'));

SELECT CreateVendor(null, GetType('service.vendor'), 'system.vendor', 'Система', 'Системные услуги.');
SELECT CreateVendor(null, GetType('service.vendor'), 'mts.vendor', 'МТС', 'ПАО "МТС" (Мобитьные ТелеСистемы).');
SELECT CreateVendor(null, GetType('service.vendor'), 'google.vendor', 'Google', 'Google.');
SELECT CreateVendor(null, GetType('service.vendor'), 'sberbank.vendor', 'Сбербанк', 'Сбербанк.');

SELECT CreateAgent(null, GetType('system.agent'), 'system.agent', 'System', GetVendor('system.vendor'), 'Агент для обработки системных сообщений.');
SELECT CreateAgent(null, GetType('system.agent'), 'event.agent', 'Event', GetVendor('system.vendor'), 'Агент для обработки системных событий.');
SELECT CreateAgent(null, GetType('stream.agent'), 'udp.agent', 'UDP', GetVendor('system.vendor'), 'Агент для обработки данных по протоколу UDP.');

SELECT CreateAgent(null, GetType('email.agent'), 'smtp.agent', 'SMTP', GetVendor('system.vendor'), 'Агент для передачи электронной почты по протоколу SMTP.');
SELECT CreateAgent(null, GetType('email.agent'), 'pop3.agent', 'POP3', GetVendor('system.vendor'), 'Агент для получения электронной почты по протоколу POP3.');
SELECT CreateAgent(null, GetType('email.agent'), 'imap.agent', 'IMAP', GetVendor('system.vendor'), 'Агент для получения электронной почты по протоколу IMAP.');

SELECT CreateAgent(null, GetType('api.agent'), 'fcm.agent', 'FCM', GetVendor('google.vendor'), 'Агент для передачи push-уведомлений через Google Firebase Cloud Messaging.');
SELECT CreateAgent(null, GetType('api.agent'), 'm2m.agent', 'M2M', GetVendor('mts.vendor'), 'Агент для передачи коротких сообщений через МТС Коммуникатор.');
SELECT CreateAgent(null, GetType('api.agent'), 'sba.agent', 'SBA',  GetVendor('sberbank.vendor'), 'Агент для передачи данных в Интернет-Эквайринг от Сбербанка.');

SELECT CreateVendor(null, GetType('device.vendor'), 'unknown.vendor', 'Неизвестный', 'Неизвестный производитель оборудования.');

SELECT CreateModel(null, GetType('device.model'), 'unknown.model', 'Неизвестная', GetVendor('unknown.vendor'), 'Неизвестная модель устройства.');
SELECT CreateModel(null, GetType('device.model'), 'android.model', 'Android', GetVendor('unknown.vendor'), 'Неизвестная модель устройства на ОС Android.');
SELECT CreateModel(null, GetType('device.model'), 'ios.model', 'iOS', GetVendor('unknown.vendor'), 'Неизвестная модель устройства на ОС iOS.');

SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_01_MINUTES', 'Каждую минуту', '1 minutes', MINDATE(), MAXDATE(), 'Каждую минуту.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_05_MINUTES', 'Каждые 5 минут', '5 minutes', MINDATE(), MAXDATE(), 'Каждые 5 минут.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_10_MINUTES', 'Каждые 10 минут', '10 minutes', MINDATE(), MAXDATE(), 'Каждые 10 минут.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_15_MINUTES', 'Каждые 15 минут', '15 minutes', MINDATE(), MAXDATE(), 'Каждые 15 минут.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_30_MINUTES', 'Каждые 30 минут', '30 minutes', MINDATE(), MAXDATE(), 'Каждые 30 минут.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_01_HOUR', 'Каждый час', '1 hour', MINDATE(), MAXDATE(), 'Каждый час.');
SELECT CreateScheduler(null, GetType('job.scheduler'), 'EACH_01_DAY', 'Каждый день', '1 day', MINDATE(), MAXDATE(), 'Каждый день.');

SELECT SignOut();