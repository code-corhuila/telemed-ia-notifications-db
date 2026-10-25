-- Unread badge and "unread" filter of a user's inbox, newest first.
CREATE INDEX idx_notification_recipient_unread
  ON notifications.notification (recipient_user_id, created_at DESC)
  WHERE read_at IS NULL;
