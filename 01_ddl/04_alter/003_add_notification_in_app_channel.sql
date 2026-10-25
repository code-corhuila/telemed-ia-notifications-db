-- HU-17/HU-18 inbox. IN_APP notifications are shown only in the inbox and
-- never e-mailed: those of professionals and the consultation PDF ready
-- notice. They are delivered when they are recorded (status SENT).
ALTER TABLE notifications.notification
    DROP CONSTRAINT ck_notification_channel,
    ADD CONSTRAINT ck_notification_channel CHECK (channel IN ('EMAIL', 'IN_APP'));
