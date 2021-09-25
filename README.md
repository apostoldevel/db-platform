# База данных программной платформы **Апостол CRM**.

**Апостол CRM** - программная платформа (framework) для разработки серверной части коммерческих информационных систем (КИС).

ОПИСАНИЕ
-

**Система** состоит из двух частей - **платформы** и **конфигурации**.

- Платформа - это технологии и протоколы, встроенные службы и модули.
- Конфигурация - это бизнес логика конкретного проекта.

**Платформа** построена на базе фреймворка [Апостол](https://github.com/ufocomp/apostol), имеет модульную конструкцию и включает в себя встроенную поддержку СУБД PostgreSQL.

Платформа состоит из следующих модулей (частей):

- [Сервера авторизации](https://github.com/ufocomp/module-AuthServer) (OAuth 2.0);
- [Сервера приложений](https://github.com/ufocomp/module-AppServer) (REST API);
- [Сервера сообщений](https://github.com/ufocomp/process-MessageServer) (SMTP/FCM/API);
- [Сервера потоковых данных](https://github.com/ufocomp/process-StreamServer) (UDP);
- [Веб-сервера](https://github.com/ufocomp/module-WebServer) (HTTP);
- [WebSocket API](https://github.com/ufocomp/module-WebSocketAPI) (WebSocket).

Платформа устанавливается на сервер из [исходных кодов](https://github.com/ufocomp/apostol-crm) в виде системной службы под операционную систему Linux.

[База данных](https://github.com/ufocomp/db-platform) платформы написана на языке программирования PL/pgSQL.

**Конфигурация** написана на языке программирования PL/pgSQL, используется для разработки бизнес-логики и RESTful API.

Конфигурация базируется на API платформы и дополняет её функциями необходимыми для решения задач конкретного проекта.

УСТАНОВКА
-

### PostgreSQL

Для того чтобы установить PostgreSQL воспользуйтесь инструкцией по [этой](https://www.postgresql.org/download/) ссылке.

### База данных

Для того чтобы установить базу данных необходимо выполнить:

1. Прописать наименование базы данных в файле db/sql/sets.conf
1. Прописать пароли для пользователей СУБД [libpq-pgpass](https://postgrespro.ru/docs/postgrespro/13/libpq-pgpass):
   ~~~
   $ sudo -iu postgres -H vim .pgpass
   ~~~
   ~~~
   *:*:*:kernel:kernel
   *:*:*:admin:admin
   *:*:*:daemon:daemon
   ~~~
1. Указать в файле настроек /etc/postgresql/{version}/main/postgresql.conf:
   Пути поиска схемы kernel:
   ~~~
   search_path = '"$user", kernel, public'	# schema names
   ~~~
1. Указать в файле настроек /etc/postgresql/{version}/main/pg_hba.conf:
   ~~~
   # TYPE  DATABASE        USER            ADDRESS                 METHOD
   local	all		kernel					md5
   local	all		admin					md5
   local	all		daemon					md5

   host	all		kernel		127.0.0.1/32		md5
   host	all		admin		127.0.0.1/32		md5
   host	all		daemon		127.0.0.1/32		md5
   ~~~
1. Выполнить:
   ~~~
   $ cd db/
   $ ./install.sh --make
   ~~~

###### Параметр `--make` необходим для установки базы данных в первый раз. Далее установочный скрипт можно запускать или без параметров или с параметром `--install`.

ДОКУМЕНТАЦИЯ
-

[Подробная документация доступа по этой ссылке](https://github.com/ufocomp/db-platform/wiki)
