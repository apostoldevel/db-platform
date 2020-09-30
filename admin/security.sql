--------------------------------------------------------------------------------
-- CUSTOMER SECURITY -----------------------------------------------------------
--------------------------------------------------------------------------------

INSERT INTO db.interface (sid, name, description) VALUES ('I:1:0:0', 'Гостевой', 'Интерфейс для всех');
INSERT INTO db.interface (sid, name, description) VALUES ('I:1:0:1', 'Администраторы', 'Интерфейс для администраторов');
INSERT INTO db.interface (sid, name, description) VALUES ('I:1:0:2', 'Операторы', 'Интерфейс для операторов системы');
INSERT INTO db.interface (sid, name, description) VALUES ('I:1:0:3', 'Пользователи', 'Интерфейс для пользователей');

SELECT CreateArea(null, GetAreaType('root'), 'root', 'Корень');
SELECT CreateArea(GetArea('root'), GetAreaType('guest'), 'guest', 'Гостевая зона');
SELECT CreateArea(GetArea('root'), GetAreaType('default'), 'default', 'По умолчанию');
SELECT CreateArea(GetArea('root'), GetAreaType('main'), 'main', 'Головной офис');
SELECT CreateArea(GetArea('main'), GetAreaType('department'), 'department', 'Удаленное подразделение');
SELECT CreateArea(GetArea('department'), GetAreaType('mobile'), 'mobile', 'Мобильное подразделение');

SELECT CreateGroup('system', 'Система', 'Группа для системных пользователей');

SELECT AddMemberToInterface(CreateGroup('guest', 'Гости', 'Группа для гостей системы'), GetInterface('I:1:0:0'));
SELECT AddMemberToInterface(CreateGroup('administrator', 'Администраторы', 'Группа для администраторов системы'), GetInterface('I:1:0:1'));
SELECT AddMemberToInterface(CreateGroup('operator', 'Операторы', 'Группа для операторов системы'), GetInterface('I:1:0:2'));
SELECT AddMemberToInterface(CreateGroup('user', 'Пользователи', 'Группа для пользователей системы'), GetInterface('I:1:0:3'));

SELECT AddMemberToGroup(CreateUser('admin', 'admin', 'Администратор', null,null, 'Администратор системы', true, false, GetArea('default')), GetGroup('administrator'));
SELECT AddMemberToGroup(CreateUser('daemon', 'daemon', 'Демон', null, null, 'Пользователь для вызова методов API', false, true, GetArea('root')), GetGroup('system'));

SELECT AddMemberToGroup(CreateUser('apibot', 'apibot', 'API клиент', null, null, 'Системная служба API', false, true, GetArea('root')), GetGroup('system'));
SELECT CreateUser('mailbot', 'mailbot', 'Mail клиент', null, null, 'Почтовый клиент', false, true, GetArea('root'));
