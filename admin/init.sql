--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

INSERT INTO db.area_type (id, code, name) VALUES ('00000000-0000-4002-a000-000000000000', 'root', 'Корень');
INSERT INTO db.area_type (id, code, name) VALUES ('00000000-0000-4002-a000-000000000001', 'system', 'Система');
INSERT INTO db.area_type (id, code, name) VALUES ('00000000-0000-4002-a000-000000000002', 'guest', 'Гость');
INSERT INTO db.area_type (id, code, name) VALUES ('00000000-0000-4002-a001-000000000000', 'default', 'По умолчанию');
INSERT INTO db.area_type (id, code, name) VALUES ('00000000-0000-4002-a001-000000000001', 'main', 'Главный');
INSERT INTO db.area_type (id, code, name) VALUES ('00000000-0000-4002-a001-000000000002', 'remote', 'Удаленный');
INSERT INTO db.area_type (id, code, name) VALUES ('00000000-0000-4002-a001-000000000003', 'mobile', 'Мобильный');

SELECT CreateScope(current_database(), current_database(), 'Область видимости текущей базы данных.', '00000000-0000-4006-a000-000000000000');

SELECT CreateArea('00000000-0000-4003-a000-000000000000', null, GetAreaType('root'), GetScope(current_database()), 'root', 'Корень');
SELECT CreateArea('00000000-0000-4003-a000-000000000001', GetArea('root'), GetAreaType('system'), GetScope(current_database()), 'system', 'Система');
SELECT CreateArea('00000000-0000-4003-a000-000000000002', GetArea('root'), GetAreaType('guest'), GetScope(current_database()), 'guest', 'Гости');
SELECT CreateArea('00000000-0000-4003-a001-000000000000', GetArea('root'), GetAreaType('root'), GetScope(current_database()), 'all', 'Всё');
SELECT CreateArea('00000000-0000-4003-a001-000000000001', GetArea('all'), GetAreaType('default'), GetScope(current_database()), current_database(), 'По умолчанию');
SELECT CreateArea('00000000-0000-4003-a001-000000000002', GetArea('all'), GetAreaType('main'), GetScope(current_database()), 'main', 'Головной офис');
SELECT CreateArea('00000000-0000-4003-a001-000000000003', GetArea('main'), GetAreaType('remote'), GetScope(current_database()), 'remote', 'Удаленное подразделение');
SELECT CreateArea('00000000-0000-4003-a001-000000000004', GetArea('remote'), GetAreaType('mobile'), GetScope(current_database()), 'mobile', 'Мобильное подразделение');

SELECT CreateInterface('all', 'Все', 'Интерфейс для всех', '00000000-0000-4004-a000-000000000000');
SELECT CreateInterface('administrator', 'Администраторы', 'Интерфейс для администраторов', '00000000-0000-4004-a000-000000000001');
SELECT CreateInterface('user', 'Пользователи', 'Интерфейс для пользователей', '00000000-0000-4004-a000-000000000002');
SELECT CreateInterface('guest', 'Гости', 'Интерфейс для гостей', '00000000-0000-4004-a000-000000000003');

SELECT CreateGroup('system', 'Система', 'Группа для системных пользователей', '00000000-0000-4000-a000-000000000000');

SELECT AddMemberToInterface(CreateGroup('administrator', 'Администраторы', 'Группа для администраторов системы', '00000000-0000-4000-a000-000000000001'), '00000000-0000-4004-a000-000000000001');
SELECT AddMemberToInterface(CreateGroup('user', 'Пользователи', 'Группа для пользователей системы', '00000000-0000-4000-a000-000000000002'), '00000000-0000-4004-a000-000000000002');
SELECT AddMemberToInterface(CreateGroup('guest', 'Гости', 'Группа для гостей системы', '00000000-0000-4000-a000-000000000003'), '00000000-0000-4004-a000-000000000003');

SELECT AddMemberToGroup(CreateUser('admin', 'admin', 'Администратор', null,null, 'Администратор системы', true, false, '00000000-0000-4000-a001-000000000001'), GetGroup('administrator'));
SELECT CreateUser('daemon', 'daemon', 'Демон', null, null, 'Пользователь для вызова методов API', false, true, '00000000-0000-4000-a001-000000000002');

SELECT AddMemberToGroup(CreateUser('apibot', 'apibot', 'API клиент', null, null, 'Системная служба API', false, true, '00000000-0000-4000-a002-000000000001'), GetGroup('system'));
SELECT CreateUser('mailbot', 'mailbot', 'Mail клиент', null, null, 'Почтовый клиент', false, true, '00000000-0000-4000-a002-000000000002');

SELECT CreateGroup('message', 'Сообщения', 'Группа для пользователей, которым разрешена рассылка массовых сообщений', '00000000-0000-4000-a000-000000000004');
SELECT AddMemberToGroup(GetUser('admin'), GetGroup('message'));

SELECT CreateGroup('replication', 'Репликация', 'Группа для пользователей, которым разрешено тиражировать данные в системе', '00000000-0000-4000-a000-000000000005');
