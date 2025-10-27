DROP FUNCTION IF EXISTS AddNotification(uuid, uuid, uuid, uuid, uuid, timestamp with time zone);
DROP FUNCTION IF EXISTS CreateNotification(uuid, uuid, uuid, uuid, uuid, uuid, timestamp with time zone);
DROP FUNCTION IF EXISTS EditNotification(uuid, uuid, uuid, uuid, uuid, uuid, uuid, timestamp with time zone);

DROP TABLE db.notification CASCADE;

\ir '../notification/create.psql'
