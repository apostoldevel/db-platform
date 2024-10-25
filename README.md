# База данных программной платформы **Апостол CRM**.

**Апостол CRM** - программная платформа (framework) для разработки серверной части коммерческих информационных систем (КИС).

ОПИСАНИЕ
-

**Система** состоит из двух частей - **платформы** и **конфигурации**.

- Платформа - это технологии и протоколы, встроенные службы и модули.
- Конфигурация - это бизнес логика конкретного проекта.

**Платформа** построена на базе фреймворка [Апостол](https://github.com/ufocomp/apostol), имеет модульную конструкцию и включает в себя встроенную поддержку СУБД PostgreSQL.

Подробное описание доступно в [Wiki](https://github.com/apostoldevel/db-platform/wiki).

УСТАНОВКА
-

### PostgreSQL

Для того чтобы установить PostgreSQL, воспользуйтесь инструкцией по [этой](https://www.postgresql.org/download/) ссылке.

### База данных

Для того чтобы установить базу данных, необходимо выполнить:

1. Прописать наименование базы данных в файле `db/sql/sets.psql`;
1. Прописать пароли для пользователей СУБД [libpq-pgpass](https://postgrespro.ru/docs/postgrespro/14/libpq-pgpass):
   ~~~
   $ sudo -iu postgres -H vim .pgpass
   ~~~
   ~~~
   *:*:*:kernel:kernel
   *:*:*:admin:admin
   *:*:*:daemon:daemon
   ~~~
1. Указать в файле настроек `/etc/postgresql/{version}/main/postgresql.conf` пути поиска схемы kernel:
   ~~~
   search_path = '"$user", kernel, public'	# schema names
   ~~~
1. Указать в файле настроек `/etc/postgresql/{version}/main/pg_hba.conf`:
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
   $ ./runme.sh --make
   ~~~

###### Параметр `--make` необходим для установки базы данных на сервер в первый раз. Для переустановки базы данных установочный скрипт можно запускать с параметром `--install`.
