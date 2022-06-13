DROP FUNCTION IF EXISTS AddNotification(uuid, uuid, uuid, uuid, uuid, timestamp with time zone);
DROP FUNCTION IF EXISTS CreateNotification(uuid, uuid, uuid, uuid, uuid, uuid, timestamp with time zone);
DROP FUNCTION IF EXISTS EditNotification(uuid, uuid, uuid, uuid, uuid, uuid, uuid, timestamp with time zone);

TRUNCATE db.notification;

ALTER TABLE db.notification
    ADD COLUMN state_old uuid NOT NULL REFERENCES db.state(id) ON DELETE CASCADE,
    ADD COLUMN state_new uuid NOT NULL REFERENCES db.state(id) ON DELETE CASCADE;
