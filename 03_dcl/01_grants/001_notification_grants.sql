-- -------------------------------------------------------------------------
-- Privileges for the notifications schema.
--
-- notifications_reader and notifications_writer are created by
-- telemed-ia-infra-postgres (postgres/init/01-instance.sh); notifications_app
-- is a member of both. Notifications are never deleted: delivery history is
-- an audit trail, so no role receives DELETE.
-- -------------------------------------------------------------------------

GRANT SELECT
  ON notifications.notification
  TO notifications_reader;

GRANT SELECT, INSERT, UPDATE
  ON notifications.notification
  TO notifications_writer;

ALTER DEFAULT PRIVILEGES IN SCHEMA notifications
  GRANT SELECT ON TABLES TO notifications_reader;

ALTER DEFAULT PRIVILEGES IN SCHEMA notifications
  GRANT SELECT, INSERT, UPDATE ON TABLES TO notifications_writer;
