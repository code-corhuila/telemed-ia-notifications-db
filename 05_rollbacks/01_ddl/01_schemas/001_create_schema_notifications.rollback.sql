-- The notifications schema is owned by telemed-ia-infra-postgres
-- (01-instance.sh) and holds the Liquibase control tables through the
-- search_path of notifications_app, so it must never be dropped here.
-- Rolling back only undoes what ddl-schemas-001 granted.
REVOKE USAGE ON SCHEMA notifications FROM notifications_reader, notifications_writer;
