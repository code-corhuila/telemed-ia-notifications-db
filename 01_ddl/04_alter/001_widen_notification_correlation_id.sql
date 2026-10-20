-- notifications-api and the identity outbox accept X-Correlation-Id values
-- of up to 128 characters, so the delivery record must store them untruncated.
ALTER TABLE notifications.notification
    ALTER COLUMN correlation_id TYPE varchar(128);
