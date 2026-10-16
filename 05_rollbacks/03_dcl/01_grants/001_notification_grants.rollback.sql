ALTER DEFAULT PRIVILEGES IN SCHEMA notifications
  REVOKE SELECT, INSERT, UPDATE ON TABLES FROM notifications_writer;

ALTER DEFAULT PRIVILEGES IN SCHEMA notifications
  REVOKE SELECT ON TABLES FROM notifications_reader;

REVOKE SELECT, INSERT, UPDATE
  ON notifications.notification
  FROM notifications_writer;

REVOKE SELECT
  ON notifications.notification
  FROM notifications_reader;
