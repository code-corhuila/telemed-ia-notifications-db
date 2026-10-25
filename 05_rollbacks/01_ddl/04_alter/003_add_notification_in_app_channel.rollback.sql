-- Fails if an IN_APP notification exists; remove those rows before rolling back.
ALTER TABLE notifications.notification
    DROP CONSTRAINT ck_notification_channel,
    ADD CONSTRAINT ck_notification_channel CHECK (channel IN ('EMAIL'));
