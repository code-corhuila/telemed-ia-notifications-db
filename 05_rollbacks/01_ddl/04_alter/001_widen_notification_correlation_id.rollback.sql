-- Fails if any stored correlation_id is longer than 100 characters; shorten
-- or clear those values before rolling back.
ALTER TABLE notifications.notification
    ALTER COLUMN correlation_id TYPE varchar(100);
