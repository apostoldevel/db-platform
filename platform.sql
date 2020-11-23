SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT SetDefaultArea(GetArea('default'));
SELECT SetArea(GetArea('default'));

SELECT InitWorkFlow();
SELECT InitEntity();
SELECT InitAPI();

SELECT FillCalendar(CreateCalendar(null, GetType('workday.calendar'), 'default.calendar', 'Календарь рабочих дней', 5, ARRAY[6,7], ARRAY[[1,1], [1,7], [2,23], [3,8], [5,1], [5,9], [6,12], [11,4]], '9 hour', '9 hour', '13 hour', '1 hour', 'Календарь рабочих дней.'), date(date_trunc('year', Now())), date((date_trunc('year', Now()) + interval '1 year') - interval '1 day'));

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

SELECT SignOut();