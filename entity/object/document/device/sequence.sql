-- Последовательность для идентификаторов статусов устройства.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_STATUS
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

-- Последовательность для идентификаторов транзакций устройства.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_TRANSACTION
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;
