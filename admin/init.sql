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

SELECT CreateScope(current_database(), current_database(), 'Область видимости текущей базы данных.');

SELECT CreateArea(null, GetAreaType('root'), GetScope(current_database()), 'root', 'Корень', null, '00000000-0000-4003-a000-000000000000');
SELECT CreateArea(GetArea('root'), GetAreaType('system'), GetScope(current_database()), 'system', 'Система', null, '00000000-0000-4003-a000-000000000001');
SELECT CreateArea(GetArea('root'), GetAreaType('guest'), GetScope(current_database()), 'guest', 'Гости', null, '00000000-0000-4003-a000-000000000002');
SELECT CreateArea(GetArea('root'), GetAreaType('root'), GetScope(current_database()), 'all', 'Всё', null, '00000000-0000-4003-a001-000000000000');
SELECT CreateArea(GetArea('all'), GetAreaType('default'), GetScope(current_database()), current_database(), 'По умолчанию', null, '00000000-0000-4003-a001-000000000001');
SELECT CreateArea(GetArea('all'), GetAreaType('main'), GetScope(current_database()), 'main', 'Головной офис', null, '00000000-0000-4003-a001-000000000002');
SELECT CreateArea(GetArea('main'), GetAreaType('remote'), GetScope(current_database()), 'remote', 'Удаленное подразделение', null, '00000000-0000-4003-a001-000000000003');
SELECT CreateArea(GetArea('remote'), GetAreaType('mobile'), GetScope(current_database()), 'mobile', 'Мобильное подразделение', null, '00000000-0000-4003-a001-000000000004');

SELECT CreateInterface('all', 'Все', 'Интерфейс для всех', '00000000-0000-4004-a000-000000000000');
SELECT CreateInterface('administrator', 'Администраторы', 'Интерфейс для администраторов', '00000000-0000-4004-a000-000000000001');
SELECT CreateInterface('user', 'Пользователи', 'Интерфейс для пользователей', '00000000-0000-4004-a000-000000000002');
SELECT CreateInterface('guest', 'Гости', 'Интерфейс для гостей', '00000000-0000-4004-a000-000000000003');

SELECT CreateGroup('system', 'Система', 'Группа для системных пользователей', '00000000-0000-4000-a000-000000000000');

SELECT AddMemberToInterface(CreateGroup('administrator', 'Администраторы', 'Группа для администраторов системы', '00000000-0000-4000-a000-000000000001'), '00000000-0000-4004-a000-000000000001');
SELECT AddMemberToInterface(CreateGroup('user', 'Пользователи', 'Группа для пользователей системы', '00000000-0000-4000-a000-000000000002'), '00000000-0000-4004-a000-000000000002');
SELECT AddMemberToInterface(CreateGroup('guest', 'Гости', 'Группа для гостей системы', '00000000-0000-4000-a000-000000000003'), '00000000-0000-4004-a000-000000000003');

SELECT AddMemberToGroup(CreateUser('admin', 'admin', 'Администратор', null,null, 'Администратор системы', true, false, GetArea('root'), '00000000-0000-4000-a001-000000000001'), GetGroup('administrator'));
SELECT CreateUser('daemon', 'daemon', 'Демон', null, null, 'Пользователь для вызова методов API', false, true, GetArea('system'), '00000000-0000-4000-a001-000000000002');

SELECT AddMemberToGroup(CreateUser('apibot', 'apibot', 'API клиент', null, null, 'Системная служба API', false, true, GetArea('root'), '00000000-0000-4000-a002-000000000001'), GetGroup('system'));
SELECT CreateUser('mailbot', 'mailbot', 'Mail клиент', null, null, 'Почтовый клиент', false, true, GetArea('root'), '00000000-0000-4000-a002-000000000002');
