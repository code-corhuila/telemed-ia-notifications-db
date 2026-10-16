CREATE TRIGGER trg_notification_updated_at
  BEFORE UPDATE ON notifications.notification
  FOR EACH ROW
  EXECUTE FUNCTION notifications.set_updated_at();
